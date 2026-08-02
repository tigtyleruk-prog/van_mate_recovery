import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_customer_journey_theme.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';

void main() {
  test('legacy and invalid journey values safely default to quote', () {
    expect(
      vanCustomerJourneyTypeFromStorage(null),
      VanCustomerJourneyType.quote,
    );
    expect(vanCustomerJourneyTypeFromStorage(''), VanCustomerJourneyType.quote);
    expect(
      vanCustomerJourneyTypeFromStorage('not-a-journey'),
      VanCustomerJourneyType.quote,
    );
  });

  test('journey copy and theme are centralized for all customer journeys', () {
    expect(VanCustomerJourneyType.quote.copy.submitAction, 'Request quote');
    expect(
      VanCustomerJourneyType.booking.copy.businessAction,
      'Confirm booking',
    );
    expect(
      VanCustomerJourneyType.order.copy.receivedHeading,
      'Order request received',
    );
    expect(
      VanCustomerJourneyType.preOrder.copy.receivedHeading,
      'Pre Order received',
    );
    expect(
      VanCustomerJourneyType.quote.journeyTheme.accent,
      isNot(VanCustomerJourneyType.booking.journeyTheme.accent),
    );
    expect(
      VanCustomerJourneyType.booking.journeyTheme.accent,
      isNot(VanCustomerJourneyType.order.journeyTheme.accent),
    );
    expect(
      VanCustomerJourneyType.preOrder.journeyTheme.accent,
      isNot(VanCustomerJourneyType.order.journeyTheme.accent),
    );
  });

  test(
    'pre orders use Order Summary wording while quotes keep quote wording',
    () {
      final preOrderMessage = buildVanQuoteMessage(
        customerName: 'Sam',
        jobTitle: 'Cupcakes',
        quoteAmountText: 'GBP 24.00',
        quoteResponseLink: 'https://example.com/quote/pre-order',
        customerJourneyType: 'preOrder',
      );
      final quoteMessage = buildVanQuoteMessage(
        customerName: 'Sam',
        jobTitle: 'Bathroom work',
        quoteAmountText: 'GBP 240.00',
        quoteResponseLink: 'https://example.com/quote/quote',
      );

      expect(preOrderMessage, contains("Here's your Order Summary"));
      expect(preOrderMessage, contains('Order total: GBP 24.00'));
      expect(preOrderMessage, isNot(contains('Quote:')));
      expect(quoteMessage, contains("Here's your quote"));
      expect(quoteMessage, contains('Quote: GBP 240.00'));
    },
  );

  test('service JSON persists journey independently from request type', () {
    final now = DateTime(2026, 7, 18);
    final service = VanJobService(
      id: 'service-1',
      name: 'Celebration cake',
      description: '',
      isActive: true,
      requestPhotos: false,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      customerJourneyType: VanCustomerJourneyType.order,
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
    );

    final restored = VanJobService.fromJson(service.toJson());
    expect(restored.customerJourneyType, VanCustomerJourneyType.order);
    expect(restored.requestType, service.requestType);

    final legacy = Map<String, dynamic>.from(service.toJson())
      ..remove('customerJourneyType');
    expect(
      VanJobService.fromJson(legacy).customerJourneyType,
      VanCustomerJourneyType.quote,
    );
  });

  test('all nine journey and service flow combinations save and load', () {
    final now = DateTime(2026, 7, 19);
    for (final journey in VanCustomerJourneyType.values) {
      for (final flow in VanServiceFlow.values) {
        final service = VanJobService(
          id: '${journey.name}-${flow.name}',
          name: 'Service',
          description: '',
          isActive: true,
          requestPhotos: false,
          requireAddress: flow == VanServiceFlow.standard,
          requestExactPinAfterQuoteAccepted: false,
          requestType: flow.requestType,
          customerJourneyType: journey,
          linkedQuestionIds: const <String>[],
          quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
          createdAt: now,
          updatedAt: now,
        );

        final json = service.toJson();
        final restored = VanJobService.fromJson(json);

        expect(json['serviceFlow'], flow.storageKey);
        expect(restored.serviceFlow, flow);
        expect(restored.customerJourneyType, journey);
      }
    }
  });

  test('required example combinations keep wording and fields independent', () {
    final now = DateTime(2026, 7, 19);
    VanJobService service({
      required String name,
      required VanCustomerJourneyType journey,
      required VanServiceFlow flow,
    }) => VanJobService(
      id: name,
      name: name,
      description: '',
      isActive: true,
      requestPhotos: false,
      requireAddress: flow == VanServiceFlow.standard,
      requestExactPinAfterQuoteAccepted: false,
      requestType: flow.requestType,
      customerJourneyType: journey,
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
    );

    final delivery = service(
      name: 'Multi-drop Delivery',
      journey: VanCustomerJourneyType.quote,
      flow: VanServiceFlow.pickupDelivery,
    );
    final grooming = service(
      name: 'Dog Grooming',
      journey: VanCustomerJourneyType.booking,
      flow: VanServiceFlow.dropOffPickup,
    );
    final cake = service(
      name: 'Cake Order',
      journey: VanCustomerJourneyType.order,
      flow: VanServiceFlow.standard,
    );

    expect(delivery.customerJourneyType.copy.customerAction, 'Request a quote');
    expect(delivery.effectiveRequestFlowOptions.showPickupAddress, isTrue);
    expect(delivery.effectiveRequestFlowOptions.showDeliveryAddress, isTrue);
    expect(
      grooming.customerJourneyType.copy.receivedHeading,
      'Booking request received',
    );
    expect(grooming.effectiveRequestFlowOptions.showDropOffDate, isTrue);
    expect(grooming.effectiveRequestFlowOptions.showPickupAddress, isFalse);
    expect(
      cake.customerJourneyType.copy.receivedHeading,
      'Order request received',
    );
    expect(cake.effectiveRequestFlowOptions.showFulfilmentChoice, isFalse);
  });

  test('legacy request types map safely and valid journey always wins', () {
    Map<String, dynamic> legacy(String requestType, {String? journey}) {
      final json = <String, dynamic>{
        'id': requestType,
        'name': 'Legacy service',
        'requestType': requestType,
        'linkedQuestionIds': <String>[],
        'quoteExtraDefaults': <String, dynamic>{},
      };
      if (journey != null) {
        json['customerJourneyType'] = journey;
      }
      return json;
    }

    expect(
      VanJobService.fromJson(legacy('quoteRequest')).customerJourneyType,
      VanCustomerJourneyType.quote,
    );
    expect(
      VanJobService.fromJson(legacy('bookingRequest')).customerJourneyType,
      VanCustomerJourneyType.booking,
    );
    expect(
      VanJobService.fromJson(legacy('orderRequest')).customerJourneyType,
      VanCustomerJourneyType.order,
    );
    expect(
      VanJobService.fromJson(legacy('orderRequest')).serviceFlow,
      VanServiceFlow.standard,
    );
    expect(
      VanJobService.fromJson(
        legacy('pickupDeliveryRequest', journey: 'booking'),
      ).customerJourneyType,
      VanCustomerJourneyType.booking,
    );
    expect(
      VanJobService.fromJson(
        legacy('dropOffPickupRequest', journey: 'order'),
      ).customerJourneyType,
      VanCustomerJourneyType.order,
    );
  });
}
