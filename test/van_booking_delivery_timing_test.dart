import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_booking_delivery_timing.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';
import 'package:van_mate_app/features/van_mate/pages/van_booking_link_page.dart';

void main() {
  test('same-day delivery requires the delivery date to match collection', () {
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 9, minute: 0),
        deliveryDate: DateTime(2026, 7, 23),
        deliveryTime: const TimeOfDay(hour: 12, minute: 0),
        sameDayDelivery: true,
      ),
      'Same-day delivery must use the collection date.',
    );
  });

  test('same-day delivery time must be later than collection time', () {
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 14, minute: 0),
        deliveryDate: DateTime(2026, 7, 22),
        deliveryTime: const TimeOfDay(hour: 13, minute: 30),
        sameDayDelivery: true,
      ),
      'Preferred delivery must not be earlier than collection.',
    );
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 14, minute: 0),
        deliveryDate: DateTime(2026, 7, 22),
        deliveryTime: const TimeOfDay(hour: 14, minute: 0),
        sameDayDelivery: true,
      ),
      'Preferred delivery time must be later than collection time.',
    );
  });

  test('scheduled delivery cannot be earlier than collection', () {
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 23),
        collectionTime: const TimeOfDay(hour: 10, minute: 0),
        deliveryDate: DateTime(2026, 7, 22),
        deliveryTime: const TimeOfDay(hour: 16, minute: 0),
        sameDayDelivery: false,
      ),
      'Preferred delivery must not be earlier than collection.',
    );
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 15, minute: 0),
        deliveryDate: DateTime(2026, 7, 22),
        deliveryTime: const TimeOfDay(hour: 14, minute: 0),
        sameDayDelivery: false,
      ),
      'Preferred delivery must not be earlier than collection.',
    );
  });

  test('valid preferred collection and delivery order passes', () {
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 9, minute: 0),
        deliveryDate: DateTime(2026, 7, 22),
        deliveryTime: const TimeOfDay(hour: 17, minute: 0),
        sameDayDelivery: true,
      ),
      isNull,
    );
    expect(
      validateVanBookingDeliveryTiming(
        collectionDate: DateTime(2026, 7, 22),
        collectionTime: const TimeOfDay(hour: 17, minute: 0),
        deliveryDate: DateTime(2026, 7, 23),
        deliveryTime: const TimeOfDay(hour: 9, minute: 0),
        sameDayDelivery: false,
      ),
      isNull,
    );
  });

  testWidgets('Courier preview shows collection and delivery without returns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 7, 22);
    final service = VanJobService(
      id: 'same-day',
      name: 'Same-day Delivery',
      description: '',
      isActive: true,
      requestPhotos: true,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      requestType: VanCustomerRequestType.pickupDeliveryRequest,
      startHandover: VanStartHandover.businessCollects,
      endHandover: VanEndHandover.businessDelivers,
      allowedStartHandoverOptions: const <VanStartHandover>[
        VanStartHandover.businessCollects,
      ],
      allowedEndHandoverOptions: const <VanEndHandover>[
        VanEndHandover.businessDelivers,
      ],
      allowBusinessCollection: true,
      allowBusinessDelivery: true,
      requestFlowOptions: const VanCustomerRequestFlowOptions(
        showFulfilmentChoice: false,
        askPreferredDate: false,
        askPreferredTime: false,
        showPickupAddress: true,
        showDeliveryAddress: true,
        showDropOffDate: true,
        showDropOffTime: true,
        showPickUpDate: true,
        showPickUpTime: true,
        showNotes: true,
      ),
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      starterTemplateId: 'courier_same_day_delivery',
      selectedBuiltInQuestionKeys: const <String>['phone', 'email', 'photos'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VanBookingLinkCustomerFormPage(
          profile: VanBusinessProfile.defaults(),
          activeServices: <VanJobService>[service],
          questionLookup: const {},
          bookingLinkActive: true,
          bookingLinkUrl: '',
          bookingLinkTitle: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    expect(field('Collection address'), findsOneWidget);
    expect(field('Delivery address'), findsOneWidget);
    expect(field('Preferred collection date'), findsOneWidget);
    expect(
      field('Preferred delivery date (same as collection)'),
      findsOneWidget,
    );
    expect(field('Preferred delivery time or delivery window'), findsOneWidget);
    expect(field('Return address'), findsNothing);
    expect(find.text('Same as collection address'), findsNothing);
    expect(find.textContaining('return it when finished'), findsNothing);
    expect(find.textContaining('business will confirm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
