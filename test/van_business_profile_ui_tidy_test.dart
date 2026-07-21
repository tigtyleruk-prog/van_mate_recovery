import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Edit Business has one page title and consistent section spacing', () {
    final source = File(
      'lib/features/van_mate/pages/van_business_profile_page.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        "title: Text\\(_setupMode \\? 'Business Setup' : 'Edit Business'\\)",
      ).allMatches(source).length,
      1,
    );
    expect(
      source,
      isNot(
        contains(
          "const Text(\n                              'Business Profile'",
        ),
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'const SizedBox(height: 12),\n'
          '                      const SizedBox(height: 12),',
        ),
      ),
    );
  });

  test('remaining sections stay focused on profile information', () {
    final source = File(
      'lib/features/van_mate/pages/van_business_profile_page.dart',
    ).readAsStringSync();

    for (final title in <String>[
      'Business Details',
      'Address Details',
      'Payment Details',
      'Tax Details',
      'Business Logo',
    ]) {
      expect(source, contains("title: '$title'"));
    }
    expect(source, isNot(contains("title: 'Invoice Defaults'")));
    expect(source, isNot(contains('Question Pack')));
    expect(source, isNot(contains('global question')));
  });
}
