'use strict';

const LEGACY_AUDIT_COLLECTIONS = Object.freeze([
  'public_job_requests',
  'van_job_requests',
  'van_jobs',
  'van_quotes',
  'van_invoices',
  'public_quote_responses',
  'public_quote_response_tokens',
  'van_pin_requests',
]);

function readString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function ownerUidFor(data, fallbackOwnerUid = '') {
  return readString(data && (data.ownerUid || data.ownerId)) ||
    readString(fallbackOwnerUid);
}

function identifiersFor(documentId, data) {
  const values = [
    ['documentId', documentId],
    ['requestId', data && data.requestId],
    ['jobId', data && data.jobId],
    ['linkedJobId', data && data.linkedJobId],
    ['quoteResponseId', data && data.quoteResponseId],
    ['quoteId', data && data.quoteId],
    ['currentQuoteId', data && data.currentQuoteId],
    ['linkedRequestId', data && data.linkedRequestId],
  ];
  return values
    .map(([kind, value]) => ({ kind, value: readString(value) }))
    .filter((entry) => entry.value);
}

function classifyLegacyRecord({
  collection,
  documentId,
  data,
  ownerUid = '',
  authoritativeEvidence = [],
}) {
  const evidence = authoritativeEvidence.filter((item) =>
    readString(item.businessProfileId));
  const profileIds = [...new Set(evidence.map((item) => item.businessProfileId))];
  let attributionStatus = 'ambiguous';
  if (profileIds.length === 1) {
    attributionStatus = evidence.some((item) => item.exact === true)
      ? 'exact'
      : 'inferable from authoritative stored relationship';
  }
  return {
    documentId: readString(documentId),
    ownerUid: ownerUidFor(data, ownerUid),
    collection,
    originatingIds: identifiersFor(documentId, data)
      .filter((entry) => entry.kind !== 'documentId'),
    candidateAuthoritativeProfileEvidence: evidence.map((item) => ({
      businessProfileId: item.businessProfileId,
      collection: item.collection,
      documentId: item.documentId,
      relationship: item.relationship,
    })),
    attributionStatus,
  };
}

function documentIdentityEntries(document) {
  const data = document.data || {};
  return identifiersFor(document.documentId, data).map((entry) => ({
    ...entry,
    documentId: document.documentId,
    collection: document.collection,
    businessProfileId: readString(data.businessProfileId),
  }));
}

function buildLegacyBusinessProfileAudit(documents) {
  const authoritativeByIdentifier = new Map();
  for (const document of documents || []) {
    const profileId = readString(document.data && document.data.businessProfileId);
    if (!profileId) continue;
    for (const entry of documentIdentityEntries(document)) {
      const key = `${entry.kind}:${entry.value}`;
      const evidence = authoritativeByIdentifier.get(key) || [];
      evidence.push({
        businessProfileId: profileId,
        collection: entry.collection,
        documentId: entry.documentId,
        relationship: entry.kind,
        exact: entry.value === entry.documentId,
      });
      authoritativeByIdentifier.set(key, evidence);
    }
  }

  return (documents || [])
    .filter((document) =>
      !readString(document.data && document.data.businessProfileId))
    .map((document) => {
      const evidence = [];
      for (const entry of documentIdentityEntries(document)) {
        const matches = authoritativeByIdentifier.get(
          `${entry.kind}:${entry.value}`,
        ) || [];
        evidence.push(...matches.map((item) => ({
          ...item,
          exact: item.exact || entry.value === document.documentId,
        })));
      }
      const uniqueEvidence = evidence.filter((item, index, all) =>
        all.findIndex((candidate) =>
          candidate.businessProfileId === item.businessProfileId &&
          candidate.documentId === item.documentId &&
          candidate.relationship === item.relationship) === index);
      return classifyLegacyRecord({
        collection: document.collection,
        documentId: document.documentId,
        data: document.data,
        ownerUid: document.ownerUid,
        authoritativeEvidence: uniqueEvidence,
      });
    });
}

function normalizeDocument(collection, document, ownerUid) {
  return {
    collection,
    documentId: document.id,
    data: document.data() || {},
    ownerUid,
  };
}

async function collectLegacyBusinessProfileDocuments({ firestore, ownerUid }) {
  const owner = readString(ownerUid);
  if (!firestore || !owner) throw new Error('firestore and ownerUid are required.');
  const userRef = firestore.collection('users').doc(owner);
  const publicCollections = [
    'public_job_requests',
    'public_quote_responses',
    'public_quote_response_tokens',
    'van_pin_requests',
  ];
  const privateCollections = [
    'van_job_requests',
    'van_jobs',
    'van_quotes',
    'van_invoices',
  ];
  const documents = [];
  for (const collection of privateCollections) {
    const snapshot = await userRef.collection(collection).get();
    documents.push(...snapshot.docs.map((document) =>
      normalizeDocument(`users/${owner}/${collection}`, document, owner)));
  }
  for (const collection of publicCollections) {
    const found = new Map();
    for (const ownerField of ['ownerUid', 'ownerId']) {
      const snapshot = await firestore.collection(collection)
        .where(ownerField, '==', owner).get();
      snapshot.docs.forEach((document) => found.set(document.id, document));
    }
    documents.push(...[...found.values()].map((document) =>
      normalizeDocument(collection, document, owner)));
  }
  return documents;
}

async function auditLegacyBusinessProfileScope({ firestore, ownerUid }) {
  const documents = await collectLegacyBusinessProfileDocuments({
    firestore,
    ownerUid,
  });
  const records = buildLegacyBusinessProfileAudit(documents);
  return {
    ownerUid: readString(ownerUid),
    scannedCollections: LEGACY_AUDIT_COLLECTIONS,
    scannedDocumentCount: documents.length,
    legacyRecordCount: records.length,
    records,
    writesPerformed: 0,
  };
}

module.exports = {
  LEGACY_AUDIT_COLLECTIONS,
  auditLegacyBusinessProfileScope,
  buildLegacyBusinessProfileAudit,
  classifyLegacyRecord,
  collectLegacyBusinessProfileDocuments,
};
