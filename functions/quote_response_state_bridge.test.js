const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { __test__ } = require('./index.js');
const functionsSource = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

test('collection Order Requests suppress exact pin after quote acceptance', () => {
  assert.equal(
    __test__.shouldRequireExactPinAfterQuoteAccepted({
      configured: true,
      requestType: 'orderRequest',
      fulfilmentType: 'collection',
    }),
    false,
  );
  assert.equal(
    __test__.shouldRequireExactPinAfterQuoteAccepted({
      configured: true,
      requestType: 'orderRequest',
      fulfilmentType: 'delivery',
    }),
    true,
  );
  assert.equal(
    __test__.shouldRequireExactPinAfterQuoteAccepted({
      configured: true,
      requestType: 'orderRequest',
      fulfilmentType: '',
    }),
    true,
  );

  const payload = __test__.buildDriverJobQuoteResponsePayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'collection-job',
      requestId: 'collection-request',
      requestType: 'orderRequest',
      fulfilmentType: 'collection',
      requiresExactPinAfterQuoteAccepted: true,
      proposedDate: '2026-07-15',
      proposedStartTime: '10:00',
      quoteStatus: 'sent',
      requestStatus: 'quote_sent',
    },
    existingJob: {
      requestId: 'collection-request',
      requiresExactPinAfterQuoteAccepted: true,
    },
    action: 'accept_proposed_time',
    quoteId: 'collection-quote',
    ownerUid: 'driver-1',
    jobId: 'collection-job',
    requestId: 'collection-request',
  });

  assert.equal(payload.requestType, 'orderRequest');
  assert.equal(payload.fulfilmentType, 'collection');
  assert.equal(payload.requiresExactPinAfterQuoteAccepted, false);
});

test('acceptQuoteProposedTime writes accepted and agreed-time fields for the driver job', () => {
  const payload = __test__.buildDriverJobQuoteResponsePayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-1',
      requestId: 'request-1',
      proposedDate: '2026-06-14',
      proposedStartTime: '10:00',
      estimatedDurationMinutes: 90,
      quoteStatus: 'sent',
      requestStatus: 'quote_sent',
    },
    existingJob: {
      requestId: 'request-1',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
    },
    action: 'accept_proposed_time',
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });

  assert.equal(payload.quoteStatus, 'accepted');
  assert.equal(payload.quoteAccepted, true);
  assert.equal(payload.acceptedProposedTime, true);
  assert.equal(payload.timeAccepted, true);
  assert.equal(payload.timeNotAccepted, false);
  assert.equal(payload.timingNeedsDecision, false);
  assert.equal(payload.timeAgreed, true);
  assert.equal(payload.needsAgreedTime, false);
  assert.equal(payload.readyForCalendar, true);
  assert.equal(payload.requestStatus, 'quote_accepted');
  assert.equal(payload.status, 'quoteAccepted');
  assert.equal(payload.agreedDurationMinutes, 90);
  assert.equal(payload.schedulingStatus, 'accepted_time');
  assert.equal(typeof payload.agreedStartAt.toDate, 'function');
});

test('acceptQuoteProposedTime uses the quote proposal, not requested collection time', () => {
  const payload = __test__.buildQuoteResponseWritePayload({
    quoteData: {
      proposedDate: '2026-07-27',
      proposedStartTime: '10:00',
      collectionDate: '2026-07-27',
      collectionTime: '09:00',
      dropOffDate: '2026-07-27',
      dropOffTime: '09:00',
    },
    action: 'accept_proposed_time',
  });

  assert.equal(payload.agreedDate, '2026-07-27');
  assert.equal(payload.agreedTime, '10:00');
  assert.equal(payload.scheduledStartTime, '10:00');
  assert.equal(payload.acceptedProposedStartTime, '10:00');
  assert.equal(payload.agreedStartAt.toDate().getHours(), 10);
});

test('acceptQuoteArrangeTime requires an alternative date and time', () => {
  assert.throws(
    () => __test__.buildQuoteResponseWritePayload({
      quoteData: {
        proposedDate: '2026-06-14',
        proposedStartTime: '10:00',
      },
      action: 'accept_arrange_time',
      data: {
        preferredDate: '2026-06-15',
      },
    }),
    /preferred alternative date and time/,
  );
});

test('acceptQuoteArrangeTime writes accepted quote with timing decision pending', () => {
  const payload = __test__.buildDriverJobQuoteResponsePayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-2',
      requestId: 'request-2',
      proposedDate: '2026-06-14',
      proposedStartTime: '10:00',
      estimatedDurationMinutes: 90,
      quoteAmount: 125,
      quoteStatus: 'sent',
      requestStatus: 'quote_sent',
    },
    existingJob: {
      requestId: 'request-2',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
    },
    action: 'accept_arrange_time',
    quoteId: 'quote-2',
    ownerUid: 'driver-1',
    jobId: 'job-2',
    requestId: 'request-2',
    data: {
      preferredDate: '2026-06-15',
      preferredTimeWindow: '14:30',
      preferredTimingNote: 'After school pickup',
    },
  });

  assert.equal(payload.quoteStatus, 'accepted');
  assert.equal(payload.quoteAccepted, true);
  assert.equal(payload.acceptedProposedTime, false);
  assert.equal(payload.proposedTimeAccepted, false);
  assert.equal(payload.timeAccepted, false);
  assert.equal(payload.timeNotAccepted, true);
  assert.equal(payload.timingNeedsDecision, true);
  assert.equal(payload.timeAgreed, false);
  assert.equal(payload.needsAgreedTime, true);
  assert.equal(payload.readyForCalendar, false);
  assert.equal(payload.requestStatus, 'quote_accepted');
  assert.equal(payload.status, 'quoteAccepted');
  assert.equal(payload.schedulingStatus, 'awaiting_agreed_time');
  assert.equal(payload.timeStatus, 'time_not_accepted');
  assert.equal(payload.timingStatus, 'timing_needs_decision');
  assert.equal(payload.agreedDateTime, null);
  assert.equal(payload.agreedStartAt, null);
  assert.equal(payload.preferredDate, '2026-06-15');
  assert.equal(payload.preferredTimeWindow, '14:30');
  assert.equal(payload.preferredTimingNote, 'After school pickup');
  assert.equal(payload.preferredTimingDecision, 'suggested_alternative');
  assert.equal(payload.proposedDate, '2026-06-14');
  assert.equal(payload.proposedStartTime, '10:00');
  assert.equal(payload.quoteAmount, 125);

  const requestUpdate = __test__.buildLinkedRequestQuoteStateUpdate({
    driverPayload: payload,
    includeExactPin: true,
  });

  assert.equal(requestUpdate.quoteTimingChoice, 'arrange_another_time');
  assert.equal(requestUpdate.schedulingStatus, 'awaiting_agreed_time');
  assert.equal(requestUpdate.readyForCalendar, false);
  assert.equal(requestUpdate.needsAgreedTime, true);
  assert.equal(requestUpdate.timeNotAccepted, true);
  assert.equal(requestUpdate.timingNeedsDecision, true);
  assert.equal(requestUpdate.preferredDate, '2026-06-15');
  assert.equal(requestUpdate.preferredTimeWindow, '14:30');
});

test('Function quote mirroring preserves explicit Courier delivery semantics', () => {
  const payload = __test__.buildQuoteJobMirror({
    before: {},
    after: {
      requestId: 'courier-request',
      requestType: 'pickupDeliveryRequest',
      startHandover: 'businessCollects',
      endHandover: 'businessDelivers',
      collectionAddress: '1 Collection Road',
      deliveryAddress: '2 Delivery Avenue',
      returnAddress: '',
      collectionDate: '2026-07-27T00:00:00.000Z',
      collectionTime: '09:00',
      deliveryDate: '2026-07-27T00:00:00.000Z',
      deliveryTime: '14:00',
      dropOffDate: '2026-07-27T00:00:00.000Z',
      dropOffTime: '09:00',
      pickUpDate: '2026-07-27T00:00:00.000Z',
      pickUpTime: '14:00',
      quoteStatus: 'sent',
      quoteResponseStatus: 'pending',
    },
    existingJob: {
      returnAddress: 'stale legacy destination',
      returnAddressSameAsCollection: true,
    },
    quoteId: 'courier-quote',
    ownerUid: 'driver-1',
    jobId: 'courier-job',
  });

  assert.equal(payload.startHandover, 'businessCollects');
  assert.equal(payload.endHandover, 'businessDelivers');
  assert.equal(payload.collectionAddress, '1 Collection Road');
  assert.equal(payload.deliveryAddress, '2 Delivery Avenue');
  assert.equal(payload.returnAddress, '');
  assert.equal(payload.returnAddressSameAsCollection, false);
  assert.equal(payload.collectionTime, '09:00');
  assert.equal(payload.deliveryTime, '14:00');
});

test('only the authoritative current quote can receive a customer response', () => {
  assert.equal(
    __test__.isPublicQuoteCurrentForJob({
      quoteId: 'quote-2',
      quoteData: {
        currentQuoteId: 'quote-2',
        isCurrent: true,
      },
      jobData: {
        currentQuoteId: 'quote-2',
        quoteResponseId: 'quote-2',
      },
    }),
    true,
  );
  assert.equal(
    __test__.isPublicQuoteCurrentForJob({
      quoteId: 'quote-1',
      quoteData: {
        currentQuoteId: 'quote-2',
        isCurrent: false,
        lifecycleStatus: 'superseded',
      },
      jobData: {
        currentQuoteId: 'quote-2',
        quoteResponseId: 'quote-2',
      },
    }),
    false,
  );
  assert.throws(
    () => __test__.assertPublicQuoteIsCurrent({
      quoteId: 'quote-1',
      quoteData: {
        currentQuoteId: 'quote-2',
        isCurrent: false,
      },
      jobData: { currentQuoteId: 'quote-2' },
    }),
    /This quote has been updated\. Please review the latest version\./,
  );
});

test('legacy single-quote jobs remain current without version metadata', () => {
  assert.equal(
    __test__.isPublicQuoteCurrentForJob({
      quoteId: 'legacy-quote',
      quoteData: {
        quoteResponseId: 'legacy-quote',
        quoteStatus: 'sent',
      },
      jobData: {
        quoteResponseId: 'legacy-quote',
      },
    }),
    true,
  );
});

test('repeated customer response actions are idempotent', () => {
  assert.equal(
    __test__.publicQuoteActionAlreadyApplied({
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
    }, 'accept_proposed_time'),
    true,
  );
  assert.equal(
    __test__.publicQuoteActionAlreadyApplied({
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteTimingChoice: 'arrange_another_time',
    }, 'accept_arrange_time'),
    true,
  );
  assert.equal(
    __test__.publicQuoteActionAlreadyApplied({
      quoteDeclined: true,
      quoteStatus: 'declined',
    }, 'decline_quote'),
    true,
  );
  assert.equal(
    __test__.publicQuoteActionAlreadyApplied({
      quoteAccepted: true,
      quoteTimingChoice: 'accepted_proposed_time',
    }, 'decline_quote'),
    false,
  );
});

test('customer responses switch state in one transaction and stale mirrors are ignored', () => {
  const responseStart = functionsSource.indexOf(
    'async function runPublicQuoteResponseAction',
  );
  const responseEnd = functionsSource.indexOf(
    'exports.acceptQuoteProposedTime',
    responseStart,
  );
  const responseSource = functionsSource.slice(responseStart, responseEnd);

  assert.match(responseSource, /admin\.firestore\(\)\.runTransaction/);
  assert.match(responseSource, /assertPublicQuoteIsCurrent/);
  assert.match(responseSource, /publicQuoteActionAlreadyApplied/);
  assert.match(responseSource, /transaction\.set\(target\.quoteRef/);
  assert.match(functionsSource, /reason=not_current/);
});

test('submitExactLocation preserves accepted proposed-time and calendar-ready fields', () => {
  const exactLocationPayload = __test__.buildQuoteExactLocationPayload({
    quoteData: {
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      schedulingStatus: 'accepted_time',
    },
    data: {
      latitude: 51.5,
      longitude: -0.12,
      note: 'Blue gate',
    },
  });

  const payload = __test__.buildDriverJobExactLocationPayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      estimatedDurationMinutes: 90,
      schedulingStatus: 'accepted_time',
    },
    existingJob: {
      requestId: 'request-1',
      quoteAccepted: true,
      acceptedProposedTime: true,
      readyForCalendar: true,
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      agreedDurationMinutes: 90,
      schedulingStatus: 'accepted_time',
    },
    exactLocationPayload,
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });

  assert.equal(payload.quoteStatus, 'accepted');
  assert.equal(payload.quoteAccepted, true);
  assert.equal(payload.acceptedProposedTime, true);
  assert.equal(payload.timeAgreed, true);
  assert.equal(payload.needsAgreedTime, false);
  assert.equal(payload.readyForCalendar, true);
  assert.equal(payload.exactPinShared, true);
  assert.equal(payload.exactPinLatitude, 51.5);
  assert.equal(payload.exactPinLongitude, -0.12);
  assert.equal(typeof payload.agreedStartAt.toDate, 'function');
});

test('acceptQuoteProposedTime mirrors accepted and agreed-time fields to linked request docs', () => {
  const driverPayload = __test__.buildDriverJobQuoteResponsePayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-1',
      requestId: 'request-1',
      proposedDate: '2026-06-14',
      proposedStartTime: '10:00',
      estimatedDurationMinutes: 90,
      quoteStatus: 'sent',
      requestStatus: 'quote_sent',
    },
    existingJob: {
      requestId: 'request-1',
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
    },
    action: 'accept_proposed_time',
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });

  const requestUpdate = __test__.buildLinkedRequestQuoteStateUpdate({
    driverPayload,
    includeExactPin: true,
  });

  assert.equal(requestUpdate.requestStatus, 'quote_accepted');
  assert.equal(requestUpdate.status, 'quote_accepted');
  assert.equal(requestUpdate.quoteTimingChoice, 'accepted_proposed_time');
  assert.equal(requestUpdate.schedulingStatus, 'accepted_time');
  assert.equal(requestUpdate.readyForCalendar, true);
  assert.equal(requestUpdate.acceptedProposedTime, true);
  assert.equal(requestUpdate.timeAgreed, true);
  assert.equal(typeof requestUpdate.agreedDateTime.toDate, 'function');
  assert.equal(typeof requestUpdate.agreedStartAt.toDate, 'function');
  assert.equal('updatedAt' in requestUpdate, false);
});

test('linked request update can opt into updatedAt when a direct write needs it', () => {
  const requestUpdate = __test__.buildLinkedRequestQuoteStateUpdate({
    driverPayload: {
      requestStatus: 'quote_accepted',
      status: 'quoteAccepted',
      quoteAccepted: true,
      schedulingStatus: 'accepted_time',
    },
    includeUpdatedAt: true,
  });

  assert.equal(typeof requestUpdate.updatedAt, 'object');
});

test('submitExactLocation request mirror preserves accepted ready-for-calendar state', () => {
  const exactLocationPayload = __test__.buildQuoteExactLocationPayload({
    quoteData: {
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      schedulingStatus: 'accepted_time',
    },
    data: {
      latitude: 51.5,
      longitude: -0.12,
      note: 'Blue gate',
    },
  });

  const driverPayload = __test__.buildDriverJobExactLocationPayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-1',
      requestId: 'request-1',
      quoteAccepted: true,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      estimatedDurationMinutes: 90,
      schedulingStatus: 'accepted_time',
    },
    existingJob: {
      requestId: 'request-1',
      quoteAccepted: true,
      acceptedProposedTime: true,
      readyForCalendar: true,
      agreedStartAt: new Date('2026-06-14T10:00:00.000Z'),
      agreedDurationMinutes: 90,
      schedulingStatus: 'accepted_time',
    },
    exactLocationPayload,
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });

  const requestUpdate = __test__.buildLinkedRequestQuoteStateUpdate({
    driverPayload,
    includeExactPin: true,
  });

  assert.equal(requestUpdate.requestStatus, 'quote_accepted');
  assert.equal(requestUpdate.schedulingStatus, 'accepted_time');
  assert.equal(requestUpdate.readyForCalendar, true);
  assert.equal(requestUpdate.hasExactPin, true);
  assert.equal(requestUpdate.exactPinLatitude, 51.5);
  assert.equal(requestUpdate.exactPinLongitude, -0.12);
});

test('declineQuote writes decline reason fields to quote and linked driver docs', () => {
  const payload = __test__.buildQuoteResponseWritePayload({
    quoteData: {
      declineReasonCode: 'too_expensive',
      declineReasonLabel: 'Too expensive',
      declineReasonText: 'Thanks anyway',
    },
    action: 'decline_quote',
    data: {
      declineReasonCode: 'found_someone_else',
      declineReasonLabel: 'Found someone else',
      declineReasonText: 'Already booked elsewhere',
    },
  });

  assert.equal(payload.quoteStatus, 'declined');
  assert.equal(payload.quoteDeclined, true);
  assert.equal(payload.declineReasonCode, 'found_someone_else');
  assert.equal(payload.declineReasonLabel, 'Found someone else');
  assert.equal(payload.declineReasonText, 'Already booked elsewhere');
  assert.equal(payload.declineNote, 'Already booked elsewhere');
  assert.equal(payload.quoteDeclineReasonCode, 'found_someone_else');
  assert.equal(payload.quoteDeclineReasonLabel, 'Found someone else');
  assert.equal(payload.quoteDeclineReason, 'Found someone else');
  assert.equal(payload.quoteDeclineNote, 'Already booked elsewhere');
  assert.equal(payload.lastQuoteDeclineReason, 'Found someone else');
  assert.equal(payload.lastQuoteDeclineNote, 'Already booked elsewhere');
  assert.equal(payload.declinedBy, 'customer');

  const driverPayload = __test__.buildDriverJobQuoteResponsePayload({
    quoteData: {
      ownerUid: 'driver-1',
      jobId: 'job-1',
      requestId: 'request-1',
      declineReasonCode: 'too_expensive',
      declineReasonLabel: 'Too expensive',
      declineReasonText: 'Thanks anyway',
    },
    existingJob: {
      requestId: 'request-1',
      quoteDeclined: false,
    },
    action: 'decline_quote',
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
    requestId: 'request-1',
  });

  const requestUpdate = __test__.buildLinkedRequestQuoteStateUpdate({
    driverPayload,
    includeExactPin: true,
  });

  assert.equal(requestUpdate.quoteStatus, 'declined');
  assert.equal(requestUpdate.quoteDeclined, true);
  assert.equal(requestUpdate.declineReasonCode, 'too_expensive');
  assert.equal(requestUpdate.declineReasonLabel, 'Too expensive');
  assert.equal(requestUpdate.declineReasonText, 'Thanks anyway');
  assert.equal(requestUpdate.declineNote, 'Thanks anyway');
  assert.equal(requestUpdate.quoteDeclineReasonCode, 'too_expensive');
  assert.equal(requestUpdate.quoteDeclineReasonLabel, 'Too expensive');
  assert.equal(requestUpdate.quoteDeclineReason, 'Too expensive');
  assert.equal(requestUpdate.quoteDeclineNote, 'Thanks anyway');
  assert.equal(requestUpdate.lastQuoteDeclineReason, 'Too expensive');
  assert.equal(requestUpdate.lastQuoteDeclineNote, 'Thanks anyway');
  assert.equal(requestUpdate.declinedBy, 'customer');
});

test('declineQuote keeps a preset reason even when no note is provided', () => {
  const payload = __test__.buildQuoteResponseWritePayload({
    quoteData: {},
    action: 'decline_quote',
    data: {
      declineReasonCode: 'too_expensive',
      declineReasonLabel: 'Too expensive',
      declineReasonText: '',
    },
  });

  assert.equal(payload.declineReasonCode, 'too_expensive');
  assert.equal(payload.declineReasonLabel, 'Too expensive');
  assert.equal(payload.declineReasonText, '');
  assert.equal(payload.declineNote, '');
  assert.deepEqual(payload.quoteDecline, {
    reasonCode: 'too_expensive',
    reasonLabel: 'Too expensive',
    reason: 'Too expensive',
    note: '',
    reasonText: '',
  });
});

test('declineQuote supports note-only and nested quoteDecline payloads', () => {
  const payload = __test__.buildQuoteResponseWritePayload({
    quoteData: {},
    action: 'decline_quote',
    data: {
      quoteDecline: {
        note: 'Need an earlier slot',
      },
    },
  });

  assert.equal(payload.declineReasonCode, '');
  assert.equal(payload.declineReasonLabel, '');
  assert.equal(payload.declineReasonText, 'Need an earlier slot');
  assert.equal(payload.declineNote, 'Need an earlier slot');
  assert.deepEqual(payload.quoteDecline, {
    reasonCode: '',
    reasonLabel: '',
    reason: '',
    note: 'Need an earlier slot',
    reasonText: 'Need an earlier slot',
  });
});

test('buildQuoteJobMirror keeps a declined quote declined when stale sent fields still exist', () => {
  const payload = __test__.buildQuoteJobMirror({
    before: {
      quoteStatus: 'declined',
      quoteResponseStatus: 'declined',
      quoteDeclined: true,
    },
    after: {
      quoteStatus: 'sent',
      quoteResponseStatus: '',
      quoteResponse: 'pending',
      quoteSentAt: '2026-06-14T10:00:00.000Z',
      quoteResponseLink: 'https://vanmate.example/quote/original-token',
    },
    existingJob: {
      requestId: 'request-1',
      status: 'quoteDeclined',
      requestStatus: 'quote_declined',
      quoteStatus: 'declined',
      quoteResponseStatus: 'declined',
      quoteDeclined: true,
      declineReasonCode: 'too_expensive',
      declineReasonLabel: 'Too expensive',
      declineReasonText: 'Thanks anyway',
      declineNote: 'Thanks anyway',
      declinedBy: 'customer',
    },
    quoteId: 'quote-1',
    ownerUid: 'driver-1',
    jobId: 'job-1',
  });

  assert.equal(payload.quoteStatus, 'declined');
  assert.equal(payload.quoteResponseStatus, 'declined');
  assert.equal(payload.quoteDeclined, true);
  assert.equal(payload.requestStatus, 'quote_declined');
  assert.equal(payload.status, 'quoteDeclined');
  assert.equal(payload.declineReasonLabel, 'Too expensive');
  assert.equal(payload.declineNote, 'Thanks anyway');
});

test('buildQuoteJobMirror keeps an accepted quote accepted when stale sent fields still exist', () => {
  const payload = __test__.buildQuoteJobMirror({
    before: {
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteAccepted: true,
    },
    after: {
      quoteStatus: 'sent',
      quoteResponseStatus: 'pending',
      quoteResponse: 'pending',
      quoteSentAt: '2026-06-14T10:00:00.000Z',
      quoteResponseLink: 'https://vanmate.example/quote/original-token',
    },
    existingJob: {
      requestId: 'request-accepted-1',
      status: 'quoteAccepted',
      requestStatus: 'quote_accepted',
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteAccepted: true,
      quoteTimingChoice: 'accepted_proposed_time',
      schedulingStatus: 'accepted_time',
      proposedDate: '2026-06-20',
      proposedStartTime: '10:00',
      acceptedProposedDate: '2026-06-20',
      acceptedProposedStartTime: '10:00',
      exactPinShared: true,
      hasExactPin: true,
      exactPinLatitude: 51.501,
      exactPinLongitude: -0.141,
    },
    quoteId: 'quote-accepted-1',
    ownerUid: 'driver-1',
    jobId: 'job-accepted-1',
  });

  assert.equal(payload.quoteStatus, 'accepted');
  assert.equal(payload.quoteResponseStatus, 'accepted');
  assert.equal(payload.quoteAccepted, true);
  assert.equal(payload.quoteDeclined, false);
  assert.equal(payload.requestStatus, 'quote_accepted');
  assert.equal(payload.status, 'quoteAccepted');
  assert.equal(payload.quoteTimingChoice, 'accepted_proposed_time');
  assert.equal(payload.schedulingStatus, 'accepted_time');
  assert.equal(payload.hasExactPin, true);
});

test('buildQuoteJobMirror preserves drop-off pickup times and clears stale pin state', () => {
  const payload = __test__.buildQuoteJobMirror({
    before: {},
    after: {
      ownerUid: 'driver-1',
      jobId: 'pet-sitting-job',
      requestId: 'pet-sitting-request',
      requestType: 'dropOffPickupRequest',
      startHandover: 'businessCollects',
      endHandover: 'customerCollects',
      allowedStartHandoverOptions: ['businessCollects'],
      allowedEndHandoverOptions: ['customerCollects'],
      collectionAddress: '1 Collection Road',
      returnAddress: '',
      returnAddressSameAsCollection: false,
      businessCollectionInstructions: 'Collect from reception',
      dropOffDate: '2026-07-22T00:00:00.000Z',
      dropOffTime: '09:30',
      pickUpDate: '2026-07-22T00:00:00.000Z',
      pickUpTime: '17:30',
      requiresExactPinAfterQuoteAccepted: false,
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteAccepted: true,
    },
    existingJob: {
      requestExactPin: true,
      requiresExactPinAfterQuoteAccepted: true,
      locationPending: true,
    },
    quoteId: 'pet-sitting-quote',
    ownerUid: 'driver-1',
    jobId: 'pet-sitting-job',
  });

  assert.equal(payload.dropOffTime, '09:30');
  assert.equal(payload.pickUpTime, '17:30');
  assert.equal(payload.startHandover, 'businessCollects');
  assert.equal(payload.endHandover, 'customerCollects');
  assert.deepEqual(payload.allowedStartHandoverOptions, ['businessCollects']);
  assert.deepEqual(payload.allowedEndHandoverOptions, ['customerCollects']);
  assert.equal(payload.collectionAddress, '1 Collection Road');
  assert.equal(payload.businessCollectionInstructions, 'Collect from reception');
  assert.equal(payload.requestExactPin, false);
  assert.equal(payload.requiresExactPinAfterQuoteAccepted, false);
  assert.equal(payload.locationPending, false);
});

test('customer reply exact pin notification prefers customer name over job title', () => {
  const body = __test__.buildCustomerReplyNotificationBody({
    customerName: 'Full Flow Test',
    jobTitle: 'Man & Van',
    hasExactPin: true,
  });

  assert.equal(body, 'Exact pin received for Full Flow Test');
});

test('customer reply exact pin notification falls back to generic wording', () => {
  const body = __test__.buildCustomerReplyNotificationBody({
    customerName: '',
    jobTitle: 'Handyman',
    hasExactPin: true,
  });

  assert.equal(body, 'Exact pin received');
});

test('listChangedKeys can ignore notification-only and sync-only churn', () => {
  const changedKeys = __test__.listChangedKeys(
    {
      quoteStatus: 'accepted',
      updatedAt: '2026-06-14T10:00:00.000Z',
      quoteNotificationSent: false,
      quoteNotificationSentAt: null,
    },
    {
      quoteStatus: 'accepted',
      updatedAt: '2026-06-14T10:05:00.000Z',
      quoteNotificationSent: true,
      quoteNotificationSentAt: '2026-06-14T10:05:00.000Z',
    },
    {
      ignoredKeys: [
        'updatedAt',
        'quoteNotificationSent',
        'quoteNotificationSentAt',
      ],
    },
  );

  assert.deepEqual(changedKeys, []);
});

test('listDesiredChangedKeys ignores timestamp-only request sync differences', () => {
  const changedKeys = __test__.listDesiredChangedKeys(
    {
      requestStatus: 'quote_accepted',
      schedulingStatus: 'awaiting_agreed_time',
      updatedAt: '2026-06-14T10:00:00.000Z',
    },
    {
      requestStatus: 'quote_accepted',
      schedulingStatus: 'awaiting_agreed_time',
      updatedAt: '2026-06-14T10:05:00.000Z',
    },
    {
      ignoredKeys: ['updatedAt'],
    },
  );

  assert.deepEqual(changedKeys, []);
});
