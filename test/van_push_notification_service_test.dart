import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/services/van_push_notification_service.dart';

void main() {
  test(
    'customer reply exact pin snackbar prefers customer name over job title',
    () {
      const payload = VanMateExactPinNotificationPayload(
        type: 'customer_reply',
        requestId: 'request-1',
        customerName: 'Full Flow Test',
        jobTitle: 'Man & Van',
        hasExactPin: true,
      );

      expect(payload.snackbarBody, 'Exact pin received for Full Flow Test');
      expect(payload.notificationBody, 'Exact pin received for Full Flow Test');
    },
  );

  test('customer reply exact pin snackbar falls back to generic wording', () {
    const payload = VanMateExactPinNotificationPayload(
      type: 'customer_reply',
      requestId: 'request-2',
      jobTitle: 'Handyman',
      hasExactPin: true,
    );

    expect(payload.snackbarBody, 'Exact pin received');
    expect(payload.notificationBody, 'Exact pin received');
  });
}
