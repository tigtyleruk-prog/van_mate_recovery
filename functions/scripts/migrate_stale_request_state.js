'use strict';

const admin = require('firebase-admin');
const crypto = require('node:crypto');

const OWNER_UID = 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1';
const BUSINESS_PROFILE_ID = 'big_baps_1784566251566898';
const REQUEST_ID = 'booking_d010032c96dcd7a06c04ae0a0fcf79df';
const JOB_ID = 'booking_1784668050802_879';
const QUOTE_ID = 'booking_1784668050802_879';
const TOKEN_ID = '30609a7bde29';

const ALLOWLIST = Object.freeze([
  `public_job_requests/${REQUEST_ID}`,
  `users/${OWNER_UID}/van_job_requests/${REQUEST_ID}`,
]);

const LINKED_PATHS = Object.freeze({
  job: `users/${OWNER_UID}/van_jobs/${JOB_ID}`,
  quote: `public_quote_responses/${QUOTE_ID}`,
  token: `public_quote_response_tokens/${TOKEN_ID}`,
  tombstone: `users/${OWNER_UID}/van_job_deletion_tombstones/${JOB_ID}`,
});

const readString = (value) => typeof value === 'string' ? value.trim() : '';
const readBool = (value) => value === true;

function argument(name, argv = process.argv) {
  const index = argv.indexOf(`--${name}`);
  return index === -1 ? '' : readString(argv[index + 1]);
}

function pathRef(firestore, path) {
  return firestore.doc(path);
}

function snapshotValue(value) {
  if (value && typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) return value.map(snapshotValue);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [
      key,
      snapshotValue(value[key]),
    ]));
  }
  return value;
}

function snapshotData(snapshot) {
  return snapshot && snapshot.exists ? (snapshot.data() || {}) : null;
}

function fingerprint(value) {
  return crypto.createHash('sha256')
    .update(JSON.stringify(snapshotValue(value)))
    .digest('hex');
}

function approvedDeletionUpdate() {
  return {
    deleted: false,
    archived: false,
    deletedByDriver: false,
    deletedAt: admin.firestore.FieldValue.delete(),
  };
}

function profileIsActive(data) {
  return !!data && readString(data.businessProfileId) === BUSINESS_PROFILE_ID &&
    data.isActive !== false && data.archived !== true && data.deleted !== true;
}

function validateChain({ requests, job, quote, token, tombstone, profiles }) {
  const errors = [];
  const requestData = requests.map(snapshotData);
  const jobData = snapshotData(job);
  const quoteData = snapshotData(quote);
  const tokenData = snapshotData(token);
  const activeProfile = profiles.some((snapshot) => profileIsActive(snapshotData(snapshot)));
  const repairedRequestState = requestData.length === 2 && requestData.every((data) =>
    data && !readBool(data.deleted) && !readBool(data.archived) &&
    !readBool(data.deletedByDriver) && data.deletedAt == null);
  const pendingRequestState = requestData.length === 2 && requestData.every((data) =>
    data && readBool(data.deleted) && readBool(data.archived) &&
    readBool(data.deletedByDriver) && data.deletedAt != null);

  if (requests.length !== 2 || requestData.some((data) => !data)) {
    errors.push('both allowlisted request documents must exist');
  }
  for (const data of requestData.filter(Boolean)) {
    if (readString(data.businessProfileId) !== BUSINESS_PROFILE_ID) {
      errors.push('request businessProfileId changed');
    }
    if (readString(data.ownerUid) && readString(data.ownerUid) !== OWNER_UID) {
      errors.push('request ownerUid changed');
    }
    if (readString(data.requestId) !== REQUEST_ID) errors.push('requestId linkage changed');
    if (readString(data.jobId) !== JOB_ID) errors.push('jobId linkage changed');
    if (!pendingRequestState && !repairedRequestState) {
      errors.push('request deletion state is partially changed');
    }
  }
  if (!jobData) errors.push('linked job is missing');
  if (jobData && (
    readString(jobData.businessProfileId) !== BUSINESS_PROFILE_ID ||
    readString(jobData.ownerUid) !== OWNER_UID ||
    readString(jobData.jobId) !== JOB_ID ||
    readString(jobData.requestId) !== REQUEST_ID ||
    readString(jobData.currentQuoteId) !== QUOTE_ID ||
    readString(jobData.quoteResponseId) !== QUOTE_ID ||
    readBool(jobData.deleted) || readBool(jobData.archived) || readBool(jobData.archivedReadOnly)
  )) errors.push('linked job is not the expected active linked job');
  if (!quoteData) errors.push('linked public quote is missing');
  if (quoteData && (
    readString(quoteData.businessProfileId) !== BUSINESS_PROFILE_ID ||
    readString(quoteData.ownerUid) !== OWNER_UID ||
    readString(quoteData.jobId) !== JOB_ID ||
    readString(quoteData.requestId) !== REQUEST_ID ||
    readString(quoteData.quoteResponseId) !== QUOTE_ID ||
    readBool(quoteData.deleted) || readBool(quoteData.archived) || readBool(quoteData.archivedReadOnly)
  )) errors.push('linked public quote is not the expected active linked quote');
  if (!tokenData) errors.push('linked token is missing');
  if (tokenData && (
    readString(tokenData.businessProfileId) !== BUSINESS_PROFILE_ID ||
    readString(tokenData.ownerUid) !== OWNER_UID ||
    readString(tokenData.jobId) !== JOB_ID ||
    readString(tokenData.requestId) !== REQUEST_ID ||
    readString(tokenData.quoteResponseId) !== QUOTE_ID ||
    readBool(tokenData.deleted) || readBool(tokenData.archived)
  )) errors.push('linked token is not the expected active linked token');
  if (tombstone && tombstone.exists) errors.push('deletion tombstone exists');
  if (!activeProfile) errors.push('business profile evidence is missing or inactive');

  return {
    approved: errors.length === 0,
    alreadyRepaired: repairedRequestState && errors.length === 0,
    errors,
  };
}

async function profileEvidence(firestore) {
  const query = await firestore.collection('public_booking_links')
    .where('businessProfileId', '==', BUSINESS_PROFILE_ID)
    .get();
  return query.docs;
}

async function readChain(firestore) {
  const requestRefs = ALLOWLIST.map((path) => pathRef(firestore, path));
  const refs = {
    requests: requestRefs,
    job: pathRef(firestore, LINKED_PATHS.job),
    quote: pathRef(firestore, LINKED_PATHS.quote),
    token: pathRef(firestore, LINKED_PATHS.token),
    tombstone: pathRef(firestore, LINKED_PATHS.tombstone),
  };
  const [requests, job, quote, token, tombstone, profiles] = await Promise.all([
    Promise.all(requestRefs.map((ref) => ref.get())),
    refs.job.get(),
    refs.quote.get(),
    refs.token.get(),
    refs.tombstone.get(),
    profileEvidence(firestore),
  ]);
  return { ...refs, snapshots: { requests, job, quote, token, tombstone, profiles } };
}

function chainReport(chain) {
  const check = validateChain(chain.snapshots);
  const before = chain.snapshots.requests.map((snapshot, index) => ({
    path: ALLOWLIST[index],
    deleted: snapshotData(snapshot)?.deleted,
    archived: snapshotData(snapshot)?.archived,
    deletedByDriver: snapshotData(snapshot)?.deletedByDriver,
    deletedAt: snapshotData(snapshot)?.deletedAt,
  }));
  return {
    approved: check.approved,
    alreadyRepaired: check.alreadyRepaired,
    errors: check.errors,
    evidence: {
      businessProfileId: BUSINESS_PROFILE_ID,
      jobPath: LINKED_PATHS.job,
      quotePath: LINKED_PATHS.quote,
      tokenPath: LINKED_PATHS.token,
      tombstonePath: LINKED_PATHS.tombstone,
      tombstoneExists: chain.snapshots.tombstone.exists,
      activeJob: !!snapshotData(chain.snapshots.job) && !readBool(snapshotData(chain.snapshots.job).deleted) && !readBool(snapshotData(chain.snapshots.job).archived),
      activeQuote: !!snapshotData(chain.snapshots.quote) && !readBool(snapshotData(chain.snapshots.quote).deleted) && !readBool(snapshotData(chain.snapshots.quote).archived),
      tokenExists: !!snapshotData(chain.snapshots.token),
      tokenQuoteResponseId: readString(snapshotData(chain.snapshots.token)?.quoteResponseId),
      profileEvidencePaths: chain.snapshots.profiles.map((snapshot) => snapshot.ref?.path || ''),
    },
    before,
    proposedAfter: before.map((item) => ({
      ...item,
      deleted: false,
      archived: false,
      deletedByDriver: false,
      deletedAt: '<removed>',
    })),
    fingerprint: fingerprint({
      requests: chain.snapshots.requests.map(snapshotData),
      job: snapshotData(chain.snapshots.job),
      quote: snapshotData(chain.snapshots.quote),
      token: snapshotData(chain.snapshots.token),
      tombstone: snapshotData(chain.snapshots.tombstone),
      profiles: chain.snapshots.profiles.map(snapshotData),
    }),
  };
}

async function buildPlan({ firestore }) {
  const chain = await readChain(firestore);
  const report = chainReport(chain);
  return { chain, report };
}

async function applyPlan({ firestore, plan }) {
  if (!plan.report.approved) throw new Error(`Preflight rejected: ${plan.report.errors.join('; ')}`);
  if (plan.report.alreadyRepaired) return 0;
  let writes = 0;
  await firestore.runTransaction(async (transaction) => {
    const refs = plan.chain;
    const requests = await Promise.all(refs.requests.map((ref) => transaction.get(ref)));
    const [job, quote, token, tombstone] = await Promise.all([
      transaction.get(refs.job),
      transaction.get(refs.quote),
      transaction.get(refs.token),
      transaction.get(refs.tombstone),
    ]);
    const profiles = await Promise.all(plan.chain.snapshots.profiles.map((snapshot) =>
      transaction.get(snapshot.ref)));
    const current = { requests, job, quote, token, tombstone, profiles };
    const currentReport = chainReport({ snapshots: current });
    if (!currentReport.approved || currentReport.alreadyRepaired) {
      throw new Error(`Evidence changed: ${currentReport.errors.join('; ') || 'request state was already repaired'}`);
    }
    if (currentReport.fingerprint !== plan.report.fingerprint) {
      throw new Error('Evidence changed since dry-run fingerprint.');
    }
    for (const ref of refs.requests) transaction.update(ref, approvedDeletionUpdate());
    writes = refs.requests.length;
  });
  return writes;
}

async function main() {
  const project = argument('project');
  const ownerUid = argument('owner-uid');
  const apply = process.argv.includes('--apply');
  if (!project || !ownerUid) {
    throw new Error('Usage: node migrate_stale_request_state.js --project PROJECT_ID --owner-uid OWNER_UID [--apply]');
  }
  if (ownerUid !== OWNER_UID) throw new Error('The explicit --owner-uid is not the approved owner allowlist.');
  if (admin.apps.length === 0) admin.initializeApp({ projectId: project });
  const firestore = admin.firestore();
  const plan = await buildPlan({ firestore });
  if (apply) {
    const writes = await applyPlan({ firestore, plan });
    plan.report.writesPerformed = writes;
  } else {
    plan.report.writesPerformed = 0;
  }
  process.stdout.write(`${JSON.stringify({
    project,
    ownerUid,
    mode: apply ? 'apply' : 'dry-run',
    allowlist: ALLOWLIST,
    writesPerformed: plan.report.writesPerformed,
    plan: plan.report,
  }, null, 2)}\n`);
  if (!plan.report.approved) process.exitCode = 2;
}

if (require.main === module) main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});

module.exports = {
  ALLOWLIST,
  BUSINESS_PROFILE_ID,
  LINKED_PATHS,
  applyPlan,
  approvedDeletionUpdate,
  buildPlan,
  chainReport,
  validateChain,
};
