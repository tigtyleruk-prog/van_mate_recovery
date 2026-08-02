import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_text_formatters.dart';
import 'package:van_mate_app/features/van_mate/services/van_booking_link_settings_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_request_cloud_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new profile keeps its own Booking Link identity and settings',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final scopes = VanBusinessProfileScopeStorage.instance;
      final settings = VanBookingLinkSettingsStorage.instance;
      const ownerUid = 'owner-123';

      final defaultId = await scopes.bookingLinkPublicConfigId(ownerUid);
      await settings.saveTitle('Legacy Booking Link', syncCloud: false);
      await settings.setActive(true, syncCloud: false);
      expect(defaultId, ownerUid);

      final baps = await scopes.addProfile('BAPS');
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'van_booking_link_public_config_id_v1_business_${baps.id}',
        ownerUid,
      );
      final bapsId = await scopes.bookingLinkPublicConfigId(ownerUid);
      await settings.saveTitle('BAPS bookings', syncCloud: false);
      await settings.setActive(false, syncCloud: false);

      expect(bapsId, '${ownerUid}_${baps.id}');
      expect(await scopes.bookingLinkPublicConfigId(ownerUid), bapsId);
      expect(await settings.loadTitle(), 'BAPS bookings');
      expect(await settings.isActive(), isFalse);

      await scopes.switchProfile(
        VanBusinessProfileScopeStorage.defaultBusinessId,
      );
      expect(await scopes.bookingLinkPublicConfigId(ownerUid), ownerUid);
      expect(await settings.loadTitle(), 'Legacy Booking Link');
      expect(await settings.isActive(), isTrue);

      await scopes.switchProfile(baps.id);
      expect(await scopes.bookingLinkPublicConfigId(ownerUid), bapsId);
      expect(await settings.loadTitle(), 'BAPS bookings');
      expect(await settings.isActive(), isFalse);
    },
  );

  test('Flutter, hosted page, function and rules share the public contract', () {
    final cloudService = File(
      'lib/features/van_mate/services/van_booking_link_cloud_service.dart',
    ).readAsStringSync();
    final settingsPage = File(
      'lib/features/van_mate/pages/van_booking_link_page.dart',
    ).readAsStringSync();
    final serviceWizardPage = File(
      'lib/features/van_mate/pages/van_service_wizard_page.dart',
    ).readAsStringSync();
    final hostedPage = File('web/booking_link.html').readAsStringSync();
    final functions = File('functions/index.js').readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    for (final source in <String>[cloudService, hostedPage, functions, rules]) {
      expect(source, contains('public_booking_links'));
    }
    for (final field in <String>[
      'publicConfigId',
      'businessProfileId',
      'ownerUid',
      'isActive',
      'services',
      'requestType',
      'serviceFlow',
      'customerJourneyType',
      'requestFlowOptions',
      'pricingMode',
      'fixedPriceAmount',
      'fromPriceAmount',
    ]) {
      expect(cloudService, contains(field));
      expect(hostedPage, contains(field));
      expect(functions, contains(field));
    }
    for (final field in <String>[
      'fulfilmentType',
      'pickupAddress',
      'deliveryAddress',
      'dropOffDate',
      'dropOffTime',
      'pickUpDate',
      'pickUpTime',
    ]) {
      expect(hostedPage, contains(field));
      expect(functions, contains(field));
    }
    for (final requestType in <String>[
      'quoteRequest',
      'bookingRequest',
      'orderRequest',
      'dropOffPickupRequest',
      'pickupDeliveryRequest',
    ]) {
      expect(hostedPage, contains(requestType));
      expect(functions, contains(requestType));
    }
    expect(hostedPage, contains('id="fulfilmentChoiceGroup"'));
    expect(hostedPage, isNot(contains('<select id="fulfilmentType"')));
    expect(
      hostedPage,
      contains('builtInQuestionSetting(service, "preferred_date").label'),
    );
    expect(
      hostedPage,
      contains('builtInQuestionSetting(service, "preferred_time").label'),
    );
    expect(
      hostedPage,
      contains('requiresBuiltInQuestion(service, "preferred_date")'),
    );
    expect(
      hostedPage,
      contains('requiresBuiltInQuestion(service, "preferred_time")'),
    );
    expect(
      hostedPage,
      contains('preferredTimingHeadingForService(service, flow, flowOptions)'),
    );
    expect(
      settingsPage,
      contains(
        "movement == 'localDelivery' || movement == 'nationwideDelivery'",
      ),
    );
    expect(settingsPage, contains("movement != 'collection'"));
    expect(settingsPage, contains("movement != 'customerDropsOff'"));
    expect(settingsPage, contains("movement != 'customerCollects'"));
    expect(
      settingsPage,
      contains("'fulfilmentType': _effectiveMovementValue ?? ''"),
    );
    expect(settingsPage, contains('_usesGenericCollectionAddress'));
    expect(settingsPage, contains('_usesGenericReturnAddress'));
    expect(settingsPage, contains('genericCollectionAddress'));
    expect(settingsPage, contains('genericReturnAddress'));
    expect(hostedPage, contains('isCollectionFulfilment'));
    expect(hostedPage, contains('isReturnFulfilment'));
    expect(settingsPage, contains('addressHeadingForService'));
    expect(settingsPage, contains('addressFieldLabelForService'));
    expect(settingsPage, contains('addressRequiredMessage'));
    expect(hostedPage, contains('addressHeadingForService(service)'));
    expect(hostedPage, contains('addressRequiredMessageForService(service)'));
    expect(settingsPage, contains("'deliveryAddress': deliveryAddress"));
    expect(settingsPage, contains('Please add the delivery address.'));
    expect(
      hostedPage,
      contains('showsConfiguredBuiltInQuestion(service, "preferred_date")'),
    );
    expect(
      hostedPage,
      contains('showsConfiguredBuiltInQuestion(service, "flexible_timing")'),
    );
    expect(hostedPage, contains('reason: "missing_preferred_date"'));
    expect(hostedPage, contains('reason: "missing_preferred_time"'));
    expect(hostedPage, contains('preferredTimeWindow.value = "anytime"'));
    expect(hostedPage, contains('preferredDateLabelForService(service)'));
    expect(settingsPage, contains('_priceLabelForService(service)'));
    expect(hostedPage, contains('priceLabelForService(service)'));
    expect(hostedPage, contains('id="servicePrice"'));
    expect(functions, contains('fixedPriceAmount'));
    expect(functions, contains('fromPriceAmount'));
    expect(serviceWizardPage, contains('_FixedPriceAmountCard'));
    expect(serviceWizardPage, contains('_FromPriceAmountCard'));
    expect(hostedPage, contains('id="preferredDateHelper"'));
    expect(hostedPage, contains('preferredDateHelperValue'));
    expect(hostedPage, contains('id="preferredTimeInput"'));
    expect(hostedPage, contains('type="time" step="900"'));
    expect(hostedPage, contains('preferredTimeControlForService(service)'));
    expect(hostedPage, contains('preferredTimeLabelForService(service)'));
    expect(hostedPage, contains('id="preferredTimeHelper"'));
    expect(hostedPage, contains('preferredTimeHelperValue'));
    expect(hostedPage, contains('preferredTimeLabel.htmlFor'));
    expect(hostedPage, contains('id="preferredFlexibleHelper"'));
    expect(hostedPage, contains('preferredFlexibleHelperValue'));
    expect(settingsPage, contains('builtInQuestionHelper('));
    expect(settingsPage, contains("'preferred_date'"));
    expect(settingsPage, contains("'preferred_time'"));
    expect(settingsPage, contains("'flexible_timing'"));
    expect(
      hostedPage,
      contains(
        'showFlexibleTiming &&\n            Boolean(preferredIsFlexible.checked)',
      ),
    );
    expect(functions, contains('if (!showsFlexibleTiming)'));
    expect(functions, contains('preferredIsFlexible = false'));
    expect(
      settingsPage,
      contains("service.requiresBuiltInQuestion('preferred_date')"),
    );
    expect(
      settingsPage,
      contains("service.requiresBuiltInQuestion('preferred_time')"),
    );
    expect(serviceWizardPage, contains("key == 'preferred_time'"));
    expect(settingsPage, contains("Text('Please choose a preferred date.')"));
    expect(settingsPage, contains('Custom public heading (optional)'));
    expect(
      settingsPage,
      contains('Leave blank to use your Business Profile name.'),
    );
    expect(settingsPage, contains('_titleController.text = linkTitle.trim()'));
    expect(settingsPage, isNot(contains('_resolveBookingLinkTitle')));
    expect(hostedPage, contains('preferredTimeWindow: showPreferredTime'));
    expect(functions, contains(r'/^([01]\d|2[0-3]):[0-5]\d$/'));
    expect(functions, contains('selectedTime.getTime() < now.getTime()'));
    expect(hostedPage, contains('additionalNotes: flowOptions.showNotes'));
    expect(functions, contains('if (!showsPreferredTime)'));
    expect(
      functions,
      contains('bookingLink.businessProfileId,\n    data.businessProfileId'),
    );
    expect(
      rules,
      contains('request.resource.data.ownerUid == request.auth.uid'),
    );
  });

  test('anytime and flexible remain valid preferred-time selections', () {
    final now = DateTime(2026, 7, 25, 10);
    final preferredDate = DateTime(2026, 7, 26);

    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: preferredDate,
        preferredTimeWindow: 'anytime',
        preferredIsFlexible: false,
        now: now,
      ),
      isNull,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: preferredDate,
        preferredTimeWindow: '',
        preferredIsFlexible: true,
        now: now,
      ),
      isNull,
    );
  });

  test('same-day exact preferred times cannot be in the past', () {
    final now = DateTime(2026, 7, 25, 10, 30);
    final preferredDate = DateTime(2026, 7, 25);

    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: preferredDate,
        preferredTimeWindow: '09:45',
        preferredIsFlexible: false,
        now: now,
      ),
      kVanMatePastBookingMessage,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: preferredDate,
        preferredTimeWindow: '10:45',
        preferredIsFlexible: false,
        now: now,
      ),
      isNull,
    );
  });

  test('preferred timing honours service lead time', () {
    final now = DateTime(2026, 7, 25, 10);

    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: DateTime(2026, 7, 25),
        preferredTimeWindow: '15:00',
        preferredIsFlexible: false,
        noticeHours: 24,
        now: now,
      ),
      kVanMateLeadTimeBookingMessage,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: DateTime(2026, 7, 26),
        preferredTimeWindow: '09:30',
        preferredIsFlexible: false,
        noticeHours: 24,
        now: now,
      ),
      kVanMateLeadTimeBookingMessage,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: DateTime(2026, 7, 26),
        preferredTimeWindow: '10:15',
        preferredIsFlexible: false,
        noticeHours: 24,
        now: now,
      ),
      isNull,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: DateTime(2026, 7, 26),
        preferredTimeWindow: '',
        preferredIsFlexible: true,
        noticeHours: 48,
        now: now,
      ),
      kVanMateLeadTimeBookingMessage,
    );
    expect(
      validateVanMatePreferredBookingWindow(
        preferredDate: null,
        preferredTimeWindow: '',
        preferredIsFlexible: false,
        noticeHours: 24,
        now: now,
      ),
      isNull,
    );
  });

  test('booking requests stay inside their matching business profile', () {
    final orderRequest = <String, dynamic>{
      'source': 'booking_link',
      'requestType': 'orderRequest',
      'businessProfileId': 'baps-profile',
    };

    expect(
      vanJobRequestMatchesBusinessProfile(
        orderRequest,
        activeBusinessProfileId: 'baps-profile',
      ),
      isTrue,
    );
    expect(
      vanJobRequestMatchesBusinessProfile(
        orderRequest,
        activeBusinessProfileId: 'other-profile',
      ),
      isFalse,
    );
    expect(
      vanJobRequestMatchesBusinessProfile(
        <String, dynamic>{'source': 'booking_link'},
        activeBusinessProfileId:
            VanBusinessProfileScopeStorage.defaultBusinessId,
      ),
      isTrue,
    );
    expect(
      vanJobRequestMatchesBusinessProfile(<String, dynamic>{
        'source': 'booking_link',
      }, activeBusinessProfileId: 'baps-profile'),
      isFalse,
    );
  });
}
