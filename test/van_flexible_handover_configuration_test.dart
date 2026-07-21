import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';

void main() {
  test('legacy fixed flows map to independent handover capabilities', () {
    final standard = _legacyService(VanCustomerRequestType.quoteRequest);
    expect(standard.hasHandoverConfiguration, isFalse);
    expect(standard.allowCustomerDropOff, isFalse);
    expect(standard.allowBusinessCollection, isFalse);
    expect(standard.allowCustomerCollection, isFalse);
    expect(standard.allowBusinessReturn, isFalse);

    final pickup = _legacyService(VanCustomerRequestType.pickupDeliveryRequest);
    expect(pickup.allowCustomerDropOff, isFalse);
    expect(pickup.allowBusinessCollection, isTrue);
    expect(pickup.allowCustomerCollection, isFalse);
    expect(pickup.allowBusinessReturn, isTrue);

    final dropOff = _legacyService(VanCustomerRequestType.dropOffPickupRequest);
    expect(dropOff.allowCustomerDropOff, isTrue);
    expect(dropOff.allowBusinessCollection, isFalse);
    expect(dropOff.allowCustomerCollection, isTrue);
    expect(dropOff.allowBusinessReturn, isFalse);
  });

  test('all four capabilities persist independently', () {
    final service = _service(
      requestType: VanCustomerRequestType.quoteRequest,
      allowCustomerDropOff: true,
      allowBusinessCollection: true,
      allowCustomerCollection: true,
      allowBusinessReturn: true,
    );
    final restored = VanJobService.fromJson(service.toJson());

    expect(restored.hasHandoverConfiguration, isTrue);
    expect(restored.effectiveHandover.allowedStarts, VanStartHandover.values);
    expect(restored.effectiveHandover.allowedEnds, VanEndHandover.values);
    expect(restored.toJson()['allowCustomerDropOff'], isTrue);
    expect(restored.toJson()['allowBusinessCollection'], isTrue);
    expect(restored.toJson()['allowCustomerCollection'], isTrue);
    expect(restored.toJson()['allowBusinessReturn'], isTrue);
  });

  test('customers choose only when a stage has multiple enabled options', () {
    final singleRoute = _service(
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowBusinessCollection: true,
      allowBusinessReturn: true,
    );
    expect(singleRoute.hasHandoverConfiguration, isTrue);
    expect(singleRoute.allowCustomerDropOff, isFalse);
    expect(singleRoute.allowCustomerCollection, isFalse);
    expect(singleRoute.effectiveHandover.customerChoosesStart, isFalse);
    expect(singleRoute.effectiveHandover.customerChoosesEnd, isFalse);

    final flexibleRoute = _service(
      requestType: VanCustomerRequestType.quoteRequest,
      allowCustomerDropOff: true,
      allowBusinessCollection: true,
      allowCustomerCollection: true,
      allowBusinessReturn: true,
    );
    expect(flexibleRoute.effectiveHandover.customerChoosesStart, isTrue);
    expect(flexibleRoute.effectiveHandover.customerChoosesEnd, isTrue);

    final missingEnd = _service(
      requestType: VanCustomerRequestType.quoteRequest,
      allowCustomerDropOff: true,
    );
    expect(missingEnd.hasHandoverConfiguration, isFalse);
  });

  test(
    'wizard and customer surfaces use capabilities instead of fixed cards',
    () {
      final wizard = File(
        'lib/features/van_mate/pages/van_service_wizard_page.dart',
      ).readAsStringSync();
      final flutterBooking = File(
        'lib/features/van_mate/pages/van_booking_link_page.dart',
      ).readAsStringSync();
      final hostedBooking = File('web/booking_link.html').readAsStringSync();
      final functions = File('functions/index.js').readAsStringSync();

      expect(wizard, contains("title: 'Customer drops off item'"));
      expect(wizard, contains("title: 'Business collects item'"));
      expect(wizard, contains("title: 'Customer collects item'"));
      expect(wizard, contains("title: 'Business returns item'"));
      expect(wizard, isNot(contains("title: 'Pickup & Delivery'")));
      expect(wizard, isNot(contains("title: 'Drop-off & Collection'")));
      expect(flutterBooking, contains('How would you like to begin?'));
      expect(flutterBooking, contains('service.hasHandoverConfiguration'));
      expect(hostedBooking, contains('allowBusinessCollection'));
      expect(hostedBooking, contains('role="radiogroup"'));
      expect(functions, contains('hasHandoverCapabilityFlags'));
    },
  );
}

VanJobService _legacyService(VanCustomerRequestType requestType) {
  final json = _service(requestType: requestType).toJson()
    ..remove('allowCustomerDropOff')
    ..remove('allowBusinessCollection')
    ..remove('allowCustomerCollection')
    ..remove('allowBusinessReturn')
    ..remove('allowedStartHandoverOptions')
    ..remove('allowedEndHandoverOptions');
  return VanJobService.fromJson(json);
}

VanJobService _service({
  required VanCustomerRequestType requestType,
  bool? allowCustomerDropOff,
  bool? allowBusinessCollection,
  bool? allowCustomerCollection,
  bool? allowBusinessReturn,
}) {
  final now = DateTime(2026, 7, 20);
  return VanJobService(
    id: 'service',
    name: 'Repair service',
    description: '',
    isActive: true,
    requestPhotos: false,
    requireAddress: false,
    requestExactPinAfterQuoteAccepted: false,
    requestType: requestType,
    linkedQuestionIds: const <String>[],
    quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
    createdAt: now,
    updatedAt: now,
    allowCustomerDropOff: allowCustomerDropOff,
    allowBusinessCollection: allowBusinessCollection,
    allowCustomerCollection: allowCustomerCollection,
    allowBusinessReturn: allowBusinessReturn,
  );
}
