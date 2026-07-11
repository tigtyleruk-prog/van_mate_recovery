import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/van_mate/pages/van_business_profile_page.dart',
    ).readAsStringSync();
  });

  test(
    'Business Profile keeps controllers outside build and avoids typing listeners',
    () {
      expect(
        RegExp(
          r'final TextEditingController _\w+Controller',
        ).allMatches(source),
        isNotEmpty,
      );
      expect(source, isNot(contains('.addListener(')));
      expect(source, isNot(contains('onChanged: (text)')));
      expect(source, contains('return RepaintBoundary('));
    },
  );

  test('Business Profile uses the expected contact keyboards', () {
    expect(
      source,
      contains(
        'controller: _phoneController,\n'
        "                              label: 'Phone number',\n"
        "                              hint: 'Phone number',\n"
        '                              keyboardType: TextInputType.phone,',
      ),
    );
    expect(source, contains('keyboardType: TextInputType.emailAddress'));
    expect(source, contains('keyboardType: TextInputType.url'));
    expect(
      source,
      contains(
        'controller: _accountNumberController,\n'
        "                              label: 'Bank account number',\n"
        "                              hint: '12345678',\n"
        '                              keyboardType: TextInputType.number,',
      ),
    );
  });

  test('bank inputs disable suggestions and personalized learning', () {
    for (final controller in <String>[
      '_bankNameController',
      '_accountNameController',
      '_sortCodeController',
      '_accountNumberController',
    ]) {
      final start = source.indexOf('controller: $controller');
      expect(start, greaterThanOrEqualTo(0));
      final fieldSource = source.substring(start, start + 750);
      expect(fieldSource, contains('autofillHints: null'));
      expect(fieldSource, contains('enableSuggestions: false'));
      expect(fieldSource, contains('autocorrect: false'));
      expect(fieldSource, contains('enableIMEPersonalizedLearning: false'));
    }
  });

  test('VAT uses a done action while other single-line fields use next', () {
    expect(source, contains('isFinalField: true'));
    expect(source, contains('TextInputAction.done'));
    expect(source, contains('TextInputAction.next'));
    expect(source, contains('FocusScope.of(context).unfocus()'));
  });
}
