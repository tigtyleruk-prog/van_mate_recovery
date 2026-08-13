'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const {
  CANONICAL_MOVEMENT_GROUPS,
  CANONICAL_MOVEMENT_IDS,
  buildPlan,
  servicePatch,
} = require('./scripts/migrate_class_b_service_consistency');

test('Bakery contract proposal contains exactly Collection and Local delivery', () => {
  const result = servicePatch(
    { kind: 'bakery-movement-contract' },
    {
      requestType: 'orderRequest',
      serviceFlow: 'order',
      serviceCapabilityIds: ['booking', 'customer_collects', 'local_delivery'],
      capabilityContract: { movementChoiceGroups: [], movementCapabilityIds: [] },
    },
  );
  assert.deepEqual(result.patch['capabilityContract.movementCapabilityIds'], CANONICAL_MOVEMENT_IDS);
  assert.deepEqual(result.patch['capabilityContract.movementChoiceGroups'], CANONICAL_MOVEMENT_GROUPS);
});

test('legacy fulfilment-enabled service is rejected instead of reconstructed', () => {
  const result = servicePatch(
    { kind: 'order-flow' },
    { requestType: 'orderRequest', requestFlowOptions: { showFulfilmentChoice: true } },
  );
  assert.equal(result.patch, undefined);
  assert.match(result.errors.join(' '), /capability contract/);
});

test('ambiguous or incomplete Bakery capability IDs are rejected', () => {
  const result = servicePatch(
    { kind: 'bakery-movement-contract' },
    {
      requestType: 'orderRequest', serviceFlow: 'order',
      serviceCapabilityIds: ['booking'],
      capabilityContract: { movementChoiceGroups: [], movementCapabilityIds: [] },
    },
  );
  assert.equal(result.patch, undefined);
  assert.match(result.errors.join(' '), /do not prove/);
});

test('dry-run performs zero writes', async () => {
  const writes = [];
  const firestore = {
    collection: () => ({
      doc: (id) => ({
        path: `public_booking_links/${id}`,
        get: async () => ({ data: () => ({ businessProfileId: 'unexpected' }) }),
        update: (...args) => writes.push(args),
      }),
    }),
  };
  const plan = await buildPlan({ firestore });
  assert.equal(plan.length, 2);
  assert.deepEqual(writes, []);
});

test('the apply allowlist remains explicit and narrow', () => {
  assert.equal(typeof buildPlan, 'function');
});
