import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_job_request_state.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_draft.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/create_job_request_flow.dart';

VanJobRequestDraft _draft({
  String customerName = 'Customer',
  String phoneNumber = '07123456789',
  String customerEmail = '',
  String jobTitle = 'Move',
  String address = '',
  String postcode = '',
  bool requiresExactPinAfterQuoteAccepted = false,
}) {
  return VanJobRequestDraft(
    jobId: 'job-1',
    customerName: customerName,
    phoneNumber: phoneNumber,
    customerEmail: customerEmail,
    jobTitle: jobTitle,
    scheduledAt: DateTime(2026, 6, 18, 10),
    jobDateLabel: 'Today',
    jobTimeLabel: '10:00',
    address: address,
    postcode: postcode,
    requestExactPin: false,
    requestPhotos: false,
    requiresExactPinAfterQuoteAccepted: requiresExactPinAfterQuoteAccepted,
    selectedQuestionIds: const <String>[],
    answers: const <VanJobRequestAnswer>[],
    checklistItems: const <String>[],
    customQuestions: const <String>[],
    locationPending:
        requiresExactPinAfterQuoteAccepted &&
        address.trim().isEmpty &&
        postcode.trim().isEmpty,
  );
}

void main() {
  group('validateVanJobRequestDraftForSend', () {
    test('requires location when exact pin after quote is off', () {
      final message = validateVanJobRequestDraftForSend(
        _draft(requiresExactPinAfterQuoteAccepted: false),
      );

      expect(message, 'Add an address or switch on exact pin request.');
    });

    test('allows missing location when exact pin after quote is on', () {
      final message = validateVanJobRequestDraftForSend(
        _draft(requiresExactPinAfterQuoteAccepted: true),
      );

      expect(message, isNull);
    });

    test('requires a job title or reference', () {
      final message = validateVanJobRequestDraftForSend(
        _draft(jobTitle: '', requiresExactPinAfterQuoteAccepted: true),
      );

      expect(message, 'Please add the customer and job details first.');
    });

    test('requires a phone or email contact method', () {
      final message = validateVanJobRequestDraftForSend(
        _draft(phoneNumber: '', customerEmail: ''),
      );

      expect(message, 'Please add the customer and job details first.');
    });
  });

  group('buildVanJobLocationSummary', () {
    test('returns location pending when location is deferred', () {
      final summary = buildVanJobLocationSummary(
        address: '',
        postcode: '',
        locationPending: true,
        requiresExactPinAfterQuoteAccepted: true,
        hasExactPin: false,
      );

      expect(summary, 'Location pending');
    });

    test('combines address and postcode when available', () {
      final summary = buildVanJobLocationSummary(
        address: '10 High Street',
        postcode: 'SW1A 1AA',
        locationPending: false,
        requiresExactPinAfterQuoteAccepted: false,
        hasExactPin: false,
      );

      expect(summary, '10 High Street • SW1A 1AA');
    });
  });
}
