'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assertDevelopmentProject,
  assertDevelopmentStorageBucket,
  assertDevelopmentTarget,
  buildCleanupPlan,
  collectCleanupCandidates,
  recordBelongsToTarget,
  hasProtectedFinancialData,
  extractSafeBookingPhotoPaths,
  executeCleanup,
} = require('./business_mate_dev_cleanup');

test('cleanup refuses an unexpected or production-looking Firebase project', () => {
  assert.throws(
    () =>
      assertDevelopmentProject({
        actualProjectId: 'unexpected-project',
        expectedProjectId: 'business-mate-dev',
      }),
    /Refusing project/,
  );
  assert.throws(
    () =>
      assertDevelopmentProject({
        actualProjectId: 'business-mate-production',
        expectedProjectId: 'business-mate-production',
      }),
    /production project/,
  );
  assert.equal(
      assertDevelopmentProject({
        actualProjectId: 'business-mate-development',
        expectedProjectId: 'business-mate-development',
    }),
    'business-mate-development',
  );
  assert.throws(
    () =>
      assertDevelopmentProject({
        actualProjectId: 'vanmate-56eac',
        expectedProjectId: 'vanmate-56eac',
      }),
    /not clearly a development project/,
  );
  assert.equal(
    assertDevelopmentProject({
      actualProjectId: 'vanmate-56eac',
      expectedProjectId: 'vanmate-56eac',
      allowedProjectIds: 'vanmate-56eac',
    }),
    'vanmate-56eac',
  );
});

test('cleanup accepts only clearly marked or explicitly allowlisted targets', () => {
  assert.throws(
    () =>
      assertDevelopmentTarget({
        ownerUid: 'ordinary_owner_123',
        businessProfileId: 'ordinary_business',
      }),
    /Refusing target/,
  );
  assert.deepEqual(
    assertDevelopmentTarget({
      ownerUid: 'test_owner_123',
      businessProfileId: 'test_business',
    }),
    { ownerUid: 'test_owner_123', businessProfileId: 'test_business' },
  );
  assert.deepEqual(
    assertDevelopmentTarget(
      {
        ownerUid: 'ordinary_owner_123',
        businessProfileId: 'ordinary_business',
      },
      { allowedTargets: 'ordinary_owner_123:ordinary_business' },
    ),
    { ownerUid: 'ordinary_owner_123', businessProfileId: 'ordinary_business' },
  );
});

test('cleanup accepts only the verified development Storage bucket', () => {
  assert.equal(
    assertDevelopmentStorageBucket({
      storageBucket: 'business-mate-development.firebasestorage.app',
      projectId: 'business-mate-development',
    }),
    'business-mate-development.firebasestorage.app',
  );
  assert.throws(
    () =>
      assertDevelopmentStorageBucket({
        storageBucket: 'unrelated-project.firebasestorage.app',
        projectId: 'business-mate-development',
      }),
    /Refusing Storage bucket/,
  );
});

test('dry-run plan is scoped to one explicit test business', () => {
  const plan = buildCleanupPlan({
    ownerUid: 'test_owner_123',
    businessProfileId: 'test_business',
  });

  assert.deepEqual(plan.target, {
    ownerUid: 'test_owner_123',
    businessProfileId: 'test_business',
    publicConfigId: 'test_owner_123_test_business',
  });
  assert.ok(
    plan.directDocumentPaths.includes(
      'users/test_owner_123/van_booking_link_settings/test_business',
    ),
  );
  assert.ok(
    plan.directDocumentPaths.includes(
      'public_booking_links/test_owner_123_test_business',
    ),
  );
  assert.ok(plan.userCollectionPaths.every((path) => path.includes('test_owner_123')));
  assert.ok(plan.preservedCollections.some((path) => path.endsWith('/van_invoices')));
  assert.equal(plan.authenticationUsersDeleted, false);
  assert.equal(plan.directDocumentPaths.some((path) => path === 'users/test_owner_123'), false);
});

test('candidate filtering rejects other businesses and protects financial records', () => {
  const target = buildCleanupPlan({
    ownerUid: 'test_owner_123',
    businessProfileId: 'test_business',
  }).target;

  assert.equal(
    recordBelongsToTarget(
      { ownerUid: 'test_owner_123', businessProfileId: 'test_business' },
      target,
      { requireOwner: true },
    ),
    true,
  );
  assert.equal(
    recordBelongsToTarget(
      { ownerUid: 'test_owner_123', businessProfileId: 'other_business' },
      target,
      { requireOwner: true },
    ),
    false,
  );
  assert.equal(
    recordBelongsToTarget(
      { ownerUid: 'other_owner', businessProfileId: 'test_business' },
      target,
      { requireOwner: true },
    ),
    false,
  );
  assert.equal(
    recordBelongsToTarget(
      { ownerUid: 'test_owner_123' },
      target,
      { requireOwner: true },
    ),
    false,
  );
  assert.equal(hasProtectedFinancialData({ invoiceNumber: 'INV-100' }), true);
  assert.equal(hasProtectedFinancialData({ paid: true }), true);
  assert.equal(hasProtectedFinancialData({ requestStatus: 'pending' }), false);
});

test('only safely attributable booking photo paths are selected', () => {
  const target = buildCleanupPlan({
    ownerUid: 'test_owner_123',
    businessProfileId: 'test_business',
  }).target;
  const paths = extractSafeBookingPhotoPaths(
    {
      photos: [
        {
          storagePath:
            'booking_requests/test_owner_123/request_1/photos/photo.jpg',
        },
        {
          storagePath: 'booking_requests/other_owner/request_1/photos/no.jpg',
        },
        { storagePath: 'business_logos/test_owner_123/logo.png' },
      ],
    },
    target,
    'request_1',
  );

  assert.deepEqual(paths, [
    'booking_requests/test_owner_123/request_1/photos/photo.jpg',
  ]);
});

function fakeDocument(path, data) {
  return {
    exists: true,
    id: path.split('/').at(-1),
    ref: { path },
    data: () => data,
  };
}

function fakeFirestore({ direct = {}, collections = {} }) {
  const documentsFor = (path) => collections[path] || [];
  return {
    doc(path) {
      return {
        async get() {
          return direct[path] || {
            exists: false,
            id: path.split('/').at(-1),
            ref: { path },
            data: () => undefined,
          };
        },
      };
    },
    collection(path) {
      return {
        async get() {
          return { docs: documentsFor(path) };
        },
        where(field, operator, expected) {
          assert.equal(operator, '==');
          return {
            async get() {
              return {
                docs: documentsFor(path).filter(
                  (document) => document.data()[field] === expected,
                ),
              };
            },
          };
        },
      };
    },
  };
}

test('dry-run candidates report every location and select only intended test records', async () => {
  const plan = buildCleanupPlan({
    ownerUid: 'test_owner_123',
    businessProfileId: 'test_business',
  });
  const privateJobsPath = 'users/test_owner_123/van_jobs';
  const firestore = fakeFirestore({
    direct: {
      'public_booking_links/test_owner_123_test_business': fakeDocument(
        'public_booking_links/test_owner_123_test_business',
        {
          ownerUid: 'test_owner_123',
          businessProfileId: 'test_business',
        },
      ),
    },
    collections: {
      [privateJobsPath]: [
        fakeDocument(`${privateJobsPath}/selected`, {
          ownerUid: 'test_owner_123',
          businessProfileId: 'test_business',
          requestId: 'request_selected',
          photos: [{
            storagePath:
              'booking_requests/test_owner_123/request_selected/photos/photo.jpg',
          }],
        }),
        fakeDocument(`${privateJobsPath}/other`, {
          ownerUid: 'test_owner_123',
          businessProfileId: 'other_business',
        }),
        fakeDocument(`${privateJobsPath}/uncertain`, {
          ownerUid: 'test_owner_123',
        }),
        fakeDocument(`${privateJobsPath}/invoice`, {
          ownerUid: 'test_owner_123',
          businessProfileId: 'test_business',
          invoiceNumber: 'INV-100',
        }),
      ],
    },
  });

  const candidates = await collectCleanupCandidates({
    firestore,
    target: plan.target,
  });

  expectIncludes(candidates.documentPaths, `${privateJobsPath}/selected`);
  expectExcludes(candidates.documentPaths, `${privateJobsPath}/other`);
  expectExcludes(candidates.documentPaths, `${privateJobsPath}/uncertain`);
  expectExcludes(candidates.documentPaths, `${privateJobsPath}/invoice`);
  assert.deepEqual(candidates.photoPaths, [
    'booking_requests/test_owner_123/request_selected/photos/photo.jpg',
  ]);
  assert.deepEqual(candidates.uncertainOwnershipDocuments, [
    `${privateJobsPath}/uncertain`,
  ]);
  assert.deepEqual(candidates.skippedFinancialDocuments, [
    `${privateJobsPath}/invoice`,
  ]);
  const privateJobCounts = candidates.locationCounts.find(
    (entry) => entry.path === privateJobsPath,
  );
  assert.deepEqual(privateJobCounts, {
    kind: 'collection',
    path: privateJobsPath,
    scanned: 4,
    selected: 1,
    protectedFinancial: 1,
    uncertainOwnership: 1,
    otherBusiness: 1,
  });
  assert.ok(
    candidates.locationCounts.some(
      (entry) => entry.path === 'public_quote_responses' && entry.scanned === 0,
    ),
  );
});

function expectIncludes(values, expected) {
  assert.equal(values.includes(expected), true);
}

function expectExcludes(values, expected) {
  assert.equal(values.includes(expected), false);
}

test('photo deletion refuses to run without an explicit Storage bucket', async () => {
  await assert.rejects(
    executeCleanup({
      firestore: {},
      bucket: null,
      candidates: {
        photoPaths: ['booking_requests/test-owner/request-1/photos/photo.jpg'],
        documentRefs: [],
      },
    }),
    /verified development Storage bucket/,
  );
});
