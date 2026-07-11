import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/services/van_booking_link_settings_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new profile keeps its own Booking Link identity and settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final scopes = VanBusinessProfileScopeStorage.instance;
    final settings = VanBookingLinkSettingsStorage.instance;
    const ownerUid = 'owner-123';

    final defaultId = await scopes.bookingLinkPublicConfigId(ownerUid);
    await settings.saveTitle('Legacy Booking Link', syncCloud: false);
    await settings.setActive(true, syncCloud: false);
    expect(defaultId, ownerUid);

    final baps = await scopes.addProfile('BAPS');
    final bapsId = await scopes.bookingLinkPublicConfigId(ownerUid);
    await settings.saveTitle('BAPS bookings', syncCloud: false);
    await settings.setActive(false, syncCloud: false);

    expect(bapsId, '${ownerUid}_${baps.id}');
    expect(await scopes.bookingLinkPublicConfigId(ownerUid), bapsId);
    expect(await settings.loadTitle(), 'BAPS bookings');
    expect(await settings.isActive(), isFalse);

    await scopes.switchProfile(VanBusinessProfileScopeStorage.defaultBusinessId);
    expect(await scopes.bookingLinkPublicConfigId(ownerUid), ownerUid);
    expect(await settings.loadTitle(), 'Legacy Booking Link');
    expect(await settings.isActive(), isTrue);

    await scopes.switchProfile(baps.id);
    expect(await scopes.bookingLinkPublicConfigId(ownerUid), bapsId);
    expect(await settings.loadTitle(), 'BAPS bookings');
    expect(await settings.isActive(), isFalse);
  });

  test('Flutter, hosted page, function and rules share the public contract', () {
    final cloudService = File(
      'lib/features/van_mate/services/van_booking_link_cloud_service.dart',
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
    ]) {
      expect(cloudService, contains(field));
      expect(hostedPage, contains(field));
      expect(functions, contains(field));
    }
    expect(rules, contains('request.resource.data.ownerUid == request.auth.uid'));
  });
}
