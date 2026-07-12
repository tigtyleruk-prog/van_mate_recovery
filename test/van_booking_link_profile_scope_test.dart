import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test(
    'Flutter, hosted page, function and rules share the public contract',
    () {
      final cloudService = File(
        'lib/features/van_mate/services/van_booking_link_cloud_service.dart',
      ).readAsStringSync();
      final settingsPage = File(
        'lib/features/van_mate/pages/van_booking_link_page.dart',
      ).readAsStringSync();
      final hostedPage = File('web/booking_link.html').readAsStringSync();
      final functions = File('functions/index.js').readAsStringSync();
      final rules = File('firestore.rules').readAsStringSync();

      for (final source in <String>[
        cloudService,
        hostedPage,
        functions,
        rules,
      ]) {
        expect(source, contains('public_booking_links'));
      }
      for (final field in <String>[
        'publicConfigId',
        'businessProfileId',
        'ownerUid',
        'isActive',
        'services',
        'requestType',
        'requestFlowOptions',
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
      expect(hostedPage, contains('id="collectionChoice"'));
      expect(hostedPage, contains('id="deliveryChoice"'));
      expect(hostedPage, isNot(contains('<select id="fulfilmentType"')));
      expect(hostedPage, contains('Preferred collection / delivery date'));
      expect(settingsPage, contains('Custom public heading (optional)'));
      expect(
        settingsPage,
        contains('Leave blank to use your Business Profile name.'),
      );
      expect(
        settingsPage,
        contains('_titleController.text = linkTitle.trim()'),
      );
      expect(settingsPage, isNot(contains('_resolveBookingLinkTitle')));
      expect(
        hostedPage,
        contains('preferredTimeWindow: flowOptions.askPreferredTime'),
      );
      expect(hostedPage, contains('additionalNotes: flowOptions.showNotes'));
      expect(functions, contains("if (!requestFlowOptions.askPreferredTime)"));
      expect(
        functions,
        contains('bookingLink.businessProfileId,\n    data.businessProfileId'),
      );
      expect(
        rules,
        contains('request.resource.data.ownerUid == request.auth.uid'),
      );
    },
  );

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
