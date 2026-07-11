import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Business Profile hides invoice defaults but keeps payment and VAT', () {
    final source = File(
      'lib/features/van_mate/pages/van_business_profile_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("title: 'Invoice Defaults'")));
    expect(source, isNot(contains("label: 'Default invoice notes'")));
    expect(source, isNot(contains("label: 'Default payment terms'")));
    expect(source, isNot(contains("label: 'Thank you message'")));
    expect(source, contains("title: 'Payment Details'"));
    expect(source, contains("title: 'Tax Details'"));
    expect(source, contains("label: 'VAT number'"));
  });

  test('Business Profile saves preserve hidden legacy invoice values', () {
    final source = File(
      'lib/features/van_mate/pages/van_business_profile_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('defaultInvoiceNotes: _loadedSettings.defaultInvoiceNotes'),
    );
    expect(
      source,
      contains('defaultPaymentTerms: _loadedSettings.defaultPaymentTerms'),
    );
    expect(
      source,
      contains('defaultMileageRate: _loadedSettings.defaultMileageRate'),
    );
  });
}
