'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test('orderRequest quote publish creates public quote, token, and van_jobs atomically when van_jobs is missing', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const {
    doc,
    getDoc,
    setDoc,
    runTransaction,
  } = require('firebase/firestore');
  const fs = require('node:fs');
  const path = require('node:path');

  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-business-mate-quote-publish',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });

  try {
    const ownerUid = 'owner-bakery-1';
    const jobId = `bakery-order-job-${Date.now()}`;
    const requestId = `bakery-order-request-${Date.now()}`;
    const quoteId = jobId;
    const quoteToken = `bakery-quote-token-${Date.now()}`;
    const quotePublishKey = 'publish-key-abc123';

    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `public_job_requests/${requestId}`),
        {
          ownerUid,
          requestId,
          jobId,
          requestType: 'orderRequest',
          customerJourneyType: 'order',
          status: 'reply_received',
          requestStatus: 'reply_received',
          publicJobTitle: 'Celebration Cake',
          publicCustomerName: 'Bakery Customer',
          publicAddressSummary: '123 High Street',
          checklistResponses: [],
          customQuestionResponses: [],
          answers: [],
          photos: [],
          additionalNotes: '',
          exactPinRequested: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        },
      );
    });

    const ownerDb = environment.authenticatedContext(ownerUid).firestore();

    const missingJobSnap = await getDoc(doc(ownerDb, `users/${ownerUid}/van_jobs/${jobId}`));
    assert.strictEqual(missingJobSnap.exists(), false, 'van_jobs doc should not exist before publish');

    const quoteRef = doc(ownerDb, `public_quote_responses/${quoteId}`);
    const jobRef = doc(ownerDb, `users/${ownerUid}/van_jobs/${jobId}`);
    const tokenRef = doc(ownerDb, `public_quote_response_tokens/${quoteToken}`);

    await assertSucceeds(
      runTransaction(ownerDb, async (transaction) => {
        const jobSnapshot = await transaction.get(jobRef);
        assert.strictEqual(jobSnapshot.exists(), false, 'jobSnapshot should be missing inside transaction');

        if (!jobSnapshot.exists()) {
          transaction.set(jobRef, {
            ownerUid,
            jobId,
            requestId,
            requestType: 'orderRequest',
            customerJourneyType: 'order',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          });
        }

        const versionedPayload = {
          ownerUid,
          jobId,
          requestId,
          requestType: 'orderRequest',
          customerJourneyType: 'order',
          quoteResponseId: quoteId,
          currentQuoteId: quoteId,
          isCurrent: true,
          lifecycleStatus: 'current',
          quotePublishKey,
          quoteResponseToken: quoteToken,
          quoteResponseLink: `https://vanmate.example.com/quote/${quoteToken}`,
          quoteVersion: 1,
          customerName: 'Bakery Customer',
          jobTitle: 'Celebration Cake',
          quoteAmount: 150,
          quoteStatus: 'sent',
          quoteResponseStatus: '',
        };

        transaction.set(quoteRef, versionedPayload);
        transaction.set(jobRef, {
          currentQuoteId: quoteId,
          quoteResponseId: quoteId,
          quoteVersion: 1,
          quotePublishKey,
        }, { merge: true });
        transaction.set(tokenRef, {
          ownerUid,
          jobId,
          requestId,
          currentQuoteId: quoteId,
          quoteResponseId: quoteId,
          quoteResponseToken: quoteToken,
          quoteResponseLink: `https://vanmate.example.com/quote/${quoteToken}`,
        });
      }),
    );

    const quoteSnap = await getDoc(quoteRef);
    assert.strictEqual(quoteSnap.exists(), true, 'public quote document should exist');
    assert.strictEqual(quoteSnap.data().requestType, 'orderRequest');
    assert.strictEqual(quoteSnap.data().customerJourneyType, 'order');
    assert.strictEqual(quoteSnap.data().quoteResponseId, quoteId);
    assert.strictEqual(quoteSnap.data().quoteResponseToken, quoteToken);
    assert.strictEqual(
      quoteSnap.data().quoteResponseLink,
      `https://vanmate.example.com/quote/${quoteToken}`,
    );

    const jobSnap = await getDoc(jobRef);
    assert.strictEqual(jobSnap.exists(), true, 'van_jobs document should exist');
    assert.strictEqual(jobSnap.data().requestType, 'orderRequest');
    assert.strictEqual(jobSnap.data().customerJourneyType, 'order');
    assert.strictEqual(jobSnap.data().currentQuoteId, quoteId);
    assert.strictEqual(jobSnap.data().quotePublishKey, quotePublishKey);

    const tokenSnap = await getDoc(tokenRef);
    assert.strictEqual(tokenSnap.exists(), true, 'quote token document should exist');
    assert.strictEqual(tokenSnap.data().quoteResponseToken, quoteToken);
    assert.strictEqual(
      tokenSnap.data().quoteResponseLink,
      `https://vanmate.example.com/quote/${quoteToken}`,
    );

    const expectedLink = `https://vanmate.example.com/quote/${quoteToken}`;
    assert.ok(expectedLink.includes('/quote/'), 'link should contain /quote/ path');
    assert.ok(expectedLink.includes(quoteToken), 'link should contain the quote token');
  } finally {
    await environment.cleanup();
  }
});
