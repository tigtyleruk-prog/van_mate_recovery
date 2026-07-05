import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_customer_request_actions.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';

void main() {
  test('builds short hosted request links when short code is present', () {
    expect(
      buildVanJobRequestHostedLink('request-123', shortCode: 'a7k9q2'),
      'https://vanmate-56eac.web.app/r/A7K9Q2',
    );
  });

  test('falls back to legacy hosted request links without a short code', () {
    expect(
      buildVanJobRequestHostedLink('request-123'),
      'https://vanmate-56eac.web.app/request.html?id=request-123',
    );
  });

  test('extracts short code from a request link', () {
    expect(
      extractVanJobRequestShortCodeFromLink(
        'https://vanmate-56eac.web.app/r/a7k9q2',
      ),
      'A7K9Q2',
    );
    expect(
      extractVanJobRequestShortCodeFromLink(
        'https://vanmate-56eac.web.app/request.html?id=request-123',
      ),
      '',
    );
  });

  test('resolves display link to short link when short code exists', () {
    expect(
      resolveVanJobRequestDisplayLink(
        requestId: 'request-123',
        requestLink:
            'https://vanmate-56eac.web.app/request.html?id=request-123',
        shortCode: 'A7K9Q2',
      ),
      'https://vanmate-56eac.web.app/r/A7K9Q2',
    );
  });

  test('request share message includes the short link', () {
    final message = buildRequestShareMessage(
      link: 'https://vanmate-56eac.web.app/r/A7K9Q2',
      customerName: 'Jamie',
      jobTitle: 'TV cabinet',
      businessName: 'Van Mate',
      exactPinRequestedAfterQuoteAccepted: true,
    );

    expect(message, contains('https://vanmate-56eac.web.app/r/A7K9Q2'));
    expect(
      message,
      contains(
        'Please fill in this quick job request so I can prepare your quote.',
      ),
    );
    expect(
      message,
      contains(
        'If you accept the quote later, I\'ll then ask for the exact pickup/drop-off pin.',
      ),
    );
  });

  test('request share message omits the exact pin sentence when disabled', () {
    final message = buildRequestShareMessage(
      link: 'https://vanmate-56eac.web.app/r/A7K9Q2',
      customerName: 'Jamie',
      jobTitle: 'TV cabinet',
      businessName: 'Van Mate',
      exactPinRequestedAfterQuoteAccepted: false,
    );

    expect(
      message,
      contains(
        'Please fill in this quick job request so I can prepare your quote.',
      ),
    );
    expect(
      message,
      isNot(contains('I\'ll then ask for the exact pickup/drop-off pin.')),
    );
  });

  test('request record preserves short code across serialization', () {
    final request = VanJobRequestRecord.fromJson(<String, dynamic>{
      'requestId': 'request-123',
      'ownerUid': 'owner-1',
      'jobId': 'job-1',
      'linkedJobId': 'job-1',
      'shortCode': 'a7k9q2',
      'status': 'request_sent',
      'createdAt': '2026-06-19T09:00:00.000Z',
      'updatedAt': '2026-06-19T09:30:00.000Z',
      'expiresAt': '2026-06-26T09:00:00.000Z',
      'publicJobTitle': 'TV cabinet',
      'publicCustomerName': 'Jamie',
      'publicAddressSummary': '12 Station Road',
      'checklistItems': const <String>[],
      'customQuestions': const <String>[],
      'exactPinRequested': false,
    });

    expect(request.shortCode, 'A7K9Q2');
    expect(request.toJson()['shortCode'], 'A7K9Q2');
    expect(request.toPublicFirestore()['shortCode'], 'A7K9Q2');
    expect(request.toPrivateFirestore()['shortCode'], 'A7K9Q2');
  });
}
