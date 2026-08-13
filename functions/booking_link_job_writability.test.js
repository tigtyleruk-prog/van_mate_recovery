'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  buildRequestJobMirror,
  buildQuoteJobMirror,
} = require('./index.js').__test__;

test('buildRequestJobMirror preserves businessProfileId from the source request', () => {
  const before = {};
  const after = {
    ownerUid: 'owner-bakery-1',
    requestId: 'request-1',
    jobId: 'booking_1785937527532_874',
    businessProfileId: 'bakery_profile',
    status: 'reply_received',
    requestStatus: 'reply_received',
    publicJobTitle: 'Celebration Cake',
    publicCustomerName: 'Bakery Customer',
    publicAddressSummary: '123 High Street',
    checklistResponses: [],
    customQuestionResponses: [],
    answers: [],
    additionalNotes: '',
    exactPinRequested: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const existingJob = {};
  const update = buildRequestJobMirror({
    before,
    after,
    existingJob,
    requestId: 'request-1',
    ownerUid: 'owner-bakery-1',
    jobId: 'booking_1785937527532_874',
  });

  assert.strictEqual(update.businessProfileId, 'bakery_profile', 'mirror should carry the source businessProfileId');
  assert.strictEqual(update.ownerUid, 'owner-bakery-1');
  assert.strictEqual(update.jobId, 'booking_1785937527532_874');
  assert.strictEqual(update.status, 'replyReceived');
});

test('a stale deleted request cannot hide an otherwise active quoted job through the mirror', () => {
  const update = buildRequestJobMirror({
    before: { status: 'quote_sent' },
    after: {
      requestId: 'request-stale-delete',
      jobId: 'job-active-quote',
      status: 'quote_sent',
      requestStatus: 'quote_sent',
      quoteStatus: 'quote_sent',
      quoteResponseStatus: 'sent',
      deleted: true,
      archived: true,
      deletedByDriver: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    existingJob: {
      status: 'quoteSent',
      requestStatus: 'quote_sent',
      currentQuoteId: 'job-active-quote',
      quoteResponseId: 'job-active-quote',
      deleted: false,
      archived: false,
    },
    requestId: 'request-stale-delete',
    ownerUid: 'owner-1',
    jobId: 'job-active-quote',
  });

  assert.notStrictEqual(update.deleted, true);
  assert.notStrictEqual(update.archived, true);
  assert.strictEqual(update.status, 'quoteSent');
  assert.strictEqual(update.currentQuoteId, undefined);
  assert.strictEqual(update.quoteResponseId, undefined);
});

test('buildRequestJobMirror falls back to existingJob.businessProfileId when source is missing', () => {
  const after = {
    ownerUid: 'owner-bakery-1',
    requestId: 'request-2',
    jobId: 'booking_999',
    status: 'reply_received',
    requestStatus: 'reply_received',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const existingJob = {
    businessProfileId: 'existing_profile',
    status: 'pending',
  };
  const update = buildRequestJobMirror({
    before: {},
    after,
    existingJob,
    requestId: 'request-2',
    ownerUid: 'owner-bakery-1',
    jobId: 'booking_999',
  });

  assert.strictEqual(update.businessProfileId, 'existing_profile', 'mirror should fall back to existing job businessProfileId');
});

test('buildQuoteJobMirror preserves businessProfileId from the source quote response', () => {
  const after = {
    ownerUid: 'owner-bakery-1',
    requestId: 'request-1',
    jobId: 'booking_1785937527532_874',
    businessProfileId: 'bakery_profile',
    quoteStatus: 'sent',
    quoteResponseStatus: 'sent',
    quoteResponseId: 'quote-1',
    currentQuoteId: 'quote-1',
    quoteAmount: 150,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const existingJob = {};
  const update = buildQuoteJobMirror({
    before: {},
    after,
    existingJob,
    quoteId: 'quote-1',
    ownerUid: 'owner-bakery-1',
    jobId: 'booking_1785937527532_874',
  });

  assert.strictEqual(update.businessProfileId, 'bakery_profile', 'quote mirror should carry the source businessProfileId');
});

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test('Booking Link Order Request for active business produces writable van_jobs without archivedReadOnly', {
  skip: !emulatorAvailable,
}, async () => {
  const {
    assertSucceeds,
    initializeTestEnvironment,
  } = require('@firebase/rules-unit-testing');
  const {
    doc,
    getDoc,
    runTransaction,
    setDoc,
  } = require('firebase/firestore');

  const environment = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-business-mate-bakery-order',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });

  try {
    const ownerUid = 'owner-bakery-order-1';
    const jobId = `booking-order-${Date.now()}`;
    const requestId = `request-${Date.now()}`;
    const businessProfileId = 'bakery_profile';

    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'public_booking_links', 'bakery-link'),
        {
          ownerUid,
          businessProfileId,
          isActive: true,
          services: [
            {
              id: 'cake-service',
              name: 'Celebration Cake',
              requestType: 'orderRequest',
              serviceFlow: 'order',
              customerJourneyType: 'order',
              pricingMode: 'fixed',
              fixedPriceAmount: 150,
              showPhoneNumber: false,
              requirePhoneNumber: false,
              showEmailAddress: false,
              requireEmailAddress: false,
              requireAddress: false,
              requestPhotos: false,
              requestFlowOptions: {
                showFulfilmentChoice: true,
                askPreferredDate: false,
                askPreferredTime: false,
                showNotes: false,
              },
            },
          ],
        },
      );

      await setDoc(
        doc(context.firestore(), 'public_job_requests', requestId),
        {
          ownerUid,
          requestId,
          jobId,
          businessProfileId,
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

    const update = buildRequestJobMirror({
      before: {},
      after: {
        ownerUid,
        requestId,
        jobId,
        businessProfileId,
        status: 'reply_received',
        requestStatus: 'reply_received',
        publicJobTitle: 'Celebration Cake',
        publicCustomerName: 'Bakery Customer',
        publicAddressSummary: '123 High Street',
        checklistResponses: [],
        customQuestionResponses: [],
        answers: [],
        additionalNotes: '',
        exactPinRequested: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      existingJob: {},
      requestId,
      ownerUid,
      jobId,
    });

    const jobRef = doc(ownerDb, `users/${ownerUid}/van_jobs/${jobId}`);
    await assertSucceeds(setDoc(jobRef, update, { merge: true }));

    const jobSnap = await getDoc(jobRef);
    assert.strictEqual(jobSnap.exists(), true, 'van_jobs document should exist after mirror');
    assert.strictEqual(
      jobSnap.data().businessProfileId,
      businessProfileId,
      'van_jobs must carry businessProfileId so deletion scoping is correct',
    );
    assert.strictEqual(
      jobSnap.data().archivedReadOnly,
      undefined,
      'van_jobs must not have archivedReadOnly for an active business job',
    );
    assert.strictEqual(
      jobSnap.data().archived,
      undefined,
      'van_jobs must not be archived for an active business job',
    );

    const quoteId = jobId;
    const quoteRef = doc(ownerDb, `public_quote_responses/${quoteId}`);
    const tokenRef = doc(ownerDb, `public_quote_response_tokens/token-${Date.now()}`);

    await assertSucceeds(
      runTransaction(ownerDb, async (transaction) => {
        const jobSnapshot = await transaction.get(jobRef);
        assert.strictEqual(jobSnapshot.exists(), true, 'job must exist inside quote-publish transaction');

        transaction.set(quoteRef, {
          ownerUid,
          jobId,
          requestId,
          quoteResponseId: quoteId,
          currentQuoteId: quoteId,
          isCurrent: true,
          lifecycleStatus: 'current',
          quotePublishKey: 'publish-key-abc123',
          quoteResponseToken: tokenRef.id,
          quoteResponseLink: `https://vanmate.example.com/quote/${tokenRef.id}`,
          quoteVersion: 1,
          customerName: 'Bakery Customer',
          jobTitle: 'Celebration Cake',
          quoteAmount: 150,
          quoteStatus: 'sent',
          quoteResponseStatus: '',
        });

        transaction.set(jobRef, {
          currentQuoteId: quoteId,
          quoteResponseId: quoteId,
          quoteVersion: 1,
          quotePublishKey: 'publish-key-abc123',
        }, { merge: true });

        transaction.set(tokenRef, {
          ownerUid,
          jobId,
          requestId,
          currentQuoteId: quoteId,
          quoteResponseId: quoteId,
          quoteResponseToken: tokenRef.id,
          quoteResponseLink: `https://vanmate.example.com/quote/${tokenRef.id}`,
        });
      }),
    );

    const quoteSnap = await getDoc(quoteRef);
    assert.strictEqual(quoteSnap.exists(), true, 'public quote document should exist after publish');
    assert.strictEqual(quoteSnap.data().quoteStatus, 'sent');
  } finally {
    await environment.cleanup();
  }
});
