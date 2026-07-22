'use strict';

const crypto = require('crypto');

const DEFAULT_BUSINESS_PROFILE_ID = 'default_business';
const DELETION_TOMBSTONE_SUBCOLLECTION = 'van_job_deletion_tombstones';
const BOOKING_PHOTO_PREFIX = 'booking_requests';

function readString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function requireDocumentId(value, fieldName) {
  const result = readString(value);
  if (!result || result.length > 512 || result.includes('/')) {
    throw new Error(`${fieldName} must be a valid Firestore document ID.`);
  }
  return result;
}

function normalizeBusinessProfileId(value) {
  return requireDocumentId(
    readString(value) || DEFAULT_BUSINESS_PROFILE_ID,
    'businessProfileId',
  );
}

function recordBusinessProfileId(record) {
  return readString(record && record.businessProfileId) ||
    DEFAULT_BUSINESS_PROFILE_ID;
}

function recordBelongsToBusiness(record, businessProfileId) {
  return recordBusinessProfileId(record) ===
    normalizeBusinessProfileId(businessProfileId);
}

function recordOwnedBy(record, ownerUid) {
  const owner = readString(ownerUid);
  return Boolean(owner) && [record && record.ownerUid, record && record.ownerId]
    .map(readString)
    .some((candidate) => candidate === owner);
}

function sameReference(candidate, expected) {
  const value = readString(candidate);
  return !value || value === expected;
}

function resolveDeletionIdentity({
  ownerUid,
  businessProfileId,
  target,
  publicRequest,
  privateRequest,
  privateJob,
}) {
  const owner = requireDocumentId(ownerUid, 'ownerUid');
  const profile = normalizeBusinessProfileId(businessProfileId);
  const targetJobId = requireDocumentId(target && target.jobId, 'jobId');
  const targetRequestId = readString(target && target.requestId);
  if (targetRequestId) requireDocumentId(targetRequestId, 'requestId');

  const request = publicRequest || privateRequest || null;
  if (request) {
    if (!recordOwnedBy(request, owner)) {
      throw new Error('The canonical request is not owned by the authenticated user.');
    }
    if (!recordBelongsToBusiness(request, profile)) {
      throw new Error('The canonical request belongs to another business profile.');
    }
    const requestId = requireDocumentId(
      readString(request.requestId) || targetRequestId,
      'requestId',
    );
    const jobId = requireDocumentId(
      readString(request.jobId) || readString(request.linkedJobId) || targetJobId,
      'jobId',
    );
    if (jobId !== targetJobId || (targetRequestId && requestId !== targetRequestId)) {
      throw new Error('The supplied job and request IDs do not match the canonical request.');
    }
    return { ownerUid: owner, businessProfileId: profile, jobId, requestId };
  }

  if (!privateJob) {
    throw new Error('No owned canonical request or job could be resolved.');
  }
  if (profile !== DEFAULT_BUSINESS_PROFILE_ID) {
    throw new Error('A profile-less legacy job can only be deleted from default_business.');
  }
  if (!recordBelongsToBusiness(privateJob, profile)) {
    throw new Error('The legacy job belongs to another business profile.');
  }
  const jobId = requireDocumentId(
    readString(privateJob.jobId) || targetJobId,
    'jobId',
  );
  if (jobId !== targetJobId) {
    throw new Error('The supplied job ID does not match the owned legacy job.');
  }
  const requestId = readString(privateJob.requestId) || targetRequestId;
  if (requestId) requireDocumentId(requestId, 'requestId');
  return { ownerUid: owner, businessProfileId: profile, jobId, requestId };
}

function quoteBelongsToIdentity(record, identity) {
  if (!recordOwnedBy(record, identity.ownerUid)) return false;
  const jobMatches = [record.jobId, record.linkedJobId]
    .map(readString)
    .filter(Boolean)
    .some((value) => value === identity.jobId);
  const requestMatches = identity.requestId && [record.requestId, record.linkedRequestId]
    .map(readString)
    .filter(Boolean)
    .some((value) => value === identity.requestId);
  return jobMatches || Boolean(requestMatches);
}

function safeBookingPhotoPrefix(identity) {
  if (!identity.requestId) return '';
  return `${BOOKING_PHOTO_PREFIX}/${identity.ownerUid}/${identity.requestId}/photos/`;
}

function classifyStoragePaths(paths, identity) {
  const prefix = safeBookingPhotoPrefix(identity);
  const safe = [];
  const preserved = [];
  for (const rawPath of paths || []) {
    const path = readString(rawPath);
    if (!path) continue;
    if (prefix && path.startsWith(prefix) && path.length > prefix.length) {
      safe.push(path);
    } else {
      preserved.push(path);
    }
  }
  return { safe: [...new Set(safe)], preserved: [...new Set(preserved)] };
}

function buildDeletionPlan({
  identity,
  quoteRecords = [],
  tokenRecords = [],
  storagePaths = [],
  invoiceRecords = [],
  ambiguousRecords = [],
}) {
  const verifiedQuotes = quoteRecords.filter((item) =>
    quoteBelongsToIdentity(item.data || {}, identity));
  const quoteIds = new Set(verifiedQuotes.map((item) => readString(item.id)).filter(Boolean));
  const verifiedTokens = tokenRecords.filter((item) => {
    const data = item.data || {};
    return quoteBelongsToIdentity(data, identity) ||
      quoteIds.has(readString(data.quoteResponseId || data.quoteId));
  });
  const storage = classifyStoragePaths(storagePaths, identity);
  const requestPaths = identity.requestId ? [
    `public_job_requests/${identity.requestId}`,
    `users/${identity.ownerUid}/van_job_requests/${identity.requestId}`,
    `van_job_requests/${identity.requestId}`,
  ] : [];
  const quotePaths = verifiedQuotes.map((item) =>
    `public_quote_responses/${requireDocumentId(item.id, 'quoteId')}`);
  const tokenPaths = verifiedTokens.map((item) =>
    `public_quote_response_tokens/${requireDocumentId(item.id, 'token')}`);

  return {
    identity,
    firestorePaths: [...new Set([
      `users/${identity.ownerUid}/van_jobs/${identity.jobId}`,
      `users/${identity.ownerUid}/van_quotes/${identity.jobId}`,
      ...requestPaths,
      ...quotePaths,
      ...tokenPaths,
    ])],
    quoteIds: [...quoteIds],
    tokenIds: verifiedTokens.map((item) => item.id),
    storagePaths: storage.safe,
    preserved: {
      invoicePaths: invoiceRecords.map((item) => item.path || item.id).filter(Boolean),
      storagePaths: storage.preserved,
      ambiguousRecords: ambiguousRecords.map((item) => item.path || item.id).filter(Boolean),
    },
  };
}

function buildPreviewDigest({ ownerUid, businessProfileId, targets, nonce }, secret) {
  const payload = JSON.stringify({
    ownerUid: requireDocumentId(ownerUid, 'ownerUid'),
    businessProfileId: normalizeBusinessProfileId(businessProfileId),
    targets: (targets || []).map((target) => ({
      jobId: requireDocumentId(target.jobId, 'jobId'),
      requestId: readString(target.requestId),
    })).sort((a, b) => a.jobId.localeCompare(b.jobId)),
    nonce: readString(nonce),
  });
  return crypto.createHmac('sha256', readString(secret) || 'local-test-secret')
    .update(payload)
    .digest('hex');
}

function tombstoneData(identity, operationId, state, timestamp) {
  return {
    ownerUid: identity.ownerUid,
    businessProfileId: identity.businessProfileId,
    requestId: identity.requestId || null,
    jobId: identity.jobId,
    operationId: requireDocumentId(operationId, 'operationId'),
    deletionState: state,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function summarizePlans(plans) {
  const summary = {
    jobs: plans.length,
    requests: 0,
    quoteVersions: 0,
    tokens: 0,
    photos: 0,
    invoicesPreserved: 0,
    ambiguousPreserved: 0,
  };
  for (const plan of plans) {
    summary.requests += plan.identity.requestId ? 1 : 0;
    summary.quoteVersions += plan.quoteIds.length;
    summary.tokens += plan.tokenIds.length;
    summary.photos += plan.storagePaths.length;
    summary.invoicesPreserved += plan.preserved.invoicePaths.length;
    summary.ambiguousPreserved +=
      plan.preserved.ambiguousRecords.length + plan.preserved.storagePaths.length;
  }
  return summary;
}

function requiredConfirmationPhrase(selection, businessName) {
  if (selection === 'explicit') return 'DELETE JOB';
  const name = readString(businessName).toUpperCase() || 'THIS BUSINESS';
  return `DELETE ${name} JOBS`;
}

function createDeletionCoordinator({ repository, now = () => new Date(), randomId }) {
  if (!repository) throw new Error('repository is required.');
  const makeId = randomId || (() => crypto.randomBytes(18).toString('hex'));

  return {
    async preview({ ownerUid, businessProfileId, selection, targets = [] }) {
      const owner = requireDocumentId(ownerUid, 'ownerUid');
      const profile = normalizeBusinessProfileId(businessProfileId);
      if (!['explicit', 'test_jobs', 'all_operational'].includes(selection)) {
        throw new Error('Unsupported deletion selection.');
      }
      const resolved = await repository.resolvePlans({
        ownerUid: owner,
        businessProfileId: profile,
        selection,
        targets,
      });
      const plans = resolved.plans || [];
      const previewToken = makeId();
      const expiresAt = new Date(now().getTime() + (15 * 60 * 1000));
      const confirmationPhrase = requiredConfirmationPhrase(
        selection,
        resolved.businessName,
      );
      const preview = {
        ownerUid: owner,
        businessProfileId: profile,
        selection,
        previewToken,
        expiresAt,
        confirmationPhrase,
        targets: plans.map((plan) => ({
          jobId: plan.identity.jobId,
          requestId: plan.identity.requestId || '',
          status: readString(plan.status) || 'unknown',
        })),
        summary: summarizePlans(plans),
        plans,
      };
      await repository.storePreview(preview);
      return {
        previewToken,
        expiresAt: expiresAt.toISOString(),
        confirmationPhrase,
        targets: preview.targets,
        summary: preview.summary,
        preserved: plans.map((plan) => ({
          jobId: plan.identity.jobId,
          ...plan.preserved,
        })),
      };
    },

    async execute({
      ownerUid,
      businessProfileId,
      previewToken,
      confirmationPhrase,
      idempotencyKey,
    }) {
      const owner = requireDocumentId(ownerUid, 'ownerUid');
      const profile = normalizeBusinessProfileId(businessProfileId);
      const token = requireDocumentId(previewToken, 'previewToken');
      const operationId = requireDocumentId(idempotencyKey, 'idempotencyKey');
      const preview = await repository.readPreview(token);
      if (!preview || preview.ownerUid !== owner ||
          preview.businessProfileId !== profile) {
        throw new Error('The deletion preview is missing or belongs to another scope.');
      }
      if (new Date(preview.expiresAt).getTime() <= now().getTime()) {
        throw new Error('The deletion preview has expired.');
      }
      if (readString(confirmationPhrase) !== preview.confirmationPhrase) {
        throw new Error('The deletion confirmation phrase does not match.');
      }

      const results = [];
      for (const plan of preview.plans) {
        try {
          results.push(await repository.executePlan({ plan, operationId }));
        } catch (error) {
          results.push({
            jobId: plan.identity.jobId,
            requestId: plan.identity.requestId || '',
            status: 'failed',
            error: String(error && error.message || error),
          });
        }
      }
      await repository.completePreview(token, results);
      return {
        operationId,
        completed: results.filter((item) => item.status === 'deleted'),
        alreadyDeleted: results.filter((item) => item.status === 'already_deleted'),
        skipped: results.filter((item) => item.status === 'skipped'),
        failed: results.filter((item) => item.status === 'failed'),
        results,
      };
    },
  };
}

function isHiddenRecord(data) {
  return data && (data.deleted === true || data.archived === true ||
    readString(data.status).toLowerCase() === 'deleted');
}

function isMarkedTestRecord(data) {
  const mode = readString(data && data.testMode).toLowerCase();
  return data && (data.isTestData === true ||
    ['true', 'test', 'development', 'debug'].includes(mode));
}

function documentRecord(document) {
  return { id: document.id, data: document.data() || {}, ref: document.ref };
}

async function deleteReferencesInBatches(db, paths, batchSize = 400) {
  const deleted = [];
  for (let offset = 0; offset < paths.length; offset += batchSize) {
    const selected = paths.slice(offset, offset + batchSize);
    const batch = db.batch();
    for (const path of selected) batch.delete(db.doc(path));
    await batch.commit();
    deleted.push(...selected);
  }
  return deleted;
}

function createFirestoreDeletionRepository({ admin, db, bucket }) {
  const timestamp = () => admin.firestore.FieldValue.serverTimestamp();

  async function ownerDocuments(collectionName, ownerUid) {
    const snapshot = await db.collection(collectionName)
      .where('ownerUid', '==', ownerUid).get();
    return snapshot.docs.map(documentRecord);
  }

  async function businessName(ownerUid, profileId) {
    const configId = profileId === DEFAULT_BUSINESS_PROFILE_ID
      ? ownerUid : `${ownerUid}_${profileId}`;
    const snap = await db.collection('public_booking_links').doc(configId).get();
    return readString(snap.exists && snap.data().businessName) || profileId;
  }

  async function loadScope(ownerUid) {
    const userRef = db.collection('users').doc(ownerUid);
    const [publicRequests, privateRequestsSnap, legacyRequests, jobsSnap,
      privateQuotesSnap, publicQuotes, tokens, invoicesSnap,
      tombstonesSnap] = await Promise.all([
      ownerDocuments('public_job_requests', ownerUid),
      userRef.collection('van_job_requests').get(),
      ownerDocuments('van_job_requests', ownerUid),
      userRef.collection('van_jobs').get(),
      userRef.collection('van_quotes').get(),
      ownerDocuments('public_quote_responses', ownerUid),
      ownerDocuments('public_quote_response_tokens', ownerUid),
      userRef.collection('van_invoices').get(),
      userRef.collection(DELETION_TOMBSTONE_SUBCOLLECTION).get(),
    ]);
    return {
      publicRequests,
      privateRequests: privateRequestsSnap.docs.map(documentRecord),
      legacyRequests,
      jobs: jobsSnap.docs.map(documentRecord),
      privateQuotes: privateQuotesSnap.docs.map(documentRecord),
      publicQuotes,
      tokens,
      invoices: invoicesSnap.docs.map(documentRecord),
      tombstones: tombstonesSnap.docs.map(documentRecord),
    };
  }

  function requestMatchesTarget(record, target) {
    const data = record.data;
    return record.id === readString(target.requestId) ||
      [data.jobId, data.linkedJobId].map(readString).includes(readString(target.jobId));
  }

  function recordReferencesIdentity(record, identity) {
    const data = record.data || {};
    return record.id === identity.jobId ||
      (identity.requestId && record.id === identity.requestId) ||
      [data.jobId, data.linkedJobId].map(readString).includes(identity.jobId) ||
      (identity.requestId && [data.requestId, data.linkedRequestId]
        .map(readString).includes(identity.requestId));
  }

  async function listPhotoPaths(identity, requestRecords) {
    const paths = [];
    for (const record of requestRecords) {
      for (const photo of Array.isArray(record.data.photos) ? record.data.photos : []) {
        const path = readString(photo && photo.storagePath);
        if (path) paths.push(path);
      }
    }
    if (bucket && identity.requestId) {
      const [files] = await bucket.getFiles({ prefix: safeBookingPhotoPrefix(identity) });
      paths.push(...files.map((file) => file.name));
    }
    return [...new Set(paths)];
  }

  return {
    async resolvePlans({ ownerUid, businessProfileId, selection, targets }) {
      const scope = await loadScope(ownerUid);
      let selectedTargets = targets || [];
      if (selection !== 'explicit') {
        const candidates = [];
        for (const record of scope.publicRequests) {
          if (!recordBelongsToBusiness(record.data, businessProfileId) ||
              isHiddenRecord(record.data)) continue;
          if (selection === 'test_jobs' && !isMarkedTestRecord(record.data)) continue;
          const jobId = readString(record.data.jobId || record.data.linkedJobId || record.id);
          if (jobId) candidates.push({ jobId, requestId: record.id });
        }
        for (const record of scope.jobs) {
          if (isHiddenRecord(record.data)) continue;
          const explicitProfile = readString(record.data.businessProfileId);
          if (explicitProfile && explicitProfile !== businessProfileId) continue;
          if (!explicitProfile && businessProfileId !== DEFAULT_BUSINESS_PROFILE_ID) continue;
          if (selection === 'test_jobs' && !isMarkedTestRecord(record.data)) continue;
          candidates.push({
            jobId: readString(record.data.jobId) || record.id,
            requestId: readString(record.data.requestId),
          });
        }
        const byJob = new Map();
        for (const target of candidates) {
          const existing = byJob.get(target.jobId);
          byJob.set(target.jobId, existing && existing.requestId ? existing : target);
        }
        selectedTargets = [...byJob.values()];
      }

      const plans = [];
      for (const target of selectedTargets) {
        const publicRequestRecord = scope.publicRequests.find((record) =>
          requestMatchesTarget(record, target));
        const privateRequestRecord = scope.privateRequests.find((record) =>
          requestMatchesTarget(record, target));
        const privateJobRecord = scope.jobs.find((record) =>
          record.id === readString(target.jobId));
        const tombstoneRecord = scope.tombstones.find((record) =>
          record.id === readString(target.jobId) &&
          record.data.ownerUid === ownerUid &&
          record.data.businessProfileId === businessProfileId);
        const identity = tombstoneRecord &&
            readString(tombstoneRecord.data.deletionState) === 'complete'
          ? {
              ownerUid,
              businessProfileId,
              jobId: tombstoneRecord.id,
              requestId: readString(tombstoneRecord.data.requestId),
            }
          : resolveDeletionIdentity({
              ownerUid,
              businessProfileId,
              target,
              publicRequest: publicRequestRecord && publicRequestRecord.data,
              privateRequest: privateRequestRecord && {
                ownerUid,
                ...privateRequestRecord.data,
                requestId: readString(privateRequestRecord.data.requestId) || privateRequestRecord.id,
              },
              privateJob: privateJobRecord && {
                ...privateJobRecord.data,
                jobId: readString(privateJobRecord.data.jobId) || privateJobRecord.id,
              },
            });
        const requestRecords = [
          ...scope.publicRequests, ...scope.privateRequests, ...scope.legacyRequests,
        ].filter((record) => recordReferencesIdentity(record, identity));
        const publicQuotes = scope.publicQuotes.filter((record) =>
          recordReferencesIdentity(record, identity));
        const privateQuotes = scope.privateQuotes.filter((record) =>
          recordReferencesIdentity(record, identity));
        const quoteIds = new Set(publicQuotes.map((record) => record.id));
        const tokens = scope.tokens.filter((record) =>
          recordReferencesIdentity(record, identity) ||
          quoteIds.has(readString(record.data.quoteResponseId || record.data.quoteId)));
        const invoices = scope.invoices.filter((record) =>
          recordReferencesIdentity(record, identity));
        const storagePaths = await listPhotoPaths(identity, requestRecords);
        const plan = buildDeletionPlan({
          identity,
          quoteRecords: publicQuotes,
          tokenRecords: tokens,
          storagePaths,
          invoiceRecords: invoices.map((record) => ({ path: record.ref.path })),
        });
        plan.firestorePaths = [...new Set([
          privateJobRecord && privateJobRecord.ref.path,
          ...requestRecords.map((record) => record.ref.path),
          ...privateQuotes.map((record) => record.ref.path),
          ...publicQuotes.map((record) => record.ref.path),
          ...tokens.map((record) => record.ref.path),
        ].filter(Boolean))];
        plan.status = readString(privateJobRecord && privateJobRecord.data.status) ||
          readString(publicRequestRecord && publicRequestRecord.data.status) ||
          (tombstoneRecord ? 'deleted' : 'unknown');
        plans.push(plan);
      }
      return {
        businessName: await businessName(ownerUid, businessProfileId),
        plans,
      };
    },

    async storePreview(preview) {
      await db.collection('users').doc(preview.ownerUid)
        .collection('van_job_deletion_previews').doc(preview.previewToken).set({
          ...preview,
          expiresAt: admin.firestore.Timestamp.fromDate(preview.expiresAt),
          createdAt: timestamp(),
        });
    },

    async readPreview(token) {
      const snapshot = await db.collectionGroup('van_job_deletion_previews')
        .where('previewToken', '==', token).limit(2).get();
      if (snapshot.size !== 1) return null;
      const data = snapshot.docs[0].data();
      return {
        ...data,
        expiresAt: data.expiresAt && data.expiresAt.toDate
          ? data.expiresAt.toDate() : new Date(data.expiresAt),
      };
    },

    async executePlan({ plan, operationId }) {
      const identity = plan.identity;
      const tombstoneRef = db.collection('users').doc(identity.ownerUid)
        .collection(DELETION_TOMBSTONE_SUBCOLLECTION).doc(identity.jobId);
      const alreadyComplete = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(tombstoneRef);
        const existing = snapshot.exists ? snapshot.data() || {} : {};
        if (existing.deletionState === 'complete') return true;
        const now = timestamp();
        transaction.set(tombstoneRef, {
          ...tombstoneData(identity, operationId, 'pending', now),
          createdAt: existing.createdAt || now,
        }, { merge: true });
        return false;
      });
      if (alreadyComplete) {
        return { jobId: identity.jobId, requestId: identity.requestId || '',
          status: 'already_deleted', deletedFirestorePaths: [], deletedStoragePaths: [] };
      }

      const deletedFirestorePaths = await deleteReferencesInBatches(
        db, plan.firestorePaths,
      );
      const deletedStoragePaths = [];
      if (bucket) {
        for (const path of plan.storagePaths) {
          await bucket.file(path).delete({ ignoreNotFound: true });
          deletedStoragePaths.push(path);
        }
      }
      await tombstoneRef.set({ deletionState: 'complete', updatedAt: timestamp() },
        { merge: true });
      return {
        jobId: identity.jobId,
        requestId: identity.requestId || '',
        status: 'deleted',
        deletedFirestorePaths,
        deletedStoragePaths,
        preserved: plan.preserved,
      };
    },

    async completePreview(token, results) {
      const snapshot = await db.collectionGroup('van_job_deletion_previews')
        .where('previewToken', '==', token).limit(1).get();
      if (snapshot.empty) return;
      await snapshot.docs[0].ref.set({
        deletionState: 'complete',
        completedAt: timestamp(),
        results: results.map((result) => ({
          jobId: result.jobId,
          requestId: result.requestId || '',
          status: result.status,
        })),
      }, { merge: true });
    },
  };
}

module.exports = {
  BOOKING_PHOTO_PREFIX,
  DEFAULT_BUSINESS_PROFILE_ID,
  DELETION_TOMBSTONE_SUBCOLLECTION,
  buildDeletionPlan,
  buildPreviewDigest,
  classifyStoragePaths,
  createDeletionCoordinator,
  createFirestoreDeletionRepository,
  deleteReferencesInBatches,
  normalizeBusinessProfileId,
  isMarkedTestRecord,
  quoteBelongsToIdentity,
  recordBelongsToBusiness,
  resolveDeletionIdentity,
  safeBookingPhotoPrefix,
  summarizePlans,
  tombstoneData,
};
