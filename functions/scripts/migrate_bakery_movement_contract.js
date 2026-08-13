'use strict';

const admin = require('firebase-admin');

const CANONICAL_BAKERY_PACK_ID = 'bakery';
const CANONICAL_BAKERY_SERVICES = Object.freeze({
  bakery_celebration_cakes: 'Celebration Cakes',
  bakery_cupcakes_treat_boxes: 'Cupcakes & Treat Boxes',
  bakery_brownies_traybakes: 'Brownies & Traybakes',
  bakery_custom_event_business_bakes: 'Custom / Event / Business Bakes',
});
const MOVEMENT_IDS = Object.freeze([
  'customer_visits_business',
  'local_delivery',
]);
const MOVEMENT_CAPABILITY_IDS = new Set([
  'customer_visits_business',
  'customer_drops_off',
  'customer_collects',
  'business_visits_customer',
  'business_collects',
  'business_returns',
  'local_delivery',
  'nationwide_delivery',
  'digital_delivery',
]);
const CANONICAL_GROUPS = Object.freeze([{
  id: 'receive',
  heading: 'How would you like to receive your order?',
  options: [
    { value: 'collection', label: 'Collect' },
    { value: 'localDelivery', label: 'Local delivery' },
  ],
}]);

// Filled only with reviewed Class A/B records. A dry-run does not need this
// list; --apply refuses to write if it is empty or no longer matches it.
const APPROVED_ALLOWLIST = Object.freeze([
  {
    linkId: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1_big_baps_1784566251566898',
    serviceId: 'service_bakery_bakery_custom_event_business_bakes_1785707791206208',
    classification: 'A. EXACT CANONICAL MATCH',
  },
]);

const text = (value) => typeof value === 'string' ? value.trim() : '';
const array = (value) => Array.isArray(value) ? value : [];
const clone = (value) => JSON.parse(JSON.stringify(value));

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return Number.isInteger(value)
    ? { integerValue: String(value) } : { doubleValue: value };
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(firestoreValue) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, firestoreValue(item)])) } };
}

function plainFirestoreValue(value) {
  if (!value) return null;
  if (Object.prototype.hasOwnProperty.call(value, 'stringValue')) return value.stringValue;
  if (Object.prototype.hasOwnProperty.call(value, 'booleanValue')) return value.booleanValue;
  if (Object.prototype.hasOwnProperty.call(value, 'integerValue')) return Number(value.integerValue);
  if (Object.prototype.hasOwnProperty.call(value, 'doubleValue')) return value.doubleValue;
  if (Object.prototype.hasOwnProperty.call(value, 'nullValue')) return null;
  if (value.arrayValue) return array(value.arrayValue.values).map(plainFirestoreValue);
  if (value.mapValue) return Object.fromEntries(Object.entries(value.mapValue.fields || {})
    .map(([key, item]) => [key, plainFirestoreValue(item)]));
  return value;
}

function restFirestore(project, accessToken) {
  const root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const headers = { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' };
  async function request(url, options = {}) {
    const response = await fetch(url, { ...options, headers: { ...headers, ...(options.headers || {}) } });
    if (!response.ok) throw new Error(`Firestore REST ${response.status}: ${await response.text()}`);
    return response.status === 204 ? {} : response.json();
  }
  function docFromWire(wire) {
    const id = wire.name.split('/').pop();
    return {
      id,
      ref: { path: wire.name.replace(`${root}/`, '') },
      exists: true,
      data: () => Object.fromEntries(Object.entries(wire.fields || {})
        .map(([key, item]) => [key, plainFirestoreValue(item)])),
    };
  }
  function docRef(id) {
    const url = `${root}/public_booking_links/${encodeURIComponent(id)}`;
    return {
      path: `public_booking_links/${id}`,
      async get() { return docFromWire(await request(url)); },
    };
  }
  return {
    collection() {
      return {
        async get() {
          const result = await request(`${root}/public_booking_links?pageSize=1000`);
          return { docs: array(result.documents).map(docFromWire) };
        },
        doc: docRef,
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) { return ref.get(); },
        async update(ref, fields) {
          await request(`${root}/${ref.path}?updateMask.fieldPaths=services`, {
            method: 'PATCH',
            body: JSON.stringify({ fields: { services: firestoreValue(fields.services) } }),
          });
        },
      };
      await callback(transaction);
    },
  };
}

function canonicalKey(service) {
  const starter = text(service && service.starterTemplateId);
  if (starter && Object.prototype.hasOwnProperty.call(CANONICAL_BAKERY_SERVICES, starter)) {
    return starter;
  }
  const id = text(service && service.id);
  const exact = Object.keys(CANONICAL_BAKERY_SERVICES).find((key) => id === key);
  if (exact) return exact;
  const prefixed = Object.keys(CANONICAL_BAKERY_SERVICES).find(
    (key) => id.startsWith(`service_${key}_`),
  );
  return prefixed || '';
}

function hasCanonicalStarterIdentity(service) {
  const starter = text(service && service.starterTemplateId);
  return text(service && service.starterPackId) === CANONICAL_BAKERY_PACK_ID &&
    Object.prototype.hasOwnProperty.call(CANONICAL_BAKERY_SERVICES, starter);
}

function canonicalCapabilities(service) {
  return array(service && service.serviceCapabilityIds)
    .map(text).filter(Boolean);
}

function authoritativeFulfilment(service) {
  // The current canonical starter definition is authoritative for an exact
  // starter identity even when the materialised record omitted its IDs.
  if (hasCanonicalStarterIdentity(service)) return true;
  const ids = new Set(canonicalCapabilities(service));
  const movement = [...ids].filter((id) => MOVEMENT_CAPABILITY_IDS.has(id)).sort();
  return JSON.stringify(movement) === JSON.stringify([...MOVEMENT_IDS].sort());
}

function classifyService(service) {
  const key = canonicalKey(service);
  if (hasCanonicalStarterIdentity(service) && key) return 'A. EXACT CANONICAL MATCH';
  // A materialised service ID containing the stable canonical key is an
  // explicit relationship, unlike a display-name match.
  if (key && authoritativeFulfilment(service)) return 'B. DETERMINISTIC LEGACY MATCH';
  return 'C. AMBIGUOUS';
}

function servicePatch(service, classification) {
  if (!classification.startsWith('A.') && !classification.startsWith('B.')) {
    return { errors: ['Class C service is not allowlisted'] };
  }
  if (!authoritativeFulfilment(service)) {
    return { errors: ['stored capabilities do not prove exactly Collection and Local delivery'] };
  }
  const ids = canonicalCapabilities(service);
  const nonMovement = ids.filter((id) => !MOVEMENT_CAPABILITY_IDS.has(id));
  const nextIds = [...new Set([...nonMovement, ...MOVEMENT_IDS])];
  const contract = service.capabilityContract || {};
  const patch = {};
  if (JSON.stringify(ids) !== JSON.stringify(nextIds)) patch.serviceCapabilityIds = nextIds;
  if (JSON.stringify(array(contract.movementCapabilityIds)) !== JSON.stringify(MOVEMENT_IDS)) {
    patch['capabilityContract.movementCapabilityIds'] = MOVEMENT_IDS;
  }
  if (JSON.stringify(array(contract.movementChoiceGroups)) !== JSON.stringify(CANONICAL_GROUPS)) {
    patch['capabilityContract.movementChoiceGroups'] = CANONICAL_GROUPS;
  }
  return { errors: [], patch };
}

function isTarget(service) {
  return service && service.requestFlowOptions &&
    service.requestFlowOptions.showFulfilmentChoice === true &&
    array(service.capabilityContract && service.capabilityContract.movementChoiceGroups).length === 0;
}

function reportEntry(doc, service) {
  const classification = classifyService(service);
  const result = servicePatch(service, classification);
  return {
    bookingLinkDocumentId: doc.id,
    businessProfileId: text(doc.data && doc.data.businessProfileId),
    serviceId: text(service.id),
    serviceName: text(service.name),
    isActive: service.isActive !== false,
    requestType: text(service.requestType),
    serviceFlow: text(service.serviceFlow),
    serviceCapabilityIds: canonicalCapabilities(service),
    movementCapabilityIds: array(service.capabilityContract && service.capabilityContract.movementCapabilityIds),
    movementChoiceGroups: array(service.capabilityContract && service.capabilityContract.movementChoiceGroups),
    matchesCurrentCanonicalBakeryService: Boolean(canonicalKey(service)),
    canonicalServiceKey: canonicalKey(service),
    authoritativeFulfilmentExactlyCollectionAndLocalDelivery: authoritativeFulfilment(service),
    classification,
    patch: result.patch || {},
    errors: result.errors,
  };
}

async function buildPlan({ firestore }) {
  const snapshot = await firestore.collection('public_booking_links').get();
  const plan = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    if (data.isActive !== true) continue;
    for (const service of array(data.services)) {
      if (service.isActive === false || !isTarget(service)) continue;
      plan.push({ ...reportEntry({ id: doc.id, data }, service), path: doc.ref ? doc.ref.path : `public_booking_links/${doc.id}` });
    }
  }
  return plan;
}

function allowlistKey(entry) {
  return `${entry.bookingLinkDocumentId}/${entry.serviceId}`;
}

async function applyApproved({ firestore, plan }) {
  if (APPROVED_ALLOWLIST.length === 0) throw new Error('Approved allowlist is empty; dry-run only.');
  const approved = new Set(APPROVED_ALLOWLIST.map((item) => `${item.linkId}/${item.serviceId}`));
  const candidates = plan.filter((entry) => approved.has(allowlistKey(entry)));
  if (candidates.length !== approved.size || candidates.some((entry) => entry.classification.startsWith('C.') || Object.keys(entry.errors).length)) {
    throw new Error('Reviewed allowlist no longer matches live Class A/B evidence.');
  }
  let writes = 0;
  for (const candidate of candidates) {
    const ref = firestore.collection('public_booking_links').doc(candidate.bookingLinkDocumentId);
    await firestore.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      const data = snap.data() || {};
      const service = array(data.services).find((item) => text(item.id) === candidate.serviceId);
      if (!snap.exists || !data.isActive || text(data.businessProfileId) !== candidate.businessProfileId ||
          !service || service.isActive === false || text(service.requestType) !== candidate.requestType ||
          text(service.serviceFlow) !== candidate.serviceFlow || !isTarget(service) ||
          classifyService(service) !== candidate.classification || !authoritativeFulfilment(service)) {
        throw new Error(`Live evidence changed for ${candidate.path}; aborting.`);
      }
      const next = array(data.services).map((item) => {
        if (text(item.id) !== candidate.serviceId) return item;
        const updated = clone(item);
        const patch = servicePatch(item, candidate.classification).patch;
        if (patch.serviceCapabilityIds) updated.serviceCapabilityIds = patch.serviceCapabilityIds;
        updated.capabilityContract = { ...(updated.capabilityContract || {}) };
        if (patch['capabilityContract.movementCapabilityIds']) updated.capabilityContract.movementCapabilityIds = patch['capabilityContract.movementCapabilityIds'];
        if (patch['capabilityContract.movementChoiceGroups']) updated.capabilityContract.movementChoiceGroups = patch['capabilityContract.movementChoiceGroups'];
        return updated;
      });
      transaction.update(ref, { services: next });
      writes += 1;
    });
  }
  return writes;
}

async function main() {
  const projectIndex = process.argv.indexOf('--project');
  const project = projectIndex >= 0 ? text(process.argv[projectIndex + 1]) : '';
  if (!project) throw new Error('Usage: node migrate_bakery_movement_contract.js --project PROJECT_ID [--apply]');
  let firestore;
  if (text(process.env.BAKERY_FIRESTORE_ACCESS_TOKEN)) {
    firestore = restFirestore(project, text(process.env.BAKERY_FIRESTORE_ACCESS_TOKEN));
  } else {
    if (admin.apps.length === 0) admin.initializeApp({ projectId: project });
    firestore = admin.firestore();
  }
  const plan = await buildPlan({ firestore });
  let writesPerformed = 0;
  if (process.argv.includes('--apply')) writesPerformed = await applyApproved({ firestore, plan });
  process.stdout.write(`${JSON.stringify({
    project, mode: process.argv.includes('--apply') ? 'apply' : 'dry-run',
    totalInconsistentServices: plan.length,
    approvedCandidates: plan.filter((entry) => entry.classification.startsWith('A.') || entry.classification.startsWith('B.')),
    rejectedCandidates: plan.filter((entry) => entry.classification.startsWith('C.')),
    writesPerformed, plan,
  }, null, 2)}\n`);
}

if (require.main === module) main().catch((error) => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });

module.exports = {
  CANONICAL_GROUPS, MOVEMENT_IDS, APPROVED_ALLOWLIST, buildPlan, classifyService,
  servicePatch, authoritativeFulfilment, isTarget, canonicalKey, applyApproved,
};
