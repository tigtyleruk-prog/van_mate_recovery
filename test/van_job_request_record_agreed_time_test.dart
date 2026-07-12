import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_quote_decline.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';

void main() {
  test(
    'collection Order Request suppresses location and deferred exact pin',
    () {
      final base = <String, dynamic>{
        'requestId': 'order-request',
        'ownerUid': 'owner-1',
        'jobId': 'order-job',
        'linkedJobId': 'order-job',
        'status': 'request_received',
        'createdAt': '2026-07-11T10:00:00.000Z',
        'updatedAt': '2026-07-11T10:00:00.000Z',
        'expiresAt': '2026-07-18T10:00:00.000Z',
        'publicJobTitle': 'Cake Orders',
        'publicCustomerName': 'Customer',
        'publicAddressSummary': '',
        'checklistItems': <String>[],
        'customQuestions': <String>[],
        'exactPinRequested': true,
        'requestType': 'orderRequest',
        'locationPending': true,
        'requiresExactPinAfterQuoteAccepted': true,
      };

      final collection = VanJobRequestRecord.fromJson(<String, dynamic>{
        ...base,
        'fulfilmentType': 'collection',
      });
      final delivery = VanJobRequestRecord.fromJson(<String, dynamic>{
        ...base,
        'fulfilmentType': 'delivery',
      });
      final legacy = VanJobRequestRecord.fromJson(base);

      expect(collection.locationPending, isFalse);
      expect(collection.fulfilmentType, 'collection');
      expect(collection.exactPinRequested, isFalse);
      expect(collection.requiresExactPinAfterQuoteAccepted, isFalse);
      expect(collection.toDraft().requiresExactPinAfterQuoteAccepted, isFalse);
      expect(delivery.locationPending, isTrue);
      expect(delivery.exactPinRequested, isTrue);
      expect(delivery.requiresExactPinAfterQuoteAccepted, isTrue);
      expect(legacy.locationPending, isTrue);
      expect(legacy.exactPinRequested, isTrue);
      expect(legacy.requiresExactPinAfterQuoteAccepted, isTrue);
    },
  );

  test('request record preserves manual agreed time fields', () {
    final request = VanJobRequestRecord.fromJson(<String, dynamic>{
      'requestId': 'request-1',
      'ownerUid': 'owner-1',
      'jobId': 'job-1',
      'linkedJobId': 'job-1',
      'status': 'quote_accepted',
      'createdAt': '2026-06-14T09:00:00.000Z',
      'updatedAt': '2026-06-14T09:30:00.000Z',
      'expiresAt': '2026-06-21T09:00:00.000Z',
      'publicJobTitle': 'Flat move',
      'publicCustomerName': 'Jamie',
      'publicAddressSummary': '12 Station Road',
      'checklistItems': const <String>[],
      'customQuestions': const <String>[],
      'exactPinRequested': true,
      'quoteTimingChoice': 'agreed_time_saved',
      'schedulingStatus': 'time_agreed',
      'agreedDateTime': '2026-06-14T10:00:00.000Z',
      'agreedStartAt': '2026-06-14T10:00:00.000Z',
      'agreedEndAt': '2026-06-14T11:30:00.000Z',
      'agreedDurationMinutes': 90,
      'acceptedProposedTime': false,
      'timeAgreed': true,
      'readyForCalendar': true,
      'needsAgreedTime': false,
      'timeStatus': 'ready_for_calendar',
      'timingStatus': 'ready_for_calendar',
      'calendarStatus': 'unscheduled',
      'estimatedDurationMinutes': 90,
      'publicPhoneNumber': '07123456789',
      'requestType': 'pickupDeliveryRequest',
    });

    expect(
      request.agreedStartAtOrParsed,
      DateTime.parse('2026-06-14T10:00:00.000Z'),
    );
    expect(
      request.agreedEndAtOrParsed,
      DateTime.parse('2026-06-14T11:30:00.000Z'),
    );
    expect(request.hasAgreedSchedulingTime, isTrue);
    expect(request.isReadyForCalendar, isTrue);
    expect(request.requestType, 'pickupDeliveryRequest');
    expect(request.toDraft().requestType, 'pickupDeliveryRequest');

    final publicMap = request.toPublicFirestore();
    expect(publicMap['agreedStartAt'], isNotNull);
    expect(publicMap['agreedEndAt'], isNotNull);
    expect(publicMap['readyForCalendar'], isTrue);
    expect(publicMap['timeStatus'], 'ready_for_calendar');
    expect(publicMap['requestType'], 'pickupDeliveryRequest');
  });

  test('request record preserves decline reason fields', () {
    final request = VanJobRequestRecord.fromJson(<String, dynamic>{
      'requestId': 'request-2',
      'ownerUid': 'owner-1',
      'jobId': 'job-1',
      'linkedJobId': 'job-1',
      'status': 'quote_declined',
      'createdAt': '2026-06-14T09:00:00.000Z',
      'updatedAt': '2026-06-14T09:30:00.000Z',
      'expiresAt': '2026-06-21T09:00:00.000Z',
      'publicJobTitle': 'Flat move',
      'publicCustomerName': 'Jamie',
      'publicAddressSummary': '12 Station Road',
      'checklistItems': const <String>[],
      'customQuestions': const <String>[],
      'exactPinRequested': true,
      'quoteTimingChoice': 'declined',
      'declineReasonCode': 'too_expensive',
      'declineReasonLabel': 'Too expensive',
      'declineReasonText': 'Thanks anyway',
      'quoteDeclineReasonCode': 'too_expensive',
      'quoteDeclineReasonLabel': 'Too expensive',
      'quoteDeclineReason': 'Too expensive',
      'quoteDeclineNote': 'Thanks anyway',
      'lastQuoteDeclineReason': 'Too expensive',
      'lastQuoteDeclineNote': 'Thanks anyway',
      'declinedAt': '2026-06-14T09:30:00.000Z',
      'declinedBy': 'customer',
      'quoteStatus': 'declined',
      'quoteDeclined': true,
      'quoteResponseStatus': 'declined',
      'publicPhoneNumber': '07123456789',
    });

    expect(request.declineReasonCode, 'too_expensive');
    expect(request.declineReasonLabel, 'Too expensive');
    expect(request.declineReasonText, 'Thanks anyway');
    expect(request.quoteDeclineReasonCode, 'too_expensive');
    expect(request.quoteDeclineReason, 'Too expensive');
    expect(request.quoteDeclineNote, 'Thanks anyway');
    expect(request.declinedBy, 'customer');
    expect(request.declinedAt, DateTime.parse('2026-06-14T09:30:00.000Z'));

    final firestoreMap = request.toFirestore();
    expect(firestoreMap['declineReasonCode'], 'too_expensive');
    expect(firestoreMap['declineReasonLabel'], 'Too expensive');
    expect(firestoreMap['declineReasonText'], 'Thanks anyway');
    expect(firestoreMap['quoteDeclineReasonCode'], 'too_expensive');
    expect(firestoreMap['quoteDeclineReasonLabel'], 'Too expensive');
    expect(firestoreMap['quoteDeclineReason'], 'Too expensive');
    expect(firestoreMap['quoteDeclineNote'], 'Thanks anyway');
    expect(firestoreMap['quoteDecline'], <String, dynamic>{
      'reasonCode': 'too_expensive',
      'reasonLabel': 'Too expensive',
      'reason': 'Too expensive',
      'note': 'Thanks anyway',
      'reasonText': 'Thanks anyway',
    });
    expect(firestoreMap['declinedBy'], 'customer');
  });

  test(
    'request record reads nested quoteDecline aliases and note-only declines',
    () {
      final request = VanJobRequestRecord.fromJson(<String, dynamic>{
        'requestId': 'request-3',
        'ownerUid': 'owner-1',
        'jobId': 'job-2',
        'linkedJobId': 'job-2',
        'status': 'quote_declined',
        'createdAt': '2026-06-14T09:00:00.000Z',
        'updatedAt': '2026-06-14T09:30:00.000Z',
        'expiresAt': '2026-06-21T09:00:00.000Z',
        'publicJobTitle': 'Sofa move',
        'publicCustomerName': 'Jamie',
        'publicAddressSummary': '12 Station Road',
        'checklistItems': const <String>[],
        'customQuestions': const <String>[],
        'quoteDeclined': true,
        'quoteDecline': <String, dynamic>{'note': 'Need an earlier slot'},
      });

      expect(request.declineReasonCode, '');
      expect(request.declineReasonLabel, '');
      expect(request.declineReasonText, 'Need an earlier slot');

      final summary = buildVanQuoteDeclineSummary(
        reasonLabel: request.declineReasonLabel,
        reasonCode: request.declineReasonCode,
        note: request.declineNote,
        reasonText: request.declineReasonText,
      );
      expect(
        formatVanQuoteDeclineText(summary),
        'Reason: Need an earlier slot',
      );
    },
  );

  test('quote message helper uses the provided active quote link', () {
    final message = buildVanQuoteMessage(
      customerName: 'Jamie',
      jobTitle: 'Flat move',
      quoteAmountText: '£120.00',
      quoteResponseLink: 'https://vanmate.example/quote/new-token',
      businessName: 'Van Mate',
      proposedAppointmentText: '14 Jun 2026 at 10:00',
    );

    expect(message, contains('https://vanmate.example/quote/new-token'));
    expect(message, isNot(contains('Quote response link ready')));
    expect(message, contains('Proposed appointment: 14 Jun 2026 at 10:00'));
  });
}
