import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

void main() {
  const quoteId = 'job-quote-link-123';

  test('new quote IDs produce a complete canonical customer URL', () {
    final token = buildVanQuoteResponseToken(quoteId);
    final link = buildVanQuoteResponseLink(quoteId);

    expect(token, hasLength(12));
    expect(link, '$vanQuoteResponseHostedBaseUrl/quote/$token');
    expect(isCompleteVanQuoteResponseLink(link), isTrue);
    expect(vanQuoteResponseIdentifierFromLink(link), token);
  });

  test('quote message contains the exact complete customer URL', () {
    final link = buildVanQuoteResponseLink(quoteId);
    final message = buildVanQuoteMessage(
      customerName: 'Customer',
      jobTitle: 'Same-day Delivery',
      quoteAmountText: 'GBP 185.00',
      quoteResponseLink: link,
    );

    expect(message, contains('Review and respond here:\n$link'));
    final urls = RegExp(r'https?://[^\s]+')
        .allMatches(message)
        .map((match) => match.group(0))
        .whereType<String>()
        .toList(growable: false);
    expect(urls, <String>[link]);

    final smsUri = Uri(
      scheme: 'sms',
      path: '07123456789',
      queryParameters: <String, String>{'body': message},
    );
    expect(smsUri.queryParameters['body'], message);
    expect(smsUri.toString(), contains(Uri.encodeComponent(link)));
  });

  test('all supported current and legacy quote URL formats are recognised', () {
    final token = buildVanQuoteResponseToken(quoteId);
    final links = <String>[
      '$vanQuoteResponseHostedBaseUrl/quote/$token',
      '$vanQuoteResponseHostedBaseUrl/quote?token=$token',
      '$vanQuoteResponseHostedBaseUrl/quote_response.html?token=$token',
      '$vanQuoteResponseHostedBaseUrl/quote_response.html?id=$quoteId',
      '$vanQuoteResponseHostedBaseUrl/quote_response.html?quoteResponseId=$quoteId',
      '$vanQuoteResponseHostedBaseUrl/quote_response.html?quoteId=$quoteId',
    ];

    for (final link in links) {
      expect(isCompleteVanQuoteResponseLink(link), isTrue, reason: link);
    }
    expect(
      buildVanLegacyQuoteResponseLink(quoteId),
      '$vanQuoteResponseHostedBaseUrl/quote_response.html?id=$quoteId',
    );
  });

  test('missing or bare Hosting URLs are rejected', () {
    expect(isCompleteVanQuoteResponseLink(''), isFalse);
    expect(
      isCompleteVanQuoteResponseLink(vanQuoteResponseHostedBaseUrl),
      isFalse,
    );
    expect(
      isCompleteVanQuoteResponseLink('$vanQuoteResponseHostedBaseUrl/quote'),
      isFalse,
    );
    expect(
      isCompleteVanQuoteResponseLink(
        '$vanQuoteResponseHostedBaseUrl/quote_response.html',
      ),
      isFalse,
    );
  });

  test('bare stored links cannot replace a valid generated link', () {
    final token = buildVanQuoteResponseToken(quoteId);
    final canonical = '$vanQuoteResponseHostedBaseUrl/quote/$token';

    expect(
      resolveVanQuoteResponseDisplayLink(
        quoteResponseLink: vanQuoteResponseHostedBaseUrl,
        quoteResponseToken: token,
        quoteId: quoteId,
      ),
      canonical,
    );
    expect(
      resolveVanQuoteResponseDisplayLink(
        quoteResponseLink: vanQuoteResponseHostedBaseUrl,
        quoteId: quoteId,
      ),
      buildVanLegacyQuoteResponseLink(quoteId),
    );
  });

  test('quote is published and verified before any external handoff opens', () {
    final source = File(
      'lib/features/van_mate/pages/driver_customer_reply_mock_page.dart',
    ).readAsStringSync();
    final createQuotePage = source.indexOf('class CreateQuotePage');
    final sendStart = source.indexOf(
      'Future<void> _sendQuote()',
      createQuotePage,
    );
    final sendEnd = source.indexOf('Future<void> _openQuoteLink()', sendStart);
    final sendSource = source.substring(sendStart, sendEnd);

    final publishIndex = sendSource.indexOf(
      'DriverReplyMockState.instance.setQuoteSent',
    );
    final launchIndex = sendSource.indexOf('launchUrl(');
    expect(publishIndex, greaterThanOrEqualTo(0));
    expect(launchIndex, greaterThan(publishIndex));
    expect(sendSource, contains('isCompleteVanQuoteResponseLink'));
    expect(sendSource, contains('publishedQuoteLink != customerQuoteLink'));
    expect(
      sendSource,
      contains(
        'Could not create a valid customer \$_responseDocumentLower link.',
      ),
    );
  });

  test('publisher owns URL identity fields after caller payload merging', () {
    final source = File(
      'lib/features/van_mate/services/van_public_quote_cloud_service.dart',
    ).readAsStringSync();
    final extraDataIndex = source.indexOf('...extraData,');
    final protectedLinkIndex = source.indexOf(
      "'quoteResponseLink': quoteResponseLink,",
      extraDataIndex,
    );
    final protectedTokenIndex = source.indexOf(
      "'quoteResponseToken': quoteResponseToken,",
      extraDataIndex,
    );

    expect(extraDataIndex, greaterThanOrEqualTo(0));
    expect(protectedLinkIndex, greaterThan(extraDataIndex));
    expect(protectedTokenIndex, greaterThan(extraDataIndex));
  });

  test('orderRequest job preserves requestType and customerJourneyType through quote publish payload', () {
    final source = File(
      'lib/features/van_mate/services/van_public_quote_cloud_service.dart',
    ).readAsStringSync();

    expect(source, contains("'requestType': job.requestType.trim()"));
    expect(source, contains('customerJourneyType'));
    expect(source, contains('job.customerJourneyType.trim()'));
  });

  test('orderRequest with serviceFlow order resolves a stable quote response id and valid link', () {
    final job = DriverCustomerReplyMockData(
      jobId: 'order-request-job-1',
      requestId: 'order-request-1',
      requestType: 'orderRequest',
      customerJourneyType: 'order',
      customerName: 'Bakery Customer',
      jobTitle: 'Celebration Cake',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '',
      phoneNumber: '',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      status: 'quoteSent',
      requestStatus: 'quote_sent',
      quoteStatus: 'sent',
      quoteResponseStatus: '',
    );

    final quoteId = DriverReplyMockState.instance.resolveQuoteResponseIdForJob(
      job,
    );
    expect(quoteId, 'order-request-job-1');

    final link = DriverReplyMockState.instance.resolveQuoteResponseLinkForJob(
      job,
    );
    expect(isCompleteVanQuoteResponseLink(link), isTrue);
    expect(link, '$vanQuoteResponseHostedBaseUrl/quote/${buildVanQuoteResponseToken(quoteId)}');
  });
}
