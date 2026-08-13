'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  CANONICAL_GROUPS,
  authoritativeFulfilment,
  buildPlan,
  classifyService,
  servicePatch,
} = require('./scripts/migrate_bakery_movement_contract');

const exact = {
  id: 'service-live-1', name: 'Renamed bakery service', isActive: true,
  starterPackId: 'bakery', starterTemplateId: 'bakery_celebration_cakes',
  requestType: 'orderRequest', serviceFlow: 'order',
  serviceCapabilityIds: ['booking', 'place_order', 'photo_upload'],
  requestFlowOptions: { showFulfilmentChoice: true },
  capabilityContract: { movementCapabilityIds: [], movementChoiceGroups: [] },
};

test('exact canonical Bakery service is classified correctly', () => {
  assert.equal(classifyService(exact), 'A. EXACT CANONICAL MATCH');
});

test('ambiguous legacy service is rejected', () => {
  const service = { ...exact, starterPackId: '', starterTemplateId: '', id: 'legacy-1', name: 'Celebration Cakes' };
  assert.equal(classifyService(service), 'C. AMBIGUOUS');
  assert.ok(servicePatch(service, 'C. AMBIGUOUS').errors.length);
});

test('legacy movement vocabulary is not treated as authoritative current fulfilment', () => {
  assert.equal(authoritativeFulfilment({
    serviceCapabilityIds: ['booking', 'customer_collects', 'local_delivery'],
  }), false);
});

test('dry-run performs zero writes', async () => {
  let writes = 0;
  const data = { businessProfileId: 'profile-1', isActive: true, services: [exact] };
  const firestore = {
    collection: () => ({
      get: async () => ({ docs: [{ id: 'link-1', data: () => data }] }),
      doc: () => ({ update: () => { writes += 1; } }),
    }),
  };
  const plan = await buildPlan({ firestore });
  assert.equal(plan.length, 1);
  assert.equal(writes, 0);
});

test('approved repair produces exactly Collection plus Local delivery', () => {
  const result = servicePatch(exact, 'A. EXACT CANONICAL MATCH');
  assert.deepEqual(result.patch['capabilityContract.movementChoiceGroups'], CANONICAL_GROUPS);
  assert.deepEqual(result.patch['capabilityContract.movementCapabilityIds'], [
    'customer_visits_business', 'local_delivery',
  ]);
  assert.equal(JSON.stringify(result.patch).includes('nationwide'), false);
});

test('unrelated capabilities remain unchanged and a second run is a no-op', () => {
  const first = servicePatch(exact, 'A. EXACT CANONICAL MATCH').patch;
  const repaired = {
    ...exact,
    serviceCapabilityIds: first.serviceCapabilityIds,
    capabilityContract: {
      movementCapabilityIds: first['capabilityContract.movementCapabilityIds'],
      movementChoiceGroups: first['capabilityContract.movementChoiceGroups'],
    },
  };
  assert.deepEqual(repaired.serviceCapabilityIds.filter((id) => ['booking', 'place_order', 'photo_upload'].includes(id)),
    ['booking', 'place_order', 'photo_upload']);
  assert.deepEqual(servicePatch(repaired, 'A. EXACT CANONICAL MATCH').patch, {});
});
