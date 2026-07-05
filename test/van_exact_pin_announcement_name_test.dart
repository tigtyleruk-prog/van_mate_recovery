import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  test('exact pin state token is empty when coordinates are missing', () {
    final token = buildVanExactPinAnnouncementStateToken(
      hasExactPin: true,
      exactPinLatitude: null,
      exactPinLongitude: -0.1276,
      exactPinSource: 'customer',
      exactPinNote: 'Bay 3',
    );

    expect(token, isEmpty);
  });

  test('exact pin state token stays stable across note whitespace changes', () {
    final left = buildVanExactPinAnnouncementStateToken(
      hasExactPin: true,
      exactPinLatitude: 51.507351,
      exactPinLongitude: -0.127758,
      exactPinSource: 'MapAdjusted',
      exactPinNote: 'Bay   3',
    );
    final right = buildVanExactPinAnnouncementStateToken(
      hasExactPin: true,
      exactPinLatitude: 51.5073512,
      exactPinLongitude: -0.1277584,
      exactPinSource: 'mapadjusted',
      exactPinNote: ' bay 3 ',
    );

    expect(left, right);
  });

  test('exact pin state token changes when exact pin changes', () {
    final oldToken = buildVanExactPinAnnouncementStateToken(
      hasExactPin: true,
      exactPinLatitude: 51.507351,
      exactPinLongitude: -0.127758,
      exactPinSource: 'map',
      exactPinNote: 'Bay 3',
    );
    final newToken = buildVanExactPinAnnouncementStateToken(
      hasExactPin: true,
      exactPinLatitude: 51.508000,
      exactPinLongitude: -0.127758,
      exactPinSource: 'map',
      exactPinNote: 'Bay 3',
    );

    expect(newToken, isNot(oldToken));
  });

  test('exact pin announcement prefers linked job customer name', () {
    final name = resolveExactPinAnnouncementCustomerName(
      requestCustomerName: 'Ghandi',
      linkedJobCustomerName: 'Full Flow Test',
      existingCustomerName: '',
    );

    expect(name, 'Full Flow Test');
  });

  test('exact pin announcement falls back to request customer name', () {
    final name = resolveExactPinAnnouncementCustomerName(
      requestCustomerName: 'Full Flow Test',
      linkedJobCustomerName: '',
      existingCustomerName: 'Ghandi',
    );

    expect(name, 'Full Flow Test');
  });
}
