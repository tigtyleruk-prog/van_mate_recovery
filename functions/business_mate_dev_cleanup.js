'use strict';

const {
  recordBelongsToBusiness,
} = require('./business_profile_scoping');
const DEFAULT_BUSINESS_PROFILE_ID = 'default_business';
const FORBIDDEN_PROJECT_MARKERS = ['prod', 'production', 'live'];
const DEVELOPMENT_MARKERS = ['dev', 'development', 'test', 'testing', 'sandbox', 'demo', 'local', 'emulator'];

const USER_RECORD_COLLECTIONS = [
  'van_job_requests',
  'van_jobs',
  'van_quotes',
  'van_pin_requests',
];

const PUBLIC_RECORD_COLLECTIONS = [
  'public_job_requests',
  'public_quote_responses',
  'public_quote_response_tokens',
  'van_job_requests',
  'van_pin_requests',
];

function clean(value) {
  return value == null ? '' : String(value).trim();
}

function normalizedAllowlist(values) {
  if (Array.isArray(values)) {
    return values.map(clean).filter(Boolean);
  }
  return clean(values).split(',').map(clean).filter(Boolean);
}

function hasDevelopmentMarker(value) {
  const lowered = clean(value).toLowerCase();
  return DEVELOPMENT_MARKERS.some((marker) =>
    new RegExp(`(^|[-_])${marker}($|[-_0-9])`).test(lowered),
  );
}

function assertDevelopmentProject({
  actualProjectId,
  expectedProjectId,
  allowedProjectIds = [],
}) {
  const actual = clean(actualProjectId);
  const expected = clean(expectedProjectId);
  if (!actual || !expected) {
    throw new Error(
      'Set BUSINESS_MATE_DEV_PROJECT_ID and pass --project with the development project ID.',
    );
  }
  if (actual !== expected) {
    throw new Error(`Refusing project ${actual}; expected development project ${expected}.`);
  }
  const lowered = actual.toLowerCase();
  if (FORBIDDEN_PROJECT_MARKERS.some((marker) => lowered.includes(marker))) {
    throw new Error(`Refusing project ${actual}; it looks like a production project.`);
  }
  const allowlist = new Set(normalizedAllowlist(allowedProjectIds));
  if (!hasDevelopmentMarker(actual) && !allowlist.has(actual)) {
    throw new Error(
      `Refusing project ${actual}; it is not clearly a development project or explicitly allowlisted.`,
    );
  }
  return actual;
}

function assertDevelopmentStorageBucket({
  storageBucket,
  projectId,
  allowedStorageBuckets = [],
}) {
  const bucket = clean(storageBucket);
  if (!bucket) return '';
  const project = clean(projectId);
  const projectBuckets = new Set([
    `${project}.appspot.com`,
    `${project}.firebasestorage.app`,
    ...normalizedAllowlist(allowedStorageBuckets),
  ]);
  if (!project || !projectBuckets.has(bucket)) {
    throw new Error(
      `Refusing Storage bucket ${bucket}; it is not verified for development project ${project || '(missing)'}.`,
    );
  }
  return bucket;
}

function normalizeTarget({ ownerUid, businessProfileId }) {
  const owner = clean(ownerUid);
  const profile = clean(businessProfileId) || DEFAULT_BUSINESS_PROFILE_ID;
  if (!/^[A-Za-z0-9_-]{6,180}$/.test(owner)) {
    throw new Error('An explicit valid --owner-uid is required.');
  }
  if (!/^[A-Za-z0-9_-]{1,180}$/.test(profile)) {
    throw new Error('Business profile ID is invalid.');
  }
  return {
    ownerUid: owner,
    businessProfileId: profile,
    publicConfigId:
      profile === DEFAULT_BUSINESS_PROFILE_ID ? owner : `${owner}_${profile}`,
  };
}

function targetKey(target) {
  return `${target.ownerUid}:${target.businessProfileId}`;
}

function assertDevelopmentTarget(target, { allowedTargets = [] } = {}) {
  const allowlist = new Set(normalizedAllowlist(allowedTargets));
  if (
    !allowlist.has(targetKey(target)) &&
    !hasDevelopmentMarker(target.ownerUid) &&
    !hasDevelopmentMarker(target.businessProfileId)
  ) {
    throw new Error(
      'Refusing target; use a clearly marked test/development owner or business ID, or explicitly allowlist ownerUid:businessProfileId.',
    );
  }
  return target;
}

function ownershipStatus(data, target, { requireOwner = false } = {}) {
  const record = data && typeof data === 'object' ? data : {};
  const owner = clean(record.ownerUid || record.ownerId);
  if (owner && owner !== target.ownerUid) return 'other';
  if (requireOwner && !owner) return 'uncertain';
  if (recordBelongsToBusiness(record, target.businessProfileId)) return 'match';
  return clean(record.businessProfileId) ? 'other' : 'uncertain';
}

function recordBelongsToTarget(data, target, { requireOwner = false } = {}) {
  return ownershipStatus(data, target, { requireOwner }) === 'match';
}

function hasProtectedFinancialData(data) {
  const record = data && typeof data === 'object' ? data : {};
  return Boolean(
    clean(record.invoiceNumber) ||
      clean(record.invoiceId) ||
      record.invoiceCreated === true ||
      record.paid === true ||
      (record.invoice &&
        (clean(record.invoice.invoiceNumber) || clean(record.invoice.id))),
  );
}

function directConfigurationTargets(target) {
  const base = `users/${target.ownerUid}`;
  const targets = [
    {
      path: `${base}/van_booking_link_settings/${
        target.businessProfileId === DEFAULT_BUSINESS_PROFILE_ID
          ? 'settings'
          : target.businessProfileId
      }`,
      requireOwner: false,
    },
    {
      path: `public_booking_links/${target.publicConfigId}`,
      requireOwner: true,
    },
  ];
  if (target.businessProfileId === DEFAULT_BUSINESS_PROFILE_ID) {
    targets.push(
      { path: `${base}/van_business_profile/profile`, requireOwner: false },
      { path: `${base}/van_job_services/library`, requireOwner: false },
      { path: `${base}/van_custom_job_questions/library`, requireOwner: false },
      { path: `${base}/van_settings/quote_extras`, requireOwner: false },
    );
  }
  return targets;
}

function directConfigurationPaths(target) {
  return directConfigurationTargets(target).map((entry) => entry.path);
}

function buildCleanupPlan(input) {
  const target = assertDevelopmentTarget(normalizeTarget(input), {
    allowedTargets: input.allowedTargets,
  });
  return {
    target,
    directDocumentPaths: directConfigurationPaths(target),
    userCollectionPaths: USER_RECORD_COLLECTIONS.map(
      (collection) => `users/${target.ownerUid}/${collection}`,
    ),
    publicCollections: [...PUBLIC_RECORD_COLLECTIONS],
    preservedCollections: [
      `users/${target.ownerUid}/van_invoices`,
      `users/${target.ownerUid}/fcmTokens`,
    ],
    authenticationUsersDeleted: false,
  };
}

function extractSafeBookingPhotoPaths(data, target, requestId) {
  const requestIds = new Set([
    clean(requestId),
    clean(data && data.requestId),
    clean(data && data.jobRequestId),
  ].filter(Boolean));
  const prefixes = [...requestIds].map(
    (id) => `booking_requests/${target.ownerUid}/${id}/photos/`,
  );
  const paths = new Set();
  const visit = (value) => {
    if (Array.isArray(value)) {
      value.forEach(visit);
      return;
    }
    if (!value || typeof value !== 'object') return;
    for (const [key, item] of Object.entries(value)) {
      if (['storagePath', 'storage_path', 'path'].includes(key)) {
        const path = clean(item);
        if (prefixes.some((prefix) => path.startsWith(prefix))) paths.add(path);
      } else {
        visit(item);
      }
    }
  };
  visit(data);
  return [...paths];
}

async function collectCleanupCandidates({ firestore, target }) {
  const documents = new Map();
  const skippedFinancialDocuments = [];
  const uncertainOwnershipDocuments = [];
  const photoPaths = new Set();
  const locationCounts = new Map();

  const countFor = (kind, path) => {
    if (!locationCounts.has(path)) {
      locationCounts.set(path, {
        kind,
        path,
        scanned: 0,
        selected: 0,
        protectedFinancial: 0,
        uncertainOwnership: 0,
        otherBusiness: 0,
      });
    }
    return locationCounts.get(path);
  };

  for (const targetDocument of directConfigurationTargets(target)) {
    countFor('document', targetDocument.path);
  }
  for (const collection of USER_RECORD_COLLECTIONS) {
    countFor('collection', `users/${target.ownerUid}/${collection}`);
  }
  for (const collection of PUBLIC_RECORD_COLLECTIONS) {
    countFor('collection', collection);
  }

  const addDocument = (
    snapshot,
    location,
    { requireOwner = false, direct = false } = {},
  ) => {
    if (!snapshot.exists) return;
    const counts = locationCounts.get(location);
    counts.scanned += 1;
    const data = snapshot.data() || {};
    const status = ownershipStatus(data, target, { requireOwner });
    if (status === 'uncertain') {
      counts.uncertainOwnership += 1;
      uncertainOwnershipDocuments.push(snapshot.ref.path);
      return;
    }
    if (status === 'other') {
      counts.otherBusiness += 1;
      return;
    }
    if (hasProtectedFinancialData(data)) {
      counts.protectedFinancial += 1;
      skippedFinancialDocuments.push(snapshot.ref.path);
      return;
    }
    counts.selected += 1;
    documents.set(snapshot.ref.path, snapshot.ref);
    if (!direct) {
      for (const path of extractSafeBookingPhotoPaths(data, target, snapshot.id)) {
        photoPaths.add(path);
      }
    }
  };

  for (const targetDocument of directConfigurationTargets(target)) {
    const snapshot = await firestore.doc(targetDocument.path).get();
    addDocument(snapshot, targetDocument.path, {
      requireOwner: targetDocument.requireOwner,
      direct: true,
    });
  }

  for (const collection of USER_RECORD_COLLECTIONS) {
    const path = `users/${target.ownerUid}/${collection}`;
    const snapshot = await firestore.collection(path).get();
    snapshot.docs.forEach((document) => addDocument(document, path));
  }

  for (const collection of PUBLIC_RECORD_COLLECTIONS) {
    const found = new Map();
    for (const ownerField of ['ownerUid', 'ownerId']) {
      const snapshot = await firestore
        .collection(collection)
        .where(ownerField, '==', target.ownerUid)
        .get();
      snapshot.docs.forEach((document) => found.set(document.ref.path, document));
    }
    found.forEach((document) =>
      addDocument(document, collection, { requireOwner: true }));
  }

  return {
    documentRefs: [...documents.values()],
    documentPaths: [...documents.keys()].sort(),
    photoPaths: [...photoPaths].sort(),
    skippedFinancialDocuments: skippedFinancialDocuments.sort(),
    uncertainOwnershipDocuments: uncertainOwnershipDocuments.sort(),
    locationCounts: [...locationCounts.values()],
  };
}

async function executeCleanup({ firestore, bucket, candidates }) {
  if (candidates.photoPaths.length > 0 && !bucket) {
    throw new Error('A verified development Storage bucket is required for booking photos.');
  }
  for (const path of candidates.photoPaths) {
    await bucket.file(path).delete({ ignoreNotFound: true });
  }
  for (const reference of candidates.documentRefs) {
    if (typeof firestore.recursiveDelete === 'function') {
      await firestore.recursiveDelete(reference);
    } else {
      await reference.delete();
    }
  }
}

module.exports = {
  DEFAULT_BUSINESS_PROFILE_ID,
  USER_RECORD_COLLECTIONS,
  PUBLIC_RECORD_COLLECTIONS,
  assertDevelopmentProject,
  assertDevelopmentStorageBucket,
  assertDevelopmentTarget,
  normalizeTarget,
  ownershipStatus,
  recordBelongsToTarget,
  hasProtectedFinancialData,
  directConfigurationPaths,
  buildCleanupPlan,
  extractSafeBookingPhotoPaths,
  collectCleanupCandidates,
  executeCleanup,
};
