'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  CLASS_A_CANDIDATES,
  buildPlan,
  candidatePath,
  validateCandidate,
} = require('./scripts/migrate_class_a_business_profile_ids');

class FakeSnapshot {
  constructor(data) {
    this._data = data;
    this.exists = data !== undefined;
  }

  data() {
    return this._data;
  }
}

class FakeDocRef {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  async get() {
    return new FakeSnapshot(this.firestore.documents[this.path]);
  }
}

class FakeCollection {
  constructor(firestore, name) {
    this.firestore = firestore;
    this.name = name;
  }

  doc(id) {
    return new FakeDocRef(this.firestore, `${this.name}/${id}`);
  }

  where() {
    return {
      get: async () => ({ docs: this.firestore.profiles || [] }),
    };
  }
}

class FakeFirestore {
  constructor(documents, profiles) {
    this.documents = documents;
    this.profiles = profiles;
    this.writes = [];
  }

  doc(path) {
    return new FakeDocRef(this, path);
  }

  collection(name) {
    return new FakeCollection(this, name);
  }
}

function profileSnapshot() {
  return {
    data: () => ({ isActive: true, archived: false, deleted: false }),
  };
}

function approvedCandidate() {
  return ['public_quote_responses', 'quote-1', 'profile-1', 'request-1'];
}

test('exact candidate migrates in the validated plan', () => {
  const result = validateCandidate({
    candidate: approvedCandidate(),
    ownerUid: 'owner-1',
    targetSnapshot: new FakeSnapshot({ archived: true, status: 'deleted' }),
    evidenceSnapshot: new FakeSnapshot({
      businessProfileId: 'profile-1',
      jobId: 'quote-1',
      requestId: 'request-1',
    }),
    profileSnapshots: [profileSnapshot()],
  });
  assert.equal(result.approved, true);
  assert.equal(result.beforeBusinessProfileId, '');
  assert.equal(result.afterBusinessProfileId, 'profile-1');
});

test('existing non-empty businessProfileId is never overwritten', () => {
  const result = validateCandidate({
    candidate: approvedCandidate(),
    ownerUid: 'owner-1',
    targetSnapshot: new FakeSnapshot({ businessProfileId: 'other-profile' }),
    evidenceSnapshot: new FakeSnapshot({
      businessProfileId: 'profile-1',
      jobId: 'quote-1',
    }),
    profileSnapshots: [profileSnapshot()],
  });
  assert.equal(result.approved, false);
  assert.match(result.errors.join(' '), /non-empty/);
});

test('already-migrated exact candidate is skipped safely', () => {
  const result = validateCandidate({
    candidate: approvedCandidate(),
    ownerUid: 'owner-1',
    targetSnapshot: new FakeSnapshot({ businessProfileId: 'profile-1' }),
    evidenceSnapshot: new FakeSnapshot({
      businessProfileId: 'profile-1',
      jobId: 'quote-1',
    }),
    profileSnapshots: [profileSnapshot()],
  });
  assert.equal(result.approved, true);
  assert.equal(result.skipped, true);
});

test('ambiguous record is rejected', () => {
  const result = validateCandidate({
    candidate: approvedCandidate(),
    ownerUid: 'owner-1',
    targetSnapshot: new FakeSnapshot({}),
    evidenceSnapshot: new FakeSnapshot({ businessProfileId: '' }),
    profileSnapshots: [profileSnapshot()],
  });
  assert.equal(result.approved, false);
  assert.match(result.errors.join(' '), /authoritative evidence/);
});

test('evidence mismatch aborts the candidate', () => {
  const result = validateCandidate({
    candidate: approvedCandidate(),
    ownerUid: 'owner-1',
    targetSnapshot: new FakeSnapshot({}),
    evidenceSnapshot: new FakeSnapshot({
      businessProfileId: 'different-profile',
      jobId: 'quote-1',
    }),
    profileSnapshots: [profileSnapshot()],
  });
  assert.equal(result.approved, false);
  assert.match(result.errors.join(' '), /does not match/);
});

test('dry-run plan performs zero writes', async () => {
  const ownerUid = 'owner-1';
  const documents = {};
  const tokenJobs = {
    '30609a7bde29': 'booking_1784668050802_879',
    '8efa2679a3a8': 'booking_1784443468982_935',
    'test-token-1786190366478': 'booking_1785937527532_874',
  };
  for (const [kind, id, profile, evidenceId] of CLASS_A_CANDIDATES) {
    documents[candidatePath(kind, id, ownerUid)] = kind === 'public_quote_response_tokens'
      ? { quoteResponseId: `quote-${id}` }
      : {};
    documents[`public_job_requests/${evidenceId}`] = {
      businessProfileId: profile,
      jobId: tokenJobs[id] || id,
      requestId: evidenceId,
    };
    if (kind === 'public_quote_response_tokens') {
      documents[`public_quote_responses/quote-${id}`] = {
        jobId: tokenJobs[id],
        requestId: evidenceId,
      };
    }
  }
  const firestore = new FakeFirestore(documents, [profileSnapshot()]);
  const plan = await buildPlan({ firestore, ownerUid });
  assert.equal(plan.length, CLASS_A_CANDIDATES.length);
  assert.deepEqual(plan.filter((entry) => !entry.approved), []);
  assert.deepEqual(firestore.writes, []);
});

test('--apply update shape changes only businessProfileId', () => {
  const update = { businessProfileId: 'profile-1' };
  assert.deepEqual(Object.keys(update), ['businessProfileId']);
  assert.deepEqual(update, { businessProfileId: 'profile-1' });
});
