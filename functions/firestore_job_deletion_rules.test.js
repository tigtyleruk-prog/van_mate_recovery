'use strict';

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test('tombstones prevent stale client job and request recreation', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc, setDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-business-mate-job-deletion',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'users/owner-1/van_job_deletion_tombstones/job-1',
        ),
        {
          ownerUid: 'owner-1',
          businessProfileId: 'courier-1',
          requestId: 'request-1',
          jobId: 'job-1',
          operationId: 'operation-1',
          deletionState: 'complete',
        },
      );
    });

    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    await assertFails(setDoc(doc(ownerDb, 'users/owner-1/van_jobs/job-1'), {
      jobId: 'job-1',
      status: 'pending',
    }));
    await assertFails(setDoc(doc(ownerDb, 'public_job_requests/request-1'), {
      ownerUid: 'owner-1',
      businessProfileId: 'courier-1',
      requestId: 'request-1',
      jobId: 'job-1',
    }));
    await assertFails(setDoc(doc(ownerDb, 'van_job_requests/request-1'), {
      ownerUid: 'owner-1',
      businessProfileId: 'courier-1',
      requestId: 'request-1',
      jobId: 'job-1',
    }));
    await assertSucceeds(setDoc(doc(ownerDb, 'users/owner-1/van_jobs/job-2'), {
      jobId: 'job-2',
      status: 'pending',
    }));
    await assertFails(getDoc(doc(
      ownerDb,
      'users/owner-1/van_job_deletion_tombstones/job-1',
    )));
  } finally {
    await environment.cleanup();
  }
});
