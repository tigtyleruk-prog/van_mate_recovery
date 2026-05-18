const crypto = require('crypto');
const admin = require('firebase-admin');
const { defineSecret } = require('firebase-functions/params');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

admin.initializeApp();

const PIN_REQUEST_COLLECTION = 'van_pin_requests';
const USERS_COLLECTION = 'users';
const PLACES_COLLECTION = 'van_places';
const ROUTES_COLLECTION = 'van_routes';
const USAGE_COLLECTION = 'usage';
const FCM_TOKENS_SUBCOLLECTION = 'fcmTokens';
const EXACT_PIN_NOTIFICATION_TYPE = 'exact_pin_received';
const LOCATION_NOTE_NOTIFICATION_TYPE = 'location_note_received';
const MAX_ROUTE_STOPS = 25;
const MAX_DAILY_HALFWAY_REFRESHES = 8;
const ROUTE_PROVIDER = 'google_routes';
const SUMMARY_MODE_START = 'start';
const SUMMARY_MODE_HALFWAY = 'halfway';
const SUMMARY_MODE_ROUTE_CHANGED = 'routeChanged';
const GOOGLE_ROUTES_API_KEY = defineSecret('GOOGLE_ROUTES_API_KEY');

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
