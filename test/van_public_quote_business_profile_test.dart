import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/services/van_public_quote_cloud_service.dart';

void main() {
  test(
    'quote publish uses one trimmed profile across quote, token, and job',
    () {
      final fields = buildVanQuoteBusinessProfileFields(
        requestedBusinessProfileId: '  bakery-profile  ',
      );

      final quote = <String, dynamic>{...fields};
      final token = <String, dynamic>{...fields};
      final fallbackJob = <String, dynamic>{...fields};

      expect(quote['businessProfileId'], 'bakery-profile');
      expect(token['businessProfileId'], 'bakery-profile');
      expect(fallbackJob['businessProfileId'], 'bakery-profile');
      expect(
        <String>{
          quote['businessProfileId'] as String,
          token['businessProfileId'] as String,
          fallbackJob['businessProfileId'] as String,
        },
        <String>{'bakery-profile'},
      );
    },
  );

  test('existing job profile is retained when incoming profile is empty', () {
    final fields = buildVanQuoteBusinessProfileFields(
      requestedBusinessProfileId: ' ',
      existingJob: <String, dynamic>{'businessProfileId': '  existing  '},
    );

    expect(fields, <String, dynamic>{'businessProfileId': 'existing'});
  });

  test('existing quote or token profile is retained without a new profile', () {
    expect(
      buildVanQuoteBusinessProfileFields(
        requestedBusinessProfileId: '',
        existingQuote: <String, dynamic>{'businessProfileId': 'quote-scope'},
      ),
      <String, dynamic>{'businessProfileId': 'quote-scope'},
    );
    expect(
      buildVanQuoteBusinessProfileFields(
        requestedBusinessProfileId: '',
        existingToken: <String, dynamic>{'businessProfileId': 'token-scope'},
      ),
      <String, dynamic>{'businessProfileId': 'token-scope'},
    );
  });

  test('empty incoming profile cannot erase a valid existing profile', () {
    final fields = buildVanQuoteBusinessProfileFields(
      requestedBusinessProfileId: '',
      existingJob: <String, dynamic>{'businessProfileId': 'valid-scope'},
      existingQuote: <String, dynamic>{'businessProfileId': 'valid-scope'},
      existingToken: <String, dynamic>{'businessProfileId': 'valid-scope'},
    );

    expect(fields['businessProfileId'], 'valid-scope');
    expect(fields.containsKey('businessProfileId'), isTrue);
  });

  test(
    'order request and quote request use the same profile propagation rule',
    () {
      for (final requestType in <String>['orderRequest', 'quoteRequest']) {
        final fields = buildVanQuoteBusinessProfileFields(
          requestedBusinessProfileId: 'profile-for-$requestType',
        );
        expect(fields['businessProfileId'], 'profile-for-$requestType');
      }
    },
  );

  test(
    'no profile is written when neither context nor stored values has one',
    () {
      expect(
        buildVanQuoteBusinessProfileFields(requestedBusinessProfileId: ' '),
        isEmpty,
      );
    },
  );
}
