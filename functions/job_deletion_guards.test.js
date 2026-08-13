'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const indexSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const rulesSource = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

test('request and quote mirror triggers reject deletion tombstones', () => {
  assert.match(indexSource, /rejectTombstonedMirror\(\{[\s\S]*label: 'VanJobRequestMirror'/);
  assert.match(indexSource, /rejectTombstonedMirror\(\{[\s\S]*label: 'VanQuoteResponseMirror'/);
  assert.match(indexSource, /sourceRef: afterSnap\.ref/);
});

test('mirrors do not rehabilitate a job once it is archived or deleted', () => {
  assert.match(indexSource,
    /existingJobArchived[\s\S]*reason=job_hidden deleted=\$\{existingJobDeleted\} archived=\$\{existingJobArchived\}/);
  assert.match(indexSource,
    /existingJobDeleted[\s\S]*VanQuoteResponseMirror[\s\S]*reason=job_hidden/);
});

test('clients cannot read or write deletion control documents', () => {
  assert.match(rulesSource,
    /match \/van_job_deletion_tombstones\/\{jobId\} \{\s*allow read, write: if false;/);
  assert.match(rulesSource,
    /match \/van_job_deletion_previews\/\{previewId\} \{\s*allow read, write: if false;/);
});

test('client job and public record creation checks tombstones', () => {
  const checks = rulesSource.match(/van_job_deletion_tombstones/g) || [];
  assert.ok(checks.length >= 5, `expected tombstone rule guards, found ${checks.length}`);
});
