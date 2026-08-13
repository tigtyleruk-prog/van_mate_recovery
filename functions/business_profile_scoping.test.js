'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  isAmbiguousBusinessRecord,
  recordBelongsToBusiness,
} = require('./business_profile_scoping');

test('explicit profile scope matches exactly and preserves other profiles', () => {
  assert.equal(recordBelongsToBusiness({ businessProfileId: 'target' }, 'target'), true);
  assert.equal(recordBelongsToBusiness({ businessProfileId: 'other' }, 'target'), false);
});

test('missing or empty profile scope is ambiguous, including default_business', () => {
  assert.equal(isAmbiguousBusinessRecord({}), true);
  assert.equal(recordBelongsToBusiness({}, 'default_business'), false);
  assert.equal(recordBelongsToBusiness({ businessProfileId: ' ' }, 'default_business'), false);
});

test('deletion sources contain no local default-profile fallback', () => {
  for (const file of ['business_mate_job_deletion.js', 'index.js']) {
    const source = fs.readFileSync(path.join(__dirname, file), 'utf8');
    assert.doesNotMatch(
      source,
      /if\s*\(\s*!recordProfileId\s*\)[\s\S]{0,120}businessProfileId\s*===\s*DEFAULT_BUSINESS_PROFILE_ID/,
      file,
    );
  }
});
