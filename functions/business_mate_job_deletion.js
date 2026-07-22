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

module.exports = {
  BOOKING_PHOTO_PREFIX,
  DEFAULT_BUSINESS_PROFILE_ID,
  DELETION_TOMBSTONE_SUBCOLLECTION,
  buildDeletionPlan,
  buildPreviewDigest,
  classifyStoragePaths,
  normalizeBusinessProfileId,
  quoteBelongsToIdentity,
  recordBelongsToBusiness,
  resolveDeletionIdentity,
  safeBookingPhotoPrefix,
  tombstoneData,
};
