import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_history_entry.dart';
import 'package:van_mate_app/features/van_mate/services/van_invoice_reminder_service.dart';

void main() {
  VanInvoiceHistoryEntry buildEntry({
    required String invoiceDate,
    String dueDate = VanInvoiceDraft.dueOnReceiptLabel,
    String paymentStatus = 'unpaid',
    DateTime? createdAt,
    DateTime? paymentReminder3dSentAt,
    DateTime? paymentReminder7dSentAt,
    DateTime? paymentReminder14dSentAt,
  }) {
    return VanInvoiceHistoryEntry(
      jobKey: 'job-1',
      draft: VanInvoiceDraft(
        jobKey: 'job-1',
        linkedJobId: 'job-1',
        businessName: 'Van Mate',
        contactName: 'Driver',
        phone: '07123456789',
        email: 'driver@example.com',
        businessAddress: '1 Van Street',
        paymentInstructions: 'Bank transfer',
        quoteExtras: const <String>[],
        quoteNotes: '',
        quotePaymentInstructions: '',
        quoteMessage: '',
        customerName: 'Mr Smith',
        customerPhone: '07123456789',
        billingAddress: '2 Customer Road',
        customerEmail: 'customer@example.com',
        invoiceNumber: 'VM-0014',
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        jobReference: 'House move',
        jobDescription: 'House move',
        lineItems: const <VanInvoiceLineItem>[
          VanInvoiceLineItem(
            description: 'House move',
            quantity: 1,
            amount: 60,
          ),
        ],
        estimatedMiles: '',
        mileageCharge: 0,
        invoiceNotes: '',
        paymentStatus: paymentStatus,
        paidAt: paymentStatus == 'paid' ? DateTime(2026, 6, 10) : null,
        paymentReminder3dSentAt: paymentReminder3dSentAt,
        paymentReminder7dSentAt: paymentReminder7dSentAt,
        paymentReminder14dSentAt: paymentReminder14dSentAt,
      ),
      savedAt: createdAt ?? DateTime(2026, 6, 1),
      createdAt: createdAt ?? DateTime(2026, 6, 1),
      updatedAt: createdAt ?? DateTime(2026, 6, 1),
    );
  }

  test('due on receipt reminders use invoice date baseline', () {
    final candidates = collectVanInvoiceReminderCandidates(
      <VanInvoiceHistoryEntry>[buildEntry(invoiceDate: '01/06/2026')],
      now: DateTime(2026, 6, 4),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.stage, VanInvoiceReminderStage.threeDays);
    expect(candidates.single.overdueDays, 3);
  });

  test(
    'highest reached reminder stage fires instead of backfilling older stages',
    () {
      final candidates = collectVanInvoiceReminderCandidates(
        <VanInvoiceHistoryEntry>[buildEntry(invoiceDate: '01/06/2026')],
        now: DateTime(2026, 6, 15),
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.stage, VanInvoiceReminderStage.fourteenDays);
    },
  );

  test(
    'marking reminder stage sent stamps lower stages too and survives json',
    () {
      final draft = buildEntry(invoiceDate: '01/06/2026').draft;
      final sentAt = DateTime(2026, 6, 8, 9, 30);
      final updated = draft.markReminderStagesSentUpTo(
        stageDays: 7,
        sentAt: sentAt,
      );
      final roundTrip = VanInvoiceDraft.fromJson(updated.toJson());

      expect(roundTrip.paymentReminder3dSentAt, sentAt);
      expect(roundTrip.paymentReminder7dSentAt, sentAt);
      expect(roundTrip.paymentReminder14dSentAt, isNull);
    },
  );

  test('paid invoices do not produce reminder candidates', () {
    final candidates = collectVanInvoiceReminderCandidates(
      <VanInvoiceHistoryEntry>[
        buildEntry(invoiceDate: '01/06/2026', paymentStatus: 'paid'),
      ],
      now: DateTime(2026, 6, 15),
    );

    expect(candidates, isEmpty);
  });

  test('reminder body includes invoice number, customer and amount', () {
    final body = buildVanInvoiceReminderBody(
      buildEntry(invoiceDate: '01/06/2026'),
    );

    expect(body, 'VM-0014 · Mr Smith · £60.00 is still awaiting payment.');
  });
}
