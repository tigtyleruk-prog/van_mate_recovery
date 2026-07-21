import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_calendar_job_presentation.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_pickup_reminder_service.dart';

typedef _Combination = ({
  VanStartHandover start,
  VanEndHandover end,
  String businessSummary,
  String customerSummary,
  String startLabel,
  String endLabel,
});

const _combinations = <_Combination>[
  (
    start: VanStartHandover.customerDropsOff,
    end: VanEndHandover.customerCollects,
    businessSummary: 'Customer drops off and collects',
    customerSummary: "You'll drop off your item and collect it when ready.",
    startLabel: 'Customer drop-off',
    endLabel: 'Customer collection',
  ),
  (
    start: VanStartHandover.customerDropsOff,
    end: VanEndHandover.businessReturns,
    businessSummary: 'Customer drops off; business returns',
    customerSummary:
        "You'll drop off your item. We'll return it when finished.",
    startLabel: 'Customer drop-off',
    endLabel: 'Business return',
  ),
  (
    start: VanStartHandover.businessCollects,
    end: VanEndHandover.customerCollects,
    businessSummary: 'Business collects; customer collects',
    customerSummary: "We'll collect your item. You'll collect it when ready.",
    startLabel: 'Business collection',
    endLabel: 'Customer collection',
  ),
  (
    start: VanStartHandover.businessCollects,
    end: VanEndHandover.businessReturns,
    businessSummary: 'Business collects and returns',
    customerSummary: "We'll collect your item and return it when finished.",
    startLabel: 'Business collection',
    endLabel: 'Business return',
  ),
];

Map<String, dynamic> _serviceJson(_Combination combination) =>
    <String, dynamic>{
      'id': 'service-1',
      'name': 'Repair service',
      'description': '',
      'isActive': true,
      'requestPhotos': false,
      'requireAddress': true,
      'requestExactPinAfterQuoteAccepted': false,
      'requestType': VanCustomerRequestType.dropOffPickupRequest.storageKey,
      'customerJourneyType': 'quote',
      'startHandover': combination.start.storageKey,
      'endHandover': combination.end.storageKey,
      'allowedStartHandoverOptions': <String>[combination.start.storageKey],
      'allowedEndHandoverOptions': <String>[combination.end.storageKey],
      'businessDropOffInstructions': 'Use reception',
      'businessCollectionInstructions': 'Collect from workshop',
      'linkedQuestionIds': <String>[],
      'quoteExtraDefaults': <String, dynamic>{},
      'createdAt': '2026-07-18T09:00:00.000',
      'updatedAt': '2026-07-18T09:00:00.000',
    };

DriverCustomerReplyMockData _job(_Combination combination) {
  return DriverCustomerReplyMockData(
    jobId: 'job-1',
    customerName: 'Customer',
    jobTitle: 'Repair service',
    scheduledAt: DateTime(2026, 7, 20, 9),
    jobDateLabel: '20 Jul 2026',
    jobTimeLabel: '09:00',
    address: '',
    phoneNumber: '07000000000',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'scheduled',
    requestStatus: 'quote_accepted',
    calendarStatus: 'scheduled',
    requestType: 'dropOffPickupRequest',
    customerJourneyType: 'booking',
    startHandover: combination.start.storageKey,
    endHandover: combination.end.storageKey,
    collectionAddress: '1 Collection Road',
    returnAddress: '2 Return Street',
    businessDropOffInstructions: 'Use reception',
    businessCollectionInstructions: 'Collect from workshop',
    dropOffDate: DateTime(2026, 7, 20),
    dropOffTime: '09:30',
    pickUpDate: DateTime(2026, 7, 21),
    pickUpTime: '16:45',
  );
}

void main() {
  for (final combination in _combinations) {
    final name =
        '${combination.start.storageKey} to ${combination.end.storageKey}';

    test('$name saves, loads, summarises and publishes additive fields', () {
      final service = VanJobService.fromJson(_serviceJson(combination));
      final restored = VanJobService.fromJson(service.toJson());

      expect(restored.effectiveHandover.start, combination.start);
      expect(restored.effectiveHandover.end, combination.end);
      expect(
        vanBusinessHandoverSummary(combination.start, combination.end),
        combination.businessSummary,
      );
      expect(
        vanCustomerHandoverSummary(combination.start, combination.end),
        combination.customerSummary,
      );
      expect(service.toJson()['startHandover'], combination.start.storageKey);
      expect(service.toJson()['endHandover'], combination.end.storageKey);
    });

    test(
      '$name keeps independent request and accepted-quote handover data',
      () {
        final record = VanJobRequestRecord.fromJson(<String, dynamic>{
          'requestId': 'request-1',
          'jobId': 'job-1',
          'requestType': 'dropOffPickupRequest',
          'startHandover': combination.start.storageKey,
          'endHandover': combination.end.storageKey,
          'collectionAddress': '1 Collection Road',
          'returnAddress': '2 Return Street',
          'returnAddressSameAsCollection': false,
        });
        final restored = VanJobRequestRecord.fromJson(record.toJson());
        final accepted = _job(
          combination,
        ).copyWith(status: 'quoteAccepted', requestStatus: 'quote_accepted');

        expect(restored.startHandover, combination.start.storageKey);
        expect(restored.endHandover, combination.end.storageKey);
        expect(restored.collectionAddress, '1 Collection Road');
        expect(restored.returnAddress, '2 Return Street');
        expect(accepted.effectiveHandover.start, combination.start);
        expect(accepted.effectiveHandover.end, combination.end);
      },
    );

    test('$name produces independent labels, addresses and journey colour', () {
      final actions = vanCalendarActionProjections(_job(combination));

      expect(actions, hasLength(2));
      expect(actions[0].label, combination.startLabel);
      expect(actions[1].label, combination.endLabel);
      expect(actions[0].start, DateTime(2026, 7, 20, 9, 30));
      expect(actions[1].start, DateTime(2026, 7, 21, 16, 45));
      expect(actions[0].icon, isA<IconData>());
      expect(actions[1].icon, isA<IconData>());
      expect(
        vanCalendarAccentForJob(_job(combination)),
        const Color(0xFF9B7CFF),
      );
      expect(
        actions[0].address,
        combination.start.needsCustomerAddress
            ? '1 Collection Road'
            : 'Use reception',
      );
      expect(
        actions[1].address,
        combination.end.needsCustomerAddress
            ? '2 Return Street'
            : 'Collect from workshop',
      );
    });

    test('$name uses the correct end reminder action', () {
      final body = buildVanPickupReminderBody(
        customerName: 'Customer',
        serviceName: 'Repair service',
        pickUpAt: DateTime(2026, 7, 21, 16, 45),
        endHandover: combination.end.storageKey,
      );

      expect(body, contains(combination.endLabel.toLowerCase()));
      expect(body, contains('16:45'));
    });

    test('$name uses the correct start reminder action', () {
      final body = buildVanStartHandoverReminderBody(
        customerName: 'Customer',
        serviceName: 'Repair service',
        startAt: DateTime(2026, 7, 20, 9, 30),
        startHandover: combination.start.storageKey,
      );

      expect(body, contains(combination.startLabel.toLowerCase()));
      expect(body, contains('09:30'));
    });
  }

  test('legacy combined modes preserve their existing combinations', () {
    final customerMode = VanJobService.fromJson(<String, dynamic>{
      ..._serviceJson(_combinations.first),
      'startHandover': null,
      'endHandover': null,
      'allowedStartHandoverOptions': null,
      'allowedEndHandoverOptions': null,
      'requestType': 'dropOffPickupRequest',
    });
    final businessMode = VanJobService.fromJson(<String, dynamic>{
      ..._serviceJson(_combinations.first),
      'startHandover': null,
      'endHandover': null,
      'allowedStartHandoverOptions': null,
      'allowedEndHandoverOptions': null,
      'requestType': 'pickupDeliveryRequest',
    });

    expect(
      customerMode.effectiveHandover.start,
      VanStartHandover.customerDropsOff,
    );
    expect(customerMode.effectiveHandover.end, VanEndHandover.customerCollects);
    expect(
      businessMode.effectiveHandover.start,
      VanStartHandover.businessCollects,
    );
    expect(businessMode.effectiveHandover.end, VanEndHandover.businessReturns);
  });

  test('legacy customer choice and invalid values resolve safely', () {
    final choice = VanServiceHandoverConfig.resolve(
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      legacyMode: 'customerChooses',
    );
    final invalid = VanServiceHandoverConfig.resolve(
      requestType: VanCustomerRequestType.pickupDeliveryRequest,
      startValue: 'invalid',
      endValue: 'invalid',
    );

    expect(choice.allowedStarts, VanStartHandover.values);
    expect(choice.allowedEnds, VanEndHandover.values);
    expect(invalid.start, VanStartHandover.businessCollects);
    expect(invalid.end, VanEndHandover.businessReturns);
  });

  test('same-as-collection and different return addresses remain distinct', () {
    final same = VanJobRequestRecord.fromJson(<String, dynamic>{
      'requestId': 'same',
      'collectionAddress': '1 Collection Road',
      'returnAddress': '1 Collection Road',
      'returnAddressSameAsCollection': true,
    });
    final different = VanJobRequestRecord.fromJson(<String, dynamic>{
      'requestId': 'different',
      'collectionAddress': '1 Collection Road',
      'returnAddress': '2 Return Street',
      'returnAddressSameAsCollection': false,
    });

    expect(same.returnAddressSameAsCollection, isTrue);
    expect(same.returnAddress, same.collectionAddress);
    expect(different.returnAddressSameAsCollection, isFalse);
    expect(different.returnAddress, isNot(different.collectionAddress));
  });
}
