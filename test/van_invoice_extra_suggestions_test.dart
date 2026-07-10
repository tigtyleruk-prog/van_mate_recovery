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
      expect(canonicalizeVanInvoiceExtraKey('3rd person'), 'third_person');
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

  test('splits accepted quote total into base job and priced extras', () {
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-quote-extras',
      businessProfile: const VanBusinessProfile.defaults(),
      customerName: 'Customer',
      customerPhone: '01234 567890',
      customerEmail: '',
      billingAddress: '1 High Street',
      invoiceDate: '1 Jan 2026',
      jobReference: 'Man & Van',
      jobDescription: 'Man & Van',
      invoiceNumber: 'INV-3',
      quoteExtras: const [
        'Stairs/access - \u00A310.00',
        'Collection/delivery - \u00A310.00',
      ],
      quoteAmount: 50,
    );

    expect(draft.lineItems, hasLength(3));
    expect(draft.lineItems[0].description, 'Man & Van');
    expect(draft.lineItems[0].amount, 30);
    expect(draft.lineItems[1].description, 'Stairs/access');
    expect(draft.lineItems[1].amount, 10);
    expect(draft.lineItems[2].description, 'Collection/delivery');
    expect(draft.lineItems[2].amount, 10);
    expect(draft.totalDue, 50);
  });

  test('reopened base-only accepted invoice seeds priced extras once', () {
    final draft =
        VanInvoiceDraft.initial(
          jobKey: 'job-reopen',
          businessProfile: const VanBusinessProfile.defaults(),
          customerName: 'Customer',
          customerPhone: '01234 567890',
          customerEmail: '',
          billingAddress: '1 High Street',
          invoiceDate: '1 Jan 2026',
          jobReference: 'Man & Van',
          jobDescription: 'Man & Van',
          invoiceNumber: 'INV-4',
          quoteExtras: const [
            'Stairs/access - \u00A310.00',
            'Collection/delivery - \u00A310.00',
          ],
          quoteAmount: 50,
        ).copyWith(
          lineItems: const [
            VanInvoiceLineItem(
              description: 'Man & Van',
              quantity: 1,
              amount: 50,
            ),
          ],
        );

    final seeded = draft.seedQuoteExtrasIfNeeded(quoteAccepted: true);
    final reopened = seeded.seedQuoteExtrasIfNeeded(quoteAccepted: true);

    expect(seeded.lineItems, hasLength(3));
    expect(seeded.lineItems[0].amount, 30);
    expect(seeded.lineItems[1].amount, 10);
    expect(seeded.lineItems[2].amount, 10);
    expect(seeded.totalDue, 50);
    expect(reopened.lineItems, hasLength(3));
    expect(reopened.totalDue, 50);
  });

  test('parses custom and quantity quote extra totals', () {
    final draft = VanInvoiceDraft.initial(
      jobKey: 'job-custom-extra',
      businessProfile: const VanBusinessProfile.defaults(),
      customerName: 'Customer',
      customerPhone: '01234 567890',
      customerEmail: '',
      billingAddress: '1 High Street',
      invoiceDate: '1 Jan 2026',
      jobReference: 'Man & Van',
      jobDescription: 'Man & Van',
      invoiceNumber: 'INV-5',
      quoteExtras: const [
        'Waiting time - 1.5h x \u00A310.00/hr = \u00A315.00',
        '4th person - \u00A315.00',
      ],
      quoteAmount: 80,
    );

    expect(draft.lineItems[0].amount, 50);
    expect(draft.lineItems[1].description, 'Waiting time');
    expect(draft.lineItems[1].amount, 15);
    expect(draft.lineItems[2].description, '4th person');
    expect(draft.lineItems[2].amount, 15);
    expect(draft.totalDue, 80);
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
