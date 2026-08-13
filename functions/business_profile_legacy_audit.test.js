'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  LEGACY_AUDIT_COLLECTIONS,
  auditLegacyBusinessProfileScope,
  buildLegacyBusinessProfileAudit,
} = require('./business_profile_legacy_audit');

function document(id, data) {
  return {
    id,
    data: () => data,
  };
}

test('legacy audit classifies explicit relationships without assigning ambiguous records', () => {
  const records = buildLegacyBusinessProfileAudit([
    {
      collection: 'public_job_requests',
      documentId: 'request-1',
      data: {
        ownerUid: 'owner-1',
        businessProfileId: 'profile-a',
        requestId: 'request-1',
        jobId: 'job-1',
      },
    },
    {
      collection: 'users/owner-1/van_jobs',
      documentId: 'job-1',
      data: { ownerUid: 'owner-1', jobId: 'job-1' },
    },
    {
      collection: 'users/owner-1/van_quotes',
      documentId: 'legacy-quote',
      data: { ownerUid: 'owner-1', jobId: 'legacy-job' },
    },
    {
      collection: 'public_quote_responses',
      documentId: 'quote-ambiguous',
      data: {
        ownerUid: 'owner-1',
        jobId: 'shared-job',
      },
    },
    {
      collection: 'public_job_requests',
      documentId: 'request-b',
      data: {
        ownerUid: 'owner-1',
        businessProfileId: 'profile-b',
        jobId: 'shared-job',
      },
    },
  ]);

  const exact = records.find((record) => record.documentId === 'job-1');
  const ambiguous = records.find((record) => record.documentId === 'legacy-quote');
  const conflicting = records.find((record) => record.documentId === 'quote-ambiguous');

  assert.equal(exact.attributionStatus, 'exact');
  assert.deepEqual(
    exact.candidateAuthoritativeProfileEvidence.map((item) => item.businessProfileId),
    ['profile-a'],
  );
  assert.equal(ambiguous.attributionStatus, 'ambiguous');
  assert.equal(conflicting.attributionStatus, 'inferable from authoritative stored relationship');
  assert.equal(
    new Set(conflicting.candidateAuthoritativeProfileEvidence.map(
      (item) => item.businessProfileId,
    )).size,
    1,
  );
});

test('legacy audit is read-only and reports only scoped identifiers', async () => {
  let writes = 0;
  const collections = {
    'users/owner-1/van_jobs': [
      document('legacy-job', { ownerUid: 'owner-1', jobId: 'legacy-job' }),
    ],
    public_job_requests: [],
    public_quote_responses: [],
    public_quote_response_tokens: [],
    van_pin_requests: [],
  };
  const firestore = {
    collection(path) {
      const docs = collections[path] || [];
      return {
        doc(id) {
          return {
            collection(child) {
              return this.firestoreCollection(`${path}/${id}/${child}`);
            },
            firestoreCollection(childPath) {
              return makeQuery(collections[childPath] || []);
            },
          };
        },
        where() {
          return makeQuery(docs);
        },
      };
    },
    set() { writes += 1; },
    update() { writes += 1; },
    delete() { writes += 1; },
  };

  function makeQuery(docs) {
    return { get: async () => ({ docs }) };
  }

  const result = await auditLegacyBusinessProfileScope({
    firestore,
    ownerUid: 'owner-1',
  });
  assert.deepEqual(result.scannedCollections, LEGACY_AUDIT_COLLECTIONS);
  assert.equal(result.records[0].documentId, 'legacy-job');
  assert.equal(result.records[0].ownerUid, 'owner-1');
  assert.equal(result.records[0].attributionStatus, 'ambiguous');
  assert.equal(result.writesPerformed, 0);
  assert.equal(writes, 0);
});

test('temporary repair HTTP endpoints are removed from the Functions export surface', () => {
  const functions = require('./index.js');
  assert.equal(functions.auditBakeryServices, undefined);
  assert.equal(functions.repairBakeryServiceFlow, undefined);
});
