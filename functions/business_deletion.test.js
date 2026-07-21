const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildBusinessDeletionPlan,
  recordBelongsToBusiness,
  shouldPreserveBusinessJob,
} = require('./index.js').__test__;

test('default business deletion targets legacy configuration explicitly', () => {
  const plan = buildBusinessDeletionPlan({
    ownerUid: 'owner-123',
    businessProfileId: 'default_business',
    publicConfigId: 'owner-123',
  });

  assert.equal(plan.publicConfigId, 'owner-123');
  assert.deepEqual(plan.configDocuments, [
    { collection: 'van_booking_link_settings', docId: 'settings' },
    { collection: 'van_business_profile', docId: 'profile' },
    { collection: 'van_job_services', docId: 'library' },
    { collection: 'van_custom_job_questions', docId: 'library' },
    { collection: 'van_settings', docId: 'quote_extras' },
  ]);
});

test('secondary business deletion cannot target another booking link', () => {
  const plan = buildBusinessDeletionPlan({
    ownerUid: 'owner-123',
    businessProfileId: 'garden_team_42',
  });

  assert.equal(plan.publicConfigId, 'owner-123_garden_team_42');
  assert.deepEqual(plan.configDocuments, [
    { collection: 'van_booking_link_settings', docId: 'garden_team_42' },
  ]);
  assert.throws(
    () => buildBusinessDeletionPlan({
      ownerUid: 'owner-123',
      businessProfileId: 'garden_team_42',
      publicConfigId: 'owner-123_other_business',
    }),
    /does not belong to this business/,
  );
});

test('legacy unscoped records belong only to the default business', () => {
  assert.equal(recordBelongsToBusiness({}, 'default_business'), true);
  assert.equal(recordBelongsToBusiness({}, 'garden_team_42'), false);
  assert.equal(
    recordBelongsToBusiness(
      { businessProfileId: 'garden_team_42' },
      'garden_team_42',
    ),
    true,
  );
  assert.equal(
    recordBelongsToBusiness(
      { businessProfileId: 'garden_team_42' },
      'default_business',
    ),
    false,
  );
});

test('completed and financial jobs are preserved during business deletion', () => {
  assert.equal(shouldPreserveBusinessJob({ status: 'completed' }), true);
  assert.equal(shouldPreserveBusinessJob({ paid: true }), true);
  assert.equal(
    shouldPreserveBusinessJob({ invoiceNumber: 'INV-1042' }),
    true,
  );
  assert.equal(shouldPreserveBusinessJob({ status: 'pending' }), false);
});
