const crypto = require('crypto');
const admin = require('firebase-admin');
const { defineSecret } = require('firebase-functions/params');
const {
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const {
  bookingLinkAddressValidationError,
  bookingLinkRequestDocumentId,
  withTimeout,
} = require('./booking_link_address_validation');
const {
  DELETION_TOMBSTONE_SUBCOLLECTION,
  createDeletionCoordinator,
  createFirestoreDeletionRepository,
} = require('./business_mate_job_deletion');

admin.initializeApp();

const PIN_REQUEST_COLLECTION = 'van_pin_requests';
const PUBLIC_JOB_REQUEST_COLLECTION = 'public_job_requests';
const PUBLIC_BOOKING_LINK_COLLECTION = 'public_booking_links';
const PUBLIC_QUOTE_RESPONSE_COLLECTION = 'public_quote_responses';
const PUBLIC_QUOTE_RESPONSE_TOKEN_COLLECTION = 'public_quote_response_tokens';
const LEGACY_JOB_REQUEST_COLLECTION = 'van_job_requests';
const VAN_JOB_REQUEST_HOSTED_BASE_URL = 'https://vanmate-56eac.web.app';
const USERS_COLLECTION = 'users';
const PLACES_COLLECTION = 'van_places';
const ROUTES_COLLECTION = 'van_routes';
const USAGE_COLLECTION = 'usage';
const FCM_TOKENS_SUBCOLLECTION = 'fcmTokens';
const EXACT_PIN_NOTIFICATION_TYPE = 'exact_pin_received';
const LOCATION_NOTE_NOTIFICATION_TYPE = 'location_note_received';
const CUSTOMER_REPLY_NOTIFICATION_TYPE = 'customer_reply';
const BOOKING_REQUEST_RECEIVED_NOTIFICATION_TYPE = 'booking_request_received';
const REPLY_NOTIFICATION_SENT_AT_FIELD = 'replyNotificationSentAt';
const QUOTE_NOTIFICATION_SENT_AT_FIELD = 'quoteNotificationSentAt';
const QUOTE_NOTIFICATION_SENT_FIELD = 'quoteNotificationSent';
const JOB_REQUEST_SYNC_ACK_FIELDS = [
  'driverJobSyncStatus',
  'driverJobSyncedAt',
  'driverJobSyncCompletedAt',
  'driverJobSyncUpdatedAt',
  'driverJobSyncTargetPath',
  'driverJobSyncError',
];
const REQUEST_TRIGGER_IGNORED_FIELDS = [
  'updatedAt',
  REPLY_NOTIFICATION_SENT_AT_FIELD,
  ...JOB_REQUEST_SYNC_ACK_FIELDS,
];
const REQUEST_JOB_DIFF_IGNORED_FIELDS = [
  'updatedAt',
  'requestUpdatedAt',
];
const QUOTE_TRIGGER_IGNORED_FIELDS = [
  'updatedAt',
  QUOTE_NOTIFICATION_SENT_FIELD,
  QUOTE_NOTIFICATION_SENT_AT_FIELD,
];
const QUOTE_JOB_DIFF_IGNORED_FIELDS = [
  'updatedAt',
  QUOTE_NOTIFICATION_SENT_FIELD,
  QUOTE_NOTIFICATION_SENT_AT_FIELD,
];
const LINKED_REQUEST_DIFF_IGNORED_FIELDS = ['updatedAt'];
const MAX_ROUTE_STOPS = 25;
const MAX_DAILY_HALFWAY_REFRESHES = 8;
const ROUTE_PROVIDER = 'google_routes';
const SUMMARY_MODE_START = 'start';
const SUMMARY_MODE_HALFWAY = 'halfway';
const SUMMARY_MODE_ROUTE_CHANGED = 'routeChanged';
const GOOGLE_ROUTES_API_KEY = defineSecret('GOOGLE_ROUTES_API_KEY');
const BOOKING_LINK_MAX_PHOTOS = 5;
const BOOKING_LINK_MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const BOOKING_LINK_PHOTO_UPLOAD_TIMEOUT_MS = 15 * 1000;
const DEFAULT_BUSINESS_PROFILE_ID = 'default_business';
const BUSINESS_DELETION_SOURCE = 'van_mate.business_delete';
const BUSINESS_RECORD_SUBCOLLECTIONS = [
  'van_jobs',
  'van_quotes',
  'van_job_requests',
  'van_pin_requests',
];
const BUSINESS_PUBLIC_COLLECTIONS = [
  PUBLIC_JOB_REQUEST_COLLECTION,
  PUBLIC_QUOTE_RESPONSE_COLLECTION,
  PIN_REQUEST_COLLECTION,
  LEGACY_JOB_REQUEST_COLLECTION,
];

function jobDeletionCoordinator() {
  const repository = createFirestoreDeletionRepository({
    admin,
    db: admin.firestore(),
    bucket: admin.storage().bucket(),
  });
  return createDeletionCoordinator({ repository });
}

async function rejectTombstonedMirror({ ownerUid, jobId, sourceRef, label }) {
  const snapshot = await admin.firestore()
    .collection(USERS_COLLECTION)
    .doc(ownerUid)
    .collection(DELETION_TOMBSTONE_SUBCOLLECTION)
    .doc(jobId)
    .get();
  if (!snapshot.exists) return false;
  const state = readString((snapshot.data() || {}).deletionState);
  if (state !== 'pending' && state !== 'complete') return false;
  console.warn(
    `[${label}] rejected ownerUid=${ownerUid} jobId=${jobId} reason=deletion_tombstone state=${state}`,
  );
  if (sourceRef) await sourceRef.delete().catch((error) => {
    console.error(`[${label}] failed to remove recreated source`, error);
  });
  return true;
}

function buildVanJobRequestHostedLink(requestId, shortCode = '') {
  const normalizedShortCode = readString(shortCode).toUpperCase();
  if (normalizedShortCode) {
    return `${VAN_JOB_REQUEST_HOSTED_BASE_URL}/r/${encodeURIComponent(normalizedShortCode)}`;
  }

  const normalizedId = readString(requestId);
  if (!normalizedId) {
    return '';
  }

  return `${VAN_JOB_REQUEST_HOSTED_BASE_URL}/request.html?id=${encodeURIComponent(normalizedId)}`;
}

function buildVanQuoteResponseToken(quoteId) {
  const normalizedId = readString(quoteId);
  if (!normalizedId) {
    return '';
  }

  return crypto
    .createHash('sha256')
    .update(`vanmate_quote_response:${normalizedId}`)
    .digest('hex')
    .slice(0, 12);
}

function buildLegacyVanQuoteResponseHostedLink(quoteId) {
  const normalizedId = readString(quoteId);
  if (!normalizedId) {
    return '';
  }

  return `${VAN_JOB_REQUEST_HOSTED_BASE_URL}/quote_response.html?id=${encodeURIComponent(normalizedId)}`;
}

function buildVanQuoteResponseHostedLink(quoteToken) {
  const normalizedToken = readString(quoteToken);
  if (!normalizedToken) {
    return '';
  }

  return `${VAN_JOB_REQUEST_HOSTED_BASE_URL}/quote/${encodeURIComponent(normalizedToken)}`;
}

function resolveVanQuoteResponseHostedLink({ quoteToken, quoteId, quoteResponseLink }) {
  const normalizedToken = readString(quoteToken);
  if (normalizedToken) {
    return buildVanQuoteResponseHostedLink(normalizedToken);
  }

  const normalizedLink = readString(quoteResponseLink);
  if (normalizedLink.startsWith('http://') || normalizedLink.startsWith('https://')) {
    return normalizedLink;
  }

  return buildLegacyVanQuoteResponseHostedLink(quoteId);
}

function parseQuoteDateAndTime(dateValue, timeValue) {
  const rawDate = readString(dateValue);
  const rawTime = readString(timeValue);
  if (!rawDate || !rawTime) {
    return null;
  }

  const isoMatch = rawDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const timeMatch = rawTime.match(/^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$/);
  if (isoMatch && timeMatch) {
    const [, yearText, monthText, dayText] = isoMatch;
    const [, hourText, minuteText, meridiemRaw] = timeMatch;
    let hour = Number(hourText);
    const minute = Number(minuteText);
    if (Number.isFinite(hour) && Number.isFinite(minute)) {
      const meridiem = readString(meridiemRaw).toLowerCase();
      if (meridiem === 'pm' && hour < 12) {
        hour += 12;
      } else if (meridiem === 'am' && hour === 12) {
        hour = 0;
      }
      const parsed = new Date(
        Number(yearText),
        Number(monthText) - 1,
        Number(dayText),
        hour,
        minute,
        0,
        0,
      );
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    }
  }

  const fallback = new Date(`${rawDate} ${rawTime}`);
  return Number.isNaN(fallback.getTime()) ? null : fallback;
}

function publicQuoteHasAgreedTime(data) {
  const schedulingStatus = readString(data.schedulingStatus).toLowerCase();
  const quoteTimingChoice = readString(data.quoteTimingChoice).toLowerCase();
  if (toDateOrNull(data.agreedDateTime) || toDateOrNull(data.agreedStartAt)) {
    return true;
  }
  if (schedulingStatus === 'accepted_time' || schedulingStatus === 'agreed_manual') {
    return true;
  }
  return quoteTimingChoice === 'accepted_proposed_time' ||
    quoteTimingChoice === 'agreed_time_saved';
}

async function resolvePublicQuoteTarget({ quoteResponseId, quoteResponseToken }) {
  const requestedQuoteId = readString(quoteResponseId);
  const requestedQuoteToken = readString(quoteResponseToken);
  let resolvedQuoteId = requestedQuoteId;
  let tokenData = {};

  if (requestedQuoteToken) {
    const tokenRef = admin
      .firestore()
      .collection(PUBLIC_QUOTE_RESPONSE_TOKEN_COLLECTION)
      .doc(requestedQuoteToken);
    const tokenSnap = await tokenRef.get();
    if (!tokenSnap.exists) {
      throw new HttpsError('not-found', 'Quote token not found.');
    }
    tokenData = tokenSnap.data() || {};
    resolvedQuoteId = firstNonEmpty([
      tokenData.quoteResponseId,
      tokenData.quoteId,
      requestedQuoteId,
    ]);
    if (!resolvedQuoteId) {
      throw new HttpsError(
        'failed-precondition',
        'Quote token is missing the linked quote.',
      );
    }
    if (requestedQuoteId && requestedQuoteId !== resolvedQuoteId) {
      throw new HttpsError(
        'failed-precondition',
        'Quote token does not match the requested quote.',
      );
    }
  }

  if (!resolvedQuoteId) {
    throw new HttpsError('invalid-argument', 'Quote ID or token is required.');
  }

  const quoteRef = admin
    .firestore()
    .collection(PUBLIC_QUOTE_RESPONSE_COLLECTION)
    .doc(resolvedQuoteId);
  const quoteSnap = await quoteRef.get();
  if (!quoteSnap.exists) {
    throw new HttpsError('not-found', 'Quote not found.');
  }

  return {
    quoteId: resolvedQuoteId,
    quoteRef,
    quoteData: quoteSnap.data() || {},
    tokenData,
    token: requestedQuoteToken,
  };
}

function assertPublicQuoteActionAllowed(quoteData, {
  requirePendingResponse = false,
  requireAcceptedQuote = false,
} = {}) {
  const quoteStatus = readString(
    firstNonEmpty([
      quoteData.quoteStatus,
      quoteData.quoteResponseStatus,
      quoteData.quoteResponse,
      quoteData.status,
      quoteData.requestStatus,
    ]),
  ).toLowerCase();
  const archived = readBool(quoteData.archived);
  const deleted = readBool(quoteData.deleted);
  const superseded =
    quoteData.isCurrent === false ||
    readString(quoteData.lifecycleStatus).toLowerCase() === 'superseded';

  if (superseded) {
    throw new HttpsError(
      'failed-precondition',
      'This quote has been updated. Please review the latest version.',
    );
  }

  if (archived || deleted || quoteStatus === 'cancelled') {
    throw new HttpsError(
      'failed-precondition',
      'This quote is no longer active.',
    );
  }

  if (requirePendingResponse) {
    if (readBool(quoteData.quoteDeclined) || quoteStatus === 'declined') {
      throw new HttpsError(
        'failed-precondition',
        'This quote has already been declined.',
      );
    }
    if (
      readBool(quoteData.quoteAccepted) ||
      quoteStatus === 'accepted' ||
      toDateOrNull(quoteData.quoteRespondedAt)
    ) {
      throw new HttpsError(
        'failed-precondition',
        'This quote has already been answered.',
      );
    }
  }

  if (requireAcceptedQuote) {
    const accepted =
      readBool(quoteData.quoteAccepted) ||
      quoteStatus === 'accepted' ||
      readString(quoteData.quoteResponseStatus).toLowerCase() === 'accepted';
    if (!accepted || readBool(quoteData.quoteDeclined)) {
      throw new HttpsError(
        'failed-precondition',
        'The quote must be accepted before saving the exact location.',
      );
    }
  }
}

function isPublicQuoteCurrentForJob({ quoteId, quoteData = {}, jobData = {} }) {
  const normalizedQuoteId = readString(quoteId);
  if (!normalizedQuoteId) {
    return false;
  }
  if (
    quoteData.isCurrent === false ||
    readString(quoteData.lifecycleStatus).toLowerCase() === 'superseded'
  ) {
    return false;
  }
  const quoteCurrentId = firstNonEmpty([
    readString(quoteData.currentQuoteId),
    normalizedQuoteId,
  ]);
  const jobCurrentId = firstNonEmpty([
    readString(jobData.currentQuoteId),
    readString(jobData.quoteResponseId),
  ]);
  return quoteCurrentId === normalizedQuoteId &&
    (!jobCurrentId || jobCurrentId === normalizedQuoteId);
}

function assertPublicQuoteIsCurrent({ quoteId, quoteData, jobData }) {
  if (isPublicQuoteCurrentForJob({ quoteId, quoteData, jobData })) {
    return;
  }
  throw new HttpsError(
    'failed-precondition',
    'This quote has been updated. Please review the latest version.',
  );
}

function publicQuoteActionAlreadyApplied(quoteData, action) {
  const accepted =
    readBool(quoteData.quoteAccepted) ||
    readString(quoteData.quoteStatus).toLowerCase() === 'accepted' ||
    readString(quoteData.quoteResponseStatus).toLowerCase() === 'accepted';
  const declined =
    readBool(quoteData.quoteDeclined) ||
    readString(quoteData.quoteStatus).toLowerCase() === 'declined' ||
    readString(quoteData.quoteResponseStatus).toLowerCase() === 'declined';
  const timingChoice = readString(quoteData.quoteTimingChoice).toLowerCase();
  if (action === 'accept_proposed_time') {
    return accepted && timingChoice === 'accepted_proposed_time';
  }
  if (action === 'accept_arrange_time') {
    return accepted && timingChoice === 'arrange_another_time';
  }
  return action === 'decline_quote' && declined;
}

function buildQuoteDeclineFieldSet({
  code = '',
  label = '',
  note = '',
  reasonText = '',
}) {
  const normalizedCode = readString(code);
  const normalizedLabel = readString(label);
  const normalizedNote = readString(firstNonEmpty([note, reasonText]));
  const normalizedReasonText = readString(firstNonEmpty([reasonText, normalizedNote]));

  return {
    declineReasonCode: normalizedCode,
    declineReasonLabel: normalizedLabel,
    declineReasonText: normalizedReasonText,
    declineNote: normalizedNote,
    quoteDeclineReasonCode: normalizedCode,
    quoteDeclineReasonLabel: normalizedLabel,
    quoteDeclineReason: normalizedLabel,
    quoteDeclineNote: normalizedNote,
    quoteDeclinedReasonCode: normalizedCode,
    quoteDeclinedReasonLabel: normalizedLabel,
    quoteDeclinedReason: normalizedLabel,
    quoteDeclinedNote: normalizedNote,
    declinedReasonCode: normalizedCode,
    declinedReason: normalizedLabel,
    declinedNote: normalizedNote,
    lastQuoteDeclineReason: normalizedLabel,
    lastQuoteDeclineNote: normalizedNote,
    quoteDecline: {
      reasonCode: normalizedCode,
      reasonLabel: normalizedLabel,
      reason: normalizedLabel,
      note: normalizedNote,
      reasonText: normalizedReasonText,
    },
  };
}

function readMap(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value;
}

function readQuoteDeclineFields(source = {}) {
  const quoteDecline = readMap(source.quoteDecline);
  const code = readString(firstNonEmpty([
    source.declineReasonCode,
    source.quoteDeclineReasonCode,
    source.quoteDeclinedReasonCode,
    source.declinedReasonCode,
    quoteDecline.reasonCode,
    quoteDecline.code,
  ]));
  const label = readString(firstNonEmpty([
    source.declineReasonLabel,
    source.quoteDeclineReasonLabel,
    source.quoteDeclineReason,
    source.quoteDeclinedReasonLabel,
    source.quoteDeclinedReason,
    source.declinedReason,
    source.lastQuoteDeclineReason,
    quoteDecline.reasonLabel,
    quoteDecline.reason,
  ]));
  const note = readString(firstNonEmpty([
    source.declineNote,
    source.quoteDeclineNote,
    source.quoteDeclinedNote,
    source.declinedNote,
    source.lastQuoteDeclineNote,
    quoteDecline.note,
    quoteDecline.reasonText,
  ]));
  const reasonText = readString(firstNonEmpty([
    source.declineReasonText,
    source.declineNote,
    source.quoteDeclineNote,
    source.quoteDeclinedNote,
    source.lastQuoteDeclineNote,
    quoteDecline.reasonText,
    quoteDecline.note,
  ]));
  return {
    code,
    label,
    note,
    reasonText,
  };
}

function readPreferredTimingFields(source = {}) {
  const preferredDate = readString(firstNonEmpty([
    source.preferredDate,
    source.suggestedDate,
    source.preferredDateAt,
  ]));
  const preferredTimeWindow = readString(firstNonEmpty([
    source.preferredTimeWindow,
    source.preferredTime,
    source.suggestedTimeWindow,
    source.suggestedTime,
  ]));
  const preferredTimingNote = readString(firstNonEmpty([
    source.preferredTimingNote,
    source.timingNote,
    source.note,
  ]));
  const preferredTimingDecision = readString(firstNonEmpty([
    source.preferredTimingDecision,
    preferredDate && preferredTimeWindow ? 'suggested_alternative' : '',
  ]));
  return {
    preferredDate,
    preferredTimeWindow,
    preferredTimingNote,
    preferredTimingDecision,
    suggestedDate: readString(firstNonEmpty([source.suggestedDate, preferredDate])),
    suggestedTimeWindow: readString(firstNonEmpty([
      source.suggestedTimeWindow,
      preferredTimeWindow,
    ])),
  };
}

function requirePreferredTimingFields(data = {}) {
  const fields = readPreferredTimingFields(data);
  if (!fields.preferredDate || !fields.preferredTimeWindow) {
    throw new HttpsError(
      'failed-precondition',
      'Choose a preferred alternative date and time before accepting.',
    );
  }
  return fields;
}

function buildQuoteResponseWritePayload({ quoteData, action, data = {} }) {
  const responseTimestamp = admin.firestore.FieldValue.serverTimestamp();
  const proposedDate = readString(quoteData.proposedDate);
  const proposedStartTime = readString(quoteData.proposedStartTime);
  const proposedDurationMinutes = readNullableInt(
    firstNonEmpty([
      quoteData.proposedDurationMinutes,
      quoteData.estimatedDurationMinutes,
    ]),
  );

  if (action === 'accept_proposed_time') {
    const agreedStart = parseQuoteDateAndTime(proposedDate, proposedStartTime);
    if (!agreedStart) {
      throw new HttpsError(
        'failed-precondition',
        'The proposed appointment could not be read.',
      );
    }
    const agreedEnd = Number.isFinite(proposedDurationMinutes)
      ? new Date(agreedStart.getTime() + (proposedDurationMinutes * 60 * 1000))
      : null;
    return {
      quoteAccepted: true,
      quoteDeclined: false,
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'accepted_proposed_time',
      quoteStatus: 'accepted',
      quoteResponse: 'accepted',
      status: 'accepted',
      requestStatus: 'accepted',
      quoteRespondedAt: responseTimestamp,
      quoteAcceptedAt: responseTimestamp,
      quoteDeclinedAt: null,
      agreedDateTime: admin.firestore.Timestamp.fromDate(agreedStart),
      agreedStartAt: admin.firestore.Timestamp.fromDate(agreedStart),
      agreedEndAt: agreedEnd
        ? admin.firestore.Timestamp.fromDate(agreedEnd)
        : null,
      agreedDate: proposedDate || null,
      agreedTime: proposedStartTime || null,
      scheduledAt: admin.firestore.Timestamp.fromDate(agreedStart),
      scheduledDate: proposedDate || null,
      scheduledStartTime: proposedStartTime || null,
      acceptedProposedDate: proposedDate || null,
      acceptedProposedStartTime: proposedStartTime || null,
      proposedDurationMinutes,
      estimatedDurationMinutes: proposedDurationMinutes,
      agreedDurationMinutes: proposedDurationMinutes,
      acceptedProposedTime: true,
      proposedTimeAccepted: true,
      timeAccepted: true,
      timeNotAccepted: false,
      timingNeedsDecision: false,
      timeAgreed: true,
      needsAgreedTime: false,
      readyForCalendar: true,
      schedulingStatus: 'accepted_time',
      timeStatus: 'agreed',
      timingStatus: 'agreed',
      confirmedAt: responseTimestamp,
      customerRespondedAt: responseTimestamp,
      updatedAt: responseTimestamp,
    };
  }

  if (action === 'accept_arrange_time') {
    const preferredTiming = requirePreferredTimingFields(data);
    return {
      quoteAccepted: true,
      quoteDeclined: false,
      quoteResponseStatus: 'accepted',
      quoteTimingChoice: 'arrange_another_time',
      quoteStatus: 'accepted',
      quoteResponse: 'accepted',
      status: 'accepted',
      requestStatus: 'accepted',
      quoteRespondedAt: responseTimestamp,
      quoteAcceptedAt: responseTimestamp,
      quoteDeclinedAt: null,
      agreedDateTime: null,
      agreedStartAt: null,
      agreedEndAt: null,
      agreedDate: null,
      agreedTime: null,
      scheduledAt: null,
      scheduledDate: null,
      scheduledStartTime: null,
      acceptedProposedDate: null,
      acceptedProposedStartTime: null,
      preferredDate: preferredTiming.preferredDate,
      preferredTimeWindow: preferredTiming.preferredTimeWindow,
      preferredTimingNote: preferredTiming.preferredTimingNote,
      preferredTimingDecision: preferredTiming.preferredTimingDecision,
      suggestedDate: preferredTiming.suggestedDate,
      suggestedTimeWindow: preferredTiming.suggestedTimeWindow,
      proposedDurationMinutes,
      estimatedDurationMinutes: proposedDurationMinutes,
      agreedDurationMinutes: null,
      acceptedProposedTime: false,
      proposedTimeAccepted: false,
      timeAccepted: false,
      timeNotAccepted: true,
      timingNeedsDecision: true,
      timeAgreed: false,
      needsAgreedTime: true,
      readyForCalendar: false,
      schedulingStatus: 'awaiting_agreed_time',
      timeStatus: 'time_not_accepted',
      timingStatus: 'timing_needs_decision',
      confirmedAt: null,
      customerRespondedAt: responseTimestamp,
      updatedAt: responseTimestamp,
    };
  }

  if (action === 'decline_quote') {
    const dataDecline = readQuoteDeclineFields(data);
    const savedDecline = readQuoteDeclineFields(quoteData);
    return {
      quoteAccepted: false,
      quoteDeclined: true,
      quoteResponseStatus: 'declined',
      quoteTimingChoice: 'declined',
      quoteStatus: 'declined',
      quoteResponse: 'declined',
      status: 'declined',
      requestStatus: 'declined',
      quoteRespondedAt: responseTimestamp,
      quoteAcceptedAt: null,
      quoteDeclinedAt: responseTimestamp,
      agreedDateTime: null,
      agreedStartAt: null,
      agreedEndAt: null,
      agreedDate: null,
      agreedTime: null,
      acceptedProposedDate: null,
      acceptedProposedStartTime: null,
      agreedDurationMinutes: null,
      acceptedProposedTime: false,
      proposedTimeAccepted: false,
      timeAgreed: false,
      needsAgreedTime: false,
      readyForCalendar: false,
      schedulingStatus: null,
      timeStatus: 'declined',
      confirmedAt: null,
      customerRespondedAt: responseTimestamp,
      updatedAt: responseTimestamp,
      ...buildQuoteDeclineFieldSet({
        code: dataDecline.code || savedDecline.code,
        label: dataDecline.label || savedDecline.label,
        note: dataDecline.note || savedDecline.note,
        reasonText: dataDecline.reasonText || savedDecline.reasonText,
      }),
      declinedAt: responseTimestamp,
      declinedBy: 'customer',
    };
  }

  throw new HttpsError('invalid-argument', 'Unknown quote response action.');
}

function buildQuoteExactLocationPayload({ quoteData, data }) {
  const latitude = readNullableNumber(
    firstNonEmpty([data.latitude, data.exactPinLatitude, data.exactPinLat]),
  );
  const longitude = readNullableNumber(
    firstNonEmpty([data.longitude, data.exactPinLongitude, data.exactPinLng]),
  );
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new HttpsError(
      'invalid-argument',
      'Exact location coordinates are required.',
    );
  }

  const responseTimestamp = admin.firestore.FieldValue.serverTimestamp();
  const responseSource = firstNonEmpty([
    data.responseSource,
    data.exactPinSource,
    data.exactPinShareSource,
    'chosenOnMap',
  ]);
  const note = readString(firstNonEmpty([data.note, data.exactPinNote]));
  return {
    exactPinShared: true,
    exactPinReceived: true,
    hasExactPin: true,
    exactPinLatitude: latitude,
    exactPinLongitude: longitude,
    exactPinLat: latitude,
    exactPinLng: longitude,
    exactPinSource: responseSource,
    exactPinShareSource: responseSource,
    exactPinNote: note,
    exactPinSubmittedAt: responseTimestamp,
    responseLat: latitude,
    responseLng: longitude,
    responseAccuracy: readNullableNumber(data.accuracy),
    responseSource,
    responseNote: note,
    awaitingExactPin: false,
    readyForCalendar: publicQuoteHasAgreedTime(quoteData),
    updatedAt: responseTimestamp,
  };
}

async function resolveLinkedDriverJobContext({ quoteId, quoteData, tokenData }) {
  let ownerUid = firstNonEmpty([
    quoteData.ownerUid,
    tokenData.ownerUid,
  ]);
  let jobId = firstNonEmpty([
    quoteData.jobId,
    tokenData.jobId,
  ]);
  let requestId = firstNonEmpty([
    quoteData.requestId,
    tokenData.requestId,
  ]);

  if ((!ownerUid || !jobId) && requestId) {
    const requestSnap = await admin
      .firestore()
      .collection(PUBLIC_JOB_REQUEST_COLLECTION)
      .doc(requestId)
      .get();
    if (requestSnap.exists) {
      const requestData = requestSnap.data() || {};
      ownerUid = firstNonEmpty([ownerUid, requestData.ownerUid]);
      jobId = firstNonEmpty([
        jobId,
        requestData.jobId,
        requestData.linkedJobId,
      ]);
      requestId = firstNonEmpty([requestId, requestData.requestId]);
    }
  }

  if ((!ownerUid || !jobId) && ownerUid && requestId) {
    const legacyRequestSnap = await admin
      .firestore()
      .collection(USERS_COLLECTION)
      .doc(ownerUid)
      .collection(LEGACY_JOB_REQUEST_COLLECTION)
      .doc(requestId)
      .get();
    if (legacyRequestSnap.exists) {
      const legacyRequestData = legacyRequestSnap.data() || {};
      jobId = firstNonEmpty([
        jobId,
        legacyRequestData.jobId,
        legacyRequestData.linkedJobId,
      ]);
      requestId = firstNonEmpty([requestId, legacyRequestData.requestId]);
    }
  }

  if (!ownerUid || !jobId) {
    throw new HttpsError(
      'failed-precondition',
      'Could not resolve the linked driver job document for this quote.',
    );
  }

  const jobRef = admin
    .firestore()
    .collection(USERS_COLLECTION)
    .doc(ownerUid)
    .collection('van_jobs')
    .doc(jobId);
  const jobSnap = await jobRef.get();
  const existingJob = jobSnap.exists ? jobSnap.data() || {} : {};

  return {
    ownerUid,
    jobId,
    requestId,
    jobRef,
    jobPath: `users/${ownerUid}/van_jobs/${jobId}`,
    existingJob,
  };
}

function buildLinkedRequestQuoteStateUpdate({
  driverPayload,
  includeExactPin = true,
  includeUpdatedAt = false,
}) {
  const requestUpdate = {
    status: firstNonEmpty([
      readString(driverPayload.requestStatus),
      readString(driverPayload.status),
    ]),
    requestStatus: firstNonEmpty([
      readString(driverPayload.requestStatus),
      readString(driverPayload.status),
    ]),
    quoteTimingChoice: readString(driverPayload.quoteTimingChoice),
    schedulingStatus: readString(driverPayload.schedulingStatus),
    agreedDateTime:
      driverPayload.agreedStartAt ??
      driverPayload.agreedDateTime ??
      null,
    agreedStartAt:
      driverPayload.agreedStartAt ??
      driverPayload.agreedDateTime ??
      null,
    agreedEndAt: driverPayload.agreedEndAt ?? null,
    scheduledDate: readString(driverPayload.agreedDate || driverPayload.scheduledDate),
    scheduledStartTime: readString(driverPayload.agreedTime || driverPayload.scheduledStartTime),
    estimatedDurationMinutes:
      readNullableInt(
        firstNonEmpty([
          driverPayload.agreedDurationMinutes,
          driverPayload.estimatedDurationMinutes,
        ]),
      ),
    agreedDurationMinutes:
      readNullableInt(driverPayload.agreedDurationMinutes),
    acceptedProposedTime: readBool(driverPayload.acceptedProposedTime),
    proposedTimeAccepted: readBool(driverPayload.proposedTimeAccepted),
    timeAccepted: readBool(driverPayload.timeAccepted),
    timeNotAccepted: readBool(driverPayload.timeNotAccepted),
    timingNeedsDecision: readBool(driverPayload.timingNeedsDecision),
    quoteAccepted: readBool(driverPayload.quoteAccepted),
    quoteDeclined: readBool(driverPayload.quoteDeclined),
    quoteStatus: readString(driverPayload.quoteStatus),
    quoteResponseStatus: readString(driverPayload.quoteResponseStatus),
    ...buildQuoteDeclineFieldSet({
      ...readQuoteDeclineFields(driverPayload),
    }),
    declinedAt: toIsoStringOrNull(driverPayload.declinedAt),
    declinedBy: readString(driverPayload.declinedBy),
    readyForCalendar: readBool(driverPayload.readyForCalendar),
    needsAgreedTime: readBool(driverPayload.needsAgreedTime),
    timeAgreed: readBool(driverPayload.timeAgreed),
    timeStatus: readString(driverPayload.timeStatus),
    timingStatus: readString(driverPayload.timingStatus),
    preferredDate: driverPayload.preferredDate ?? null,
    preferredTimeWindow: readString(driverPayload.preferredTimeWindow),
    preferredTimingNote: readString(driverPayload.preferredTimingNote),
    preferredTimingDecision: readString(driverPayload.preferredTimingDecision),
    suggestedDate: driverPayload.suggestedDate ?? null,
    suggestedTimeWindow: readString(driverPayload.suggestedTimeWindow),
    requiresExactPinAfterQuoteAccepted:
      driverPayload.requiresExactPinAfterQuoteAccepted === true,
  };

  if (includeUpdatedAt) {
    requestUpdate.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  if (includeExactPin) {
    requestUpdate.hasExactPin = driverPayload.hasExactPin === true;
    requestUpdate.exactPinShared = driverPayload.hasExactPin === true;
    requestUpdate.exactPinReceived = driverPayload.hasExactPin === true;
    requestUpdate.exactPinLatitude = driverPayload.exactPinLatitude ?? null;
    requestUpdate.exactPinLongitude = driverPayload.exactPinLongitude ?? null;
    requestUpdate.exactPinLat = driverPayload.exactPinLatitude ?? null;
    requestUpdate.exactPinLng = driverPayload.exactPinLongitude ?? null;
    requestUpdate.exactPinSource = readString(driverPayload.exactPinSource);
    requestUpdate.exactPinNote = readString(driverPayload.exactPinNote);
  }

  return requestUpdate;
}

function computeAgreedEndAt(startDate, durationMinutes) {
  if (!(startDate instanceof Date) || Number.isNaN(startDate.getTime())) {
    return null;
  }
  if (!Number.isFinite(durationMinutes)) {
    return null;
  }
  return new Date(startDate.getTime() + (durationMinutes * 60 * 1000));
}

function readQuoteDurationMinutesForDriver({ quoteData, existingJob }) {
  return readNullableInt(firstNonEmpty([
    quoteData.proposedDurationMinutes,
    quoteData.estimatedDurationMinutes,
    quoteData.agreedDurationMinutes,
    existingJob.proposedDurationMinutes,
    existingJob.estimatedDurationMinutes,
    existingJob.agreedDurationMinutes,
  ]));
}

function buildDriverJobQuoteResponsePayload({
  quoteData,
  existingJob,
  action,
  quoteId,
  ownerUid,
  jobId,
  requestId,
  data = {},
}) {
  const responseTimestamp = admin.firestore.FieldValue.serverTimestamp();
  const publicPayload = buildQuoteResponseWritePayload({ quoteData, action, data });
  const mergedQuoteState = {
    ...quoteData,
    ...publicPayload,
    ownerUid,
    jobId,
    requestId,
  };
  const mirrored = buildQuoteJobMirror({
    before: quoteData,
    after: mergedQuoteState,
    existingJob,
    quoteId,
    ownerUid,
    jobId,
  });
  const proposedDate = readString(quoteData.proposedDate);
  const proposedStartTime = readString(quoteData.proposedStartTime);
  const agreedStart = action === 'accept_proposed_time'
    ? parseQuoteDateAndTime(proposedDate, proposedStartTime)
    : null;
  const durationMinutes = readQuoteDurationMinutesForDriver({
    quoteData,
    existingJob,
  });
  const agreedEnd = computeAgreedEndAt(agreedStart, durationMinutes);
  const preferredTiming = action === 'accept_arrange_time'
    ? readPreferredTimingFields(publicPayload)
    : readPreferredTimingFields({ ...existingJob, ...quoteData });
  const quoteDecline = readQuoteDeclineFields(quoteData);
  const existingDecline = readQuoteDeclineFields(existingJob);

  return {
    ...mirrored,
    ownerUid,
    jobId,
    requestId: requestId || readString(existingJob.requestId),
    quoteResponseId: quoteId,
    currentQuoteId: firstNonEmpty([
      readString(quoteData.currentQuoteId),
      quoteId,
    ]),
    quoteVersion:
      readNullableInt(quoteData.quoteVersion) ??
      readNullableInt(existingJob.quoteVersion) ??
      1,
    quotePublishKey: firstNonEmpty([
      readString(quoteData.quotePublishKey),
      readString(existingJob.quotePublishKey),
    ]),
    quoteStatus: action === 'decline_quote' ? 'declined' : (action.startsWith('accept_') ? 'accepted' : mirrored.quoteStatus),
    quoteResponseStatus: action === 'decline_quote' ? 'declined' : (action.startsWith('accept_') ? 'accepted' : mirrored.quoteResponseStatus),
    quoteAccepted: action === 'decline_quote' ? false : action.startsWith('accept_'),
    quoteDeclined: action === 'decline_quote',
    quoteRespondedAt: responseTimestamp,
    quoteAcceptedAt: action === 'decline_quote' ? null : responseTimestamp,
    quoteDeclinedAt: action === 'decline_quote' ? responseTimestamp : null,
    acceptedProposedTime: action === 'accept_proposed_time',
    proposedTimeAccepted: action === 'accept_proposed_time',
    timeAccepted: action === 'accept_proposed_time',
    timeNotAccepted: action === 'accept_arrange_time',
    timingNeedsDecision: action === 'accept_arrange_time',
    timeAgreed: action === 'accept_proposed_time',
    needsAgreedTime: action === 'accept_arrange_time',
    readyForCalendar: action === 'accept_proposed_time',
    requestStatus: action === 'decline_quote'
      ? 'quote_declined'
      : (action.startsWith('accept_') ? 'quote_accepted' : mirrored.requestStatus),
    status: action === 'decline_quote'
      ? 'quoteDeclined'
      : (action.startsWith('accept_') ? 'quoteAccepted' : mirrored.status),
    schedulingStatus: action === 'accept_proposed_time'
      ? 'accepted_time'
      : (action === 'accept_arrange_time' ? 'awaiting_agreed_time' : null),
    agreedDateTime: action === 'accept_proposed_time' && agreedStart
      ? admin.firestore.Timestamp.fromDate(agreedStart)
      : null,
    agreedStartAt: action === 'accept_proposed_time' && agreedStart
      ? admin.firestore.Timestamp.fromDate(agreedStart)
      : null,
    agreedEndAt: action === 'accept_proposed_time' && agreedEnd
      ? admin.firestore.Timestamp.fromDate(agreedEnd)
      : null,
    agreedDate: action === 'accept_proposed_time' ? (proposedDate || null) : null,
    agreedTime: action === 'accept_proposed_time' ? (proposedStartTime || null) : null,
    scheduledAt: action === 'accept_proposed_time' && agreedStart
      ? admin.firestore.Timestamp.fromDate(agreedStart)
      : null,
    scheduledDate: action === 'accept_proposed_time' ? (proposedDate || null) : null,
    scheduledStartTime: action === 'accept_proposed_time' ? (proposedStartTime || null) : null,
    acceptedProposedDate: action === 'accept_proposed_time' ? (proposedDate || null) : null,
    acceptedProposedStartTime: action === 'accept_proposed_time' ? (proposedStartTime || null) : null,
    preferredDate: action === 'accept_arrange_time' ? preferredTiming.preferredDate : null,
    preferredTimeWindow: action === 'accept_arrange_time' ? preferredTiming.preferredTimeWindow : '',
    preferredTimingNote: action === 'accept_arrange_time' ? preferredTiming.preferredTimingNote : '',
    preferredTimingDecision: action === 'accept_arrange_time' ? preferredTiming.preferredTimingDecision : '',
    suggestedDate: action === 'accept_arrange_time' ? preferredTiming.suggestedDate : null,
    suggestedTimeWindow: action === 'accept_arrange_time' ? preferredTiming.suggestedTimeWindow : '',
    proposedDurationMinutes: durationMinutes,
    agreedDurationMinutes: action === 'accept_proposed_time' ? durationMinutes : null,
    estimatedDurationMinutes: durationMinutes,
    confirmedAt: action === 'accept_proposed_time' ? responseTimestamp : null,
    timeStatus: action === 'accept_arrange_time'
      ? 'time_not_accepted'
      : (action === 'accept_proposed_time' ? 'agreed' : mirrored.timeStatus),
    timingStatus: action === 'accept_arrange_time'
      ? 'timing_needs_decision'
      : (action === 'accept_proposed_time' ? 'agreed' : mirrored.timingStatus),
    ...buildQuoteDeclineFieldSet({
      code: quoteDecline.code || existingDecline.code,
      label: quoteDecline.label || existingDecline.label,
      note: quoteDecline.note || existingDecline.note,
      reasonText: quoteDecline.reasonText || existingDecline.reasonText,
    }),
    declinedAt: action === 'decline_quote' ? responseTimestamp : toIsoStringOrNull(existingJob.declinedAt) || null,
    declinedBy: action === 'decline_quote' ? 'customer' : readString(existingJob.declinedBy),
    updatedAt: responseTimestamp,
  };
}

function buildDriverJobExactLocationPayload({
  quoteData,
  existingJob,
  exactLocationPayload,
  quoteId,
  ownerUid,
  jobId,
  requestId,
}) {
  const mergedQuoteState = {
    ...quoteData,
    ...exactLocationPayload,
    ownerUid,
    jobId,
    requestId,
  };
  const mirrored = buildQuoteJobMirror({
    before: quoteData,
    after: mergedQuoteState,
    existingJob,
    quoteId,
    ownerUid,
    jobId,
  });
  const accepted =
    readBool(quoteData.quoteAccepted) ||
    readString(quoteData.quoteStatus).toLowerCase() === 'accepted' ||
    readString(quoteData.quoteResponseStatus).toLowerCase() === 'accepted' ||
    readBool(existingJob.quoteAccepted);
  const acceptedProposedTime =
    readBool(quoteData.acceptedProposedTime) ||
    readBool(quoteData.proposedTimeAccepted) ||
    readString(quoteData.quoteTimingChoice).toLowerCase() === 'accepted_proposed_time' ||
    readBool(existingJob.acceptedProposedTime);
  const agreedStart =
    toDateOrNull(quoteData.agreedStartAt) ||
    toDateOrNull(quoteData.agreedDateTime) ||
    toDateOrNull(existingJob.agreedStartAt) ||
    toDateOrNull(existingJob.agreedDateTime);
  const durationMinutes = readQuoteDurationMinutesForDriver({
    quoteData,
    existingJob,
  });
  const agreedEnd = computeAgreedEndAt(agreedStart, durationMinutes);
  const hasAgreedTime = !!agreedStart;
  const preferredTiming = readPreferredTimingFields({
    ...existingJob,
    ...quoteData,
  });
  const timingNeedsDecision =
    readBool(quoteData.timingNeedsDecision) ||
    readBool(existingJob.timingNeedsDecision) ||
    readString(quoteData.quoteTimingChoice).toLowerCase() === 'arrange_another_time' ||
    readString(existingJob.quoteTimingChoice).toLowerCase() === 'arrange_another_time';

  return {
    ...mirrored,
    ownerUid,
    jobId,
    requestId: requestId || readString(existingJob.requestId),
    quoteResponseId: quoteId,
    ...(accepted ? {
      quoteStatus: 'accepted',
      quoteResponseStatus: 'accepted',
      quoteAccepted: true,
      quoteDeclined: false,
      acceptedProposedTime,
      proposedTimeAccepted: acceptedProposedTime,
      timeAccepted: hasAgreedTime,
      timeNotAccepted: !hasAgreedTime && timingNeedsDecision,
      timingNeedsDecision: !hasAgreedTime && timingNeedsDecision,
      timeAgreed: hasAgreedTime,
      needsAgreedTime: !hasAgreedTime,
      readyForCalendar: hasAgreedTime,
      requestStatus: 'quote_accepted',
      status: 'quoteAccepted',
      schedulingStatus: hasAgreedTime
        ? 'accepted_time'
        : firstNonEmpty([
          readString(existingJob.schedulingStatus),
          readString(quoteData.schedulingStatus),
        ]),
      agreedDateTime: agreedStart
        ? admin.firestore.Timestamp.fromDate(agreedStart)
        : mirrored.agreedDateTime,
      agreedStartAt: agreedStart
        ? admin.firestore.Timestamp.fromDate(agreedStart)
        : null,
      agreedEndAt: agreedEnd
        ? admin.firestore.Timestamp.fromDate(agreedEnd)
        : null,
      agreedDurationMinutes: durationMinutes,
      timeStatus: hasAgreedTime ? 'agreed' : 'time_not_accepted',
      timingStatus: hasAgreedTime ? 'agreed' : 'timing_needs_decision',
      preferredDate: !hasAgreedTime ? preferredTiming.preferredDate : null,
      preferredTimeWindow: !hasAgreedTime ? preferredTiming.preferredTimeWindow : '',
      preferredTimingNote: !hasAgreedTime ? preferredTiming.preferredTimingNote : '',
      preferredTimingDecision: !hasAgreedTime ? preferredTiming.preferredTimingDecision : '',
      suggestedDate: !hasAgreedTime ? preferredTiming.suggestedDate : null,
      suggestedTimeWindow: !hasAgreedTime ? preferredTiming.suggestedTimeWindow : '',
    } : {}),
    exactPinShared: true,
    exactPinReceived: true,
    hasExactPin: true,
    exactPinLatitude: exactLocationPayload.exactPinLatitude,
    exactPinLongitude: exactLocationPayload.exactPinLongitude,
    exactPinLat: exactLocationPayload.exactPinLatitude,
    exactPinLng: exactLocationPayload.exactPinLongitude,
    exactPinSource: readString(exactLocationPayload.exactPinSource),
    exactPinNote: readString(exactLocationPayload.exactPinNote),
    awaitingExactPin: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function toDateOrNull(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value.toDate === 'function') {
    const converted = value.toDate();
    return converted instanceof Date && !Number.isNaN(converted.getTime())
      ? converted
      : null;
  }

  if (typeof value === 'number') {
    const converted = new Date(value);
    return Number.isNaN(converted.getTime()) ? null : converted;
  }

  const parsed = new Date(String(value).trim());
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function toIsoStringOrNull(value) {
  const date = toDateOrNull(value);
  return date ? date.toISOString() : null;
}

function isPlainObject(value) {
  return !!value &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    !(value instanceof Date) &&
    typeof value.toDate !== 'function';
}

function firestoreValuesEqual(left, right) {
  if (left === right) {
    return true;
  }

  if (left == null || right == null) {
    return left == null && right == null;
  }

  const leftDate = toDateOrNull(left);
  const rightDate = toDateOrNull(right);
  if (leftDate || rightDate) {
    return !!leftDate &&
      !!rightDate &&
      leftDate.toISOString() === rightDate.toISOString();
  }

  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length) {
      return false;
    }
    for (let index = 0; index < left.length; index += 1) {
      if (!firestoreValuesEqual(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  if (isPlainObject(left) || isPlainObject(right)) {
    if (!isPlainObject(left) || !isPlainObject(right)) {
      return false;
    }
    const keys = new Set([
      ...Object.keys(left),
      ...Object.keys(right),
    ]);
    for (const key of keys) {
      if (!firestoreValuesEqual(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }

  return false;
}

function listChangedKeys(before, after, { ignoredKeys = [] } = {}) {
  const ignored = new Set(ignoredKeys);
  const left = before && typeof before === 'object' ? before : {};
  const right = after && typeof after === 'object' ? after : {};
  const keys = new Set([...Object.keys(left), ...Object.keys(right)]);
  return Array.from(keys)
    .filter((key) => !ignored.has(key))
    .filter((key) => !firestoreValuesEqual(left[key], right[key]))
    .sort();
}

function listDesiredChangedKeys(current, desired, { ignoredKeys = [] } = {}) {
  const ignored = new Set(ignoredKeys);
  const source = current && typeof current === 'object' ? current : {};
  const target = desired && typeof desired === 'object' ? desired : {};
  return Object.keys(target)
    .filter((key) => !ignored.has(key))
    .filter((key) => !firestoreValuesEqual(source[key], target[key]))
    .sort();
}

function formatChangedKeys(keys) {
  return Array.isArray(keys) && keys.length > 0 ? keys.join(',') : '(none)';
}

function normalizeJobRequestStatus(value) {
  const normalized = readString(value).toLowerCase();
  switch (normalized) {
    case 'pending':
    case 'sent':
    case 'requestsent':
    case 'request_sent':
    case 'request_received':
    case 'awaiting_reply':
    case 'awaitingreply':
      return 'awaiting_reply';
    case 'submitted':
    case 'reply_received':
    case 'replyreceived':
      return 'reply_received';
    case 'cancelled':
      return 'cancelled';
    case 'draft':
      return 'draft';
    default:
      return normalized;
  }
}

function readJobRequestStatus(data) {
  return normalizeJobRequestStatus(firstNonEmpty([data.requestStatus, data.status]));
}

function normalizePreferredTimeWindow(value) {
  const normalized = readString(value).toLowerCase();
  switch (normalized) {
    case 'morning':
    case 'afternoon':
    case 'evening':
    case 'anytime':
      return normalized;
    case 'flexible':
      return 'anytime';
    default:
      return '';
  }
}

function normalizeCustomerRequestType(value, fallback = 'quoteRequest') {
  const normalized = readString(value);
  switch (normalized) {
    case 'quoteRequest':
    case 'bookingRequest':
    case 'orderRequest':
    case 'dropOffPickupRequest':
    case 'pickupDeliveryRequest':
      return normalized;
    default:
      return fallback;
  }
}

function normalizeCustomerJourneyType(value, fallback = 'quote') {
  const normalized = readString(value).toLowerCase();
  return normalized === 'quote' || normalized === 'booking' || normalized === 'order'
    ? normalized
    : fallback;
}

function customerJourneyForLegacyRequestType(requestType) {
  if (requestType === 'bookingRequest') return 'booking';
  if (requestType === 'orderRequest') return 'order';
  return 'quote';
}

function normalizeServiceFlow(value, legacyRequestType = 'quoteRequest') {
  const normalized = readString(value).toLowerCase();
  if (normalized === 'pickupdelivery' || normalized === 'pickupdeliveryrequest') {
    return 'pickupDelivery';
  }
  if (normalized === 'dropoffpickup' || normalized === 'dropoffpickuprequest') {
    return 'dropOffPickup';
  }
  if (normalized === 'standard') return 'standard';
  if (legacyRequestType === 'pickupDeliveryRequest') return 'pickupDelivery';
  if (legacyRequestType === 'dropOffPickupRequest') return 'dropOffPickup';
  return 'standard';
}

function requestTypeForServiceFlow(serviceFlow) {
  if (serviceFlow === 'pickupDelivery') return 'pickupDeliveryRequest';
  if (serviceFlow === 'dropOffPickup') return 'dropOffPickupRequest';
  return 'quoteRequest';
}

function normalizeStartHandover(value, fallback = 'customerDropsOff') {
  const normalized = readString(value);
  return normalized === 'businessCollects' || normalized === 'customerDropsOff'
    ? normalized
    : fallback;
}

function normalizeEndHandover(value, fallback = 'customerCollects') {
  const normalized = readString(value);
  return normalized === 'businessReturns' ||
    normalized === 'businessDelivers' ||
    normalized === 'customerCollects'
    ? normalized
    : fallback;
}

function normalizeHandoverOptions(value, allowedValues, selected) {
  const source = Array.isArray(value) ? value : [];
  return [...new Set([selected, ...source.map(readString)])]
    .filter((item) => allowedValues.includes(item));
}

function normalizeFulfilmentType(value) {
  const normalized = readString(value).toLowerCase();
  return normalized === 'collection' || normalized === 'delivery'
    ? normalized
    : '';
}

function timeOfDayMinutes(value) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(readString(value));
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

function shouldRequireExactPinAfterQuoteAccepted({
  configured,
  requestType,
  fulfilmentType,
}) {
  if (!readBool(configured)) {
    return false;
  }
  const normalizedRequestType = readString(requestType).toLowerCase();
  const normalizedFulfilmentType = normalizeFulfilmentType(fulfilmentType);
  return !(
    normalizedRequestType === 'orderrequest' &&
    normalizedFulfilmentType === 'collection'
  );
}

function normalizeRequestFlowOptions(value, requestType) {
  const source = value && typeof value === 'object' ? value : {};
  const defaults = {
    showFulfilmentChoice: false,
    askPreferredDate: requestType !== 'dropOffPickupRequest',
    askPreferredTime: requestType !== 'dropOffPickupRequest',
    showPickupAddress: requestType === 'pickupDeliveryRequest',
    showDeliveryAddress: requestType === 'pickupDeliveryRequest',
    showDropOffDate: requestType === 'dropOffPickupRequest',
    showDropOffTime: requestType === 'dropOffPickupRequest',
    showPickUpDate: requestType === 'dropOffPickupRequest',
    showPickUpTime: requestType === 'dropOffPickupRequest',
    showNotes: true,
  };
  return Object.fromEntries(
    Object.entries(defaults).map(([key, fallback]) => [
      key,
      typeof source[key] === 'boolean' ? source[key] : fallback,
    ]),
  );
}

function bookingPastDateMessage() {
  return "You can't book a job in the past. Please choose today or a future date.";
}

function startOfLocalDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function validatePreferredBookingWindow({
  preferredDate,
  preferredTimeWindow,
  preferredIsFlexible,
  now = new Date(),
}) {
  if (!(preferredDate instanceof Date) || Number.isNaN(preferredDate.getTime())) {
    return null;
  }

  const today = startOfLocalDay(now);
  const selectedDay = startOfLocalDay(preferredDate);
  if (selectedDay.getTime() < today.getTime()) {
    return bookingPastDateMessage();
  }
  if (preferredIsFlexible) {
    return null;
  }
  if (selectedDay.getTime() !== today.getTime()) {
    return null;
  }

  const normalizedWindow = normalizePreferredTimeWindow(preferredTimeWindow);
  const slotEndHour = (() => {
    switch (normalizedWindow) {
      case 'morning':
        return 12;
      case 'afternoon':
        return 17;
      case 'evening':
        return 21;
      default:
        return null;
    }
  })();
  if (slotEndHour == null) {
    return null;
  }

  const slotEnd = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    slotEndHour,
    0,
    0,
    0,
  );
  return now.getTime() > slotEnd.getTime() ? bookingPastDateMessage() : null;
}

function normalizeCalendarStatus(value) {
  const normalized = readString(value).toLowerCase();
  switch (normalized) {
    case 'scheduled':
    case 'completed':
    case 'unscheduled':
      return normalized;
    default:
      return 'unscheduled';
  }
}

function normalizeJobWorkflowStatus(existingStatus, requestStatus, hasReply) {
  const normalizedExisting = readString(existingStatus).toLowerCase();
  switch (normalizedExisting) {
    case 'cancelled':
      return 'cancelled';
    case 'confirmed':
      return 'confirmed';
    case 'replyreceived':
      return 'replyReceived';
    case 'quotesent':
    case 'quote_sent':
      return 'quoteSent';
    case 'completed':
    case 'done':
    case 'completedjob':
      return 'completed';
    default:
      break;
  }

  if (requestStatus === 'reply_received' || hasReply) {
    return 'replyReceived';
  }

  if (requestStatus === 'awaiting_reply' || requestStatus === 'request_sent') {
    return 'requestSent';
  }

  return readString(existingStatus) || 'draft';
}

function normalizeChecklistResponses(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => {
      const source = item && typeof item === 'object' ? item : {};
      const question = readString(source.question);
      const answer = readString(source.answer);
      const note = readString(source.note);
      if (!question && !answer && !note) {
        return null;
      }

      return { question, answer, note };
    })
    .filter(Boolean);
}

function normalizeCustomQuestionResponses(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => {
      const source = item && typeof item === 'object' ? item : {};
      const question = readString(source.question);
      const answer = readString(source.answer);
      if (!question && !answer) {
        return null;
      }

      return { question, answer };
    })
    .filter(Boolean);
}

function normalizeRequestAnswers(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item, index) => {
      const source = item && typeof item === 'object' ? item : {};
      const questionId = readString(source.questionId);
      const questionText = readString(source.questionText);
      const answerValue = readString(source.answerValue || source.answer);
      if (!questionId && !questionText && !answerValue) {
        return null;
      }

      return {
        questionId,
        questionText,
        answerType: readString(source.answerType || source.type),
        category: readString(source.category),
        answerValue,
        answer: answerValue,
        order:
          readNullableInt(source.order) == null
            ? index
            : readNullableInt(source.order),
      };
    })
    .filter(Boolean)
    .sort((a, b) => {
      const left = readNullableInt(a.order);
      const right = readNullableInt(b.order);
      return (left == null ? Number.MAX_SAFE_INTEGER : left) -
        (right == null ? Number.MAX_SAFE_INTEGER : right);
    })
    .map((item, index) => ({
      ...item,
      order: readNullableInt(item.order) == null ? index : readNullableInt(item.order),
    }));
}

function buildRequestJobMirror({
  before,
  after,
  existingJob,
  requestId,
  ownerUid,
  jobId,
}) {
  const normalizedRequestStatus = readJobRequestStatus(after);
  const checklistResponses = normalizeChecklistResponses(after.checklistResponses);
  const customQuestionResponses = normalizeCustomQuestionResponses(
    after.customQuestionResponses,
  );
  const answers = normalizeRequestAnswers(after.answers);
  const additionalNotes = readString(after.additionalNotes);
  const exactPinLat =
    readNullableNumber(after.exactPinLat) ??
    readNullableNumber(after.exactPinLatitude);
  const exactPinLng =
    readNullableNumber(after.exactPinLng) ??
    readNullableNumber(after.exactPinLongitude);
  const hasExactPin =
    readBool(after.hasExactPin) ||
    (Number.isFinite(exactPinLat) && Number.isFinite(exactPinLng));
  const hasReply =
    normalizedRequestStatus === 'reply_received' ||
    readBool(after.hasReply) ||
    checklistResponses.length > 0 ||
    customQuestionResponses.length > 0 ||
    additionalNotes.trim().length > 0 ||
    hasExactPin;
  const requestCreatedAt =
    toIsoStringOrNull(after.createdAt) ||
    toIsoStringOrNull(before && before.createdAt) ||
    toIsoStringOrNull(existingJob.requestCreatedAt) ||
    toIsoStringOrNull(existingJob.createdAt) ||
    new Date().toISOString();
  const requestUpdatedAt =
    toIsoStringOrNull(after.updatedAt) ||
    toIsoStringOrNull(existingJob.requestUpdatedAt) ||
    new Date().toISOString();
  const requestSubmittedAt = hasReply
    ? (toIsoStringOrNull(after.customerSubmittedAt) ||
      toIsoStringOrNull(after.submittedAt) ||
      toIsoStringOrNull(existingJob.requestSubmittedAt) ||
      requestUpdatedAt)
    : (toIsoStringOrNull(existingJob.requestSubmittedAt) || null);
  const replyReceivedAt = hasReply
    ? (requestSubmittedAt ||
      toIsoStringOrNull(existingJob.replyReceivedAt) ||
      requestUpdatedAt)
    : (toIsoStringOrNull(existingJob.replyReceivedAt) || null);
  const requestExpiresAt =
    toIsoStringOrNull(after.expiresAt) ||
    toIsoStringOrNull(existingJob.requestExpiresAt) ||
    null;
  const requestLink = firstNonEmpty([
      after.requestLink,
      existingJob.requestLink,
      buildVanJobRequestHostedLink(requestId, after.shortCode),
    ]);
  const preferredDate = firstNonEmpty([
    toIsoStringOrNull(after.preferredDate),
    toIsoStringOrNull(existingJob.preferredDate),
  ]);
  const preferredTimeWindow = firstNonEmpty([
    normalizePreferredTimeWindow(after.preferredTimeWindow || after.preferredWindow),
    normalizePreferredTimeWindow(existingJob.preferredTimeWindow),
  ]);
  const preferredTimingDecision = firstNonEmpty([
    readString(after.preferredTimingDecision),
    readString(existingJob.preferredTimingDecision),
  ]);
  const suggestedDate = firstNonEmpty([
    toIsoStringOrNull(after.suggestedDate),
    toIsoStringOrNull(existingJob.suggestedDate),
  ]);
  const suggestedTimeWindow = firstNonEmpty([
    normalizePreferredTimeWindow(after.suggestedTimeWindow),
    normalizePreferredTimeWindow(existingJob.suggestedTimeWindow),
  ]);
  const scheduledAtIso = firstNonEmpty([
    toIsoStringOrNull(after.scheduledAt),
    toIsoStringOrNull(existingJob.scheduledAt),
  ]);
  const scheduledDate = firstNonEmpty([
    readString(after.scheduledDate),
    readString(existingJob.scheduledDate),
  ]);
  const scheduledStartTime = firstNonEmpty([
    readString(after.scheduledStartTime),
    readString(existingJob.scheduledStartTime),
  ]);
  const estimatedDurationMinutes =
    readNullableInt(after.estimatedDurationMinutes) ??
    readNullableInt(existingJob.estimatedDurationMinutes);
  const calendarStatus = normalizeCalendarStatus(
    firstNonEmpty([after.calendarStatus, existingJob.calendarStatus]),
  );
  const normalizedStatus = normalizeJobWorkflowStatus(
    existingJob.status,
    normalizedRequestStatus,
    hasReply,
  );
  const requestType = firstNonEmpty([
    readString(after.requestType),
    readString(existingJob.requestType),
  ]);
  const customerJourneyType = normalizeCustomerJourneyType(
    firstNonEmpty([
      readString(after.customerJourneyType),
      readString(existingJob.customerJourneyType),
    ]),
    customerJourneyForLegacyRequestType(requestType),
  );
  const fulfilmentType = firstNonEmpty([
    readString(after.fulfilmentType),
    readString(existingJob.fulfilmentType),
  ]);
  const startHandover = firstNonEmpty([
    readString(after.startHandover),
    readString(existingJob.startHandover),
  ]);
  const endHandover = firstNonEmpty([
    readString(after.endHandover),
    readString(existingJob.endHandover),
  ]);
  const usesBusinessDelivery = endHandover.toLowerCase() === 'businessdelivers';
  const configuredExactPinAfterQuoteAccepted =
    requestType === 'dropOffPickupRequest'
      ? readBool(after.requiresExactPinAfterQuoteAccepted) ||
        readBool(after.exactPinRequiredAfterQuoteAccepted)
      : readBool(after.requiresExactPinAfterQuoteAccepted) ||
        readBool(after.exactPinRequiredAfterQuoteAccepted) ||
        readBool(existingJob.requiresExactPinAfterQuoteAccepted);
  const requiresExactPinAfterQuoteAccepted =
    shouldRequireExactPinAfterQuoteAccepted({
      configured: configuredExactPinAfterQuoteAccepted,
      requestType,
      fulfilmentType,
    });

  return {
    id: jobId,
    ownerUid,
    jobId,
    status: normalizedStatus,
    customerName: firstNonEmpty([
      readString(after.publicCustomerName),
      readString(existingJob.customerName),
    ]),
    jobTitle: firstNonEmpty([
      readString(after.publicJobTitle),
      readString(existingJob.jobTitle),
    ]),
    address: firstNonEmpty([
      readString(after.publicAddressSummary),
      readString(existingJob.address),
    ]),
    phoneNumber: firstNonEmpty([
      readString(after.publicPhoneNumber),
      readString(after.customerPhone),
      readString(existingJob.phoneNumber),
    ]),
    customerEmail: readString(after.publicCustomerEmail || existingJob.customerEmail),
    postcode: readString(after.customerPostcode || existingJob.postcode),
    scheduledAt: scheduledAtIso,
    jobDateLabel: firstNonEmpty([
      readString(after.jobDateLabel),
      readString(existingJob.jobDateLabel),
    ]),
    jobTimeLabel: firstNonEmpty([
      readString(after.jobTimeLabel),
      readString(existingJob.jobTimeLabel),
    ]),
    preferredDate: preferredDate || null,
    preferredTimeWindow,
    preferredIsFlexible:
      readBool(after.preferredIsFlexible) ||
      readBool(after.timingFlexible) ||
      readBool(existingJob.preferredIsFlexible),
    preferredTimingNote: firstNonEmpty([
      readString(after.preferredTimingNote),
      readString(after.timingNote),
      readString(existingJob.preferredTimingNote),
    ]),
    preferredTimingDecision,
    suggestedDate: suggestedDate || null,
    suggestedTimeWindow,
    requestType,
    customerJourneyType,
    fulfilmentType,
    startHandover,
    endHandover,
    allowedStartHandoverOptions: Array.isArray(after.allowedStartHandoverOptions)
      ? after.allowedStartHandoverOptions
      : (Array.isArray(existingJob.allowedStartHandoverOptions)
        ? existingJob.allowedStartHandoverOptions
        : []),
    allowedEndHandoverOptions: Array.isArray(after.allowedEndHandoverOptions)
      ? after.allowedEndHandoverOptions
      : (Array.isArray(existingJob.allowedEndHandoverOptions)
        ? existingJob.allowedEndHandoverOptions
        : []),
    collectionAddress: firstNonEmpty([
      readString(after.collectionAddress),
      readString(existingJob.collectionAddress),
    ]),
    deliveryAddress: firstNonEmpty([
      readString(after.deliveryAddress),
      readString(existingJob.deliveryAddress),
    ]),
    returnAddress: usesBusinessDelivery
      ? ''
      : firstNonEmpty([
        readString(after.returnAddress),
        readString(existingJob.returnAddress),
      ]),
    returnAddressSameAsCollection: usesBusinessDelivery
      ? false
      : readBool(after.returnAddressSameAsCollection) ||
        readBool(existingJob.returnAddressSameAsCollection),
    businessDropOffInstructions: firstNonEmpty([
      readString(after.businessDropOffInstructions),
      readString(existingJob.businessDropOffInstructions),
    ]),
    businessCollectionInstructions: firstNonEmpty([
      readString(after.businessCollectionInstructions),
      readString(existingJob.businessCollectionInstructions),
    ]),
    dropOffDate: firstNonEmpty([
      toIsoStringOrNull(after.dropOffDate),
      toIsoStringOrNull(existingJob.dropOffDate),
    ]) || null,
    dropOffTime: firstNonEmpty([after.dropOffTime, existingJob.dropOffTime]),
    pickUpDate: firstNonEmpty([
      toIsoStringOrNull(after.pickUpDate),
      toIsoStringOrNull(existingJob.pickUpDate),
    ]) || null,
    pickUpTime: firstNonEmpty([after.pickUpTime, existingJob.pickUpTime]),
    collectionDate: firstNonEmpty([
      toIsoStringOrNull(after.collectionDate),
      toIsoStringOrNull(existingJob.collectionDate),
    ]) || null,
    collectionTime: firstNonEmpty([
      after.collectionTime,
      existingJob.collectionTime,
    ]),
    deliveryDate: firstNonEmpty([
      toIsoStringOrNull(after.deliveryDate),
      toIsoStringOrNull(existingJob.deliveryDate),
    ]) || null,
    deliveryTime: firstNonEmpty([
      after.deliveryTime,
      existingJob.deliveryTime,
    ]),
    requestExactPin: requestType === 'dropOffPickupRequest'
      ? false
      : readBool(after.exactPinRequested) || readBool(existingJob.requestExactPin),
    requestPhotos: readBool(after.requestPhotos) || readBool(existingJob.requestPhotos),
    requiresExactPinAfterQuoteAccepted,
    locationPending: requestType === 'dropOffPickupRequest'
      ? requiresExactPinAfterQuoteAccepted &&
        (readBool(after.locationPending) || readBool(existingJob.locationPending))
      : readBool(after.locationPending) || readBool(existingJob.locationPending),
    selectedServiceId: readString(after.selectedServiceId || existingJob.selectedServiceId),
    selectedServiceName: readString(after.selectedServiceName || existingJob.selectedServiceName),
    checklistItems: Array.isArray(after.checklistItems)
      ? after.checklistItems
      : (Array.isArray(existingJob.checklistItems) ? existingJob.checklistItems : []),
    customQuestions: Array.isArray(after.customQuestions)
      ? after.customQuestions
      : (Array.isArray(existingJob.customQuestions) ? existingJob.customQuestions : []),
    notesMessage: firstNonEmpty([
      readString(after.sourceLabel) ? `Source: ${readString(after.sourceLabel)}` : '',
      readString(existingJob.notesMessage),
    ]),
    requestId,
    requestLink,
    requestStatus: normalizedRequestStatus,
    requestCreatedAt,
    requestSentAt:
      toIsoStringOrNull(existingJob.requestSentAt) || requestCreatedAt,
    requestUpdatedAt,
    requestSubmittedAt,
    requestExpiresAt,
    replyReceivedAt,
    exactPinShared: hasReply ? hasExactPin : readBool(existingJob.exactPinShared),
    exactPinLatitude: hasReply
      ? (hasExactPin ? exactPinLat : null)
      : (existingJob.exactPinLatitude ?? null),
    exactPinLongitude: hasReply
      ? (hasExactPin ? exactPinLng : null)
      : (existingJob.exactPinLongitude ?? null),
    exactPinShareSource: hasReply
      ? (hasExactPin
        ? firstNonEmpty([
          after.exactPinShareSource,
          after.exactPinSource,
          existingJob.exactPinShareSource,
          'currentLocationConfirmed',
        ])
        : '')
      : readString(existingJob.exactPinShareSource),
    exactPinSource: hasReply
      ? (hasExactPin
        ? firstNonEmpty([
          after.exactPinSource,
          after.exactPinShareSource,
          existingJob.exactPinSource,
          existingJob.exactPinShareSource,
          'none',
        ])
        : 'none')
      : firstNonEmpty([
        readString(existingJob.exactPinSource),
        readString(existingJob.exactPinShareSource),
        'none',
      ]),
    exactPinNote: hasReply
      ? (hasExactPin
        ? (readString(after.exactPinNote) || readString(existingJob.exactPinNote))
        : '')
      : readString(existingJob.exactPinNote),
    checklistResponses: hasReply
      ? checklistResponses
      : Array.isArray(existingJob.checklistResponses)
        ? existingJob.checklistResponses
        : [],
    customQuestionResponses: hasReply
      ? customQuestionResponses
      : Array.isArray(existingJob.customQuestionResponses)
        ? existingJob.customQuestionResponses
        : [],
    answers: answers.length > 0
      ? answers
      : (Array.isArray(existingJob.answers) ? existingJob.answers : []),
    additionalNotes: hasReply ? additionalNotes : readString(existingJob.additionalNotes),
    photos: Array.isArray(after.photos)
      ? after.photos
      : (Array.isArray(existingJob.photos) ? existingJob.photos : []),
    hasReply,
    hasExactPin,
    updatedAt: requestUpdatedAt,
    createdAt:
      toIsoStringOrNull(existingJob.createdAt) ||
      requestCreatedAt,
  };
}

function buildQuoteJobMirror({
  before,
  after,
  existingJob,
  quoteId,
  ownerUid,
  jobId,
}) {
  const hasOwn = (object, key) =>
    !!object && Object.prototype.hasOwnProperty.call(object, key);
  const hasExplicitQuoteStateReset =
    (hasOwn(after, 'quoteStatus') ||
      hasOwn(after, 'quoteResponseStatus') ||
      hasOwn(after, 'quoteResponse') ||
      hasOwn(after, 'quoteAccepted') ||
      hasOwn(after, 'quoteDeclined') ||
      hasOwn(after, 'quoteRespondedAt') ||
      hasOwn(after, 'quoteAcceptedAt') ||
      hasOwn(after, 'quoteDeclinedAt')) &&
    !readBool(after.quoteAccepted) &&
    !readBool(after.quoteDeclined) &&
    !toIsoStringOrNull(after.quoteRespondedAt) &&
    !toIsoStringOrNull(after.quoteAcceptedAt) &&
    !toIsoStringOrNull(after.quoteDeclinedAt) &&
    ['', 'pending'].includes(readString(after.quoteResponseStatus).toLowerCase()) &&
    ['', 'pending'].includes(readString(after.quoteResponse).toLowerCase()) &&
    ['sent', 'opened_for_sending'].includes(readString(after.quoteStatus).toLowerCase());
  const quoteStatusRaw = firstNonEmpty([
    after.quoteStatus,
    after.quoteResponseStatus,
    after.quoteResponse,
    after.status,
    existingJob.quoteStatus,
  ]);
  const requestStatusRaw = firstNonEmpty([
    after.requestStatus,
    existingJob.requestStatus,
  ]);
  const quoteStatus = readString(quoteStatusRaw).toLowerCase();
  const quoteResponseStatus = firstNonEmpty([
    readString(after.quoteResponseStatus),
    readString(existingJob.quoteResponseStatus),
    quoteStatus,
  ]).toLowerCase();
  const quoteTimingChoice = firstNonEmpty([
    readString(after.quoteTimingChoice),
    readString(existingJob.quoteTimingChoice),
    '',
  ]);
  const existingQuoteAccepted =
    readBool(existingJob.quoteAccepted) ||
    readString(existingJob.quoteStatus).toLowerCase() === 'accepted' ||
    readString(existingJob.quoteResponseStatus).toLowerCase() === 'accepted' ||
    readString(existingJob.requestStatus).toLowerCase() === 'quote_accepted' ||
    readString(existingJob.status).toLowerCase() === 'quoteaccepted';
  const existingQuoteDeclined =
    readBool(existingJob.quoteDeclined) ||
    readString(existingJob.quoteStatus).toLowerCase() === 'declined' ||
    readString(existingJob.quoteResponseStatus).toLowerCase() === 'declined' ||
    readString(existingJob.requestStatus).toLowerCase() === 'quote_declined' ||
    readString(existingJob.status).toLowerCase() === 'quotedeclined';
  let quoteAccepted =
    readBool(after.quoteAccepted) ||
    quoteStatus === 'accepted' ||
    quoteResponseStatus === 'accepted';
  let quoteDeclined =
    readBool(after.quoteDeclined) ||
    quoteStatus === 'declined' ||
    quoteResponseStatus === 'declined';
  if (!quoteAccepted && !quoteDeclined) {
    if (existingQuoteDeclined && !hasExplicitQuoteStateReset) {
      quoteDeclined = true;
    } else if (existingQuoteAccepted) {
      quoteAccepted = true;
    }
  }
  const explicitSchedulingStatus = readString(after.schedulingStatus);
  const existingSchedulingStatus = readString(existingJob.schedulingStatus);
  const effectiveAcceptedSchedulingStatus = firstNonEmpty([
    explicitSchedulingStatus,
    existingSchedulingStatus,
  ]);
  const acceptedProposedDate = quoteAccepted
    ? (effectiveAcceptedSchedulingStatus === 'awaiting_agreed_time'
      ? ''
      : firstNonEmpty([
        readString(after.acceptedProposedDate),
        explicitSchedulingStatus === 'accepted_time'
          ? readString(after.proposedDate)
          : '',
        readString(existingJob.acceptedProposedDate),
      ]))
    : firstNonEmpty([
      readString(existingJob.acceptedProposedDate),
    ]);
  const acceptedProposedStartTime = quoteAccepted
    ? (effectiveAcceptedSchedulingStatus === 'awaiting_agreed_time'
      ? ''
      : firstNonEmpty([
        readString(after.acceptedProposedStartTime),
        explicitSchedulingStatus === 'accepted_time'
          ? readString(after.proposedStartTime)
          : '',
        readString(existingJob.acceptedProposedStartTime),
      ]))
    : firstNonEmpty([
      readString(existingJob.acceptedProposedStartTime),
    ]);
  const agreedDateTime = quoteAccepted
    ? firstNonEmpty([
      toIsoStringOrNull(after.agreedDateTime),
      explicitSchedulingStatus === 'accepted_time' &&
          readString(after.proposedDate) &&
          readString(after.proposedStartTime)
        ? `${readString(after.proposedDate)}T${readString(after.proposedStartTime)}:00.000`
        : '',
      toIsoStringOrNull(existingJob.agreedDateTime),
    ]) || null
    : null;
  const quoteRespondedAt = firstNonEmpty([
    toIsoStringOrNull(after.quoteRespondedAt),
    toIsoStringOrNull(after.quoteAcceptedAt),
    toIsoStringOrNull(after.quoteDeclinedAt),
    toIsoStringOrNull(before && before.quoteRespondedAt),
    toIsoStringOrNull(existingJob.quoteRespondedAt),
  ]);
  const quoteAcceptedAt = quoteAccepted
    ? firstNonEmpty([
      toIsoStringOrNull(after.quoteAcceptedAt),
      quoteRespondedAt,
      toIsoStringOrNull(existingJob.quoteAcceptedAt),
    ])
    : null;
  const quoteDeclinedAt = quoteDeclined
    ? firstNonEmpty([
      toIsoStringOrNull(after.quoteDeclinedAt),
      quoteRespondedAt,
      toIsoStringOrNull(existingJob.quoteDeclinedAt),
    ])
    : null;
  const quoteNotificationSent = readBool(after[QUOTE_NOTIFICATION_SENT_FIELD]) ||
    readBool(existingJob[QUOTE_NOTIFICATION_SENT_FIELD]);
  const quoteNotificationSentAt = firstNonEmpty([
    toIsoStringOrNull(after[QUOTE_NOTIFICATION_SENT_AT_FIELD]),
    toIsoStringOrNull(existingJob[QUOTE_NOTIFICATION_SENT_AT_FIELD]),
  ]);
  const requestType = firstNonEmpty([
    readString(after.requestType),
    readString(existingJob.requestType),
  ]);
  const customerJourneyType = normalizeCustomerJourneyType(
    firstNonEmpty([
      readString(after.customerJourneyType),
      readString(existingJob.customerJourneyType),
    ]),
    customerJourneyForLegacyRequestType(requestType),
  );
  const fulfilmentType = firstNonEmpty([
    readString(after.fulfilmentType),
    readString(existingJob.fulfilmentType),
  ]);
  const startHandover = firstNonEmpty([
    readString(after.startHandover),
    readString(existingJob.startHandover),
  ]);
  const endHandover = firstNonEmpty([
    readString(after.endHandover),
    readString(existingJob.endHandover),
  ]);
  const usesBusinessDelivery = endHandover.toLowerCase() === 'businessdelivers';
  const configuredExactPinAfterQuoteAccepted =
    requestType === 'dropOffPickupRequest'
      ? readBool(after.requiresExactPinAfterQuoteAccepted) ||
        readBool(after.exactPinRequiredAfterQuoteAccepted)
      : readBool(after.requiresExactPinAfterQuoteAccepted) ||
        readBool(after.exactPinRequiredAfterQuoteAccepted) ||
        readBool(existingJob.requiresExactPinAfterQuoteAccepted);
  const requiresExactPinAfterQuoteAccepted =
    shouldRequireExactPinAfterQuoteAccepted({
      configured: configuredExactPinAfterQuoteAccepted,
      requestType,
      fulfilmentType,
    });
  const exactPinLatitude =
    readNullableNumber(after.exactPinLatitude) ??
    readNullableNumber(after.exactPinLat) ??
    readNullableNumber(existingJob.exactPinLatitude) ??
    readNullableNumber(existingJob.exactPinLat);
  const exactPinLongitude =
    readNullableNumber(after.exactPinLongitude) ??
    readNullableNumber(after.exactPinLng) ??
    readNullableNumber(existingJob.exactPinLongitude) ??
    readNullableNumber(existingJob.exactPinLng);
  const exactPinAlreadyExists =
    readBool(after.exactPinShared) ||
    readBool(after.hasExactPin) ||
    (Number.isFinite(exactPinLatitude) && Number.isFinite(exactPinLongitude)) ||
    readBool(existingJob.exactPinShared) ||
    readBool(existingJob.hasExactPin);
  const confirmedAt = quoteAccepted
    ? (firstNonEmpty([
      explicitSchedulingStatus === 'awaiting_agreed_time' ||
          readString(quoteTimingChoice).toLowerCase() === 'arrange_another_time'
        ? null
        : toIsoStringOrNull(after.confirmedAt),
      explicitSchedulingStatus === 'awaiting_agreed_time' ||
          readString(quoteTimingChoice).toLowerCase() === 'arrange_another_time'
        ? null
        : toIsoStringOrNull(existingJob.confirmedAt),
    ]) || null)
    : (quoteDeclined
      ? null
      : firstNonEmpty([
        toIsoStringOrNull(after.confirmedAt),
        toIsoStringOrNull(existingJob.confirmedAt),
      ]));
  const effectiveStatus = quoteAccepted
    ? 'quoteAccepted'
    : (quoteDeclined ? 'quoteDeclined' : readString(firstNonEmpty([after.status, existingJob.status])) || 'sent');
  const effectiveRequestStatus = quoteAccepted
    ? 'quote_accepted'
    : (quoteDeclined ? 'quote_declined' : readString(requestStatusRaw) || 'sent');
  const updatedAt = firstNonEmpty([
    toIsoStringOrNull(after.updatedAt),
    toIsoStringOrNull(existingJob.updatedAt),
    toIsoStringOrNull(existingJob.createdAt),
    toIsoStringOrNull(after.createdAt),
  ]);
  const createdAt = firstNonEmpty([
    toIsoStringOrNull(existingJob.createdAt),
    toIsoStringOrNull(after.createdAt),
    updatedAt,
  ]);
  const quoteResponseToken = firstNonEmpty([
    readString(after.quoteResponseToken),
    readString(existingJob.quoteResponseToken),
    buildVanQuoteResponseToken(quoteId),
  ]);
  const quoteResponseLink = firstNonEmpty([
      resolveVanQuoteResponseHostedLink({
        quoteToken: quoteResponseToken,
        quoteId,
        quoteResponseLink: firstNonEmpty([
          readString(after.quoteResponseLink),
          readString(existingJob.quoteResponseLink),
        ]),
      }),
      buildLegacyVanQuoteResponseHostedLink(quoteId),
  ]);

  return {
    id: jobId,
    ownerUid,
    jobId,
    requestId: firstNonEmpty([after.requestId, existingJob.requestId]),
    proposedDate: firstNonEmpty([
      readString(after.proposedDate),
      readString(existingJob.proposedDate),
    ]),
    proposedStartTime: firstNonEmpty([
      readString(after.proposedStartTime),
      readString(existingJob.proposedStartTime),
    ]),
    proposedAppointmentNote: firstNonEmpty([
      readString(after.proposedAppointmentNote),
      readString(existingJob.proposedAppointmentNote),
    ]),
    acceptedProposedDate,
    acceptedProposedStartTime,
    schedulingStatus: firstNonEmpty([
      explicitSchedulingStatus,
      quoteAccepted &&
          acceptedProposedDate &&
          acceptedProposedStartTime
        ? 'accepted_time'
        : '',
      readString(existingJob.schedulingStatus),
    ]),
    scheduledDate: firstNonEmpty([
      readString(after.scheduledDate),
      readString(existingJob.scheduledDate),
    ]),
    scheduledStartTime: firstNonEmpty([
      readString(after.scheduledStartTime),
      readString(existingJob.scheduledStartTime),
    ]),
    estimatedDurationMinutes:
      readNullableInt(after.estimatedDurationMinutes) ??
      readNullableInt(existingJob.estimatedDurationMinutes),
    requestType,
    customerJourneyType,
    fulfilmentType,
    startHandover,
    endHandover,
    allowedStartHandoverOptions: Array.isArray(after.allowedStartHandoverOptions)
      ? after.allowedStartHandoverOptions
      : (Array.isArray(existingJob.allowedStartHandoverOptions)
        ? existingJob.allowedStartHandoverOptions
        : []),
    allowedEndHandoverOptions: Array.isArray(after.allowedEndHandoverOptions)
      ? after.allowedEndHandoverOptions
      : (Array.isArray(existingJob.allowedEndHandoverOptions)
        ? existingJob.allowedEndHandoverOptions
        : []),
    collectionAddress: firstNonEmpty([
      readString(after.collectionAddress),
      readString(existingJob.collectionAddress),
    ]),
    deliveryAddress: firstNonEmpty([
      readString(after.deliveryAddress),
      readString(existingJob.deliveryAddress),
    ]),
    returnAddress: usesBusinessDelivery
      ? ''
      : firstNonEmpty([
        readString(after.returnAddress),
        readString(existingJob.returnAddress),
      ]),
    returnAddressSameAsCollection: usesBusinessDelivery
      ? false
      : readBool(after.returnAddressSameAsCollection) ||
        readBool(existingJob.returnAddressSameAsCollection),
    businessDropOffInstructions: firstNonEmpty([
      readString(after.businessDropOffInstructions),
      readString(existingJob.businessDropOffInstructions),
    ]),
    businessCollectionInstructions: firstNonEmpty([
      readString(after.businessCollectionInstructions),
      readString(existingJob.businessCollectionInstructions),
    ]),
    dropOffDate: firstNonEmpty([
      toIsoStringOrNull(after.dropOffDate),
      toIsoStringOrNull(existingJob.dropOffDate),
    ]) || null,
    dropOffTime: firstNonEmpty([after.dropOffTime, existingJob.dropOffTime]),
    pickUpDate: firstNonEmpty([
      toIsoStringOrNull(after.pickUpDate),
      toIsoStringOrNull(existingJob.pickUpDate),
    ]) || null,
    pickUpTime: firstNonEmpty([after.pickUpTime, existingJob.pickUpTime]),
    collectionDate: firstNonEmpty([
      toIsoStringOrNull(after.collectionDate),
      toIsoStringOrNull(existingJob.collectionDate),
    ]) || null,
    collectionTime: firstNonEmpty([
      after.collectionTime,
      existingJob.collectionTime,
    ]),
    deliveryDate: firstNonEmpty([
      toIsoStringOrNull(after.deliveryDate),
      toIsoStringOrNull(existingJob.deliveryDate),
    ]) || null,
    deliveryTime: firstNonEmpty([
      after.deliveryTime,
      existingJob.deliveryTime,
    ]),
    requestExactPin: requestType === 'dropOffPickupRequest'
      ? false
      : readBool(after.requestExactPin) || readBool(existingJob.requestExactPin),
    requiresExactPinAfterQuoteAccepted,
    locationPending: requestType === 'dropOffPickupRequest'
      ? requiresExactPinAfterQuoteAccepted &&
        (readBool(after.locationPending) || readBool(existingJob.locationPending))
      : readBool(after.locationPending) || readBool(existingJob.locationPending),
    calendarStatus: normalizeCalendarStatus(
      firstNonEmpty([after.calendarStatus, existingJob.calendarStatus]),
    ),
    exactPinSource: firstNonEmpty([
      readString(after.exactPinSource),
      readString(existingJob.exactPinSource),
      'none',
    ]),
    exactPinShared: exactPinAlreadyExists,
    hasExactPin: exactPinAlreadyExists,
    exactPinLatitude,
    exactPinLongitude,
    exactPinLat: exactPinLatitude,
    exactPinLng: exactPinLongitude,
    exactPinNote: firstNonEmpty([
      readString(after.exactPinNote),
      readString(after.responseNote),
      readString(existingJob.exactPinNote),
    ]),
    ...buildQuoteDeclineFieldSet({
      code: readQuoteDeclineFields(after).code || readQuoteDeclineFields(existingJob).code,
      label: readQuoteDeclineFields(after).label || readQuoteDeclineFields(existingJob).label,
      note: readQuoteDeclineFields(after).note || readQuoteDeclineFields(existingJob).note,
      reasonText:
        readQuoteDeclineFields(after).reasonText ||
        readQuoteDeclineFields(existingJob).reasonText,
    }),
    quoteResponseId: quoteId,
    currentQuoteId: firstNonEmpty([
      readString(after.currentQuoteId),
      quoteId,
    ]),
    quoteVersion:
      readNullableInt(after.quoteVersion) ??
      readNullableInt(existingJob.quoteVersion) ??
      1,
    quotePublishKey: firstNonEmpty([
      readString(after.quotePublishKey),
      readString(existingJob.quotePublishKey),
    ]),
    quoteResponseToken,
    quoteResponseLink,
    quoteAmount: readNullableNumber(after.quoteAmount) ?? readNullableNumber(existingJob.quoteAmount),
    quoteSavedAt: toIsoStringOrNull(after.quoteSavedAt) || toIsoStringOrNull(existingJob.quoteSavedAt) || null,
    quoteSentAt: toIsoStringOrNull(after.quoteSentAt) || toIsoStringOrNull(existingJob.quoteSentAt) || null,
    quoteOpenedAt: toIsoStringOrNull(after.quoteOpenedAt) || toIsoStringOrNull(existingJob.quoteOpenedAt) || null,
    quoteAcceptedAt,
    quoteDeclinedAt,
    quoteRespondedAt: quoteRespondedAt || null,
    quoteNotificationSent,
    quoteNotificationSentAt,
    quoteStatus: quoteAccepted ? 'accepted' : (quoteDeclined ? 'declined' : effectiveStatus),
    quoteResponseStatus: quoteAccepted ? 'accepted' : (quoteDeclined ? 'declined' : quoteResponseStatus),
    quoteTimingChoice,
    quoteAccepted,
    quoteDeclined,
    status: effectiveStatus,
    requestStatus: effectiveRequestStatus,
    agreedDateTime,
    confirmedAt,
    updatedAt,
    createdAt,
    deleted: readBool(after.deleted) || readBool(existingJob.deleted),
    archived: readBool(after.archived) || readBool(existingJob.archived),
  };
}

function isPublicJobRequestSyncAck(data) {
  const syncStatus = readString(data.driverJobSyncStatus).toLowerCase();
  return (
    (syncStatus === 'synced' || syncStatus === 'failed') &&
    (toDateOrNull(data.driverJobSyncedAt) ||
      toDateOrNull(data.driverJobSyncCompletedAt) ||
      toDateOrNull(data.driverJobSyncUpdatedAt))
  );
}

function normalizeFileName(value, fallback) {
  const cleaned = readString(value).replace(/[^a-zA-Z0-9._-]/g, '_');
  return cleaned || fallback;
}

function buildBookingPhotoDownloadUrl(bucketName, storagePath, downloadToken) {
  const normalizedBucket = readString(bucketName);
  const normalizedPath = readString(storagePath);
  const normalizedToken = readString(downloadToken);
  if (!normalizedBucket || !normalizedPath || !normalizedToken) {
    return '';
  }
  return `https://firebasestorage.googleapis.com/v0/b/${encodeURIComponent(normalizedBucket)}/o/${encodeURIComponent(normalizedPath)}?alt=media&token=${encodeURIComponent(normalizedToken)}`;
}

function readBookingLinkPhotos(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .slice(0, BOOKING_LINK_MAX_PHOTOS)
    .map((item, index) => {
      const source = item && typeof item === 'object' ? item : {};
      const fileName = normalizeFileName(
        source.fileName,
        `photo_${index + 1}.jpg`,
      );
      const contentType = readString(source.contentType).toLowerCase();
      const dataBase64 = readString(source.dataBase64);
      if (!dataBase64) {
        return null;
      }
      if (!contentType.startsWith('image/')) {
        return null;
      }
      return { fileName, contentType, dataBase64 };
    })
    .filter(Boolean);
}

async function uploadBookingLinkPhotos({ ownerUid, requestId, photos }) {
  if (!Array.isArray(photos) || photos.length === 0) {
    return [];
  }

  const bucket = admin.storage().bucket();
  const bucketName = readString(bucket && bucket.name);
  const uploadedAt = new Date().toISOString();
  const uploaded = [];

  for (let index = 0; index < photos.length; index += 1) {
    const photo = photos[index];
    const fileName = normalizeFileName(
      photo.fileName,
      `photo_${index + 1}.jpg`,
    );
    try {
      const dataBuffer = Buffer.from(photo.dataBase64, 'base64');
      if (!dataBuffer.length || dataBuffer.length > BOOKING_LINK_MAX_PHOTO_BYTES) {
        console.warn(
          `[BookingLinkSubmit] photo skipped ownerUid=${ownerUid} requestId=${requestId} index=${index} fileName=${fileName} reason=invalid_size bytes=${dataBuffer.length}`,
        );
        continue;
      }

      const storagePath =
        `booking_requests/${ownerUid}/${requestId}/photos/${Date.now()}_${index}_${fileName}`;
      const file = bucket.file(storagePath);
      console.info(
        `[BookingLinkSubmit] photo upload attempt ownerUid=${ownerUid} requestId=${requestId} index=${index} fileName=${fileName} path=${storagePath}`,
      );
      const downloadToken = crypto.randomUUID();
      const downloadUrl = buildBookingPhotoDownloadUrl(
        bucketName,
        storagePath,
        downloadToken,
      );
      await withTimeout(
        file.save(dataBuffer, {
          resumable: false,
          contentType: photo.contentType,
          metadata: {
            contentType: photo.contentType,
            cacheControl: 'public,max-age=31536000',
            metadata: {
              firebaseStorageDownloadTokens: downloadToken,
            },
          },
        }),
        BOOKING_LINK_PHOTO_UPLOAD_TIMEOUT_MS,
        `Photo upload timed out for ${fileName}.`,
      );
      if (!downloadUrl) {
        console.warn(
          `[BookingLinkSubmit] photo upload missing_download_url ownerUid=${ownerUid} requestId=${requestId} index=${index} path=${storagePath}`,
        );
        continue;
      }
      console.info(
        `[BookingLinkSubmit] photo download url generated ownerUid=${ownerUid} requestId=${requestId} index=${index} path=${storagePath} url=${downloadUrl}`,
      );
      uploaded.push({
        url: downloadUrl,
        storagePath,
        fileName,
        uploadedAt,
      });
      console.info(
        `[BookingLinkSubmit] photo upload success ownerUid=${ownerUid} requestId=${requestId} index=${index} path=${storagePath}`,
      );
    } catch (error) {
      console.error(
        `[BookingLinkSubmit] photo upload failed ownerUid=${ownerUid} requestId=${requestId} index=${index} fileName=${fileName}`,
        error,
      );
    }
  }

  return uploaded;
}

exports.submitPublicJobRequestReply = onCall(async (request) => {
  const data = request.data || {};
  const requestId = readString(data.requestId);
  if (!requestId) {
    throw new HttpsError('invalid-argument', 'Request ID is required.');
  }

  const requestRef = admin
    .firestore()
    .collection(PUBLIC_JOB_REQUEST_COLLECTION)
    .doc(requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) {
    throw new HttpsError('not-found', 'Request not found.');
  }

  const existing = requestSnap.data() || {};
  const ownerUid = readString(existing.ownerUid);
  const jobId = readString(existing.jobId);
  const status = normalizeJobRequestStatus(
    firstNonEmpty([existing.requestStatus, existing.status]),
  );
  const expiresAt = toDateOrNull(existing.expiresAt);
  if (!ownerUid || !jobId) {
    throw new HttpsError(
      'failed-precondition',
      'Request is missing owner or job details.',
    );
  }
  if (
    status === 'cancelled' ||
    status === 'deleted' ||
    status === 'reply_received'
  ) {
    throw new HttpsError(
      'failed-precondition',
      'This request can no longer be submitted.',
    );
  }
  if (expiresAt && expiresAt.getTime() < Date.now()) {
    throw new HttpsError(
      'failed-precondition',
      'This request has expired.',
    );
  }

  const checklistResponses = normalizeChecklistResponses(data.checklistResponses);
  const customQuestionResponses = normalizeCustomQuestionResponses(
    data.customQuestionResponses,
  );
  const answers = normalizeRequestAnswers(data.answers);
  const additionalNotes = readString(data.additionalNotes);
  const exactPinLat = readNullableNumber(
    firstNonEmpty([data.exactPinLat, data.exactPinLatitude]),
  );
  const exactPinLng = readNullableNumber(
    firstNonEmpty([data.exactPinLng, data.exactPinLongitude]),
  );
  const hasExactPin =
    readBool(data.hasExactPin) ||
    (Number.isFinite(exactPinLat) && Number.isFinite(exactPinLng));
  const requestPhotos = readBool(existing.requestPhotos);
  const requestedPhotos = requestPhotos ? readBookingLinkPhotos(data.photos) : [];
  let uploadedPhotos = [];
  let photoUploadFailed = false;

  if (requestPhotos && requestedPhotos.length > 0) {
    try {
      uploadedPhotos = await uploadBookingLinkPhotos({
        ownerUid,
        requestId,
        photos: requestedPhotos,
      });
    } catch (error) {
      photoUploadFailed = true;
      console.error(
        `[PublicJobRequestReply] photo upload failed requestId=${requestId} ownerUid=${ownerUid}`,
        error,
      );
    }
  }
  if (
    requestPhotos &&
    requestedPhotos.length > 0 &&
    uploadedPhotos.length < requestedPhotos.length
  ) {
    photoUploadFailed = true;
  }

  const compiledNotes = [
    additionalNotes,
    photoUploadFailed ? 'Photos requested, upload failed' : '',
  ].filter(Boolean).join('\n');

  const update = {
    status: 'reply_received',
    requestStatus: 'reply_received',
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    customerSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    requestSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    replyReceivedAt: admin.firestore.FieldValue.serverTimestamp(),
    hasReply: true,
    hasExactPin,
    exactPinShared: hasExactPin,
    checklistResponses,
    customQuestionResponses,
    answers,
    additionalNotes: compiledNotes,
    exactPinLatitude: hasExactPin ? exactPinLat : null,
    exactPinLongitude: hasExactPin ? exactPinLng : null,
    exactPinLat: hasExactPin ? exactPinLat : null,
    exactPinLng: hasExactPin ? exactPinLng : null,
    exactPinShareSource: hasExactPin
      ? firstNonEmpty([data.exactPinShareSource, data.exactPinSource, 'none'])
      : 'none',
    exactPinSource: hasExactPin
      ? firstNonEmpty([data.exactPinSource, data.exactPinShareSource, 'none'])
      : 'none',
    exactPinNote: hasExactPin ? readString(data.exactPinNote) : '',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    photos: uploadedPhotos,
    photoUploadFailed,
  };

  await requestRef.set(update, { merge: true });
  return {
    requestId,
    ownerUid,
    jobId,
    photoUploadFailed,
    photosUploadedCount: uploadedPhotos.length,
    requestedPhotoCount: requestedPhotos.length,
  };
});

async function runPublicQuoteResponseAction({ data, action }) {
  const target = await resolvePublicQuoteTarget({
    quoteResponseId: data.quoteResponseId,
    quoteResponseToken: data.quoteResponseToken,
  });
  const driverContext = await resolveLinkedDriverJobContext({
    quoteId: target.quoteId,
    quoteData: target.quoteData,
    tokenData: target.tokenData,
  });
  const docPath = `${PUBLIC_QUOTE_RESPONSE_COLLECTION}/${target.quoteId}`;
  let responseResult = null;
  await admin.firestore().runTransaction(async (transaction) => {
    const liveQuoteSnapshot = await transaction.get(target.quoteRef);
    const liveJobSnapshot = await transaction.get(driverContext.jobRef);
    if (!liveQuoteSnapshot.exists) {
      throw new HttpsError('not-found', 'Quote not found.');
    }
    const liveQuoteData = liveQuoteSnapshot.data() || {};
    const liveJobData = liveJobSnapshot.exists
      ? liveJobSnapshot.data() || {}
      : {};
    assertPublicQuoteActionAllowed(liveQuoteData);
    assertPublicQuoteIsCurrent({
      quoteId: target.quoteId,
      quoteData: liveQuoteData,
      jobData: liveJobData,
    });

    const linkedRequestId = firstNonEmpty([
      driverContext.requestId,
      readString(liveJobData.requestId),
      readString(liveQuoteData.requestId),
    ]);
    if (publicQuoteActionAlreadyApplied(liveQuoteData, action)) {
      responseResult = {
        ok: true,
        idempotent: true,
        action,
        quoteId: target.quoteId,
        docPath,
        driverDocPath: driverContext.jobPath,
        linkedRequestId,
        payloadKeys: [],
        driverPayloadKeys: [],
        requestUpdateKeys: [],
      };
      return;
    }

    assertPublicQuoteActionAllowed(liveQuoteData, {
      requirePendingResponse: true,
    });
    const payload = buildQuoteResponseWritePayload({
      quoteData: liveQuoteData,
      action,
      data,
    });
    const driverPayload = buildDriverJobQuoteResponsePayload({
      quoteData: liveQuoteData,
      existingJob: liveJobData,
      action,
      quoteId: target.quoteId,
      ownerUid: driverContext.ownerUid,
      jobId: driverContext.jobId,
      requestId: linkedRequestId,
      data,
    });
    const requestUpdate = linkedRequestId
      ? buildLinkedRequestQuoteStateUpdate({
        driverPayload,
        includeExactPin: true,
        includeUpdatedAt: true,
      })
      : null;
    console.info('[PublicQuoteResponseAction] transaction write start', {
      action,
      quoteId: target.quoteId,
      quoteToken: target.token,
      docPath,
      driverDocPath: driverContext.jobPath,
      projectId: admin.app().options.projectId || '',
      publicPayloadKeys: Object.keys(payload),
      driverPayloadKeys: Object.keys(driverPayload),
      linkedRequestId,
      requestUpdateKeys: requestUpdate ? Object.keys(requestUpdate) : [],
    });
    transaction.set(target.quoteRef, payload, { merge: true });
    transaction.set(driverContext.jobRef, driverPayload, { merge: true });
    if (linkedRequestId && requestUpdate) {
      transaction.set(
        admin
          .firestore()
          .collection(PUBLIC_JOB_REQUEST_COLLECTION)
          .doc(linkedRequestId),
        requestUpdate,
        { merge: true },
      );
      transaction.set(
        admin
          .firestore()
          .collection(USERS_COLLECTION)
          .doc(driverContext.ownerUid)
          .collection(LEGACY_JOB_REQUEST_COLLECTION)
          .doc(linkedRequestId),
        requestUpdate,
        { merge: true },
      );
    }
    responseResult = {
      ok: true,
      idempotent: false,
      action,
      quoteId: target.quoteId,
      docPath,
      driverDocPath: driverContext.jobPath,
      linkedRequestId,
      payloadKeys: Object.keys(payload),
      driverPayloadKeys: Object.keys(driverPayload),
      requestUpdateKeys: requestUpdate ? Object.keys(requestUpdate) : [],
    };
  });
  console.info('[PublicQuoteResponseAction] write success', {
    action,
    docPath,
    quoteId: target.quoteId,
    driverDocPath: driverContext.jobPath,
    linkedRequestId: responseResult && responseResult.linkedRequestId,
    idempotent: responseResult && responseResult.idempotent === true,
  });
  return responseResult;
}

exports.acceptQuoteProposedTime = onCall(async (request) => {
  return runPublicQuoteResponseAction({
    data: request.data || {},
    action: 'accept_proposed_time',
  });
});

exports.acceptQuoteArrangeTime = onCall(async (request) => {
  return runPublicQuoteResponseAction({
    data: request.data || {},
    action: 'accept_arrange_time',
  });
});

exports.declineQuote = onCall(async (request) => {
  return runPublicQuoteResponseAction({
    data: request.data || {},
    action: 'decline_quote',
  });
});

exports.submitExactLocation = onCall(async (request) => {
  const data = request.data || {};
  const target = await resolvePublicQuoteTarget({
    quoteResponseId: data.quoteResponseId,
    quoteResponseToken: data.quoteResponseToken,
  });
  assertPublicQuoteActionAllowed(target.quoteData, {
    requireAcceptedQuote: true,
  });
  const payload = buildQuoteExactLocationPayload({
    quoteData: target.quoteData,
    data,
  });
  const driverContext = await resolveLinkedDriverJobContext({
    quoteId: target.quoteId,
    quoteData: target.quoteData,
    tokenData: target.tokenData,
  });
  const driverPayload = buildDriverJobExactLocationPayload({
    quoteData: target.quoteData,
    existingJob: driverContext.existingJob,
    exactLocationPayload: payload,
    quoteId: target.quoteId,
    ownerUid: driverContext.ownerUid,
    jobId: driverContext.jobId,
    requestId: driverContext.requestId,
  });
  const docPath = `${PUBLIC_QUOTE_RESPONSE_COLLECTION}/${target.quoteId}`;
  const linkedRequestId = firstNonEmpty([
    driverContext.requestId,
    readString(driverContext.existingJob.requestId),
    readString(target.quoteData.requestId),
  ]);
  const requestUpdate = linkedRequestId
    ? buildLinkedRequestQuoteStateUpdate({
      driverPayload,
      includeExactPin: true,
      includeUpdatedAt: true,
    })
    : null;
  console.info('[PublicQuoteExactLocation] write start', {
    quoteId: target.quoteId,
    quoteToken: target.token,
    docPath,
    driverDocPath: driverContext.jobPath,
    projectId: admin.app().options.projectId || '',
    payloadKeys: Object.keys(payload),
    driverPayloadKeys: Object.keys(driverPayload),
    linkedRequestId,
    requestUpdateKeys: requestUpdate ? Object.keys(requestUpdate) : [],
    payload,
    driverPayload,
    requestUpdate,
  });
  const writes = [
    target.quoteRef.set(payload, { merge: true }),
    driverContext.jobRef.set(driverPayload, { merge: true }),
  ];
  if (linkedRequestId && requestUpdate) {
    writes.push(
      admin
        .firestore()
        .collection(PUBLIC_JOB_REQUEST_COLLECTION)
        .doc(linkedRequestId)
        .set(requestUpdate, { merge: true }),
      admin
        .firestore()
        .collection(USERS_COLLECTION)
        .doc(driverContext.ownerUid)
        .collection(LEGACY_JOB_REQUEST_COLLECTION)
        .doc(linkedRequestId)
        .set(requestUpdate, { merge: true }),
    );
  }
  await Promise.all(writes);
  console.info('[PublicQuoteExactLocation] write success', {
    docPath,
    quoteId: target.quoteId,
    driverDocPath: driverContext.jobPath,
    linkedRequestId,
  });
  return {
    ok: true,
    quoteId: target.quoteId,
    docPath,
    driverDocPath: driverContext.jobPath,
    linkedRequestId,
    payloadKeys: Object.keys(payload),
    driverPayloadKeys: Object.keys(driverPayload),
    requestUpdateKeys: requestUpdate ? Object.keys(requestUpdate) : [],
    readyForCalendar: payload.readyForCalendar === true,
  };
});

function buildBookingRequestNotificationBody({ customerName, serviceName }) {
  const cleanedCustomerName = readString(customerName);
  const cleanedServiceName = readString(serviceName);
  if (cleanedCustomerName && cleanedServiceName) {
    return `${cleanedCustomerName} sent a ${cleanedServiceName} request`;
  }
  if (!cleanedCustomerName && cleanedServiceName) {
    return `New ${cleanedServiceName} request received`;
  }
  return 'New booking request received';
}

function buildCustomerReplyNotificationBody({
  customerName,
  jobTitle,
  hasExactPin,
}) {
  const cleanedCustomerName = readString(customerName);
  const cleanedJobTitle = readString(jobTitle);
  if (hasExactPin) {
    if (cleanedCustomerName) {
      return `Exact pin received for ${cleanedCustomerName}`;
    }
    return 'Exact pin received';
  }
  if (cleanedCustomerName && cleanedJobTitle) {
    return `${cleanedCustomerName} replied about ${cleanedJobTitle}`;
  }
  if (cleanedJobTitle) {
    return `Customer replied to ${cleanedJobTitle}`;
  }
  if (cleanedCustomerName) {
    return `${cleanedCustomerName} replied to your job request`;
  }
  return 'Customer replied to your job request';
}

async function sendBookingRequestReceivedNotification({
  ownerUid,
  requestId,
  jobId,
  customerName,
  serviceName,
  customerJourneyType,
}) {
  const normalizedOwnerUid = readString(ownerUid);
  const normalizedRequestId = readString(requestId);
  if (!normalizedOwnerUid || !normalizedRequestId) {
    console.warn(
      `[BookingLinkSubmit] push skipped ownerUid=${normalizedOwnerUid || '(missing)'} requestId=${normalizedRequestId || '(missing)'} reason=missing_reference`,
    );
    return;
  }

  const journeyType = normalizeCustomerJourneyType(customerJourneyType);
  const notificationTitle = journeyType === 'order'
    ? 'New order'
    : (journeyType === 'booking' ? 'New booking request' : 'New quote request');
  const notificationBody = buildBookingRequestNotificationBody({
    customerName,
    serviceName,
  });
  const payloadData = {
    type: BOOKING_REQUEST_RECEIVED_NOTIFICATION_TYPE,
    requestId: normalizedRequestId,
    ownerUid: normalizedOwnerUid,
    serviceName: readString(serviceName),
    jobId: readString(jobId),
    customerName: readString(customerName),
    customerJourneyType: journeyType,
  };

  console.info(
    `[BookingLinkSubmit] push start ownerUid=${normalizedOwnerUid} requestId=${normalizedRequestId} serviceName=${readString(serviceName) || '(none)'}`,
  );

  const tokenRecords = await loadTokens(normalizedOwnerUid);
  console.info(
    `[BookingLinkSubmit] push tokens ownerUid=${normalizedOwnerUid} tokenCount=${tokenRecords.length}`,
  );
  if (tokenRecords.length === 0) {
    console.warn(
      `[BookingLinkSubmit] push skipped ownerUid=${normalizedOwnerUid} requestId=${normalizedRequestId} reason=no_tokens`,
    );
    return;
  }

  const uniqueRecords = dedupeTokenRecords(tokenRecords);
  const chunks = chunk(uniqueRecords, 500);
  let successCount = 0;
  let failureCount = 0;
  for (const records of chunks) {
    const enabledRecords = records.filter((record) => record.enabled !== false);
    const tokens = enabledRecords.map((record) => record.token);
    if (tokens.length === 0) {
      continue;
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: payloadData,
    });
    successCount += response.successCount || 0;
    failureCount += response.failureCount || 0;
    await pruneInvalidTokens(
      normalizedOwnerUid,
      enabledRecords,
      response.responses,
    );
  }

  console.info(
    `[BookingLinkSubmit] push complete ownerUid=${normalizedOwnerUid} requestId=${normalizedRequestId} successCount=${successCount} failureCount=${failureCount}`,
  );
}

exports.submitBookingLinkRequest = onCall(async (request) => {
  console.info('[BookingLinkSubmit] callable request start');
  const data = request.data || {};
  let ownerUid = readString(data.ownerUid);
  const publicConfigId = firstNonEmpty([
    data.publicConfigId,
    data.bookingLinkId,
    data.ownerUid,
  ]);
  const serviceId = readString(data.serviceId);
  const clientSubmissionId = readString(data.clientSubmissionId)
    .replace(/[^a-zA-Z0-9_-]/g, '')
    .slice(0, 128);
  const requestedServiceName = readString(data.serviceName);
  const customerName = readString(data.customerName);
  const phoneNumber = readString(data.phoneNumber);
  const customerEmail = readString(data.customerEmail);
  const address = readString(data.address);
  const postcode = readString(data.postcode);
  const requestedRequestTypeRaw = readString(data.requestType);
  const supportsStructuredRequestFlow = requestedRequestTypeRaw.length > 0;
  const requestedRequestType = normalizeCustomerRequestType(
    requestedRequestTypeRaw,
  );
  let fulfilmentType = normalizeFulfilmentType(data.fulfilmentType);
  let pickupAddress = readString(data.pickupAddress);
  let deliveryAddress = readString(data.deliveryAddress);
  let collectionAddress = readString(data.collectionAddress);
  let returnAddress = readString(data.returnAddress);
  const returnAddressSameAsCollection = readBool(
    data.returnAddressSameAsCollection,
  );
  let dropOffDate = toDateOrNull(firstNonEmpty([
    data.collectionDate,
    data.dropOffDate,
  ]));
  let dropOffTime = readString(firstNonEmpty([
    data.collectionTime,
    data.dropOffTime,
  ]));
  let pickUpDate = toDateOrNull(firstNonEmpty([
    data.deliveryDate,
    data.pickUpDate,
  ]));
  let pickUpTime = readString(firstNonEmpty([
    data.deliveryTime,
    data.pickUpTime,
  ]));
  let additionalNotes = readString(data.additionalNotes);
  const preferredDateInput = firstNonEmpty([
    data.preferredDate,
    data.preferredDateAt,
  ]);
  let preferredDate = toDateOrNull(preferredDateInput);
  let preferredTimeWindow = normalizePreferredTimeWindow(
    data.preferredTimeWindow || data.preferredWindow,
  );
  let preferredIsFlexible =
    readBool(data.preferredIsFlexible) || readBool(data.timingFlexible);
  let preferredTimingNote = readString(
    firstNonEmpty([data.preferredTimingNote, data.timingNote]),
  );
  console.info(
    `[BookingLinkSubmit] preferred timing received ownerUid=${ownerUid || '(missing)'} serviceId=${serviceId || '(missing)'} preferredDateRaw=${preferredDateInput || '(none)'} preferredDateIso=${preferredDate ? preferredDate.toISOString() : '(none)'} preferredTimeWindow=${preferredTimeWindow || '(none)'} preferredIsFlexible=${preferredIsFlexible} preferredTimingNote=${preferredTimingNote || '(none)'}`,
  );
  const estimatedDurationMinutes = readNullableInt(
    data.estimatedDurationMinutes,
  );
  const photoFileNames = Array.isArray(data.photoFileNames)
    ? data.photoFileNames.map((item) => readString(item)).filter(Boolean)
    : [];
  const requestedPhotos = readBookingLinkPhotos(data.photos);
  const answers = Array.isArray(data.answers)
    ? data.answers
        .map((item) => {
          const source = item && typeof item === 'object' ? item : {};
          const questionId = readString(source.questionId);
          const libraryQuestionId = readString(source.libraryQuestionId);
          const questionText = readString(source.questionText);
          const answerType = readString(source.answerType || source.type);
          const category = readString(source.category);
          const answerValue = readString(source.answerValue || source.answer);
          const order = readNullableInt(source.order);
          if (!questionId || !questionText || !answerValue) {
            return null;
          }
          return {
            questionId,
            libraryQuestionId,
            questionText,
            answerType,
            category,
            answerValue,
            order,
          };
        })
        .filter(Boolean)
    : [];

  console.info(
    `[BookingLinkSubmit] tapped ownerUid=${ownerUid || '(missing)'} serviceId=${serviceId || '(missing)'} customerName=${customerName || '(missing)'} phone=${phoneNumber || '(missing)'} answersCollected=${answers.length} selectedPhotoCount=${requestedPhotos.length}`,
  );

  if (!publicConfigId || !serviceId) {
    throw new HttpsError(
      'invalid-argument',
      'Booking Link owner and selected service are required.',
    );
  }
  if (!customerName) {
    throw new HttpsError('invalid-argument', 'Please enter your full name.');
  }
  const bookingLinkSnap = await admin
    .firestore()
    .collection(PUBLIC_BOOKING_LINK_COLLECTION)
    .doc(publicConfigId)
    .get();
  if (!bookingLinkSnap.exists) {
    throw new HttpsError('not-found', 'Booking Link not found.');
  }

  const bookingLink = bookingLinkSnap.data() || {};
  ownerUid = firstNonEmpty([bookingLink.ownerUid, ownerUid, publicConfigId]);
  if (bookingLink.isActive === false) {
    throw new HttpsError('failed-precondition', 'Booking Link is inactive.');
  }
  const businessProfileId = firstNonEmpty([
    bookingLink.businessProfileId,
    data.businessProfileId,
  ]);

  const services = Array.isArray(bookingLink.services) ? bookingLink.services : [];
  const selectedService = services.find((item) => readString(item && item.id) === serviceId);
  if (!selectedService) {
    throw new HttpsError('not-found', 'Service not found.');
  }
  if (
    selectedService.showPhoneNumber !== false &&
    selectedService.requirePhoneNumber !== false &&
    !phoneNumber
  ) {
    throw new HttpsError('invalid-argument', 'Please enter your phone number.');
  }
  if (
    selectedService.showEmailAddress !== false &&
    selectedService.requireEmailAddress === true &&
    !customerEmail
  ) {
    throw new HttpsError('invalid-argument', 'Please enter your email address.');
  }
  const photoSettings =
    selectedService.builtInQuestionSettings &&
    typeof selectedService.builtInQuestionSettings === 'object'
      ? selectedService.builtInQuestionSettings.photos
      : null;
  if (
    readBool(selectedService.requestPhotos) &&
    readBool(photoSettings && photoSettings.required) &&
    requestedPhotos.length === 0
  ) {
    throw new HttpsError('invalid-argument', 'Please add at least one photo.');
  }

  const serviceName =
    readString(selectedService.name) ||
    requestedServiceName ||
    'Service request';
  const legacyRequestType = normalizeCustomerRequestType(
    selectedService.requestType,
    requestedRequestType,
  );
  const serviceFlow = normalizeServiceFlow(
    selectedService.serviceFlow,
    legacyRequestType,
  );
  const requestType = requestTypeForServiceFlow(serviceFlow);
  const legacyJourney = customerJourneyForLegacyRequestType(legacyRequestType);
  const customerJourneyType = normalizeCustomerJourneyType(
    selectedService.customerJourneyType,
    legacyJourney,
  );
  const legacySupportsHandover =
    requestType === 'dropOffPickupRequest' ||
    requestType === 'pickupDeliveryRequest';
  const handoverCapabilityKeys = [
    'allowCustomerDropOff',
    'allowBusinessCollection',
    'allowCustomerCollection',
    'allowBusinessReturn',
    'allowBusinessDelivery',
  ];
  const hasHandoverCapabilityFlags = handoverCapabilityKeys.some(
    (key) => Object.prototype.hasOwnProperty.call(selectedService, key),
  );
  const legacyHandoverMode = readString(
    selectedService.handoverMode || selectedService.transportMode,
  ).toLowerCase();
  const legacyBusinessMoves =
    legacyHandoverMode === 'businesscollectreturn' ||
    legacyHandoverMode === 'business_collect_return';
  const legacyCustomerChooses =
    legacyHandoverMode === 'customerchooses' ||
    legacyHandoverMode === 'customer_chooses';
  const fallbackStartHandover =
    requestType === 'pickupDeliveryRequest' || legacyBusinessMoves
    ? 'businessCollects'
    : 'customerDropsOff';
  const fallbackEndHandover =
    requestType === 'pickupDeliveryRequest' || legacyBusinessMoves
    ? 'businessReturns'
    : 'customerCollects';
  const configuredStartHandover = normalizeStartHandover(
    selectedService.startHandover,
    fallbackStartHandover,
  );
  const configuredEndHandover = normalizeEndHandover(
    selectedService.endHandover,
    fallbackEndHandover,
  );
  const allowedStartHandoverOptions = hasHandoverCapabilityFlags
    ? [
      ...(readBool(selectedService.allowCustomerDropOff)
        ? ['customerDropsOff']
        : []),
      ...(readBool(selectedService.allowBusinessCollection)
        ? ['businessCollects']
        : []),
    ]
    : (legacySupportsHandover
      ? normalizeHandoverOptions(
        Array.isArray(selectedService.allowedStartHandoverOptions)
          ? selectedService.allowedStartHandoverOptions
          : (legacyCustomerChooses
            ? ['customerDropsOff', 'businessCollects']
            : []),
        ['customerDropsOff', 'businessCollects'],
        configuredStartHandover,
      )
      : []);
  const allowedEndHandoverOptions = hasHandoverCapabilityFlags
    ? [
      ...(readBool(selectedService.allowCustomerCollection)
        ? ['customerCollects']
        : []),
      ...(readBool(selectedService.allowBusinessReturn)
        ? ['businessReturns']
        : []),
      ...(readBool(selectedService.allowBusinessDelivery)
        ? ['businessDelivers']
        : []),
    ]
    : (legacySupportsHandover
      ? normalizeHandoverOptions(
        Array.isArray(selectedService.allowedEndHandoverOptions)
          ? selectedService.allowedEndHandoverOptions
          : (legacyCustomerChooses
            ? ['customerCollects', 'businessReturns']
            : []),
        ['customerCollects', 'businessReturns', 'businessDelivers'],
        configuredEndHandover,
      )
      : []);
  const supportsHandover =
    allowedStartHandoverOptions.length > 0 &&
    allowedEndHandoverOptions.length > 0;
  const requestedStartHandover = readString(data.startHandover);
  const requestedEndHandover = readString(data.endHandover);
  if (
    supportsHandover &&
    requestedStartHandover &&
    !allowedStartHandoverOptions.includes(requestedStartHandover)
  ) {
    throw new HttpsError('invalid-argument', 'Start handover is not available.');
  }
  if (
    supportsHandover &&
    requestedEndHandover &&
    !allowedEndHandoverOptions.includes(requestedEndHandover)
  ) {
    throw new HttpsError('invalid-argument', 'End handover is not available.');
  }
  const startHandover = supportsHandover
    ? (requestedStartHandover ||
      (allowedStartHandoverOptions.includes(configuredStartHandover)
        ? configuredStartHandover
        : allowedStartHandoverOptions[0]))
    : '';
  const endHandover = supportsHandover
    ? (requestedEndHandover ||
      (allowedEndHandoverOptions.includes(configuredEndHandover)
        ? configuredEndHandover
        : allowedEndHandoverOptions[0]))
    : '';
  if (supportsHandover && !collectionAddress) {
    collectionAddress = pickupAddress;
  }
  if (
    supportsHandover &&
    endHandover === 'businessReturns' &&
    !returnAddress
  ) {
    returnAddress = deliveryAddress;
  }
  if (
    returnAddressSameAsCollection &&
    startHandover === 'businessCollects' &&
    endHandover === 'businessReturns'
  ) {
    returnAddress = collectionAddress;
  }
  if (supportsHandover && endHandover === 'businessDelivers') {
    pickupAddress = collectionAddress;
    returnAddress = '';
  }
  const requestFlowOptions = normalizeRequestFlowOptions(
    selectedService.requestFlowOptions,
    requestType,
  );
  if (supportsStructuredRequestFlow) {
    if (
      requestType !== 'orderRequest' ||
      !requestFlowOptions.showFulfilmentChoice
    ) {
      fulfilmentType = '';
    }
    if (
      (supportsHandover && endHandover !== 'businessDelivers') ||
      requestType !== 'pickupDeliveryRequest' ||
      !requestFlowOptions.showPickupAddress
    ) {
      pickupAddress = '';
    }
    const keepsDeliveryAddress =
      (supportsHandover && endHandover === 'businessDelivers') ||
      (!supportsHandover &&
      ((requestType === 'orderRequest' &&
        requestFlowOptions.showFulfilmentChoice &&
        fulfilmentType === 'delivery') ||
      (requestType === 'pickupDeliveryRequest' &&
        requestFlowOptions.showDeliveryAddress)));
    if (!keepsDeliveryAddress) {
      deliveryAddress = '';
    }
    if (!supportsHandover && !requestFlowOptions.showDropOffDate) {
      dropOffDate = null;
    }
    if (!supportsHandover && !requestFlowOptions.showDropOffTime) {
      dropOffTime = '';
    }
    if (!supportsHandover && !requestFlowOptions.showPickUpDate) {
      pickUpDate = null;
    }
    if (!supportsHandover && !requestFlowOptions.showPickUpTime) {
      pickUpTime = '';
    }
    if (!requestFlowOptions.askPreferredDate) {
      preferredDate = null;
    }
    if (!requestFlowOptions.askPreferredTime) {
      preferredTimeWindow = '';
    }
    if (
      !requestFlowOptions.askPreferredDate &&
      !requestFlowOptions.askPreferredTime
    ) {
      preferredIsFlexible = false;
      preferredTimingNote = '';
    }
    if (!requestFlowOptions.showNotes) {
      additionalNotes = '';
    }
  }
  const requireAddress = readBool(selectedService.requireAddress);
  const requestPhotos = readBool(selectedService.requestPhotos);
  const configuredExactPinAfterQuoteAccepted =
    readBool(selectedService.requestExactPinAfterQuoteAccepted) ||
    readBool(selectedService.requiresExactPinAfterQuoteAccepted);
  const requiresExactPinAfterQuoteAccepted =
    shouldRequireExactPinAfterQuoteAccepted({
      configured: configuredExactPinAfterQuoteAccepted,
      requestType,
      fulfilmentType,
    });
  const rawLinkedQuestions = Array.isArray(selectedService.linkedQuestions)
    ? selectedService.linkedQuestions
    : [];
  const linkedQuestions = rawLinkedQuestions;
  const linkedQuestionIndex = new Map(
    linkedQuestions
      .map((item, index) => [readString(item && item.id), index])
      .filter(([id]) => Boolean(id)),
  );

  console.info(
    `[BookingLinkSubmit] ownerUid=${ownerUid} serviceId=${serviceId} serviceName=${serviceName} requestType=${requestType} requireAddress=${requireAddress} requiresExactPinAfterQuoteAccepted=${requiresExactPinAfterQuoteAccepted} linkedQuestions=${linkedQuestions.length}`,
  );
  console.info(
    `[BookingLinkSubmit] linkedQuestions loaded serviceId=${serviceId} ids=${linkedQuestions.map((item) => readString(item && item.id)).filter(Boolean).join(', ') || '(none)'}`,
  );
  answers.forEach((item, index) => {
    console.info(
      `[BookingLinkSubmit] answer collected index=${index} questionId=${item.questionId} questionText=${item.questionText} type=${item.answerType || '(none)'} category=${item.category || '(none)'} order=${item.order == null ? '(none)' : item.order} answer=${item.answerValue}`,
    );
  });

  const addressValidationError = bookingLinkAddressValidationError({
    requireAddress,
    supportsStructuredRequestFlow,
    requestType,
    requestFlowOptions,
    supportsHandover,
    startHandover,
    endHandover,
    address,
    postcode,
    fulfilmentType,
    pickupAddress,
    deliveryAddress,
    collectionAddress,
    returnAddress,
  });
  if (addressValidationError) {
    console.warn(
      `[BookingLinkSubmit] validation failed ownerUid=${ownerUid} serviceId=${serviceId} reason=${addressValidationError.code}`,
    );
    throw new HttpsError('invalid-argument', addressValidationError.message);
  }
  if (
    !supportsHandover &&
    supportsStructuredRequestFlow &&
    requestType === 'dropOffPickupRequest' &&
    requestFlowOptions.showDropOffDate &&
    !dropOffDate
  ) {
    throw new HttpsError('invalid-argument', 'Drop-off date is required.');
  }
  if (
    !supportsHandover &&
    supportsStructuredRequestFlow &&
    requestType === 'dropOffPickupRequest' &&
    requestFlowOptions.showPickUpDate &&
    !pickUpDate
  ) {
    throw new HttpsError('invalid-argument', 'Pick-up date is required.');
  }
  if (supportsHandover && !dropOffDate) {
    throw new HttpsError(
      'invalid-argument',
      endHandover === 'businessDelivers'
        ? 'Preferred collection date is required.'
        : 'Start handover date is required.',
    );
  }
  if (supportsHandover && !pickUpDate) {
    throw new HttpsError(
      'invalid-argument',
      endHandover === 'businessDelivers'
        ? 'Preferred delivery date is required.'
        : 'End handover date is required.',
    );
  }
  if (
    dropOffDate &&
    pickUpDate &&
    pickUpDate.getTime() < dropOffDate.getTime()
  ) {
    throw new HttpsError(
      'invalid-argument',
      endHandover === 'businessDelivers'
        ? 'Preferred delivery must not be earlier than collection.'
        : 'End handover date must be on or after the start handover date.',
    );
  }
  if (supportsHandover && endHandover === 'businessDelivers') {
    if (!dropOffTime) {
      throw new HttpsError(
        'invalid-argument',
        'Preferred collection time is required.',
      );
    }
    if (!pickUpTime) {
      throw new HttpsError(
        'invalid-argument',
        'Preferred delivery time or delivery window is required.',
      );
    }
    const sameCalendarDate =
      dropOffDate &&
      pickUpDate &&
      dropOffDate.toISOString().slice(0, 10) ===
        pickUpDate.toISOString().slice(0, 10);
    const isSameDayService =
      readString(selectedService.starterTemplateId) ===
      'courier_same_day_delivery';
    if (isSameDayService && !sameCalendarDate) {
      throw new HttpsError(
        'invalid-argument',
        'Same-day delivery must use the collection date.',
      );
    }
    if (sameCalendarDate) {
      const collectionMinutes = timeOfDayMinutes(dropOffTime);
      const deliveryMinutes = timeOfDayMinutes(pickUpTime);
      if (
        collectionMinutes != null &&
        deliveryMinutes != null &&
        (deliveryMinutes < collectionMinutes ||
          (isSameDayService && deliveryMinutes === collectionMinutes))
      ) {
        throw new HttpsError(
          'invalid-argument',
          isSameDayService
            ? 'Preferred delivery time must be later than collection time.'
            : 'Preferred delivery must not be earlier than collection.',
        );
      }
    }
  }
  for (const [label, date] of [
    [supportsHandover ? 'Start handover' : 'Drop-off', dropOffDate],
    [supportsHandover ? 'End handover' : 'Pick-up', pickUpDate],
  ]) {
    const dateValidationMessage = validatePreferredBookingWindow({
      preferredDate: date,
      preferredTimeWindow: 'anytime',
      preferredIsFlexible: true,
      now: new Date(),
    });
    if (dateValidationMessage) {
      throw new HttpsError(
        'invalid-argument',
        `${label} date must be today or in the future.`,
      );
    }
  }

  const preferredTimingValidationMessage = validatePreferredBookingWindow({
    preferredDate,
    preferredTimeWindow,
    preferredIsFlexible,
    now: new Date(),
  });
  if (preferredTimingValidationMessage) {
    throw new HttpsError('invalid-argument', preferredTimingValidationMessage);
  }

  const allowedQuestionIds = new Set(
    linkedQuestions.map((item) => readString(item && item.id)).filter(Boolean),
  );
  const normalizedAnswers = answers
    .filter((item) => allowedQuestionIds.has(item.questionId))
    .map((item) => {
      const matchedQuestion =
        linkedQuestions.find(
          (question) => readString(question && question.id) === item.questionId,
        ) || {};
      const matchedOrder = linkedQuestionIndex.get(item.questionId);
      return {
        questionId: item.questionId,
        questionText:
          item.questionText || readString(matchedQuestion.questionText),
        answerType: item.answerType || readString(matchedQuestion.answerType),
        category: item.category || readString(matchedQuestion.category),
        answerValue: item.answerValue,
        order: item.order == null ? matchedOrder ?? null : item.order,
      };
    })
    .filter((item) => item.questionId && item.questionText && item.answerValue)
    .sort((a, b) => {
      const left = a.order == null ? Number.MAX_SAFE_INTEGER : a.order;
      const right = b.order == null ? Number.MAX_SAFE_INTEGER : b.order;
      return left - right;
    })
    .map((item, index) => ({
      ...item,
      order: item.order == null ? index : item.order,
    }));
  normalizedAnswers.forEach((item, index) => {
    console.info(
      `[BookingLinkSubmit] answer normalized index=${index} questionId=${item.questionId} order=${item.order} questionText=${item.questionText} answer=${item.answerValue}`,
    );
  });
  const normalizedAnswerQuestionIds = new Set(
    normalizedAnswers.map((item) => readString(item.questionId)).filter(Boolean),
  );
  const missingLinkedQuestions = linkedQuestions
    .filter((item) => !readBool(item && item.optional))
    .map((item) => ({
      id: readString(item && item.id),
      questionText: readString(item && item.questionText),
    }))
    .filter((item) => item.id)
    .filter((item) => !normalizedAnswerQuestionIds.has(item.id));
  if (missingLinkedQuestions.length > 0) {
    const firstMissing = missingLinkedQuestions[0];
    console.warn(
      `[BookingLinkSubmit] validation failed ownerUid=${ownerUid} serviceId=${serviceId} reason=missing_linked_question_answer questionId=${firstMissing.id} questionText=${firstMissing.questionText || '(none)'}`,
    );
    throw new HttpsError(
      'invalid-argument',
      firstMissing.questionText
        ? `Please answer: ${firstMissing.questionText}`
        : 'Please answer all linked questions before submitting.',
    );
  }
  console.info(
    `[BookingLinkSubmit] validation passed ownerUid=${ownerUid} serviceId=${serviceId} answersCount=${normalizedAnswers.length}`,
  );

  const now = new Date();
  const requestId =
    bookingLinkRequestDocumentId(ownerUid, clientSubmissionId) ||
    admin.firestore().collection(PUBLIC_JOB_REQUEST_COLLECTION).doc().id;
  const jobId = `booking_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  const expiresAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const addressSummary = supportsHandover
    ? [
        startHandover === 'businessCollects' ? collectionAddress : '',
        endHandover === 'businessReturns'
          ? returnAddress
          : (endHandover === 'businessDelivers' ? deliveryAddress : ''),
      ].filter(Boolean).join(' → ')
    : supportsStructuredRequestFlow && requestType === 'pickupDeliveryRequest'
      ? [pickupAddress, deliveryAddress].filter(Boolean).join(' → ')
      : supportsStructuredRequestFlow &&
          requestType === 'orderRequest' &&
          fulfilmentType === 'delivery'
        ? deliveryAddress
        : [address, postcode].filter(Boolean).join(' ').trim();
  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const effectiveSchedule =
    (supportsStructuredRequestFlow ? dropOffDate : null) || preferredDate || now;
  const jobDateLabel =
    `${effectiveSchedule.getDate()} ${monthNames[effectiveSchedule.getMonth()]} ${effectiveSchedule.getFullYear()}`;
  const jobTimeLabel = dropOffTime || preferredTimeWindow
    ? (dropOffTime || preferredTimeWindow)
    : `${String(effectiveSchedule.getHours()).padStart(2, '0')}:${String(effectiveSchedule.getMinutes()).padStart(2, '0')}`;
  let uploadedPhotos = [];
  let photoUploadFailed = false;
  if (requestPhotos && requestedPhotos.length > 0) {
    console.info(
      `[BookingLinkSubmit] photo upload start ownerUid=${ownerUid} requestId=${requestId} selectedPhotoCount=${requestedPhotos.length}`,
    );
    try {
      uploadedPhotos = await uploadBookingLinkPhotos({
        ownerUid,
        requestId,
        photos: requestedPhotos,
      });
    } catch (error) {
      photoUploadFailed = true;
      console.error(
        `[BookingLinkSubmit] photo upload failed ownerUid=${ownerUid} requestId=${requestId}`,
        error,
      );
      uploadedPhotos = [];
    }
  }
  if (requestPhotos && requestedPhotos.length > 0 &&
      uploadedPhotos.length < requestedPhotos.length) {
    photoUploadFailed = true;
  }
  console.info(
    `[BookingLinkSubmit] photo upload summary ownerUid=${ownerUid} requestId=${requestId} requested=${requestedPhotos.length} uploaded=${uploadedPhotos.length} failed=${photoUploadFailed}`,
  );
  const compiledNotes = [
    fulfilmentType ? `Fulfilment: ${fulfilmentType}` : '',
    !supportsHandover && pickupAddress ? `Pickup address: ${pickupAddress}` : '',
    !supportsHandover && deliveryAddress ? `Delivery address: ${deliveryAddress}` : '',
    dropOffDate
      ? `${endHandover === 'businessDelivers' ? 'Preferred collection' : 'Drop-off'}: ${dropOffDate.toISOString().slice(0, 10)}${dropOffTime ? ` at ${dropOffTime}` : ''}`
      : '',
    pickUpDate
      ? `${endHandover === 'businessDelivers' ? 'Preferred delivery' : 'Pick-up'}: ${pickUpDate.toISOString().slice(0, 10)}${pickUpTime ? ` at ${pickUpTime}` : ''}`
      : '',
    additionalNotes,
    requestPhotos
      ? (uploadedPhotos.length > 0
        ? `Photos attached: ${uploadedPhotos.length}`
        : (photoUploadFailed
          ? 'Photos requested, upload failed'
          : 'Photos requested: yes (none attached)'))
      : '',
  ].filter(Boolean).join('\n');

  const customQuestionResponses = normalizedAnswers.map((item) => ({
    question: item.questionText,
    answer: item.answerValue,
  }));

  console.info(
    `[BookingLinkSubmit] firestore write path=${PUBLIC_JOB_REQUEST_COLLECTION}/${requestId} privatePath=users/${ownerUid}/${LEGACY_JOB_REQUEST_COLLECTION}/${requestId} answersStored=${normalizedAnswers.length}`,
  );

  const payload = {
    requestId,
    ownerUid,
    publicConfigId,
    businessProfileId,
    customerJourneyType,
    serviceFlow,
    requestType,
    requestFlowOptions,
    fulfilmentType,
    pickupAddress,
    deliveryAddress,
    startHandover,
    endHandover,
    allowedStartHandoverOptions,
    allowedEndHandoverOptions,
    collectionAddress,
    returnAddress,
    returnAddressSameAsCollection:
      endHandover === 'businessReturns' && returnAddressSameAsCollection,
    collectionDate: endHandover === 'businessDelivers' && dropOffDate
      ? admin.firestore.Timestamp.fromDate(dropOffDate)
      : null,
    collectionTime: endHandover === 'businessDelivers' ? dropOffTime : '',
    deliveryDate: endHandover === 'businessDelivers' && pickUpDate
      ? admin.firestore.Timestamp.fromDate(pickUpDate)
      : null,
    deliveryTime: endHandover === 'businessDelivers' ? pickUpTime : '',
    businessDropOffInstructions: readString(
      selectedService.businessDropOffInstructions,
    ),
    businessCollectionInstructions: readString(
      selectedService.businessCollectionInstructions,
    ),
    dropOffDate: dropOffDate
      ? admin.firestore.Timestamp.fromDate(dropOffDate)
      : null,
    dropOffTime,
    pickUpDate: pickUpDate
      ? admin.firestore.Timestamp.fromDate(pickUpDate)
      : null,
    pickUpTime,
    jobId,
    linkedJobId: jobId,
    status: 'request_received',
    requestStatus: 'request_received',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    requestExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    scheduledAt: null,
    jobDateLabel,
    jobTimeLabel,
    scheduledDate: '',
    scheduledStartTime: '',
    estimatedDurationMinutes,
    calendarStatus: 'unscheduled',
    preferredDate: preferredDate
      ? admin.firestore.Timestamp.fromDate(preferredDate)
      : null,
    preferredTimeWindow,
    preferredIsFlexible,
    preferredTimingNote,
    preferredTimingDecision: '',
    suggestedDate: null,
    suggestedTimeWindow: '',
    publicJobTitle: serviceName,
    publicCustomerName: customerName,
    publicAddressSummary: addressSummary,
    customerPhone: phoneNumber,
    publicPhoneNumber: phoneNumber,
    publicCustomerEmail: customerEmail,
    checklistItems: [],
    customQuestions: normalizedAnswers
      .map((item) => item.questionText)
      .filter(Boolean),
    exactPinRequested: false,
    requiresExactPinAfterQuoteAccepted,
    driverMessagePreview: 'Source: Booking Link',
    hasReply: false,
    hasExactPin: false,
    submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    customerSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    requestSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    replyReceivedAt: null,
    checklistResponses: [],
    customQuestionResponses,
    answers: normalizedAnswers,
    additionalNotes: compiledNotes,
    exactPinLat: null,
    exactPinLng: null,
    exactPinLatitude: null,
    exactPinLongitude: null,
    exactPinSource: '',
    exactPinShareSource: '',
    exactPinNote: '',
    deleted: false,
    archived: false,
    source: 'booking_link',
    isPreview: false,
    sourceLabel: 'Booking Link',
    requestStatusLabel: 'Request Received',
    selectedServiceId: serviceId,
    selectedServiceName: serviceName,
    customerPostcode: postcode,
    photoFileNames,
    photos: uploadedPhotos,
    photoUploadFailed,
  };
  console.info(
    `[BookingLinkSubmit] preferred timing stored ownerUid=${ownerUid} requestId=${requestId} preferredDate=${preferredDate ? preferredDate.toISOString() : '(none)'} preferredTimeWindow=${preferredTimeWindow || '(none)'} preferredIsFlexible=${preferredIsFlexible} preferredTimingNote=${preferredTimingNote || '(none)'}`,
  );
  console.info(
    `[BookingLinkSubmit] request flag ownerUid=${ownerUid} requestId=${requestId} serviceId=${serviceId} serviceName=${serviceName} requiresExactPinAfterQuoteAccepted=${requiresExactPinAfterQuoteAccepted}`,
  );

  const privateMirrorPayload = {
    ...payload,
    checklistItemCount: 0,
    customQuestionCount: normalizedAnswers.length,
  };

  const batch = admin.firestore().batch();
  batch.set(
    admin.firestore().collection(PUBLIC_JOB_REQUEST_COLLECTION).doc(requestId),
    payload,
    { merge: true },
  );
  batch.set(
    admin.firestore()
      .collection('users')
      .doc(ownerUid)
      .collection('van_job_requests')
      .doc(requestId),
    privateMirrorPayload,
    { merge: true },
  );
  try {
    await batch.commit();
    console.info(
      `[BookingLinkSubmit] success ownerUid=${ownerUid} requestId=${requestId} jobId=${jobId} serviceName=${serviceName} publicPath=${PUBLIC_JOB_REQUEST_COLLECTION}/${requestId} privatePath=users/${ownerUid}/${LEGACY_JOB_REQUEST_COLLECTION}/${requestId} answersStored=${normalizedAnswers.length} photosStored=${uploadedPhotos.length}`,
    );
    console.info(
      `[BookingLinkSubmit] booking request created ownerUid=${ownerUid} requestId=${requestId} serviceName=${serviceName || '(none)'}`,
    );
    try {
      await withTimeout(
        sendBookingRequestReceivedNotification({
          ownerUid,
          requestId,
          jobId,
          customerName,
          serviceName,
          customerJourneyType,
        }),
        10 * 1000,
        'Booking request notification timed out.',
      );
    } catch (notificationError) {
      console.error(
        `[BookingLinkSubmit] push failed ownerUid=${ownerUid} requestId=${requestId}`,
        notificationError,
      );
    }
  } catch (error) {
    console.error(
      `[BookingLinkSubmit] failure ownerUid=${ownerUid} requestId=${requestId} jobId=${jobId}`,
      error,
    );
    throw new HttpsError(
      'internal',
      'Could not save this Booking Link request right now.',
    );
  }

  return {
    requestId,
    jobId,
    serviceName,
    status: 'Request Received',
    photoUploadFailed,
    photosUploadedCount: uploadedPhotos.length,
    requestedPhotoCount: requestedPhotos.length,
  };
});

exports.calculateRouteSummary = onCall(
  { secrets: [GOOGLE_ROUTES_API_KEY] },
  async (request) => {
    const authUid = request.auth && request.auth.uid ? String(request.auth.uid).trim() : '';
    if (!authUid) {
      throw new HttpsError('unauthenticated', 'Sign in to calculate a route summary.');
    }

    const data = request.data || {};
    const routeId = readString(data.routeId);
    if (!routeId) {
      throw new HttpsError('invalid-argument', 'routeId is required.');
    }

    if (routeId.includes('/')) {
      throw new HttpsError('invalid-argument', 'routeId is invalid.');
    }

    const force = readBool(data.force);
    const summaryMode = normalizeSummaryMode(data.mode);
    const routeRef = admin.firestore().collection(ROUTES_COLLECTION).doc(routeId);
    const routeSnap = await routeRef.get();
    if (!routeSnap.exists) {
      throw new HttpsError('not-found', 'Route not found.');
    }

    const route = routeSnap.data() || {};
    const ownerId = readString(route.ownerId || route.createdBy);
    if (!ownerId || ownerId !== authUid) {
      throw new HttpsError(
        'permission-denied',
        'This route does not belong to the signed-in user.',
      );
    }

    const routeQueuedStops = normalizeQueuedStops(readStopArray(route.stops));
    const submittedStops = normalizeSubmittedStops(data.remainingStops);
    const stops = submittedStops.length > 0 ? submittedStops : routeQueuedStops;
    if (stops.length === 0) {
      throw new HttpsError('failed-precondition', 'No remaining stops to summarize.');
    }

    if (stops.length > MAX_ROUTE_STOPS) {
      throw new HttpsError(
        'failed-precondition',
        `Route summaries support up to ${MAX_ROUTE_STOPS} remaining stops.`,
      );
    }

    if (submittedStops.length > 0) {
      validateSubmittedStops(routeQueuedStops, submittedStops);
    }

    const routeTotalStops = routeQueuedStops.length;
    const routeState = routeSummaryStateFromRoute(route, routeTotalStops);
    const submittedRouteHash = readString(data.routeHash);

    let summaryHash = '';
    try {
      const placesById = await loadPlacesById(ownerId, stops);
      const startLocation = resolveAnchorPayload(
        readAnchor(route.startAnchor) || readAnchor(data.startLocation),
      );
      const endLocation = resolveAnchorPayload(
        readAnchor(route.endAnchor) || readAnchor(data.endLocation),
      );

      summaryHash = buildSummaryHash({
        routeId,
        routeDate: readString(route.routeDate),
        startLocation,
        endLocation,
        stops,
        placesById,
      });

      const routeHashChanged = readString(route.premiumSummaryHash) !== summaryHash;
      const cachedSummaryAvailable =
        readString(route.premiumSummaryError) === '' &&
        readString(route.premiumSummaryHash) === summaryHash &&
        routeHasCachedSummary(route);
      let dailyUsageBefore = {
        premiumRouteSummaryCount: 0,
        premiumHalfwayRefreshCount: 0,
        capReached: false,
      };
      if (summaryMode === SUMMARY_MODE_HALFWAY) {
        try {
          dailyUsageBefore = await readDailyUsage(ownerId);
        } catch (usageError) {
          console.error(
            `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} reason=usage_read_failed message=${usageError instanceof Error ? usageError.message : usageError}`,
          );
        }
      }

      if (submittedRouteHash && submittedRouteHash !== summaryHash) {
        console.warn(
          `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} reason=route_hash_mismatch submittedHash=${submittedRouteHash} computedHash=${summaryHash}`,
        );
      }

      if (summaryMode === SUMMARY_MODE_HALFWAY) {
        const halfwayCapReached =
          dailyUsageBefore.premiumHalfwayRefreshCount >= MAX_DAILY_HALFWAY_REFRESHES;
        console.info(
          `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} routeHashChanged=${routeHashChanged} halfwayDone=${routeState.halfwayRefreshDone} dailyHalfwayCount=${dailyUsageBefore.premiumHalfwayRefreshCount} capReached=${halfwayCapReached} cacheHit=${cachedSummaryAvailable} googleCalled=${false}`,
        );

        if (halfwayCapReached) {
          if (cachedSummaryAvailable) {
            return buildSummaryResponseFromRoute(route, summaryHash, true);
          }

          throw new HttpsError(
            'resource-exhausted',
            'Daily smart refreshes used. Navigation still works as normal.',
          );
        }

        if (routeState.halfwayRefreshDone && !force && cachedSummaryAvailable) {
          console.info(
            `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} routeHashChanged=${routeHashChanged} halfwayDone=${routeState.halfwayRefreshDone} dailyHalfwayCount=${dailyUsageBefore.premiumHalfwayRefreshCount} capReached=${halfwayCapReached} cacheHit=${true} googleCalled=${false}`,
          );
          return buildSummaryResponseFromRoute(route, summaryHash, true);
        }
      } else if (!force && cachedSummaryAvailable) {
        console.info(
          `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} routeHashChanged=${routeHashChanged} halfwayDone=${routeState.halfwayRefreshDone} dailyHalfwayCount=${dailyUsageBefore.premiumHalfwayRefreshCount} capReached=${false} cacheHit=${true} googleCalled=${false}`,
        );
        return buildSummaryResponseFromRoute(route, summaryHash, true);
      }

      const waypoints = buildWaypoints({
        routeId,
        stopCount: stops.length,
        startLocation,
        endLocation,
        stops,
        placesById,
      });

      if (waypoints.length < 2) {
        logRouteSummaryIssue({
          routeId,
          stopCount: stops.length,
          reason: 'not_enough_route_points',
        });
        await writeRouteSummaryError(
          routeRef,
          summaryHash,
          'Could not calculate from one of the saved stops. Check stop locations and try again.',
        );
        throw new HttpsError(
          'failed-precondition',
          'Could not calculate from one of the saved stops. Check stop locations and try again.',
        );
      }

      const apiKey = readString(
        process.env.GOOGLE_ROUTES_API_KEY ||
          process.env.GOOGLE_MAPS_API_KEY ||
          GOOGLE_ROUTES_API_KEY.value(),
      );
      if (!apiKey) {
        console.error(
          `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} stopCount=${stops.length} reason=missing_routes_api_key`,
        );
        await writeRouteSummaryError(
          routeRef,
          summaryHash,
          'Google Routes API key is unavailable.',
        );
        throw new HttpsError(
          'failed-precondition',
          'Google Routes API key is unavailable.',
        );
      }

      const nowIso = new Date().toISOString();
      console.info(
        `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} routeHashChanged=${routeHashChanged} halfwayDone=${routeState.halfwayRefreshDone} dailyHalfwayCount=${dailyUsageBefore.premiumHalfwayRefreshCount} capReached=${dailyUsageBefore.capReached} cacheHit=${false} googleCalled=${true}`,
      );
      const routeData = await fetchGoogleRouteSummary({
        apiKey,
        waypoints,
        routeId,
        stopCount: stops.length,
      });
      const totalDistanceMeters = readNumber(routeData.distanceMeters);
      const totalDurationSeconds = parseGoogleDurationSeconds(
        readString(routeData.duration),
      );
      const legs = Array.isArray(routeData.legs) ? routeData.legs : [];
      const legDistanceMeters = legs.map((leg) => readNumber(leg.distanceMeters));
      const legDurationSeconds = legs.map((leg) =>
        parseGoogleDurationSeconds(readString(leg.duration)),
      );
      const routeStateForWrite = buildRouteSummaryStateForWrite({
        routeState,
        routeTotalStops: stops.length,
        summaryMode,
        nowIso,
      });

      const summary = {
        totalDistanceMeters,
        totalDurationSeconds,
        estimatedFinishIso: new Date(
          Date.now() + (totalDurationSeconds * 1000),
        ).toISOString(),
        calculatedAt: nowIso,
        stopCount: stops.length,
        summaryHash,
        provider: ROUTE_PROVIDER,
        fromCache: false,
        legDistanceMeters,
        legDurationSeconds,
        totalStopsAtStart: routeStateForWrite.totalStopsAtStart,
        halfwayTriggerStopCount: routeStateForWrite.halfwayTriggerStopCount,
        halfwayRefreshDone: routeStateForWrite.halfwayRefreshDone,
        halfwayRefreshAtIso: routeStateForWrite.halfwayRefreshAtIso,
        lastSummaryMode: routeStateForWrite.lastSummaryMode,
      };

      await writeRouteSummaryCache(routeRef, summary);
      try {
        await updateDailyUsage(ownerId, summaryMode);
      } catch (usageError) {
        console.error(
          `[RouteSummary] routeId=${routeId} uid=${ownerId} mode=${summaryMode} reason=usage_write_failed message=${usageError instanceof Error ? usageError.message : usageError}`,
        );
      }
      return summary;
  } catch (error) {
    const message = error instanceof HttpsError
      ? error.message
      : 'Route summary unavailable.';
    await writeRouteSummaryError(routeRef, summaryHash, message);
    if (error instanceof HttpsError) {
      console.error(
        `[RouteSummary] routeId=${routeId} stopCount=${stops.length} failed code=${error.code} message=${error.message}`,
      );
      throw error;
    }

    console.error(
      `[RouteSummary] routeId=${routeId} stopCount=${stops.length} failed reason=unexpected_error`,
      error,
    );
    throw new HttpsError('internal', message);
  }
  },
);

function normalizeBusinessProfileId(value) {
  const normalized = readString(value);
  if (!normalized || !/^[A-Za-z0-9_-]{1,180}$/.test(normalized)) {
    throw new HttpsError('invalid-argument', 'Business profile ID is invalid.');
  }
  return normalized;
}

function buildBusinessDeletionPlan({ ownerUid, businessProfileId, publicConfigId }) {
  const normalizedOwnerUid = readString(ownerUid);
  const normalizedBusinessProfileId = normalizeBusinessProfileId(businessProfileId);
  if (!normalizedOwnerUid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete a business.');
  }

  const expectedPublicConfigId = normalizedBusinessProfileId === DEFAULT_BUSINESS_PROFILE_ID
    ? normalizedOwnerUid
    : `${normalizedOwnerUid}_${normalizedBusinessProfileId}`;
  const suppliedPublicConfigId = readString(publicConfigId);
  if (suppliedPublicConfigId && suppliedPublicConfigId !== expectedPublicConfigId) {
    throw new HttpsError(
      'invalid-argument',
      'Booking Link identity does not belong to this business.',
    );
  }

  const configDocuments = [
    {
      collection: 'van_booking_link_settings',
      docId: normalizedBusinessProfileId === DEFAULT_BUSINESS_PROFILE_ID
        ? 'settings'
        : normalizedBusinessProfileId,
    },
  ];
  if (normalizedBusinessProfileId === DEFAULT_BUSINESS_PROFILE_ID) {
    configDocuments.push(
      { collection: 'van_business_profile', docId: 'profile' },
      { collection: 'van_job_services', docId: 'library' },
      { collection: 'van_custom_job_questions', docId: 'library' },
      { collection: 'van_settings', docId: 'quote_extras' },
    );
  }

  return {
    ownerUid: normalizedOwnerUid,
    businessProfileId: normalizedBusinessProfileId,
    publicConfigId: expectedPublicConfigId,
    configDocuments,
  };
}

function recordBelongsToBusiness(data, businessProfileId) {
  const recordProfileId = readString(data && data.businessProfileId);
  if (recordProfileId) {
    return recordProfileId === businessProfileId;
  }
  return businessProfileId === DEFAULT_BUSINESS_PROFILE_ID;
}

function shouldPreserveBusinessJob(data) {
  const status = readString(data && (data.status || data.requestStatus)).toLowerCase();
  const invoiceNumber = readString(
    data && (data.invoiceNumber || (data.invoice && data.invoice.invoiceNumber)),
  );
  return Boolean(
    invoiceNumber ||
    data && (data.invoiceCreated === true || data.paid === true) ||
    ['completed', 'complete', 'paid', 'invoiced'].includes(status)
  );
}

async function loadOwnedPublicDocuments(firestore, collectionName, ownerUid) {
  const documents = new Map();
  for (const ownerField of ['ownerUid', 'ownerId']) {
    const snapshot = await firestore
      .collection(collectionName)
      .where(ownerField, '==', ownerUid)
      .get();
    for (const document of snapshot.docs) {
      documents.set(document.ref.path, document);
    }
  }
  return [...documents.values()];
}

async function archiveReadOnlyDocuments(firestore, documents, deletionMetadata) {
  if (documents.length === 0) {
    return 0;
  }
  for (const documentChunk of chunk(documents, 400)) {
    const batch = firestore.batch();
    for (const document of documentChunk) {
      batch.set(
        document.ref,
        {
          archived: true,
          archivedReadOnly: true,
          businessDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
          deletedBusinessProfileId: deletionMetadata.businessProfileId,
          source: BUSINESS_DELETION_SOURCE,
        },
        { merge: true },
      );
    }
    await batch.commit();
  }
  return documents.length;
}

async function recursiveDeleteDocuments(firestore, documents) {
  for (const document of documents) {
    await firestore.recursiveDelete(document.ref);
  }
  return documents.length;
}

exports.deleteBusinessProfileSafely = onCall(async (request) => {
  const ownerUid = request.auth && request.auth.uid;
  if (!ownerUid) {
    throw new HttpsError('unauthenticated', 'Sign in to delete a business.');
  }
  if (request.data && request.data.confirmed !== true) {
    throw new HttpsError('failed-precondition', 'Confirm the business deletion first.');
  }

  const confirmedBusinessName = readString(
    request.data && request.data.confirmedBusinessName,
  );
  if (!confirmedBusinessName) {
    throw new HttpsError('invalid-argument', 'Business name confirmation is required.');
  }

  const plan = buildBusinessDeletionPlan({
    ownerUid,
    businessProfileId: request.data && request.data.businessProfileId,
    publicConfigId: request.data && request.data.publicConfigId,
  });
  const firestore = admin.firestore();
  const userRef = firestore.collection(USERS_COLLECTION).doc(plan.ownerUid);
  const publicConfigRef = firestore
    .collection(PUBLIC_BOOKING_LINK_COLLECTION)
    .doc(plan.publicConfigId);
  const publicConfigSnapshot = await publicConfigRef.get();
  if (
    publicConfigSnapshot.exists &&
    readString(publicConfigSnapshot.data().ownerUid) !== plan.ownerUid
  ) {
    throw new HttpsError(
      'permission-denied',
      'Booking Link ownership could not be verified.',
    );
  }
  if (publicConfigSnapshot.exists) {
    await publicConfigRef.set(
      {
        isActive: false,
        deletionInProgress: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        source: BUSINESS_DELETION_SOURCE,
      },
      { merge: true },
    );
  }
  const logoPaths = new Set();
  const publicLogoPath = readString(
    publicConfigSnapshot.exists && publicConfigSnapshot.data().logoPath,
  );
  if (publicLogoPath) {
    logoPaths.add(publicLogoPath);
  }
  if (plan.businessProfileId === DEFAULT_BUSINESS_PROFILE_ID) {
    const profileSnapshot = await userRef
      .collection('van_business_profile')
      .doc('profile')
      .get();
    const profileLogoPath = readString(
      profileSnapshot.exists && profileSnapshot.data().logoPath,
    );
    if (profileLogoPath) {
      logoPaths.add(profileLogoPath);
    }
  }
  let deletedLogoCount = 0;
  const allowedLogoPrefix = `users/${plan.ownerUid}/van_business_profile/`;
  for (const logoPath of logoPaths) {
    if (!logoPath.startsWith(allowedLogoPrefix)) {
      continue;
    }
    await admin.storage().bucket().file(logoPath).delete({ ignoreNotFound: true });
    deletedLogoCount += 1;
  }

  const privateDocumentsByCollection = new Map();
  for (const collectionName of BUSINESS_RECORD_SUBCOLLECTIONS) {
    const snapshot = await userRef.collection(collectionName).get();
    privateDocumentsByCollection.set(
      collectionName,
      snapshot.docs.filter((document) =>
        recordBelongsToBusiness(document.data(), plan.businessProfileId)),
    );
  }
  const invoiceSnapshot = await userRef.collection('van_invoices').get();
  const invoiceDocuments = invoiceSnapshot.docs.filter((document) =>
    recordBelongsToBusiness(document.data(), plan.businessProfileId));

  const completedJobDocuments = [];
  const activeJobDocuments = [];
  for (const document of privateDocumentsByCollection.get('van_jobs') || []) {
    if (shouldPreserveBusinessJob(document.data())) {
      completedJobDocuments.push(document);
    } else {
      activeJobDocuments.push(document);
    }
  }

  const archivedInvoiceCount = await archiveReadOnlyDocuments(
    firestore,
    invoiceDocuments,
    plan,
  );
  const archivedJobCount = await archiveReadOnlyDocuments(
    firestore,
    completedJobDocuments,
    plan,
  );
  const archivedQuoteCount = await archiveReadOnlyDocuments(
    firestore,
    privateDocumentsByCollection.get('van_quotes') || [],
    plan,
  );

  let deletedPrivateRecordCount = 0;
  deletedPrivateRecordCount += await recursiveDeleteDocuments(
    firestore,
    activeJobDocuments,
  );
  for (const collectionName of ['van_job_requests', 'van_pin_requests']) {
    deletedPrivateRecordCount += await recursiveDeleteDocuments(
      firestore,
      privateDocumentsByCollection.get(collectionName) || [],
    );
  }

  let deletedPublicRecordCount = 0;
  for (const collectionName of [
    ...BUSINESS_PUBLIC_COLLECTIONS,
    PUBLIC_QUOTE_RESPONSE_TOKEN_COLLECTION,
  ]) {
    const ownedDocuments = await loadOwnedPublicDocuments(
      firestore,
      collectionName,
      plan.ownerUid,
    );
    const matchingDocuments = ownedDocuments.filter((document) =>
      recordBelongsToBusiness(document.data(), plan.businessProfileId));
    deletedPublicRecordCount += await recursiveDeleteDocuments(
      firestore,
      matchingDocuments,
    );
  }

  for (const target of plan.configDocuments) {
    await firestore.recursiveDelete(
      userRef.collection(target.collection).doc(target.docId),
    );
  }
  await firestore.recursiveDelete(publicConfigRef);

  console.info(
    `[BusinessDelete] uid=${plan.ownerUid} businessProfileId=${plan.businessProfileId} ` +
    `archivedInvoices=${archivedInvoiceCount} archivedJobs=${archivedJobCount} ` +
    `archivedQuotes=${archivedQuoteCount} deletedPrivate=${deletedPrivateRecordCount} ` +
    `deletedPublic=${deletedPublicRecordCount} configDocs=${plan.configDocuments.length} ` +
    `logos=${deletedLogoCount}`,
  );
  return {
    success: true,
    businessProfileId: plan.businessProfileId,
    archivedInvoiceCount,
    archivedJobCount,
    archivedQuoteCount,
    deletedPrivateRecordCount,
    deletedPublicRecordCount,
    deletedConfigDocumentCount: plan.configDocuments.length + 1,
    deletedLogoCount,
  };
});

exports.deleteBusinessMateJobs = onCall(async (request) => {
  if (!request.auth || !readString(request.auth.uid)) {
    throw new HttpsError('unauthenticated', 'Sign in before deleting jobs.');
  }
  const data = request.data || {};
  const mode = readString(data.mode).toLowerCase();
  const selection = readString(data.selection).toLowerCase() || 'explicit';
  try {
    const coordinator = jobDeletionCoordinator();
    if (mode === 'preview') {
      return await coordinator.preview({
        ownerUid: request.auth.uid,
        businessProfileId: data.businessProfileId,
        selection,
        targets: Array.isArray(data.targets) ? data.targets : [],
      });
    }
    if (mode === 'execute') {
      return await coordinator.execute({
        ownerUid: request.auth.uid,
        businessProfileId: data.businessProfileId,
        previewToken: data.previewToken,
        confirmationPhrase: data.confirmationPhrase,
        idempotencyKey: data.idempotencyKey,
      });
    }
    throw new Error('mode must be preview or execute.');
  } catch (error) {
    console.error(
      `[JobDeletion] uid=${request.auth.uid} mode=${mode || '(missing)'} selection=${selection}`,
      error,
    );
    throw new HttpsError('failed-precondition',
      String(error && error.message || error || 'Job deletion failed.'));
  }
});

exports.onVanPinRequestReceived = onDocumentUpdated(
  `${PIN_REQUEST_COLLECTION}/{requestId}`,
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    const requestId = event.params.requestId;

    if (!before || !after) {
      return;
    }

    const wasPending = readString(before.status) === 'pending';
    const nowReceived =
      readString(after.status) === 'received' ||
      readString(after.status) === 'received_note';

    if (!wasPending || !nowReceived) {
      return;
    }

    if (after.usedAsExactPin === true) {
      return;
    }

    const ownerId = readString(after.ownerId);
    if (!ownerId) {
      return;
    }

    const dropId = readString(after.dropId);
    const dropName = readString(after.dropName);
    const requestType = readString(after.requestType);
    const isEmergency = requestType === 'emergency_number_only' || !dropName;
    const title = isEmergency
      ? 'Unmatched pin received'
      : (readString(after.status) === 'received_note'
          ? 'Location note received'
          : 'Exact pin received');
    const body = isEmergency
      ? 'A customer/site shared a location pin.'
      : (readString(after.status) === 'received_note'
          ? (dropName
              ? `${dropName} sent location details.`
              : 'A customer/site sent location details.')
          : (dropName
              ? `${dropName} shared a location pin.`
              : 'A customer/site shared a location pin.'));
    const payloadData = {
      type: readString(after.status) === 'received_note'
        ? LOCATION_NOTE_NOTIFICATION_TYPE
        : EXACT_PIN_NOTIFICATION_TYPE,
      requestId: requestId || '',
      dropId,
      dropName,
    };

    const tokenRecords = await loadTokens(ownerId);
    if (tokenRecords.length === 0) {
      console.error(`No FCM tokens found for owner ${ownerId}`);
      return;
    }

    const uniqueRecords = dedupeTokenRecords(tokenRecords);
    const chunks = chunk(uniqueRecords, 500);

    for (const records of chunks) {
      const tokens = records.map((record) => record.token);
      if (tokens.length === 0) {
        continue;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: payloadData,
      });

      await pruneInvalidTokens(ownerId, records, response.responses);
    }
  },
);

exports.onVanJobRequestReplyNotification = onDocumentUpdated(
  `${PUBLIC_JOB_REQUEST_COLLECTION}/{requestId}`,
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    const requestId = event.params.requestId;

    if (!before || !after) {
      return;
    }

    if (after[REPLY_NOTIFICATION_SENT_AT_FIELD] != null) {
      return;
    }

    const beforeStatus = readJobRequestStatus(before);
    const afterStatus = readJobRequestStatus(after);
    const beforeHasReply = readBool(before.hasReply);
    const afterHasReply = readBool(after.hasReply);
    const becameSubmitted =
      beforeStatus !== 'reply_received' && afterStatus === 'reply_received';
    const becameReplied = !beforeHasReply && afterHasReply;

    if (!becameSubmitted && !becameReplied) {
      return;
    }

    const ownerUid = readString(after.ownerUid);
    if (!ownerUid) {
      return;
    }

    const jobId = readString(after.jobId) || requestId;
    const customerName = firstNonEmpty([
      after.publicCustomerName,
      after.customerName,
    ]);
    const jobTitle = firstNonEmpty([
      after.publicJobTitle,
      after.jobTitle,
      after.publicCustomerName,
    ]);
    const hasExactPin = readBool(after.hasExactPin);
    const notificationTitle = hasExactPin
      ? 'Exact pin received'
      : 'New job reply received';
    const body = buildCustomerReplyNotificationBody({
      customerName,
      jobTitle,
      hasExactPin,
    });
    const payloadData = {
      type: CUSTOMER_REPLY_NOTIFICATION_TYPE,
      requestId: requestId || '',
      jobId,
      ownerUid,
      hasExactPin: hasExactPin ? 'true' : 'false',
      jobTitle,
      customerName,
    };

    const tokenRecords = await loadTokens(ownerUid);
    if (tokenRecords.length === 0) {
      console.error(`No FCM tokens found for owner ${ownerUid}`);
      return;
    }

    const uniqueRecords = dedupeTokenRecords(tokenRecords);
    const chunks = chunk(uniqueRecords, 500);

    for (const records of chunks) {
      const enabledRecords = records.filter((record) => record.enabled !== false);
      const tokens = enabledRecords.map((record) => record.token);
      if (tokens.length === 0) {
        continue;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: notificationTitle,
          body,
        },
        data: payloadData,
      });

      await pruneInvalidTokens(ownerUid, enabledRecords, response.responses);
    }

    const notificationSentAt = admin.firestore.FieldValue.serverTimestamp();
    const updates = {
      [REPLY_NOTIFICATION_SENT_AT_FIELD]: notificationSentAt,
    };

    await Promise.allSettled([
      admin
        .firestore()
        .collection(PUBLIC_JOB_REQUEST_COLLECTION)
        .doc(requestId)
        .set(updates, { merge: true }),
      admin
        .firestore()
        .collection(USERS_COLLECTION)
        .doc(ownerUid)
        .collection(LEGACY_JOB_REQUEST_COLLECTION)
        .doc(requestId)
        .set(updates, { merge: true }),
    ]);
  },
);

exports.onVanJobRequestMirror = onDocumentWritten(
  `${PUBLIC_JOB_REQUEST_COLLECTION}/{requestId}`,
  async (event) => {
    const beforeSnap = event.data && event.data.before ? event.data.before : null;
    const afterSnap = event.data && event.data.after ? event.data.after : null;

    if (!afterSnap || !afterSnap.exists) {
      return;
    }

    const before = beforeSnap && beforeSnap.exists ? beforeSnap.data() || {} : {};
    const after = afterSnap.data() || {};
    const requestId = readString(event.params.requestId || after.requestId || before.requestId);
    const ownerUid = firstNonEmpty([after.ownerUid, before.ownerUid]);
    const jobId = firstNonEmpty([after.jobId, before.jobId, requestId]);
    const sourceChangedKeys = listChangedKeys(before, after, {
      ignoredKeys: REQUEST_TRIGGER_IGNORED_FIELDS,
    });

    if (!requestId || !ownerUid || !jobId) {
      console.warn(
        `[VanJobRequestMirror] skipped requestId=${requestId || '(missing)'} ownerUid=${ownerUid || '(missing)'} jobId=${jobId || '(missing)'} reason=missing_reference`,
      );
      return;
    }

    if (await rejectTombstonedMirror({
      ownerUid,
      jobId,
      sourceRef: afterSnap.ref,
      label: 'VanJobRequestMirror',
    })) return;

    if (sourceChangedKeys.length === 0) {
      console.info(
        `[VanJobRequestMirror] skipped requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId} reason=no_meaningful_source_change rawChangedKeys=${formatChangedKeys(listChangedKeys(before, after))}`,
      );
      return;
    }

    const jobRef = admin
      .firestore()
      .collection(USERS_COLLECTION)
      .doc(ownerUid)
      .collection('van_jobs')
      .doc(jobId);
    const jobSnap = await jobRef.get();
    const existingJob = jobSnap.exists ? jobSnap.data() || {} : {};
    const existingJobDeleted = readBool(existingJob.deleted);
    const existingJobArchived = readBool(existingJob.archived);
    const incomingDeletionState =
      readBool(after.deleted) || readBool(after.archived);
    if ((existingJobDeleted || existingJobArchived) && !incomingDeletionState) {
      console.info(
        `[VanJobRequestMirror] skipped requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId} reason=job_hidden deleted=${existingJobDeleted} archived=${existingJobArchived}`,
      );
      return;
    }
    const update = buildRequestJobMirror({
      before,
      after,
      existingJob,
      requestId,
      ownerUid,
      jobId,
    });
    const checklistKeys = update.checklistResponses
      .map((item) => readString(item.question))
      .filter(Boolean);
    const customKeys = update.customQuestionResponses
      .map((item) => readString(item.question))
      .filter(Boolean);
    const jobWriteKeys = listDesiredChangedKeys(existingJob, update, {
      ignoredKeys: REQUEST_JOB_DIFF_IGNORED_FIELDS,
    });

    console.info(
      `[VanJobRequestMirror] requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId} targetPublicPath=${PUBLIC_JOB_REQUEST_COLLECTION}/${requestId} targetPrivatePath=users/${ownerUid}/van_jobs/${jobId} requestStatus=${update.requestStatus} jobStatus=${update.status} hasReply=${update.hasReply} exactPinShared=${update.exactPinShared} checklistCount=${checklistKeys.length} customCount=${customKeys.length} sourceChangedKeys=${formatChangedKeys(sourceChangedKeys)} jobWriteKeys=${formatChangedKeys(jobWriteKeys)}`,
    );

    if (jobWriteKeys.length === 0) {
      console.info(
        `[VanJobRequestMirror] skipped requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId} reason=no_derived_job_change sourceChangedKeys=${formatChangedKeys(sourceChangedKeys)}`,
      );
      return;
    }

    try {
      await jobRef.set(update, { merge: true });
      await admin
        .firestore()
        .collection(PUBLIC_JOB_REQUEST_COLLECTION)
        .doc(requestId)
        .set(
          {
            driverJobSyncStatus: 'synced',
            driverJobSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
            driverJobSyncCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            driverJobSyncUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            driverJobSyncTargetPath: `users/${ownerUid}/van_jobs/${jobId}`,
            driverJobSyncError: null,
          },
          { merge: true },
        );
      console.info(
        `[VanJobRequestMirror] job doc update success requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId} status=${update.status} requestStatus=${update.requestStatus} jobWriteKeys=${formatChangedKeys(jobWriteKeys)}`,
      );
    } catch (error) {
      await admin
        .firestore()
        .collection(PUBLIC_JOB_REQUEST_COLLECTION)
        .doc(requestId)
        .set(
          {
            driverJobSyncStatus: 'failed',
            driverJobSyncCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            driverJobSyncUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            driverJobSyncTargetPath: `users/${ownerUid}/van_jobs/${jobId}`,
            driverJobSyncError: String(error?.message || error || 'Unknown error'),
          },
          { merge: true },
        )
        .catch((ackError) => {
          console.error(
            `[VanJobRequestMirror] failed to write sync failure ack requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId}`,
            ackError,
          );
        });
      console.error(
        `[VanJobRequestMirror] job doc update failed requestId=${requestId} ownerUid=${ownerUid} jobId=${jobId}`,
        error,
      );
      throw error;
    }
  },
);

exports.onVanJobQuoteMirror = onDocumentWritten(
  `${PUBLIC_QUOTE_RESPONSE_COLLECTION}/{quoteId}`,
  async (event) => {
    const beforeSnap = event.data && event.data.before ? event.data.before : null;
    const afterSnap = event.data && event.data.after ? event.data.after : null;

    if (!afterSnap || !afterSnap.exists) {
      return;
    }

    const before = beforeSnap && beforeSnap.exists ? beforeSnap.data() || {} : {};
    const after = afterSnap.data() || {};
    const quoteId = readString(event.params.quoteId || after.quoteResponseId || before.quoteResponseId);
    const ownerUid = firstNonEmpty([after.ownerUid, before.ownerUid]);
    const jobId = firstNonEmpty([after.jobId, before.jobId, quoteId]);
    const sourceChangedKeys = listChangedKeys(before, after, {
      ignoredKeys: QUOTE_TRIGGER_IGNORED_FIELDS,
    });

    if (!quoteId || !ownerUid || !jobId) {
      console.warn(
      `[VanQuoteResponseMirror] skipped quoteId=${quoteId || '(missing)'} ownerUid=${ownerUid || '(missing)'} jobId=${jobId || '(missing)'} reason=missing_reference`,
      );
      return;
    }

    if (await rejectTombstonedMirror({
      ownerUid,
      jobId,
      sourceRef: afterSnap.ref,
      label: 'VanQuoteResponseMirror',
    })) return;

    if (sourceChangedKeys.length === 0) {
      console.info(
        `[VanQuoteResponseMirror] skipped quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} reason=no_meaningful_source_change rawChangedKeys=${formatChangedKeys(listChangedKeys(before, after))}`,
      );
      return;
    }

    const jobRef = admin
      .firestore()
      .collection(USERS_COLLECTION)
      .doc(ownerUid)
      .collection('van_jobs')
      .doc(jobId);
    const jobSnap = await jobRef.get();
    const existingJob = jobSnap.exists ? jobSnap.data() || {} : {};
    if (!isPublicQuoteCurrentForJob({
      quoteId,
      quoteData: after,
      jobData: existingJob,
    })) {
      console.info(
        `[VanQuoteResponseMirror] skipped quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} reason=not_current currentQuoteId=${firstNonEmpty([existingJob.currentQuoteId, existingJob.quoteResponseId, '(none)'])}`,
      );
      return;
    }
    const existingJobDeleted = readBool(existingJob.deleted);
    const existingJobArchived = readBool(existingJob.archived);
    const incomingDeletionState =
      readBool(after.deleted) || readBool(after.archived);
    if ((existingJobDeleted || existingJobArchived) && !incomingDeletionState) {
      console.info(
        `[VanQuoteResponseMirror] skipped quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} reason=job_hidden deleted=${existingJobDeleted} archived=${existingJobArchived}`,
      );
      return;
    }
    const update = buildQuoteJobMirror({
      before,
      after,
      existingJob,
      quoteId,
      ownerUid,
      jobId,
    });
    const jobWriteKeys = listDesiredChangedKeys(existingJob, update, {
      ignoredKeys: QUOTE_JOB_DIFF_IGNORED_FIELDS,
    });

    console.info(
      `[VanQuoteResponseMirror] quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} targetPublicPath=${PUBLIC_QUOTE_RESPONSE_COLLECTION}/${quoteId} targetPrivatePath=users/${ownerUid}/van_jobs/${jobId} quoteStatus=${update.quoteStatus} requestStatus=${update.requestStatus} quoteAccepted=${update.quoteAccepted} quoteDeclined=${update.quoteDeclined} requiresExactPinAfterQuoteAccepted=${update.requiresExactPinAfterQuoteAccepted === true} exactPinAlreadyExists=${update.hasExactPin === true} sourceChangedKeys=${formatChangedKeys(sourceChangedKeys)} jobWriteKeys=${formatChangedKeys(jobWriteKeys)}`,
    );

    try {
      if (jobWriteKeys.length > 0) {
        await jobRef.set(update, { merge: true });
      } else {
        console.info(
          `[VanQuoteResponseMirror] skipped van_jobs write quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} reason=no_derived_job_change sourceChangedKeys=${formatChangedKeys(sourceChangedKeys)}`,
        );
      }

      if (readString(update.quoteResponseToken)) {
        const quoteRef = admin
          .firestore()
          .collection(PUBLIC_QUOTE_RESPONSE_COLLECTION)
          .doc(quoteId);
        const publicQuoteSyncPayload = {
          quoteResponseToken: readString(update.quoteResponseToken),
          quoteResponseLink: readString(update.quoteResponseLink),
        };
        const publicQuoteSyncKeys = listDesiredChangedKeys(
          after,
          publicQuoteSyncPayload,
        );
        const tokenSyncPayload = {
          ownerUid,
          jobId,
          requestId: firstNonEmpty([
            after.requestId,
            existingJob.requestId,
            '',
          ]),
          quoteResponseId: quoteId,
          ...publicQuoteSyncPayload,
        };
        const tokenRef = admin
          .firestore()
          .collection(PUBLIC_QUOTE_RESPONSE_TOKEN_COLLECTION)
          .doc(readString(update.quoteResponseToken));
        const tokenSnap = await tokenRef.get();
        const existingToken = tokenSnap.exists ? tokenSnap.data() || {} : {};
        const tokenWriteKeys = listDesiredChangedKeys(existingToken, tokenSyncPayload);
        const tokenWrites = [];
        if (publicQuoteSyncKeys.length > 0) {
          tokenWrites.push(quoteRef.set(publicQuoteSyncPayload, { merge: true }));
        }
        if (tokenWriteKeys.length > 0) {
          tokenWrites.push(tokenRef.set({
            ...tokenSyncPayload,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }));
        }
        if (tokenWrites.length > 0) {
          console.info(
            `[VanQuoteResponseMirror] token sync quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} publicQuoteWriteKeys=${formatChangedKeys(publicQuoteSyncKeys)} tokenWriteKeys=${formatChangedKeys(tokenWriteKeys)}`,
          );
          await Promise.allSettled(tokenWrites);
        }
      }

      const linkedRequestId = firstNonEmpty([
        after.requestId,
        existingJob.requestId,
      ]);
      if (linkedRequestId) {
        const requestUpdate = buildLinkedRequestQuoteStateUpdate({
          driverPayload: update,
          includeExactPin: true,
        });
        const publicRequestRef = admin
          .firestore()
          .collection(PUBLIC_JOB_REQUEST_COLLECTION)
          .doc(linkedRequestId);
        const legacyRequestRef = admin
          .firestore()
          .collection(USERS_COLLECTION)
          .doc(ownerUid)
          .collection(LEGACY_JOB_REQUEST_COLLECTION)
          .doc(linkedRequestId);
        const [publicRequestSnap, legacyRequestSnap] = await Promise.all([
          publicRequestRef.get(),
          legacyRequestRef.get(),
        ]);
        const existingPublicRequest = publicRequestSnap.exists
          ? publicRequestSnap.data() || {}
          : {};
        const existingLegacyRequest = legacyRequestSnap.exists
          ? legacyRequestSnap.data() || {}
          : {};
        const publicRequestWriteKeys = listDesiredChangedKeys(
          existingPublicRequest,
          requestUpdate,
          { ignoredKeys: LINKED_REQUEST_DIFF_IGNORED_FIELDS },
        );
        const legacyRequestWriteKeys = listDesiredChangedKeys(
          existingLegacyRequest,
          requestUpdate,
          { ignoredKeys: LINKED_REQUEST_DIFF_IGNORED_FIELDS },
        );
        const requestWrites = [];
        if (publicRequestWriteKeys.length > 0) {
          requestWrites.push(publicRequestRef.set({
            ...requestUpdate,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }));
        }
        if (legacyRequestWriteKeys.length > 0) {
          requestWrites.push(legacyRequestRef.set({
            ...requestUpdate,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true }));
        }
        if (requestWrites.length > 0) {
          await Promise.allSettled(requestWrites);
          console.info(
            `[VanQuoteResponseMirror] request sync quoteId=${quoteId} requestId=${linkedRequestId} requestStatus=${requestUpdate.requestStatus} schedulingStatus=${requestUpdate.schedulingStatus} readyForCalendar=${requestUpdate.readyForCalendar === true} exactPinReceived=${requestUpdate.hasExactPin === true} publicRequestWriteKeys=${formatChangedKeys(publicRequestWriteKeys)} legacyRequestWriteKeys=${formatChangedKeys(legacyRequestWriteKeys)}`,
          );
        } else {
          console.info(
            `[VanQuoteResponseMirror] request sync skipped quoteId=${quoteId} requestId=${linkedRequestId} reason=no_derived_request_change`,
          );
        }
      }

      const beforeQuoteStatus = readString(
        firstNonEmpty([before.quoteStatus, before.status, before.requestStatus]),
      ).toLowerCase();
      const beforeQuoteAccepted =
        readBool(before.quoteAccepted) || beforeQuoteStatus === 'accepted';
      const beforeQuoteDeclined =
        readBool(before.quoteDeclined) || beforeQuoteStatus === 'declined';
      const quoteNotificationAlreadySent =
        readBool(after[QUOTE_NOTIFICATION_SENT_FIELD]) ||
        toIsoStringOrNull(after[QUOTE_NOTIFICATION_SENT_AT_FIELD]) ||
        readBool(existingJob[QUOTE_NOTIFICATION_SENT_FIELD]) ||
        toIsoStringOrNull(existingJob[QUOTE_NOTIFICATION_SENT_AT_FIELD]);
      const shouldSendQuoteNotification =
        ((update.quoteAccepted && !beforeQuoteAccepted) ||
          (update.quoteDeclined && !beforeQuoteDeclined)) &&
        !quoteNotificationAlreadySent;

      if (shouldSendQuoteNotification) {
        const customerName = firstNonEmpty([
          after.customerName,
          after.publicCustomerName,
          existingJob.customerName,
          existingJob.publicCustomerName,
        ]);
        const quoteVerb = update.quoteAccepted ? 'accepted' : 'declined';
        const customerJourneyType = normalizeCustomerJourneyType(firstNonEmpty([
          after.customerJourneyType,
          update.customerJourneyType,
          existingJob.customerJourneyType,
        ]));
        const journeyNoun = customerJourneyType === 'booking'
          ? 'booking'
          : (customerJourneyType === 'order' ? 'order' : 'quote');
        const notificationBody = customerName
          ? `${customerName} ${quoteVerb} your ${journeyNoun}.`
          : `Your ${journeyNoun} was ${quoteVerb}.`;
        const quoteResponseId = firstNonEmpty([
          after.quoteResponseId,
          quoteId,
        ]);
        const notificationData = {
          type: update.quoteAccepted ? 'quoteAccepted' : 'quoteDeclined',
          requestId: firstNonEmpty([
            after.requestId,
            existingJob.requestId,
            quoteId,
          ]),
          quoteId,
          quoteResponseId,
          jobId,
          ownerUid,
          customerName,
          jobTitle: firstNonEmpty([
            after.jobTitle,
            after.publicJobTitle,
            existingJob.jobTitle,
            existingJob.publicJobTitle,
          ]),
          quoteStatus: update.quoteAccepted ? 'accepted' : 'declined',
          customerJourneyType,
        };
        try {
          const tokenRecords = await loadTokens(ownerUid);
          if (tokenRecords.length === 0) {
            console.error(`No FCM tokens found for owner ${ownerUid}`);
          } else {
            const uniqueRecords = dedupeTokenRecords(tokenRecords);
            const chunks = chunk(uniqueRecords, 500);

            for (const records of chunks) {
              const enabledRecords = records.filter((record) => record.enabled !== false);
              const tokens = enabledRecords.map((record) => record.token);
              if (tokens.length === 0) {
                continue;
              }

              const response = await admin.messaging().sendEachForMulticast({
                tokens,
                notification: {
                  title: `${journeyNoun[0].toUpperCase()}${journeyNoun.slice(1)} reply`,
                  body: notificationBody,
                },
                data: notificationData,
              });

              await pruneInvalidTokens(ownerUid, enabledRecords, response.responses);
            }

            const quoteNotificationSentAt = admin.firestore.FieldValue.serverTimestamp();
            const notificationUpdates = {
              [QUOTE_NOTIFICATION_SENT_FIELD]: true,
              [QUOTE_NOTIFICATION_SENT_AT_FIELD]: quoteNotificationSentAt,
            };

            await Promise.allSettled([
              admin
                .firestore()
                .collection(PUBLIC_QUOTE_RESPONSE_COLLECTION)
                .doc(quoteId)
                .set(notificationUpdates, { merge: true }),
            ]);
          }
        } catch (notificationError) {
          console.error(
            `[VanQuoteResponseMirror] quote notification failed quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId}`,
            notificationError,
          );
        }
      }

      console.info(
        `[VanQuoteResponseMirror] job doc update success quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId} status=${update.status} requestStatus=${update.requestStatus} jobWriteKeys=${formatChangedKeys(jobWriteKeys)}`,
      );
    } catch (error) {
      console.error(
        `[VanQuoteResponseMirror] job doc update failed quoteId=${quoteId} ownerUid=${ownerUid} jobId=${jobId}`,
        error,
      );
      throw error;
    }
  },
);

async function fetchGoogleRouteSummary({ apiKey, waypoints, routeId, stopCount }) {
  const body = {
    origin: waypoints[0].waypoint,
    destination: waypoints[waypoints.length - 1].waypoint,
    travelMode: 'DRIVE',
    routingPreference: 'TRAFFIC_AWARE',
    computeAlternativeRoutes: false,
    languageCode: 'en-GB',
    units: 'METRIC',
  };

  if (waypoints.length > 2) {
    body.intermediates = waypoints
      .slice(1, waypoints.length - 1)
      .map((entry) => entry.waypoint);
  }

  const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask':
        'routes.duration,routes.distanceMeters,routes.legs.duration,routes.legs.distanceMeters',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorBody = await readResponseText(response);
    console.error(
      `[RouteSummary] routeId=${routeId} stopCount=${stopCount} reason=google_route_http_error status=${response.status} ${response.statusText} body=${errorBody}`,
    );
    throw new HttpsError(
      'failed-precondition',
      'Could not calculate from one of the saved stops. Check stop locations and try again.',
    );
  }

  const decoded = await response.json();
  if (!decoded || !Array.isArray(decoded.routes) || decoded.routes.length === 0) {
    console.error(
      `[RouteSummary] routeId=${routeId} stopCount=${stopCount} reason=google_no_route`,
    );
    throw new HttpsError(
      'failed-precondition',
      'Could not calculate from one of the saved stops. Check stop locations and try again.',
    );
  }

  return decoded.routes[0];
}

function buildWaypoints({
  routeId,
  stopCount,
  startLocation,
  endLocation,
  stops,
  placesById,
}) {
  const waypoints = [];

  if (startLocation.kind !== 'missing') {
    waypoints.push({ waypoint: startLocation.waypoint, hash: startLocation.hash });
  }

  for (let index = 0; index < stops.length; index += 1) {
    const stop = stops[index];
    const place = placesById[stop.placeId];
    const resolved = resolveStopLocation(stop, place);
    if (resolved.kind === 'missing') {
      logRouteSummaryIssue({
        routeId,
        stopCount,
        failedStopNumber: stop.routeOrder + 1 || index + 1,
        reason: 'missing postcode/address/coords',
      });
      throw new HttpsError(
        'failed-precondition',
        'Could not calculate from one of the saved stops. Check stop locations and try again.',
      );
    }

    waypoints.push(resolved);
  }

  if (endLocation.kind !== 'missing') {
    waypoints.push({ waypoint: endLocation.waypoint, hash: endLocation.hash });
  }

  return waypoints;
}

function resolveAnchorPayload(anchor) {
  if (!anchor || anchor.kind === 'missing') {
    return { kind: 'missing' };
  }

  return anchor;
}

function resolveStopLocation(stop, place) {
  if (place && place.trustedExactPin === true && isValidLatLng(place.latitude, place.longitude)) {
    return {
      kind: 'exact',
      waypoint: {
        location: {
          latLng: {
            latitude: place.latitude,
            longitude: place.longitude,
          },
        },
      },
      hash: {
        kind: 'exact',
        lat: round6(place.latitude),
        lng: round6(place.longitude),
      },
    };
  }

  const postcode = firstNonEmpty([stop.postcodeArea, place && place.postcodeArea]);
  if (postcode) {
    return {
      kind: 'text',
      waypoint: { address: postcode },
      hash: { kind: 'text', value: postcode },
    };
  }

  const address = firstNonEmpty([stop.address, place && place.address]);
  if (address) {
    return {
      kind: 'text',
      waypoint: { address },
      hash: { kind: 'text', value: address },
    };
  }

  const name = firstNonEmpty([stop.name, place && place.name]);
  if (name) {
    return {
      kind: 'text',
      waypoint: { address: name },
      hash: { kind: 'text', value: name },
    };
  }

  return { kind: 'missing', reason: 'missing postcode/address/coords' };
}

function logRouteSummaryIssue({
  routeId,
  stopCount,
  failedStopNumber = null,
  reason,
}) {
  const failedPart = failedStopNumber == null ? '' : ` failedStop=${failedStopNumber}`;
  console.warn(
    `[RouteSummary] routeId=${routeId} stopCount=${stopCount}${failedPart} reason=${reason}`,
  );
}

function buildSummaryHash({ routeId, routeDate, startLocation, endLocation, stops, placesById }) {
  const payload = {
    routeId,
    routeDate,
    start: startLocation.hash || { kind: 'missing' },
    end: endLocation.hash || { kind: 'missing' },
    stops: stops.map((stop) => {
      const place = placesById[stop.placeId];
      const resolved = resolveStopLocation(stop, place);
      return {
        id: stop.id,
        placeId: stop.placeId,
        order: stop.routeOrder,
        location: resolved.hash || { kind: 'missing' },
      };
    }),
  };

  return crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

function normalizeSubmittedStops(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => ({
      id: readString(item && item.id),
      placeId: readString(item && item.placeId),
      routeOrder: readNumber(item && item.routeOrder),
    }))
    .filter((item) => item.id && item.placeId)
    .sort((a, b) => a.routeOrder - b.routeOrder);
}

function normalizeQueuedStops(value) {
  return value
    .map((item) => ({
      id: readString(item.id),
      placeId: readString(item.placeId),
      routeOrder: readNumber(item.routeOrder),
      status: readString(item.status),
      name: readString(item.name),
      address: readString(item.address),
      postcodeArea: readString(item.postcodeArea),
    }))
    .filter((item) => item.id && item.placeId && item.status === 'queued')
    .sort((a, b) => a.routeOrder - b.routeOrder);
}

function validateSubmittedStops(routeQueuedStops, submittedStops) {
  if (routeQueuedStops.length !== submittedStops.length) {
    throw new HttpsError(
      'failed-precondition',
      'The remaining stops no longer match the route.',
    );
  }

  for (let index = 0; index < submittedStops.length; index += 1) {
    const expected = routeQueuedStops[index];
    const actual = submittedStops[index];
    if (!expected || expected.id !== actual.id || expected.placeId !== actual.placeId) {
      throw new HttpsError(
        'failed-precondition',
        'The remaining stops do not match the saved route order.',
      );
    }
  }
}

async function loadPlacesById(ownerId, stops) {
  const placeIds = [...new Set(stops.map((stop) => stop.placeId).filter(Boolean))];
  const snapshots = await Promise.all(
    placeIds.map((placeId) =>
      admin.firestore().collection(PLACES_COLLECTION).doc(placeId).get(),
    ),
  );

  const placesById = {};
  snapshots.forEach((snapshot, index) => {
    const placeId = placeIds[index];
    if (!snapshot.exists) {
      throw new HttpsError(
        'failed-precondition',
        `Saved drop ${placeId} could not be found.`,
      );
    }

    const place = snapshot.data() || {};
    const placeOwnerId = readString(place.ownerId || place.createdBy);
    if (placeOwnerId !== ownerId) {
      throw new HttpsError(
        'permission-denied',
        `Saved drop ${placeId} does not belong to the signed-in user.`,
      );
    }

    placesById[placeId] = {
      id: placeId,
      ownerId: placeOwnerId,
      name: readString(place.name),
      address: readString(place.address),
      postcodeArea: readString(place.postcodeArea || place.postcodeOrArea),
      latitude: readNullableNumber(place.latitude),
      longitude: readNullableNumber(place.longitude),
      trustedExactPin: readBool(place.trustedExactPin || place.exactPinTrusted),
    };
  });

  return placesById;
}

function readStopArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value;
}

function readAnchor(value) {
  if (!value || typeof value !== 'object') {
    return null;
  }

  const type = readString(value.type);
  const label = readString(value.label);
  const latitude = readNullableNumber(value.latitude);
  const longitude = readNullableNumber(value.longitude);
  const savedPlaceId = readString(value.savedPlaceId);
  const hasCoordinates = isValidLatLng(latitude, longitude);
  if (!hasCoordinates && !label) {
    return null;
  }

  if (hasCoordinates) {
    return {
      kind: 'exact',
      waypoint: {
        location: {
          latLng: {
            latitude,
            longitude,
          },
        },
      },
      hash: {
        kind: 'exact',
        type,
        label,
        lat: round6(latitude),
        lng: round6(longitude),
        savedPlaceId,
      },
    };
  }

  if (type === 'current_location') {
    return null;
  }

  return {
    kind: 'text',
    waypoint: { address: label },
    hash: {
      kind: 'text',
      type,
      label,
      savedPlaceId,
    },
  };
}

function routeHasCachedSummary(route) {
  return (
    readNullableNumber(route.premiumDistanceMeters) !== null &&
    readNullableInt(route.premiumDurationSeconds) !== null &&
    readString(route.premiumEstimatedFinishIso) !== '' &&
    readString(route.premiumCalculatedAt) !== '' &&
    readNullableInt(route.premiumStopCount) !== null
  );
}

function buildSummaryResponseFromRoute(route, summaryHash, fromCache) {
  const routeTotalStops = Array.isArray(route.stops) ? route.stops.length : 0;
  const routeState = routeSummaryStateFromRoute(route, routeTotalStops);
  return {
    totalDistanceMeters: readNumber(route.premiumDistanceMeters),
    totalDurationSeconds: readNullableInt(route.premiumDurationSeconds) || 0,
    estimatedFinishIso: readString(route.premiumEstimatedFinishIso),
    calculatedAt: readString(route.premiumCalculatedAt),
    stopCount: readNullableInt(route.premiumStopCount) || 0,
    summaryHash,
    provider: readString(route.premiumProvider) || ROUTE_PROVIDER,
    fromCache: Boolean(fromCache),
    legDistanceMeters: Array.isArray(route.premiumLegDistanceMeters)
      ? route.premiumLegDistanceMeters.map((item) => readNumber(item))
      : [],
    legDurationSeconds: Array.isArray(route.premiumLegDurationSeconds)
      ? route.premiumLegDurationSeconds.map((item) => readNullableInt(item) || 0)
      : [],
    totalStopsAtStart: routeState.totalStopsAtStart,
    halfwayTriggerStopCount: routeState.halfwayTriggerStopCount,
    halfwayRefreshDone: routeState.halfwayRefreshDone,
    halfwayRefreshAtIso: routeState.halfwayRefreshAtIso,
    lastSummaryMode: routeState.lastSummaryMode,
  };
}

async function writeRouteSummaryCache(routeRef, summary) {
  await routeRef.set(
    {
      premiumSummaryHash: summary.summaryHash,
      premiumDistanceMeters: summary.totalDistanceMeters,
      premiumDurationSeconds: summary.totalDurationSeconds,
      premiumEstimatedFinishIso: summary.estimatedFinishIso,
      premiumCalculatedAt: summary.calculatedAt,
      premiumStopCount: summary.stopCount,
      premiumProvider: summary.provider,
      premiumSummaryError: '',
      premiumLegDistanceMeters: summary.legDistanceMeters,
      premiumLegDurationSeconds: summary.legDurationSeconds,
      premiumHalfwayRefreshDone: summary.halfwayRefreshDone ?? false,
      premiumHalfwayRefreshAt: summary.halfwayRefreshAtIso ?? null,
      premiumTotalStopsAtStart: summary.totalStopsAtStart ?? null,
      premiumHalfwayTriggerStopCount: summary.halfwayTriggerStopCount ?? null,
      premiumLastSummaryMode: summary.lastSummaryMode ?? SUMMARY_MODE_START,
    },
    { merge: true },
  );
}

async function writeRouteSummaryError(routeRef, summaryHash, message) {
  await routeRef.set(
    {
      premiumSummaryHash: summaryHash,
      premiumDistanceMeters: null,
      premiumDurationSeconds: null,
      premiumEstimatedFinishIso: null,
      premiumCalculatedAt: new Date().toISOString(),
      premiumStopCount: 0,
      premiumProvider: ROUTE_PROVIDER,
      premiumSummaryError: message,
      premiumLegDistanceMeters: [],
      premiumLegDurationSeconds: [],
    },
    { merge: true },
  );
}

function parseGoogleDurationSeconds(durationText) {
  if (!durationText) {
    return 0;
  }

  const match = /^(\d+)(?:\.(\d+))?s$/.exec(durationText);
  if (match) {
    const wholeSeconds = parseInt(match[1], 10) || 0;
    const fractional = match[2] || '';
    if (!fractional) {
      return wholeSeconds;
    }

    const milliseconds = parseInt(fractional.padEnd(3, '0').slice(0, 3), 10) || 0;
    return wholeSeconds + Math.round(milliseconds / 1000);
  }

  const parsed = Number(durationText);
  return Number.isFinite(parsed) ? Math.round(parsed) : 0;
}

function isValidLatLng(latitude, longitude) {
  return (
    typeof latitude === 'number' &&
    typeof longitude === 'number' &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180
  );
}

function round6(value) {
  return typeof value === 'number' ? Number(value.toFixed(6)) : value;
}

function readString(value) {
  return value == null ? '' : String(value).trim();
}

function readNullableString(value) {
  const parsed = readString(value);
  return parsed ? parsed : null;
}

function readNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  const parsed = Number(readString(value));
  return Number.isFinite(parsed) ? parsed : 0;
}

function readNullableNumber(value) {
  if (value == null || value === '') {
    return null;
  }

  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  const parsed = Number(readString(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function readNullableInt(value) {
  const number = readNullableNumber(value);
  return number == null ? null : Math.round(number);
}

function readBool(value) {
  if (typeof value === 'boolean') {
    return value;
  }

  const normalized = readString(value).toLowerCase();
  return normalized === 'true';
}

function normalizeSummaryMode(value) {
  const normalized = readString(value).toLowerCase();
  if (normalized === SUMMARY_MODE_HALFWAY) {
    return SUMMARY_MODE_HALFWAY;
  }
  if (normalized === SUMMARY_MODE_ROUTE_CHANGED.toLowerCase() ||
      normalized === 'route_changed') {
    return SUMMARY_MODE_ROUTE_CHANGED;
  }
  return SUMMARY_MODE_START;
}

function routeSummaryStateFromRoute(route, routeTotalStops) {
  const totalStopsAtStart = readNullableInt(route.premiumTotalStopsAtStart);
  const halfwayTriggerStopCount = readNullableInt(
    route.premiumHalfwayTriggerStopCount,
  );
  const totalStops = totalStopsAtStart && totalStopsAtStart > 0
    ? totalStopsAtStart
    : routeTotalStops;

  return {
    totalStopsAtStart: totalStops,
    halfwayTriggerStopCount:
      halfwayTriggerStopCount && halfwayTriggerStopCount > 0
        ? halfwayTriggerStopCount
        : Math.max(1, Math.ceil(totalStops / 2)),
    halfwayRefreshDone: readBool(route.premiumHalfwayRefreshDone),
    halfwayRefreshAtIso: readString(route.premiumHalfwayRefreshAt),
    lastSummaryMode: readString(route.premiumLastSummaryMode) || SUMMARY_MODE_START,
  };
}

function routeHasSummaryState(route) {
  return (
    readNullableInt(route.premiumTotalStopsAtStart) !== null &&
    readNullableInt(route.premiumHalfwayTriggerStopCount) !== null
  );
}

function buildRouteSummaryStateForWrite({
  routeState,
  routeTotalStops,
  summaryMode,
  nowIso,
}) {
  const totalStopsAtStart = routeState.totalStopsAtStart > 0
    ? routeState.totalStopsAtStart
    : routeTotalStops;
  const halfwayTriggerStopCount = routeState.halfwayTriggerStopCount > 0
    ? routeState.halfwayTriggerStopCount
    : Math.max(1, Math.ceil(totalStopsAtStart / 2));

  if (summaryMode === SUMMARY_MODE_HALFWAY) {
    return {
      totalStopsAtStart,
      halfwayTriggerStopCount,
      halfwayRefreshDone: true,
      halfwayRefreshAtIso: nowIso,
      lastSummaryMode: SUMMARY_MODE_HALFWAY,
    };
  }

  return {
    totalStopsAtStart,
    halfwayTriggerStopCount,
    halfwayRefreshDone: false,
    halfwayRefreshAtIso: null,
    lastSummaryMode: summaryMode,
  };
}

function firstNonEmpty(values) {
  for (const value of values) {
    const parsed = readString(value);
    if (parsed) {
      return parsed;
    }
  }

  return '';
}

async function readResponseText(response) {
  try {
    const text = await response.text();
    if (!text) {
      return '';
    }

    try {
      const decoded = JSON.parse(text);
      if (decoded && typeof decoded === 'object') {
        const message = readString(
          decoded.error && decoded.error.message
            ? decoded.error.message
            : decoded.message,
        );
        if (message) {
          return message;
        }
      }
    } catch (_) {}

    return text.slice(0, 500);
  } catch (_) {
    return '';
  }
}

async function readDailyUsage(ownerId) {
  const usageDateKey = new Date().toISOString().slice(0, 10);
  const usageRef = admin
    .firestore()
    .collection(USERS_COLLECTION)
    .doc(ownerId)
    .collection(USAGE_COLLECTION)
    .doc(usageDateKey);

  const snapshot = await usageRef.get();
  const data = snapshot.data() || {};
  return {
    premiumRouteSummaryCount: readNullableInt(data.premiumRouteSummaryCount) || 0,
    premiumHalfwayRefreshCount: readNullableInt(data.premiumHalfwayRefreshCount) || 0,
    capReached:
      (readNullableInt(data.premiumHalfwayRefreshCount) || 0) >=
      MAX_DAILY_HALFWAY_REFRESHES,
  };
}

async function updateDailyUsage(ownerId, summaryMode) {
  const usageDateKey = new Date().toISOString().slice(0, 10);
  const usageRef = admin
    .firestore()
    .collection(USERS_COLLECTION)
    .doc(ownerId)
    .collection(USAGE_COLLECTION)
    .doc(usageDateKey);

  const result = {
    premiumRouteSummaryCount: 0,
    premiumHalfwayRefreshCount: 0,
    capReached: false,
  };

  await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(usageRef);
    const data = snapshot.data() || {};
    const routeSummaryCount = readNullableInt(data.premiumRouteSummaryCount) || 0;
    const halfwayCount = readNullableInt(data.premiumHalfwayRefreshCount) || 0;

    if (summaryMode === SUMMARY_MODE_HALFWAY &&
        halfwayCount >= MAX_DAILY_HALFWAY_REFRESHES) {
      result.premiumRouteSummaryCount = routeSummaryCount;
      result.premiumHalfwayRefreshCount = halfwayCount;
      result.capReached = true;
      return;
    }

    const nextRouteSummaryCount = routeSummaryCount + 1;
    const nextHalfwayCount = summaryMode === SUMMARY_MODE_HALFWAY
      ? halfwayCount + 1
      : halfwayCount;

    transaction.set(
      usageRef,
      {
        premiumRouteSummaryCount: nextRouteSummaryCount,
        premiumHalfwayRefreshCount: nextHalfwayCount,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );

    result.premiumRouteSummaryCount = nextRouteSummaryCount;
    result.premiumHalfwayRefreshCount = nextHalfwayCount;
  });

  return result;
}

async function loadTokens(ownerId) {
  const tokenDocs = await admin
    .firestore()
    .collection(USERS_COLLECTION)
    .doc(ownerId)
    .collection(FCM_TOKENS_SUBCOLLECTION)
    .get();

  return tokenDocs.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        token: readString(data.token),
        tokenDocId: doc.id,
        enabled: data.enabled !== false,
      };
    })
    .filter((record) => record.token);
}

function dedupeTokenRecords(records) {
  const seen = new Set();
  const uniqueRecords = [];

  for (const record of records) {
    if (seen.has(record.token)) {
      continue;
    }

    seen.add(record.token);
    uniqueRecords.push(record);
  }

  return uniqueRecords;
}

async function pruneInvalidTokens(ownerId, records, responses) {
  const removals = [];

  responses.forEach((response, index) => {
    if (response.success) {
      return;
    }

    const code = response.error && response.error.code;
    if (
      code !== 'messaging/registration-token-not-registered' &&
      code !== 'messaging/invalid-registration-token'
    ) {
      return;
    }

    const record = records[index];
    if (!record || !record.tokenDocId) {
      return;
    }

    removals.push(
      admin
        .firestore()
        .collection(USERS_COLLECTION)
        .doc(ownerId)
        .collection(FCM_TOKENS_SUBCOLLECTION)
        .doc(record.tokenDocId)
        .delete(),
    );
  });

  if (removals.length > 0) {
    await Promise.allSettled(removals);
  }
}

function chunk(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

exports.__test__ = {
  buildBusinessDeletionPlan,
  recordBelongsToBusiness,
  shouldPreserveBusinessJob,
  buildQuoteResponseWritePayload,
  buildQuoteExactLocationPayload,
  buildDriverJobQuoteResponsePayload,
  buildDriverJobExactLocationPayload,
  buildLinkedRequestQuoteStateUpdate,
  buildQuoteJobMirror,
  buildCustomerReplyNotificationBody,
  buildVanQuoteResponseToken,
  listChangedKeys,
  listDesiredChangedKeys,
  shouldRequireExactPinAfterQuoteAccepted,
  isPublicQuoteCurrentForJob,
  assertPublicQuoteIsCurrent,
  publicQuoteActionAlreadyApplied,
};
