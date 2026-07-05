import 'package:flutter_test/flutter_test.dart';

import 'package:van_mate_app/features/van_mate/models/van_job_request_record.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/pages/van_incoming_requests_page.dart';

void main() {
  test('incoming jobs sort stays stable when only updatedAt changes', () {
    final olderJob = DriverCustomerReplyMockData(
      jobId: 'job-a',
      customerName: 'Alex',
      jobTitle: 'Flat move',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '1 Alpha Street',
      phoneNumber: '07111111111',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      requestId: 'request-a',
      createdAt: DateTime.parse('2026-06-10T09:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-13T10:00:00.000Z'),
    );
    final newerJob = DriverCustomerReplyMockData(
      jobId: 'job-b',
      customerName: 'Blake',
      jobTitle: 'Storage run',
      scheduledAt: null,
      jobDateLabel: '',
      jobTimeLabel: '',
      address: '2 Beta Street',
      phoneNumber: '07222222222',
      exactPinShared: false,
      checklistResponses: const <DriverChecklistResponse>[],
      customQuestionResponses: const <DriverCustomQuestionResponse>[],
      additionalNotes: '',
      requestId: 'request-b',
      createdAt: DateTime.parse('2026-06-11T09:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-12T10:00:00.000Z'),
    );

    final requestsByJobId = <String, VanJobRequestRecord>{
      'job-a': _requestRecord(
        requestId: 'request-a',
        jobId: 'job-a',
        createdAt: DateTime.parse('2026-06-10T09:00:00.000Z'),
        updatedAt: DateTime.parse('2026-06-13T10:00:00.000Z'),
        customerName: 'Alex',
      ),
      'job-b': _requestRecord(
        requestId: 'request-b',
        jobId: 'job-b',
        createdAt: DateTime.parse('2026-06-11T09:00:00.000Z'),
        updatedAt: DateTime.parse('2026-06-12T10:00:00.000Z'),
        customerName: 'Blake',
      ),
    };

    final sorted = sortIncomingJobsForDisplay(<DriverCustomerReplyMockData>[
      olderJob,
      newerJob,
    ], requestForJob: (jobId) => requestsByJobId[jobId]);

    expect(sorted.map((job) => job.jobId).toList(), <String>['job-b', 'job-a']);
  });

  test(
    'incoming jobs sort falls back to request id when createdAt matches',
    () {
      final createdAt = DateTime.parse('2026-06-12T09:00:00.000Z');
      final firstJob = DriverCustomerReplyMockData(
        jobId: 'job-z',
        customerName: 'Zoe',
        jobTitle: 'Office move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '9 Zeta Road',
        phoneNumber: '07999999999',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        requestId: 'request-z',
        createdAt: createdAt,
      );
      final secondJob = DriverCustomerReplyMockData(
        jobId: 'job-a',
        customerName: 'Ava',
        jobTitle: 'Box delivery',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '1 Able Road',
        phoneNumber: '07000000000',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        requestId: 'request-a',
        createdAt: createdAt,
      );

      final requestsByJobId = <String, VanJobRequestRecord>{
        'job-z': _requestRecord(
          requestId: 'request-z',
          jobId: 'job-z',
          createdAt: createdAt,
          updatedAt: createdAt,
          customerName: 'Zoe',
        ),
        'job-a': _requestRecord(
          requestId: 'request-a',
          jobId: 'job-a',
          createdAt: createdAt,
          updatedAt: createdAt,
          customerName: 'Ava',
        ),
      };

      final sorted = sortIncomingJobsForDisplay(<DriverCustomerReplyMockData>[
        firstJob,
        secondJob,
      ], requestForJob: (jobId) => requestsByJobId[jobId]);

      expect(sorted.map((job) => job.jobId).toList(), <String>[
        'job-a',
        'job-z',
      ]);
    },
  );

  test(
    'incoming job stable key prefers request id and never uses list index',
    () {
      final job = DriverCustomerReplyMockData(
        jobId: 'job-123',
        customerName: 'Casey',
        jobTitle: 'Student move',
        scheduledAt: null,
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '3 Gamma Street',
        phoneNumber: '07333333333',
        exactPinShared: false,
        checklistResponses: const <DriverChecklistResponse>[],
        customQuestionResponses: const <DriverCustomQuestionResponse>[],
        additionalNotes: '',
        requestId: 'request-123',
      );

      expect(
        incomingJobStableKey(
          job,
          request: _requestRecord(
            requestId: 'request-123',
            jobId: 'job-123',
            createdAt: DateTime.parse('2026-06-12T09:00:00.000Z'),
            updatedAt: DateTime.parse('2026-06-12T09:00:00.000Z'),
            customerName: 'Casey',
          ),
        ),
        'incoming-request-123',
      );
    },
  );
}

VanJobRequestRecord _requestRecord({
  required String requestId,
  required String jobId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String customerName,
}) {
  return VanJobRequestRecord(
    requestId: requestId,
    ownerUid: 'owner-1',
    jobId: jobId,
    linkedJobId: jobId,
    status: 'submitted',
    createdAt: createdAt,
    updatedAt: updatedAt,
    expiresAt: createdAt.add(const Duration(days: 7)),
    publicJobTitle: 'Service request',
    publicCustomerName: customerName,
    publicAddressSummary: 'Test address',
    checklistItems: const <String>[],
    customQuestions: const <String>[],
    exactPinRequested: false,
  );
}
