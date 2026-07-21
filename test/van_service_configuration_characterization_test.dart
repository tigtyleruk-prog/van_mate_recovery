import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_handover.dart';

void main() {
  test('VanJobService JSON round trip preserves every configuration field', () {
    final createdAt = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final updatedAt = DateTime.utc(2026, 7, 21, 10, 11, 12);
    final service = VanJobService(
      id: 'legacy-custom-service',
      name: 'Customer customised delivery',
      description: 'Do not replace this description.',
      isActive: true,
      requestPhotos: true,
      requireAddress: true,
      requestExactPinAfterQuoteAccepted: true,
      requestType: VanCustomerRequestType.pickupDeliveryRequest,
      customerJourneyType: VanCustomerJourneyType.quote,
      startHandover: VanStartHandover.businessCollects,
      endHandover: VanEndHandover.businessReturns,
      allowedStartHandoverOptions: const <VanStartHandover>[
        VanStartHandover.businessCollects,
      ],
      allowedEndHandoverOptions: const <VanEndHandover>[
        VanEndHandover.businessReturns,
      ],
      allowCustomerDropOff: false,
      allowBusinessCollection: true,
      allowCustomerCollection: false,
      allowBusinessReturn: true,
      businessDropOffInstructions: 'Original drop-off instructions',
      businessCollectionInstructions: 'Original collection instructions',
      requestFlowOptions: const VanCustomerRequestFlowOptions(
        showFulfilmentChoice: true,
        askPreferredDate: true,
        askPreferredTime: false,
        showPickupAddress: true,
        showDeliveryAddress: true,
        showDropOffDate: false,
        showDropOffTime: false,
        showPickUpDate: false,
        showPickUpTime: false,
        showNotes: true,
      ),
      linkedQuestionIds: const <String>['shared-question', 'custom-question'],
      disabledLinkedQuestionIds: const <String>['shared-question'],
      optionalQuestionIds: const <String>['custom-question'],
      quoteExtraDefaults: VanQuoteExtraDefaults.fromJson(<String, dynamic>{
        'customExtras': <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'custom_fragile',
            'label': 'Fragile handling',
            'enabled': true,
            'defaultPrice': 12.5,
          },
        ],
        'extraOrder': <String>['custom_fragile'],
        'includedBuiltInKeys': <String>[],
      }),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: false,
      category: 'Transport & Delivery',
      iconKey: 'local_shipping',
      colorValue: 0xFF123456,
      isDraft: true,
      workingDays: const <int>[1, 3, 5],
      businessStartMinutes: 8 * 60,
      businessEndMinutes: 18 * 60,
      availabilityByDay: const <int, VanServiceDaySchedule>{
        1: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
        3: VanServiceDaySchedule(startMinutes: 10 * 60, endMinutes: 20 * 60),
        5: VanServiceDaySchedule(startMinutes: 7 * 60, endMinutes: 12 * 60),
      },
      noticeHours: 6,
      maxBookingsPerDay: 3,
      selectedBuiltInQuestionKeys: const <String>[
        'phone',
        'collection_address',
      ],
      builtInQuestionSettings: const <String, Map<String, dynamic>>{
        'phone': <String, dynamic>{
          'required': true,
          'helperText': 'Call first',
        },
      },
      maxCustomerPhotos: 4,
      extraChargeUnits: const <String, String>{'custom_fragile': 'Fixed'},
      creationSource: 'customer-edited',
      starterTemplateId: 'multi_drop_delivery',
      starterPackId: 'courier_business',
      starterCapabilityIds: const <String>['booking'],
      serviceCapabilityIds: const <String>['booking', 'business_collects'],
      capabilitySchemaVersion: 1,
      capabilityGeneratedQuestionIds: const <String>['shared-question'],
      capabilityGeneratedQuestionKeys: const <String, String>{
        'collection': 'shared-question',
      },
      capabilityGeneratedExtraKeys: const <String>['custom_fragile'],
      capabilityGeneratedBuiltInQuestionKeys: const <String>['phone'],
      pricingMode: 'custom_quote',
      suggestedReminderMinutes: const <int>[60, 1440],
      suggestedStatusNames: const <String, String>{'accepted': 'Booked'},
      appointmentDurationMinutes: 95,
      customerMessage: 'Keep this customer message.',
      wizardStep: 6,
    );

    final decoded = VanJobService.fromJson(service.toJson());

    expect(decoded.toJson(), equals(service.toJson()));
  });

  test('legacy shared hours expand to each enabled working day', () {
    final service = VanJobService.fromJson(<String, dynamic>{
      'id': 'legacy-hours',
      'name': 'Legacy hours',
      'description': '',
      'isActive': true,
      'requestPhotos': false,
      'requireAddress': false,
      'requestExactPinAfterQuoteAccepted': false,
      'linkedQuestionIds': <String>[],
      'quoteExtraDefaults': VanQuoteExtraDefaults.empty().toJson(),
      'createdAt': DateTime.utc(2024).toIso8601String(),
      'updatedAt': DateTime.utc(2024).toIso8601String(),
      'workingDays': <int>[2, 4],
      'businessStartMinutes': 555,
      'businessEndMinutes': 1110,
    });

    expect(service.effectiveAvailabilityByDay.keys, <int>[2, 4]);
    expect(service.effectiveAvailabilityByDay[2]?.startMinutes, 555);
    expect(service.effectiveAvailabilityByDay[4]?.endMinutes, 1110);
  });
}
