'use strict';

const admin = require('firebase-admin');

const CLASS_A_CANDIDATES = Object.freeze([
  ['public_quote_responses', 'booking_1784443468982_935', 'default_business', '2iN3JKdUSf2nZ3PhdFZv'],
  ['public_quote_responses', 'booking_1784668050802_879', 'big_baps_1784566251566898', 'booking_d010032c96dcd7a06c04ae0a0fcf79df'],
  ['public_quote_response_tokens', '30609a7bde29', 'big_baps_1784566251566898', 'booking_d010032c96dcd7a06c04ae0a0fcf79df'],
  ['public_quote_response_tokens', '8efa2679a3a8', 'default_business', '2iN3JKdUSf2nZ3PhdFZv'],
  ['van_jobs', 'booking_1784385466391_96', 'default_business', 'sbpRBwtJAPayIgEldDpi'],
  ['van_jobs', 'booking_1784443468982_935', 'default_business', '2iN3JKdUSf2nZ3PhdFZv'],
  ['van_jobs', 'booking_1784668050802_879', 'big_baps_1784566251566898', 'booking_d010032c96dcd7a06c04ae0a0fcf79df'],
  ['van_jobs', 'booking_1784899222707_59', 'big_baps_1784566251566898', 'booking_4c1cff5824145e7580dee3b7915dd260'],
  ['van_jobs', 'booking_1785849991851_530', 'big_baps_1784566251566898', 'booking_3ed52a2f8d20637e6606fc0229048b11'],
  ['van_quotes', 'booking_1784443468982_935', 'default_business', '2iN3JKdUSf2nZ3PhdFZv'],
]);

const readString = (value) => typeof value === 'string' ? value.trim() : '';

function withoutBusinessProfileId(data) {
  const copy = { ...(data || {}) };
  delete copy.businessProfileId;
  return copy;
}

function profileOnlyUpdate(profileId) {
  return { businessProfileId: profileId };
}

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? '' : readString(process.argv[index + 1]);
}

function candidatePath(kind, id, ownerUid) {
  if (kind === 'van_jobs' || kind === 'van_quotes') {
    return `users/${ownerUid}/${kind}/${id}`;
  }
  return `${kind}/${id}`;
}

function validateCandidate({
  candidate,
  ownerUid,
  targetSnapshot,
  evidenceSnapshot,
  quoteSnapshot,
  profileSnapshots,
}) {
  const [kind, id, targetProfileId, evidenceId] = candidate;
  const errors = [];
  const targetData = targetSnapshot?.data() || null;
  const evidenceData = evidenceSnapshot?.data() || null;
  const targetPath = candidatePath(kind, id, ownerUid);
  const evidencePath = `public_job_requests/${evidenceId}`;

  const existingProfileId = readString(targetData?.businessProfileId);
  const alreadyMigrated = existingProfileId === targetProfileId;

  if (!targetSnapshot?.exists) errors.push('candidate document is missing');
  if (targetData && existingProfileId && !alreadyMigrated) {
    errors.push('candidate already has a non-empty businessProfileId');
  }
  if (targetData && readString(targetData.ownerUid) &&
      readString(targetData.ownerUid) !== ownerUid) {
    errors.push('candidate ownerUid does not match --owner-uid');
  }
  if (!evidenceSnapshot?.exists) errors.push('authoritative evidence document is missing');
  if (evidenceData && readString(evidenceData.businessProfileId) !== targetProfileId) {
    errors.push('authoritative evidence profile does not match the allowlist');
  }
  if (evidenceData && kind !== 'public_quote_response_tokens' &&
      readString(evidenceData.jobId) !== id) {
    errors.push('authoritative evidence jobId does not match the candidate');
  }
  if (kind === 'public_quote_response_tokens') {
    const quoteData = quoteSnapshot?.data() || null;
    if (!quoteSnapshot?.exists) errors.push('token quote document is missing');
    if (quoteData && evidenceData && (
      readString(quoteData.jobId) !== readString(evidenceData.jobId) ||
      readString(quoteData.requestId) !== readString(evidenceData.requestId)
    )) {
      errors.push('token quote linkage does not match the authoritative evidence');
    }
  }
  if (!profileSnapshots?.some((snapshot) => {
    const data = snapshot.data() || {};
    return data.isActive !== false && data.archived !== true && data.deleted !== true;
  })) {
    errors.push('referenced business profile is missing or inactive');
  }

  return {
    path: targetPath,
    id,
    targetProfileId,
    evidence: {
      path: evidencePath,
      profileId: readString(evidenceData?.businessProfileId),
      jobId: readString(evidenceData?.jobId),
      requestId: readString(evidenceData?.requestId),
    },
    beforeBusinessProfileId: readString(targetData?.businessProfileId),
    afterBusinessProfileId: targetProfileId,
    errors,
    approved: errors.length === 0,
    skipped: alreadyMigrated,
  };
}

async function profileSnapshots(firestore, profileId) {
  const snapshot = await firestore.collection('public_booking_links')
    .where('businessProfileId', '==', profileId).get();
  return snapshot.docs;
}

async function evidenceSnapshot(firestore, evidenceId) {
  return firestore.collection('public_job_requests').doc(evidenceId).get();
}

async function tokenQuoteSnapshot(firestore, targetSnapshot) {
  const data = targetSnapshot.data() || {};
  const quoteId = readString(data.quoteResponseId) || readString(data.currentQuoteId);
  if (!quoteId) return null;
  return firestore.collection('public_quote_responses').doc(quoteId).get();
}

async function candidateSnapshot(firestore, kind, id, ownerUid) {
  return firestore.doc(candidatePath(kind, id, ownerUid)).get();
}

async function buildPlan({ firestore, ownerUid }) {
  const plan = [];
  for (const candidate of CLASS_A_CANDIDATES) {
    const [kind, id, targetProfileId, evidenceId] = candidate;
    const target = await candidateSnapshot(firestore, kind, id, ownerUid);
    const [evidence, profiles, quote] = await Promise.all([
      evidenceSnapshot(firestore, evidenceId),
      profileSnapshots(firestore, targetProfileId),
      kind === 'public_quote_response_tokens'
        ? tokenQuoteSnapshot(firestore, target)
        : Promise.resolve(null),
    ]);
    plan.push(validateCandidate({
      candidate,
      ownerUid,
      targetSnapshot: target,
      evidenceSnapshot: evidence,
      quoteSnapshot: quote,
      profileSnapshots: profiles,
    }));
  }
  return plan;
}

async function applyPlan({ firestore, ownerUid, plan }) {
  if (plan.some((entry) => !entry.approved)) {
    throw new Error('Refusing --apply because the preflight plan contains rejected candidates.');
  }
  for (const entry of plan) {
    if (entry.skipped) continue;
    const candidate = CLASS_A_CANDIDATES.find((item) =>
      candidatePath(item[0], item[1], ownerUid) === entry.path);
    const [, id, targetProfileId, evidenceId] = candidate;
    await firestore.runTransaction(async (transaction) => {
      const targetRef = firestore.doc(entry.path);
      const evidenceRef = firestore.collection('public_job_requests').doc(evidenceId);
      const [target, evidence] = await Promise.all([
        transaction.get(targetRef),
        transaction.get(evidenceRef),
      ]);
      let quote = null;
      if (candidate[0] === 'public_quote_response_tokens') {
        const tokenData = target.data() || {};
        const quoteId = readString(tokenData.quoteResponseId) ||
          readString(tokenData.currentQuoteId);
        if (quoteId) {
          quote = await transaction.get(
            firestore.collection('public_quote_responses').doc(quoteId),
          );
        }
      }
      const profiles = await profileSnapshots(firestore, targetProfileId);
      const check = validateCandidate({
        candidate,
        ownerUid,
        targetSnapshot: target,
        evidenceSnapshot: evidence,
        quoteSnapshot: quote,
        profileSnapshots: profiles,
      });
      if (!check.approved) {
        throw new Error(`Evidence changed for ${entry.path}: ${check.errors.join('; ')}`);
      }
      entry.beforeProtectedData = withoutBusinessProfileId(target.data());
      transaction.update(targetRef, profileOnlyUpdate(targetProfileId));
    });
    const after = await firestore.doc(entry.path).get();
    entry.protectedFieldsUnchanged = JSON.stringify(
      withoutBusinessProfileId(after.data()),
    ) === JSON.stringify(entry.beforeProtectedData);
    if (!entry.protectedFieldsUnchanged) {
      throw new Error(`Protected fields changed unexpectedly for ${entry.path}.`);
    }
    entry.finalBusinessProfileId = readString(after.data()?.businessProfileId);
    delete entry.beforeProtectedData;
    entry.applied = true;
  }
}

async function main() {
  const project = argument('project');
  const ownerUid = argument('owner-uid');
  const apply = process.argv.includes('--apply');
  if (!project || !ownerUid) {
    throw new Error('Usage: node migrate_class_a_business_profile_ids.js --project PROJECT_ID --owner-uid OWNER_UID [--apply]');
  }
  if (admin.apps.length === 0) admin.initializeApp({ projectId: project });
  const firestore = admin.firestore();
  const plan = await buildPlan({ firestore, ownerUid });
  if (apply) await applyPlan({ firestore, ownerUid, plan });
  process.stdout.write(`${JSON.stringify({
    project,
    ownerUid,
    mode: apply ? 'apply' : 'dry-run',
    writesPerformed: plan.filter((entry) => entry.applied === true).length,
    remainingCandidates: plan.filter((entry) => entry.approved && !entry.skipped).length,
    skippedAlreadyMigrated: plan.filter((entry) => entry.skipped).length,
    plan,
  }, null, 2)}\n`);
  if (plan.some((entry) => !entry.approved)) process.exitCode = 2;
}

if (require.main === module) main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});

module.exports = {
  CLASS_A_CANDIDATES,
  applyPlan,
  buildPlan,
  candidatePath,
  profileOnlyUpdate,
  validateCandidate,
};
