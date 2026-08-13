'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

async function setupDoc(environment, collectionPath, docId, data) {
  await environment.withSecurityRulesDisabled(async (context) => {
    const { doc, setDoc } = require('firebase/firestore');
    await setDoc(doc(context.firestore(), collectionPath, docId), data);
  });
}

test('owner can get an existing quote they own', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    await setupDoc(environment, 'public_quote_responses', 'quote-existing', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteStatus: 'pending',
    });
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    await assertSucceeds(getDoc(doc(ownerDb, 'public_quote_responses', 'quote-existing')));
  } finally {
    await environment.cleanup();
  }
});

test('another authenticated user cannot get an owned quote', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    await setupDoc(environment, 'public_quote_responses', 'quote-owned', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteStatus: 'pending',
    });
    const otherDb = environment.authenticatedContext('other-2').firestore();
    await assertFails(getDoc(doc(otherDb, 'public_quote_responses', 'quote-owned')));
  } finally {
    await environment.cleanup();
  }
});

test('unauthenticated direct read is allowed for token-based public page', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    await setupDoc(environment, 'public_quote_responses', 'quote-public', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteStatus: 'pending',
    });
    const unauthDb = environment.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(unauthDb, 'public_quote_responses', 'quote-public')));
  } finally {
    await environment.cleanup();
  }
});

test('owner transaction succeeds when the quote does not yet exist', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, runTransaction } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const quoteRef = doc(ownerDb, 'public_quote_responses', 'quote-new');
    const jobRef = doc(ownerDb, 'users', 'owner-1', 'van_jobs', 'job-1');
    await assertSucceeds(
      runTransaction(ownerDb, async (transaction) => {
        const jobSnap = await transaction.get(jobRef);
        if (!jobSnap.exists) {
          transaction.set(jobRef, {
            ownerUid: 'owner-1',
            jobId: 'job-1',
            requestId: 'request-1',
            status: 'pending',
          });
        }
        const quoteSnap = await transaction.get(quoteRef);
        if (!quoteSnap.exists) {
          transaction.set(quoteRef, {
            ownerUid: 'owner-1',
            jobId: 'job-1',
            requestId: 'request-1',
            quoteStatus: 'pending',
          });
        }
      }),
    );
  } finally {
    await environment.cleanup();
  }
});

test('owner transaction succeeds when updating an existing quote', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, setDoc, runTransaction } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const quoteRef = doc(ownerDb, 'public_quote_responses', 'quote-existing');
    const jobRef = doc(ownerDb, 'users', 'owner-1', 'van_jobs', 'job-1');
    await setupDoc(environment, 'users/owner-1/van_jobs', 'job-1', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      requestId: 'request-1',
      status: 'pending',
    });
    await setupDoc(environment, 'public_quote_responses', 'quote-existing', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteStatus: 'pending',
    });
    await assertSucceeds(
      runTransaction(ownerDb, async (transaction) => {
        const jobSnap = await transaction.get(jobRef);
        const quoteSnap = await transaction.get(quoteRef);
        const quoteData = quoteSnap.data() || {};
        transaction.set(quoteRef, {
          ...quoteData,
          quoteStatus: 'accepted',
          quoteResponseStatus: 'accepted',
          quoteAccepted: true,
          quoteDeclined: false,
        }, { merge: true });
      }),
    );
  } finally {
    await environment.cleanup();
  }
});

test('owner transaction creates job and quote atomically when both do not exist', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, runTransaction } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const quoteRef = doc(ownerDb, 'public_quote_responses', 'quote-atomic');
    const jobRef = doc(ownerDb, 'users', 'owner-1', 'van_jobs', 'job-1');
    await assertSucceeds(
      runTransaction(ownerDb, async (transaction) => {
        const jobSnap = await transaction.get(jobRef);
        const quoteSnap = await transaction.get(quoteRef);
        if (!jobSnap.exists) {
          transaction.set(jobRef, {
            ownerUid: 'owner-1',
            jobId: 'job-1',
            requestId: 'request-1',
            status: 'pending',
          });
        }
        if (!quoteSnap.exists) {
          transaction.set(quoteRef, {
            ownerUid: 'owner-1',
            jobId: 'job-1',
            requestId: 'request-1',
            quoteStatus: 'pending',
          });
        }
      }),
    );
  } finally {
    await environment.cleanup();
  }
});

test('token reads preserve public missing-token access and owner-only existing access', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const missingToken = 'missing-token';
    const tokenPath = 'public_quote_response_tokens';
    const unauthDb = environment.unauthenticatedContext().firestore();
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const otherDb = environment.authenticatedContext('other-2').firestore();

    await assertSucceeds(getDoc(doc(unauthDb, tokenPath, missingToken)));
    await assertSucceeds(getDoc(doc(ownerDb, tokenPath, missingToken)));

    await setupDoc(environment, tokenPath, 'owned-token', {
      ownerUid: 'owner-1',
      jobId: 'job-1',
      quoteResponseId: 'quote-1',
    });
    await assertSucceeds(getDoc(doc(ownerDb, tokenPath, 'owned-token')));
    await assertFails(getDoc(doc(otherDb, tokenPath, 'owned-token')));
  } finally {
    await environment.cleanup();
  }
});

test('token create remains restricted to its matching owner', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, setDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const ownerDb = environment.authenticatedContext('owner-1').firestore();
    const otherDb = environment.authenticatedContext('other-2').firestore();
    await assertSucceeds(
      setDoc(doc(ownerDb, 'public_quote_response_tokens', 'owner-token'), {
        ownerUid: 'owner-1',
        jobId: 'job-1',
        quoteResponseId: 'quote-1',
      }),
    );
    await assertFails(
      setDoc(doc(otherDb, 'public_quote_response_tokens', 'wrong-owner-token'), {
        ownerUid: 'owner-1',
        jobId: 'job-1',
        quoteResponseId: 'quote-1',
      }),
    );
  } finally {
    await environment.cleanup();
  }
});

test('first publish transaction reads a missing token then creates quote and token idempotently', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const { doc, getDoc, runTransaction, setDoc } = require('firebase/firestore');
  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'vanmate-56eac',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });
  try {
    const ownerUid = 'owner-1';
    const jobId = 'job-first-publish';
    const quoteId = jobId;
    const token = 'first-publish-token';
    const ownerDb = environment.authenticatedContext(ownerUid).firestore();
    const jobRef = doc(ownerDb, 'users', ownerUid, 'van_jobs', jobId);
    const quoteRef = doc(ownerDb, 'public_quote_responses', quoteId);
    const tokenRef = doc(ownerDb, 'public_quote_response_tokens', token);
    await setDoc(jobRef, {
      ownerUid,
      jobId,
      requestId: 'request-1',
      status: 'draft',
    });

    const publish = () => runTransaction(ownerDb, async (transaction) => {
      await transaction.get(jobRef);
      await transaction.get(quoteRef);
      const tokenSnapshot = await transaction.get(tokenRef);
      transaction.set(quoteRef, {
        ownerUid,
        jobId,
        requestId: 'request-1',
        quoteStatus: 'sent',
        quotePublishKey: 'publish-key-1',
      }, { merge: true });
      transaction.set(jobRef, {
        currentQuoteId: quoteId,
        quoteResponseId: quoteId,
      }, { merge: true });
      if (!tokenSnapshot.exists()) {
        transaction.set(tokenRef, {
          ownerUid,
          jobId,
          quoteResponseId: quoteId,
          quotePublishKey: 'publish-key-1',
        });
      }
    });

    await assertSucceeds(publish());
    const [createdQuote, createdToken] = await Promise.all([
      getDoc(quoteRef),
      getDoc(tokenRef),
    ]);
    assert.equal(createdQuote.exists(), true);
    assert.equal(createdToken.exists(), true);
    assert.equal(createdToken.data().quotePublishKey, 'publish-key-1');
    await assertSucceeds(publish());
  } finally {
    await environment.cleanup();
  }
});
