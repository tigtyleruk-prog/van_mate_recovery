'use strict';

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test('optional archive and owner fields remain safe in scoped Firestore rules', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const {
    doc,
    getDoc,
    setDoc,
  } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-optional-fields-rules',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });

  async function seed(collectionPath, documentId, data) {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), collectionPath, documentId), data);
    });
  }

  try {
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const otherDb = environment.authenticatedContext('other-1').firestore();

    for (const [suffix, archiveValue] of [
      ['absent', undefined],
      ['false', false],
      ['true', true],
    ]) {
      const data = { ownerUid: 'owner-1', status: 'pending' };
      if (archiveValue !== undefined) data.archivedReadOnly = archiveValue;
      await seed('users/owner-1/van_jobs', `job-${suffix}`, data);
      const update = setDoc(
        doc(ownerDb, 'users/owner-1/van_jobs', `job-${suffix}`),
        { status: 'updated' },
        { merge: true },
      );
      if (archiveValue === true) {
        await assertFails(update);
      } else {
        await assertSucceeds(update);
      }
    }

    for (const [suffix, archiveValue] of [
      ['absent', undefined],
      ['false', false],
      ['true', true],
    ]) {
      const data = { ownerUid: 'owner-1', quoteStatus: 'pending' };
      if (archiveValue !== undefined) data.archivedReadOnly = archiveValue;
      await seed('users/owner-1/van_quotes', `quote-${suffix}`, data);
      const update = setDoc(
        doc(ownerDb, 'users/owner-1/van_quotes', `quote-${suffix}`),
        { quoteStatus: 'sent' },
        { merge: true },
      );
      if (archiveValue === true) {
        await assertFails(update);
      } else {
        await assertSucceeds(update);
      }
    }

    await seed('users/owner-1/van_jobs', 'job-owner-check', {
      ownerUid: 'owner-1',
      status: 'pending',
    });
    await assertFails(setDoc(
      doc(otherDb, 'users/owner-1/van_jobs/job-owner-check'),
      { status: 'hijacked' },
      { merge: true },
    ));

    await seed('users/owner-1/van_job_deletion_tombstones', 'job-tombstoned', {
      ownerUid: 'owner-1',
      jobId: 'job-tombstoned',
      deletionState: 'complete',
    });
    await assertFails(setDoc(
      doc(ownerDb, 'users/owner-1/van_jobs/job-tombstoned'),
      { ownerUid: 'owner-1', jobId: 'job-tombstoned', status: 'pending' },
    ));
    await seed('users/owner-1/van_jobs', 'job-tombstoned-existing', {
      ownerUid: 'owner-1',
      jobId: 'job-tombstoned-existing',
      status: 'pending',
    });
    await seed(
      'users/owner-1/van_job_deletion_tombstones',
      'job-tombstoned-existing',
      {
        ownerUid: 'owner-1',
        jobId: 'job-tombstoned-existing',
        deletionState: 'complete',
      },
    );
    await assertSucceeds(setDoc(
      doc(ownerDb, 'users/owner-1/van_jobs/job-tombstoned-existing'),
      { status: 'updated-before-delete' },
      { merge: true },
    ));

    const missingToken = doc(ownerDb, 'public_quote_response_tokens/missing-token');
    await assertFails(getDoc(missingToken));
    await assertSucceeds(getDoc(
      doc(
        environment.unauthenticatedContext().firestore(),
        'public_quote_response_tokens/missing-token-public',
      ),
    ));

    await seed('public_quote_response_tokens', 'token-owned', {
      ownerUid: 'owner-1',
      quoteResponseId: 'quote-1',
    });
    await assertSucceeds(setDoc(
      doc(ownerDb, 'public_quote_response_tokens/token-owned'),
      { quoteResponseId: 'quote-2' },
      { merge: true },
    ));
    await assertFails(setDoc(
      doc(otherDb, 'public_quote_response_tokens/token-owned'),
      { quoteResponseId: 'hijacked' },
      { merge: true },
    ));
  } finally {
    await environment.cleanup();
  }
});
