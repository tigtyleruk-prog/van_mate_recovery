import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/models/van_service_capability.dart';

void main() {
  test('legacy services receive safe wizard defaults', () {
    final service = VanJobService.fromJson(<String, dynamic>{
      'id': 'legacy',
      'name': 'Window cleaning',
      'description': '',
      'isActive': true,
      'requestPhotos': false,
      'requireAddress': true,
      'requestExactPinAfterQuoteAccepted': true,
      'requestType': 'quote_request',
      'linkedQuestionIds': <String>[],
      'quoteExtraDefaults': VanQuoteExtraDefaults.empty().toJson(),
      'createdAt': '2026-01-01T09:00:00.000',
      'updatedAt': '2026-01-01T09:00:00.000',
    });

    expect(service.isDraft, isFalse);
    expect(service.category, 'General');
    expect(service.iconKey, 'work');
    expect(service.workingDays, <int>[1, 2, 3, 4, 5]);
    expect(service.businessStartMinutes, 9 * 60);
    expect(service.businessEndMinutes, 17 * 60);
    expect(service.optionalQuestionIds, isEmpty);
    expect(
      service.effectiveSelectedBuiltInQuestionKeys,
      containsAll(<String>['phone', 'email', 'address']),
    );
    expect(service.maxCustomerPhotos, 5);
    expect(service.creationSource, isEmpty);
    expect(service.starterTemplateId, isEmpty);
    expect(service.starterPackId, isEmpty);
    expect(service.starterCapabilityIds, isEmpty);
    expect(service.serviceCapabilityIds, isEmpty);
    expect(service.capabilitySchemaVersion, 0);
    expect(service.isCapabilityDriven, isFalse);
    expect(service.appointmentDurationMinutes, 60);
    expect(service.customerMessage, isEmpty);
    expect(service.wizardStep, 0);
    expect(service.availabilityByDay, isNull);
    expect(service.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5]);
    expect(
      service.effectiveAvailabilityByDay[1]!.startMinutes,
      service.businessStartMinutes,
    );
    expect(
      service.effectiveAvailabilityByDay[5]!.endMinutes,
      service.businessEndMinutes,
    );
  });

  test('per-day availability survives JSON without flattening day hours', () {
    final now = DateTime.utc(2026, 7, 21);
    final original = VanJobService(
      id: 'different-hours',
      name: 'Different hours',
      description: '',
      isActive: true,
      requestPhotos: false,
      requireAddress: true,
      requestExactPinAfterQuoteAccepted: false,
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      workingDays: const <int>[1, 2, 3, 4, 5],
      availabilityByDay: const <int, VanServiceDaySchedule>{
        1: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
        2: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 20 * 60),
        3: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
        4: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 20 * 60),
        5: VanServiceDaySchedule(startMinutes: 9 * 60, endMinutes: 20 * 60),
      },
    );

    final json = original.toJson()
      ..['workingDays'] = <int>[7]
      ..['businessStartMinutes'] = 6 * 60
      ..['businessEndMinutes'] = 12 * 60;
    final restored = VanJobService.fromJson(json);

    expect(restored.availabilityByDay, isNotNull);
    expect(restored.workingDays, <int>[1, 2, 3, 4, 5]);
    expect(restored.businessStartMinutes, 9 * 60);
    expect(restored.businessEndMinutes, 17 * 60);
    expect(restored.effectiveAvailabilityByDay.keys, <int>[1, 2, 3, 4, 5]);
    expect(restored.effectiveAvailabilityByDay[1]!.endMinutes, 17 * 60);
    expect(restored.effectiveAvailabilityByDay[2]!.endMinutes, 20 * 60);
    expect(restored.effectiveAvailabilityByDay[5]!.endMinutes, 20 * 60);
  });

  test('wizard metadata survives service JSON round trip', () {
    final now = DateTime(2026, 7, 20, 12);
    final original = VanJobService(
      id: 'service-1',
      name: 'Dog grooming',
      description: 'A calm full groom.',
      isActive: false,
      requestPhotos: true,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      customerJourneyType: VanCustomerJourneyType.booking,
      linkedQuestionIds: const <String>['pet-name', 'medical-notes'],
      optionalQuestionIds: const <String>['medical-notes'],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      category: 'Pets',
      iconKey: 'pet',
      colorValue: 0xFF7B61FF,
      isDraft: true,
      workingDays: const <int>[2, 3, 4, 6],
      businessStartMinutes: 8 * 60 + 30,
      businessEndMinutes: 16 * 60,
      noticeHours: 48,
      maxBookingsPerDay: 5,
      selectedBuiltInQuestionKeys: const <String>['phone', 'photos'],
      builtInQuestionSettings: const <String, Map<String, dynamic>>{
        'phone': <String, dynamic>{'required': false, 'helperText': 'Text us'},
        'photos': <String, dynamic>{'required': true, 'helperText': ''},
      },
      maxCustomerPhotos: 3,
      extraChargeUnits: const <String, String>{'mileage': 'Mile'},
      creationSource: 'starterPack',
      starterTemplateId: 'dog_grooming',
      starterPackId: 'dog_groomer_business',
      starterCapabilityIds: const <String>[
        'customer_drops_pet',
        'customer_collects_pet',
      ],
      serviceCapabilityIds: const <String>[
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
      ],
      capabilitySchemaVersion: 1,
      capabilityGeneratedQuestionIds: const <String>['medical-notes'],
      capabilityGeneratedQuestionKeys: const <String, String>{
        'medical-notes': 'health conditions or allergies',
      },
      capabilityGeneratedExtraKeys: const <String>['custom_extra_deposit'],
      capabilityGeneratedBuiltInQuestionKeys: const <String>['preferred_date'],
      pricingMode: VanServiceCapabilityIds.fromPrice,
      suggestedReminderMinutes: const <int>[1440, 120],
      suggestedStatusNames: const <String, String>{
        'accepted': 'Grooming confirmed',
      },
      appointmentDurationMinutes: 90,
      customerMessage: 'We will confirm the grooming time with you.',
      wizardStep: 4,
    );

    final restored = VanJobService.fromJson(original.toJson());

    expect(restored.category, original.category);
    expect(restored.iconKey, original.iconKey);
    expect(restored.colorValue, original.colorValue);
    expect(restored.isDraft, isTrue);
    expect(restored.optionalQuestionIds, original.optionalQuestionIds);
    expect(restored.workingDays, original.workingDays);
    expect(restored.businessStartMinutes, original.businessStartMinutes);
    expect(restored.businessEndMinutes, original.businessEndMinutes);
    expect(restored.noticeHours, original.noticeHours);
    expect(restored.maxBookingsPerDay, original.maxBookingsPerDay);
    expect(
      restored.selectedBuiltInQuestionKeys,
      original.selectedBuiltInQuestionKeys,
    );
    expect(restored.builtInQuestionSettings, original.builtInQuestionSettings);
    expect(restored.maxCustomerPhotos, 3);
    expect(restored.extraChargeUnits, original.extraChargeUnits);
    expect(restored.creationSource, 'starterPack');
    expect(restored.starterTemplateId, 'dog_grooming');
    expect(restored.starterPackId, 'dog_groomer_business');
    expect(restored.starterCapabilityIds, original.starterCapabilityIds);
    expect(restored.serviceCapabilityIds, original.serviceCapabilityIds);
    expect(restored.capabilitySchemaVersion, 1);
    expect(restored.isCapabilityDriven, isTrue);
    expect(restored.capabilityGeneratedQuestionIds, <String>['medical-notes']);
    expect(
      restored.capabilityGeneratedQuestionKeys['medical-notes'],
      'health conditions or allergies',
    );
    expect(restored.capabilityGeneratedExtraKeys, <String>[
      'custom_extra_deposit',
    ]);
    expect(restored.capabilityGeneratedBuiltInQuestionKeys, <String>[
      'preferred_date',
    ]);
    expect(restored.pricingMode, VanServiceCapabilityIds.fromPrice);
    expect(restored.suggestedReminderMinutes, <int>[1440, 120]);
    expect(restored.suggestedStatusNames['accepted'], 'Grooming confirmed');
    expect(restored.appointmentDurationMinutes, 90);
    expect(
      restored.customerMessage,
      'We will confirm the grooming time with you.',
    );
    expect(restored.wizardStep, 4);
    expect(restored.requiresBuiltInQuestion('photos'), isTrue);
    expect(restored.requiresBuiltInQuestion('phone'), isFalse);
  });

  test('capability-driven order request type survives legacy flow fields', () {
    final now = DateTime(2026, 7, 20, 12);
    final service = VanJobService(
      id: 'order-service',
      name: 'Cupcakes',
      description: '',
      isActive: true,
      requestPhotos: false,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      requestType: VanCustomerRequestType.orderRequest,
      customerJourneyType: VanCustomerJourneyType.order,
      linkedQuestionIds: const <String>[],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      serviceCapabilityIds: const <String>[VanServiceCapabilityIds.placeOrder],
      capabilitySchemaVersion: 1,
    );

    final json = service.toJson();
    final restored = VanJobService.fromJson(json);

    expect(json['requestType'], 'orderRequest');
    expect(restored.requestType, VanCustomerRequestType.orderRequest);
    expect(restored.customerJourneyType, VanCustomerJourneyType.order);
  });
}
