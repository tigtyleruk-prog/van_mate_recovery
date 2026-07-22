'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  buildDeletionPlan,
  buildPreviewDigest,
  classifyStoragePaths,
  createDeletionCoordinator,
  deleteReferencesInBatches,
  isMarkedTestRecord,
  resolveDeletionIdentity,
  tombstoneData,
} = require('./business_mate_job_deletion');

test('canonical request authorizes an exact business-scoped deletion', () => {
  const identity = resolveDeletionIdentity({
    ownerUid: 'owner-1',
    businessProfileId: 'courier-1',
    target: { jobId: 'job-1', requestId: 'request-1' },
    publicRequest: {
      ownerUid: 'owner-1',
      businessProfileId: 'courier-1',
      requestId: 'request-1',
      jobId: 'job-1',
    },
  });

  assert.deepEqual(identity, {
    ownerUid: 'owner-1',
    businessProfileId: 'courier-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });
});

test('another owner or business cannot authorize deletion', () => {
  const base = {
    ownerUid: 'owner-1',
    businessProfileId: 'courier-1',
    target: { jobId: 'job-1', requestId: 'request-1' },
  };
  assert.throws(() => resolveDeletionIdentity({
    ...base,
    publicRequest: {
      ownerUid: 'owner-2', businessProfileId: 'courier-1',
      requestId: 'request-1', jobId: 'job-1',
    },
  }), /not owned/);
  assert.throws(() => resolveDeletionIdentity({
    ...base,
    publicRequest: {
      ownerUid: 'owner-1', businessProfileId: 'other-business',
      requestId: 'request-1', jobId: 'job-1',
    },
  }), /another business/);
});

test('profile-less legacy jobs are restricted to default_business', () => {
  assert.throws(() => resolveDeletionIdentity({
    ownerUid: 'owner-1',
    businessProfileId: 'courier-1',
    target: { jobId: 'legacy-job' },
    privateJob: { jobId: 'legacy-job' },
  }), /only be deleted from default_business/);

  assert.deepEqual(resolveDeletionIdentity({
    ownerUid: 'owner-1',
    businessProfileId: 'default_business',
    target: { jobId: 'legacy-job' },
    privateJob: { jobId: 'legacy-job' },
  }), {
    ownerUid: 'owner-1', businessProfileId: 'default_business',
    jobId: 'legacy-job', requestId: '',
  });
});

test('plan deletes exact job graph and preserves invoices and ambiguous records', () => {
  const identity = {
    ownerUid: 'owner-1', businessProfileId: 'courier-1',
    jobId: 'job-1', requestId: 'request-1',
  };
  const plan = buildDeletionPlan({
    identity,
    quoteRecords: [
      { id: 'quote-1', data: { ownerUid: 'owner-1', jobId: 'job-1' } },
      { id: 'other-quote', data: { ownerUid: 'owner-1', jobId: 'job-2' } },
    ],
    tokenRecords: [
      { id: 'token-1', data: { ownerUid: 'owner-1', quoteResponseId: 'quote-1' } },
      { id: 'token-2', data: { ownerUid: 'owner-1', jobId: 'job-2' } },
    ],
    invoiceRecords: [{ path: 'users/owner-1/van_invoices/job-1' }],
    ambiguousRecords: [{ path: 'van_pin_requests/unknown' }],
  });

  assert.ok(plan.firestorePaths.includes('users/owner-1/van_jobs/job-1'));
  assert.ok(plan.firestorePaths.includes('public_quote_responses/quote-1'));
  assert.ok(plan.firestorePaths.includes('public_quote_response_tokens/token-1'));
  assert.ok(!plan.firestorePaths.some((path) => path.includes('other-quote')));
  assert.deepEqual(plan.preserved.invoicePaths, ['users/owner-1/van_invoices/job-1']);
  assert.deepEqual(plan.preserved.ambiguousRecords, ['van_pin_requests/unknown']);
});

test('only verified booking photo prefix is deletable', () => {
  const result = classifyStoragePaths([
    'booking_requests/owner-1/request-1/photos/a.jpg',
    'booking_requests/owner-1/request-2/photos/b.jpg',
    'business_logos/owner-1/logo.png',
  ], {
    ownerUid: 'owner-1', requestId: 'request-1', jobId: 'job-1',
  });
  assert.deepEqual(result.safe, [
    'booking_requests/owner-1/request-1/photos/a.jpg',
  ]);
  assert.equal(result.preserved.length, 2);
});

test('preview digest is stable for the same immutable target set', () => {
  const common = {
    ownerUid: 'owner-1', businessProfileId: 'courier-1', nonce: 'nonce-1',
  };
  assert.equal(
    buildPreviewDigest({ ...common, targets: [{ jobId: 'b' }, { jobId: 'a' }] }, 'secret'),
    buildPreviewDigest({ ...common, targets: [{ jobId: 'a' }, { jobId: 'b' }] }, 'secret'),
  );
});

test('tombstones contain only minimal operational fields', () => {
  const value = tombstoneData({
    ownerUid: 'owner-1', businessProfileId: 'courier-1',
    requestId: 'request-1', jobId: 'job-1',
  }, 'operation-1', 'pending', 'timestamp');
  assert.deepEqual(Object.keys(value).sort(), [
    'businessProfileId', 'createdAt', 'deletionState', 'jobId',
    'operationId', 'ownerUid', 'requestId', 'updatedAt',
  ]);
  assert.equal(JSON.stringify(value).includes('address'), false);
  assert.equal(JSON.stringify(value).includes('phone'), false);
});

test('preview is server-scoped, counted, stored and requires matching confirmation', async () => {
  const stored = new Map();
  let executions = 0;
  const plan = {
    identity: {
      ownerUid: 'owner-1', businessProfileId: 'courier-1',
      jobId: 'job-1', requestId: 'request-1',
    },
    status: 'completed',
    quoteIds: ['quote-1', 'quote-2'],
    tokenIds: ['token-1'],
    storagePaths: ['photo-1'],
    preserved: {
      invoicePaths: ['invoice-1'], storagePaths: [], ambiguousRecords: [],
    },
  };
  const coordinator = createDeletionCoordinator({
    now: () => new Date('2026-07-22T10:00:00Z'),
    randomId: () => 'preview-1',
    repository: {
      resolvePlans: async () => ({ businessName: 'Swift Courier', plans: [plan] }),
      storePreview: async (preview) => stored.set(preview.previewToken, preview),
      readPreview: async (token) => stored.get(token),
      executePlan: async () => {
        executions += 1;
        return { jobId: 'job-1', status: 'deleted' };
      },
      completePreview: async () => {},
    },
  });

  const preview = await coordinator.preview({
    ownerUid: 'owner-1', businessProfileId: 'courier-1',
    selection: 'all_operational',
  });
  assert.equal(preview.confirmationPhrase, 'DELETE SWIFT COURIER JOBS');
  assert.deepEqual(preview.summary, {
    jobs: 1, requests: 1, quoteVersions: 2, tokens: 1, photos: 1,
    invoicesPreserved: 1, ambiguousPreserved: 0,
  });
  await assert.rejects(coordinator.execute({
    ownerUid: 'owner-1', businessProfileId: 'courier-1',
    previewToken: 'preview-1', confirmationPhrase: 'DELETE JOBS',
    idempotencyKey: 'operation-1',
  }), /does not match/);
  assert.equal(executions, 0);

  const result = await coordinator.execute({
    ownerUid: 'owner-1', businessProfileId: 'courier-1',
    previewToken: 'preview-1',
    confirmationPhrase: 'DELETE SWIFT COURIER JOBS',
    idempotencyKey: 'operation-1',
  });
  assert.equal(result.completed.length, 1);
  assert.equal(executions, 1);
});

test('marked test selection never relies on customer-facing names', () => {
  assert.equal(isMarkedTestRecord({ isTestData: true }), true);
  assert.equal(isMarkedTestRecord({ testMode: 'development' }), true);
  assert.equal(isMarkedTestRecord({ customerName: 'Bob Sinclair' }), false);
  assert.equal(isMarkedTestRecord({ serviceName: 'Test delivery' }), false);
});

test('Firestore references are deleted in recoverable bounded batches', async () => {
  const commits = [];
  const db = {
    doc: (path) => ({ path }),
    batch: () => {
      const paths = [];
      return {
        delete: (ref) => paths.push(ref.path),
        commit: async () => commits.push(paths),
      };
    },
  };
  const paths = Array.from({ length: 805 }, (_, index) => `records/${index}`);
  assert.deepEqual(await deleteReferencesInBatches(db, paths), paths);
  assert.deepEqual(commits.map((batch) => batch.length), [400, 400, 5]);
});
