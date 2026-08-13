'use strict';

const admin = require('firebase-admin');

const CANONICAL_MOVEMENT_IDS = Object.freeze([
  'customer_collects',
  'local_delivery',
]);
const CANONICAL_MOVEMENT_GROUPS = Object.freeze([
  {
    id: 'completion',
    heading: 'How would you like to receive your completed item?',
    options: [{ value: 'customerCollects', label: "I'll collect it" }],
  },
  {
    id: 'receive',
    heading: 'How would you like to receive your order?',
    options: [{ value: 'localDelivery', label: 'Local delivery' }],
  },
]);

// Exact production records only. Test links and legacy records without a
// capability contract are deliberately not in this allowlist.
const CLASS_B_ALLOWLIST = Object.freeze([
  {
    linkId: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1_big_baps_1784566251566898',
    serviceId: 'service_bakery_bakery_custom_event_business_bakes_1785707791206208',
    profileId: 'big_baps_1784566251566898',
    kind: 'bakery-movement-contract',
  },
  {
    linkId: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1_dave_s_delicious_delicacies_1783690765014760',
    serviceId: 'service_cake_orders_1783708435784092',
    ownerUid: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1',
    profileId: 'dave_s_delicious_delicacies_1783690765014760',
    kind: 'order-flow',
  },
]);

const readString = (value) => typeof value === 'string' ? value.trim() : '';

function argument(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? '' : readString(process.argv[i + 1]);
}

function findService(data, serviceId) {
  return (Array.isArray(data && data.services) ? data.services : [])
    .find((service) => readString(service && service.id) === serviceId) || null;
}

function servicePatch(candidate, service) {
  if (!service) return { errors: ['service is missing'] };
  const errors = [];
  const currentFlow = readString(service.serviceFlow);
  const contract = service.capabilityContract;
  if (candidate.kind === 'order-flow') {
    if (readString(service.requestType) !== 'orderRequest') {
      errors.push('service requestType is not orderRequest');
    }
    if (service.requestFlowOptions &&
        service.requestFlowOptions.showFulfilmentChoice === true) {
      errors.push('fulfilment-enabled legacy service has no capability contract');
    }
    if (errors.length) return { errors };
    if (currentFlow === 'order') return { errors: [], patch: {} };
    return { errors, patch: { serviceFlow: 'order' } };
  }

  if (readString(service.requestType) !== 'orderRequest') {
    errors.push('service requestType is not orderRequest');
  }
  if (currentFlow !== 'order') errors.push('serviceFlow is not order');
  if (!contract || !Array.isArray(service.serviceCapabilityIds)) {
    errors.push('capability contract or capability IDs are missing');
    return { errors };
  }
  const ids = [...new Set(service.serviceCapabilityIds.map(readString).filter(Boolean))]
    .sort();
  const movementIds = [...new Set([...
    ids.filter((id) => CANONICAL_MOVEMENT_IDS.includes(id)),
  ])].sort();
  if (JSON.stringify(movementIds) !== JSON.stringify([...CANONICAL_MOVEMENT_IDS].sort())) {
    errors.push('stored capability IDs do not prove both intended movement capabilities');
  }
  if (errors.length) return { errors };
  const sameGroups = JSON.stringify(contract.movementChoiceGroups || []) ===
    JSON.stringify(CANONICAL_MOVEMENT_GROUPS);
  const sameMovementIds = JSON.stringify(contract.movementCapabilityIds || []) ===
    JSON.stringify(CANONICAL_MOVEMENT_IDS);
  if (sameGroups && sameMovementIds) return { errors: [], patch: {} };
  return {
    errors: [],
    patch: {
      'capabilityContract.movementChoiceGroups': CANONICAL_MOVEMENT_GROUPS,
      'capabilityContract.movementCapabilityIds': CANONICAL_MOVEMENT_IDS,
    },
  };
}

async function buildPlan({ firestore }) {
  const plan = [];
  for (const candidate of CLASS_B_ALLOWLIST) {
    const ref = firestore.collection('public_booking_links').doc(candidate.linkId);
    const snapshot = await ref.get();
    const data = snapshot.data() || {};
    const service = findService(data, candidate.serviceId);
    const result = servicePatch(candidate, service);
    const profileMatches = readString(data.businessProfileId) === candidate.profileId;
    if (!profileMatches) result.errors.push('booking link profile does not match allowlist');
    plan.push({
      path: ref.path,
      serviceId: candidate.serviceId,
      profileId: candidate.profileId,
      before: {
        requestType: readString(service && service.requestType),
        serviceFlow: readString(service && service.serviceFlow),
        showFulfilmentChoice: service && service.requestFlowOptions
          ? service.requestFlowOptions.showFulfilmentChoice === true
          : false,
        serviceCapabilityIds: service && Array.isArray(service.serviceCapabilityIds)
          ? service.serviceCapabilityIds
          : [],
        movementChoiceGroups: service && service.capabilityContract
          ? service.capabilityContract.movementChoiceGroups || []
          : [],
      },
      patch: result.patch || {},
      errors: result.errors,
      approved: result.errors.length === 0,
    });
  }
  return plan;
}

async function applyPlan() {
  if (CLASS_B_ALLOWLIST.length !== 2 ||
      CLASS_B_ALLOWLIST[1].kind !== 'order-flow') {
    throw new Error('Refusing Class B apply because the exact approved allowlist changed.');
  }
  const project = argument('project');
  if (admin.apps.length === 0) admin.initializeApp({ projectId: project });
  const firestore = admin.firestore();
  const candidate = CLASS_B_ALLOWLIST[1];
  const ref = firestore.collection('public_booking_links').doc(candidate.linkId);
  let protectedBefore;
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() || {};
    const service = findService(data, candidate.serviceId);
    if (!snapshot.exists || !service) throw new Error('Approved Class B service is missing.');
    if (readString(data.businessProfileId) !== candidate.profileId) {
      throw new Error('Booking-link profile ownership changed.');
    }
    if (readString(data.ownerUid) !== candidate.ownerUid) {
      throw new Error('Booking-link owner ownership changed.');
    }
    if (readString(service.requestType) !== 'orderRequest') {
      throw new Error('Approved service requestType changed.');
    }
    if (readString(service.serviceFlow)) {
      throw new Error('Approved serviceFlow is no longer missing/empty.');
    }
    protectedBefore = JSON.parse(JSON.stringify(data));
    protectedBefore.services = protectedBefore.services.map((item) => {
      if (readString(item && item.id) === candidate.serviceId) {
        const copy = { ...item };
        delete copy.serviceFlow;
        return copy;
      }
      return item;
    });
    const services = data.services.map((item) =>
      readString(item && item.id) === candidate.serviceId
        ? { ...item, serviceFlow: 'order' }
        : item,
    );
    transaction.update(ref, { services });
  });
  const after = await ref.get();
  const afterData = after.data() || {};
  const afterService = findService(afterData, candidate.serviceId);
  const protectedAfter = JSON.parse(JSON.stringify(afterData));
  protectedAfter.services = protectedAfter.services.map((item) => {
    if (readString(item && item.id) === candidate.serviceId) {
      const copy = { ...item };
      delete copy.serviceFlow;
      return copy;
    }
    return item;
  });
  if (readString(afterService && afterService.serviceFlow) !== 'order' ||
      JSON.stringify(protectedBefore) !== JSON.stringify(protectedAfter)) {
    throw new Error('Post-apply verification failed: more than serviceFlow changed.');
  }
  return { writesPerformed: 1, path: ref.path, serviceId: candidate.serviceId };
}

async function main() {
  const project = argument('project');
  if (!project) throw new Error('Usage: node migrate_class_b_service_consistency.js --project PROJECT_ID [--apply]');
  if (admin.apps.length === 0) admin.initializeApp({ projectId: project });
  let applied = null;
  if (process.argv.includes('--apply')) applied = await applyPlan();
  const plan = await buildPlan({ firestore: admin.firestore() });
  process.stdout.write(`${JSON.stringify({
    project,
    mode: applied ? 'apply' : 'dry-run',
    allowlistCount: CLASS_B_ALLOWLIST.length,
    approvedCandidates: plan.filter((entry) => entry.approved && Object.keys(entry.patch).length),
    rejectedCandidates: plan.filter((entry) => !entry.approved),
    alreadyConsistent: plan.filter((entry) => entry.approved && !Object.keys(entry.patch).length),
    writesPerformed: applied ? applied.writesPerformed : 0,
    applied,
    plan,
  }, null, 2)}\n`);
}

if (require.main === module) main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});

module.exports = {
  CANONICAL_MOVEMENT_GROUPS,
  CANONICAL_MOVEMENT_IDS,
  CLASS_B_ALLOWLIST,
  buildPlan,
  findService,
  servicePatch,
};
