import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_invoice_extra_suggestions.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_invoice_draft.dart';

void main() {
  group('canonicalizeVanInvoiceExtraKey', () {
    test('matches helper variants', () {
      expect(canonicalizeVanInvoiceExtraKey('Extra helper'), 'helper');
      expect(canonicalizeVanInvoiceExtraKey('Helper'), 'helper');
      expect(canonicalizeVanInvoiceExtraKey('Loading help'), 'helper');
      expect(
        canonicalizeVanInvoiceExtraKey('Help loading/unloading'),
        'helper',
      );
    });

    test('matches stairs variants', () {
      expect(canonicalizeVanInvoiceExtraKey('Stairs/access'), 'stairs');
      expect(canonicalizeVanInvoiceExtraKey('Stairs'), 'stairs');
      expect(canonicalizeVanInvoiceExtraKey('Access charge'), 'stairs');
    });

    test('matches other quick extras', () {
      expect(canonicalizeVanInvoiceExtraKey('Waiting time'), 'waiting_time');
      expect(
        canonicalizeVanInvoiceExtraKey('Collection/delivery'),
        'collection_delivery',
      );
      expect(canonicalizeVanInvoiceExtraKey('Mileage charge'), 'mileage');
      expect(canonicalizeVanInvoiceExtraKey('Mileage'), 'mileage');
    });
  });

  test('still suggests helper from affirmative loading help reply', () {
    final suggestions = buildSuggestedInvoiceExtraKeys(
      checklistResponses: const [
        VanInvoiceReplyAnswer(
          question: 'Do you need loading help?',
          answer: 'Yes',
        ),
      ],
    );

    expect(suggestions, contains('helper'));
  });

  test(
    'suppresses reply-based suggestions when quote context is already known',
    () {
      final suggestions = buildSuggestedInvoiceExtraKeys(
        checklistResponses: const [
          VanInvoiceReplyAnswer(
            question: 'Do you need loading help?',
            answer: 'Yes',
          ),
        ],
        allowCustomerReplySuggestions: false,
      );

      expect(suggestions, isEmpty);
    },
  );

  test('seeds quote extras only when invoice line items are base-only', () {
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-1',
      businessProfile: const VanBusinessProfile.defaults(),
      customerName: 'Customer',
      customerPhone: '01234 567890',
      customerEmail: '',
      billingAddress: '1 High Street',
      invoiceDate: '1 Jan 2026',
      jobReference: 'Move house',
      jobDescription: 'Move house',
      invoiceNumber: 'INV-1',
      quoteExtras: const ['Extra helper', 'Collection/delivery'],
      quoteAmount: 120,
    );

    final seeded = draft
        .copyWith(
          lineItems: [
            const VanInvoiceLineItem(
              description: 'Move house',
              quantity: 1,
              amount: 120,
            ),
          ],
        )
        .seedQuoteExtrasIfNeeded(quoteAccepted: true);

    expect(seeded.lineItems, hasLength(3));
    expect(seeded.lineItems[1].description, 'Extra helper');
    expect(seeded.lineItems[2].description, 'Collection/delivery');
  });

  test('does not replace manually edited invoice line items', () {
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-2',
      businessProfile: const VanBusinessProfile.defaults(),
      customerName: 'Customer',
      customerPhone: '01234 567890',
      customerEmail: '',
      billingAddress: '1 High Street',
      invoiceDate: '1 Jan 2026',
      jobReference: 'Move house',
      jobDescription: 'Move house',
      invoiceNumber: 'INV-2',
      quoteExtras: const ['Extra helper'],
      quoteAmount: 120,
    );

    final edited = draft.copyWith(
      lineItems: [
        const VanInvoiceLineItem(
          description: 'Move house',
          quantity: 1,
          amount: 120,
        ),
        const VanInvoiceLineItem(
          description: 'Waiting time',
          quantity: 1,
          amount: 15,
          extraKey: 'waiting_time',
        ),
      ],
    );

    final seeded = edited.seedQuoteExtrasIfNeeded(quoteAccepted: true);

    expect(seeded.lineItems, hasLength(2));
    expect(seeded.lineItems[1].description, 'Waiting time');
  });
}
