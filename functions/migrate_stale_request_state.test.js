'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ALLOWLIST,
  BUSINESS_PROFILE_ID,
  LINKED_PATHS,
  applyPlan,
  approvedDeletionUpdate,
  buildPlan,
  validateChain,
} = require('./scripts/migrate_stale_request_state');

class Snapshot {
  constructor(path, data) { this.ref = { path }; this._data = data; this.exists = data !== undefined; }
  data() { return this._data; }
}

class Ref {
  constructor(db, path) { this.db = db; this.path = path; }
  async get() { return new Snapshot(this.path, this.db.docs[this.path]); }
}

class Transaction {
  constructor(db) { this.db = db; this.updates = []; }
  async get(ref) {
    return ref.get ? ref.get() : new Snapshot(ref.path, this.db.profileDocs[ref.path]);
  }
  update(ref, data) { this.updates.push({ path: ref.path, data }); }
}

class FakeDb {
  constructor(docs, profiles) {
    this.docs = docs;
    this.profiles = profiles;
    this.profileDocs = Object.fromEntries(profiles.map((data, i) => [`public_booking_links/profile-${i}`, data]));
    this.writes = [];
  }
  doc(path) { return new Ref(this, path); }
  collection(name) {
    return {
      where: () => ({ get: async () => ({ docs: this.profiles.map((data, i) => new Snapshot(`${name}/profile-${i}`, data)) }) }),
    };
  }
  async runTransaction(fn) {
    const tx = new Transaction(this);
    await fn(tx);
    for (const update of tx.updates) {
      const next = { ...(this.docs[update.path] || {}), ...update.data };
      if (update.data.deletedAt && update.data.deletedAt.constructor.name === 'DeleteTransform') {
        delete next.deletedAt;
      }
      this.docs[update.path] = next;
      this.writes.push(update);
    }
  }
}

function documents() {
  const request = {
    ownerUid: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1',
    requestId: 'booking_d010032c96dcd7a06c04ae0a0fcf79df',
    jobId: 'booking_1784668050802_879',
    businessProfileId: BUSINESS_PROFILE_ID,
    deleted: true,
    archived: true,
    deletedByDriver: true,
    deletedAt: 'timestamp',
  };
  return {
    [ALLOWLIST[0]]: { ...request },
    [ALLOWLIST[1]]: { ...request },
    [LINKED_PATHS.job]: {
      ownerUid: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1', jobId: 'booking_1784668050802_879',
      requestId: 'booking_d010032c96dcd7a06c04ae0a0fcf79df', businessProfileId: BUSINESS_PROFILE_ID,
      currentQuoteId: 'booking_1784668050802_879', quoteResponseId: 'booking_1784668050802_879',
      deleted: false, archived: false, archivedReadOnly: false,
    },
    [LINKED_PATHS.quote]: {
      ownerUid: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1', jobId: 'booking_1784668050802_879',
      requestId: 'booking_d010032c96dcd7a06c04ae0a0fcf79df', quoteResponseId: 'booking_1784668050802_879',
      businessProfileId: BUSINESS_PROFILE_ID, deleted: false, archived: false, archivedReadOnly: false,
    },
    [LINKED_PATHS.token]: {
      ownerUid: 'EZxC98rPJeNhgEGY8IlqjkGZ9Rt1', jobId: 'booking_1784668050802_879',
      requestId: 'booking_d010032c96dcd7a06c04ae0a0fcf79df', quoteResponseId: 'booking_1784668050802_879',
      businessProfileId: BUSINESS_PROFILE_ID, deleted: false, archived: false,
    },
  };
}

function fakePlan(db) { return buildPlan({ firestore: db }); }

test('dry-run performs zero writes', async () => {
  const db = new FakeDb(documents(), [{ businessProfileId: BUSINESS_PROFILE_ID, isActive: true }]);
  const plan = await fakePlan(db);
  assert.equal(plan.report.approved, true);
  assert.equal(db.writes.length, 0);
});

test('approved update contains only the four allowed deletion fields', () => {
  assert.deepEqual(Object.keys(approvedDeletionUpdate()).sort(), ['archived', 'deleted', 'deletedAt', 'deletedByDriver']);
});

test('both allowlisted documents are repaired and linked documents are untouched', async () => {
  const db = new FakeDb(documents(), [{ businessProfileId: BUSINESS_PROFILE_ID, isActive: true }]);
  const plan = await fakePlan(db);
  const linkedBefore = JSON.stringify([db.docs[LINKED_PATHS.job], db.docs[LINKED_PATHS.quote], db.docs[LINKED_PATHS.token]]);
  assert.equal(await applyPlan({ firestore: db, plan }), 2);
  for (const path of ALLOWLIST) {
    assert.equal(db.docs[path].deleted, false);
    assert.equal(db.docs[path].archived, false);
    assert.equal(db.docs[path].deletedByDriver, false);
    assert.equal(db.docs[path].deletedAt, undefined);
  }
  assert.equal(JSON.stringify([db.docs[LINKED_PATHS.job], db.docs[LINKED_PATHS.quote], db.docs[LINKED_PATHS.token]]), linkedBefore);
});

for (const [label, mutate] of [
  ['tombstone appears', (db) => { db.docs[LINKED_PATHS.tombstone] = { jobId: 'booking_1784668050802_879' }; }],
  ['job linkage changes', (db) => { db.docs[LINKED_PATHS.job].requestId = 'different'; }],
  ['quote linkage changes', (db) => { db.docs[LINKED_PATHS.quote].jobId = 'different'; }],
  ['token linkage changes', (db) => { db.docs[LINKED_PATHS.token].quoteResponseId = 'different'; }],
  ['business profile changes', (db) => { db.docs[LINKED_PATHS.job].businessProfileId = 'different'; }],
]) {
  test(`apply aborts if ${label}`, async () => {
    const db = new FakeDb(documents(), [{ businessProfileId: BUSINESS_PROFILE_ID, isActive: true }]);
    const plan = await fakePlan(db);
    mutate(db);
    await assert.rejects(() => applyPlan({ firestore: db, plan }), /Evidence changed|tombstone|linked/);
    assert.equal(db.writes.length, 0);
  });
}

test('second run is idempotent after repair', async () => {
  const db = new FakeDb(documents(), [{ businessProfileId: BUSINESS_PROFILE_ID, isActive: true }]);
  const plan = await fakePlan(db);
  await applyPlan({ firestore: db, plan });
  const second = await fakePlan(db);
  assert.equal(second.report.approved, true);
  assert.equal(second.report.alreadyRepaired, true);
  assert.equal(await applyPlan({ firestore: db, plan: second }), 0);
  assert.equal(db.writes.length, 2);
});

test('validator rejects changed profile evidence', () => {
  const db = new FakeDb(documents(), [{ businessProfileId: 'different', isActive: true }]);
  return fakePlan(db).then((plan) => {
    assert.equal(plan.report.approved, false);
    assert.match(plan.report.errors.join(' '), /business profile evidence/);
  });
});
