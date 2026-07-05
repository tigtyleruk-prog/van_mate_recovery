import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _job({
  required String status,
  String requestStatus = '',
  String calendarStatus = '',
  DateTime? completedAt,
}) {
  return DriverCustomerReplyMockData(
    jobId: 'job-1',
    customerName: 'Taylor',
    jobTitle: 'Sofa move',
    scheduledAt: DateTime.parse('2026-06-18T10:00:00.000Z'),
    jobDateLabel: '18 Jun 2026',
    jobTimeLabel: '10:00',
    address: '10 Market Road',
    phoneNumber: '07123456789',
    exactPinShared: true,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: status,
    requestStatus: requestStatus,
    calendarStatus: calendarStatus,
    completedAt: completedAt,
  );
}

void main() {
  group('completed jobs active list filtering', () {
    test('completedAt alone makes a scheduled job count as completed', () {
      final job = _job(
        status: 'scheduled',
        requestStatus: 'confirmed',
        calendarStatus: 'scheduled',
        completedAt: DateTime.parse('2026-06-18T12:30:00.000Z'),
      );

      expect(job.isCompletedJob, isTrue);
      expect(debugBucketDecisionForJob(job).bucket, VanJobBucket.completedJob);
    });

    test('completed calendar status keeps a job out of active buckets', () {
      final job = _job(
        status: 'scheduled',
        requestStatus: 'confirmed',
        calendarStatus: 'completed',
      );

      expect(job.isCompletedJob, isTrue);
      expect(job.isPendingCustomerRequest, isFalse);
      expect(debugBucketDecisionForJob(job).bucket, VanJobBucket.completedJob);
    });

    test('completed signals survive status drift back to scheduled', () {
      final completed = _job(
        status: 'completed',
        requestStatus: 'completed',
        calendarStatus: 'completed',
        completedAt: DateTime.parse('2026-06-18T12:30:00.000Z'),
      );
      final drifted = completed.copyWith(
        status: 'scheduled',
        requestStatus: 'confirmed',
      );

      expect(drifted.isCompletedJob, isTrue);
      expect(
        debugBucketDecisionForJob(drifted).bucket,
        VanJobBucket.completedJob,
      );
    });

    test(
      'completed signals survive JSON reload without returning to active',
      () {
        final completed = _job(
          status: 'scheduled',
          requestStatus: 'confirmed',
          calendarStatus: 'completed',
          completedAt: DateTime.parse('2026-06-18T12:30:00.000Z'),
        );
        final reloaded = DriverCustomerReplyMockData.fromJson(
          completed.toJson(),
        );

        expect(reloaded.isCompletedJob, isTrue);
        expect(
          debugBucketDecisionForJob(reloaded).bucket,
          VanJobBucket.completedJob,
        );
      },
    );
  });
}
