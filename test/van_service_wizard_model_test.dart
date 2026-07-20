import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_journey.dart';
import 'package:van_mate_app/features/van_mate/models/van_customer_request_flow.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';

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
  });
}
