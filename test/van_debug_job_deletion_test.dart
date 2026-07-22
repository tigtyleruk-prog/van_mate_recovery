import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';
import 'package:van_mate_app/features/van_mate/pages/jobs_calendar_page.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_deletion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  testWidgets(
    'developer deletion previews exact counts and requires typed confirmation',
    (tester) async {
      final state = DriverReplyMockState.instance;
      state.debugResetStateForTest();
      addTearDown(state.debugResetStateForTest);
      state.debugAddJobForTest(_job('bulk-job'));
      final calls = <Map<String, dynamic>>[];
      final service = VanJobDeletionService(
        activeProfile: () async => VanBusinessProfileSummary(
          id: 'courier-business',
          name: 'Swift Courier',
          createdAt: DateTime.utc(2026, 7, 1),
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
        callable: (data) async {
          calls.add(Map<String, dynamic>.from(data));
          if (data['mode'] == 'preview') {
            return <String, dynamic>{
              'previewToken': 'bulk-preview',
              'confirmationPhrase': 'DELETE SWIFT COURIER JOBS',
              'expiresAt': '2026-07-22T10:15:00.000Z',
              'targets': <Map<String, dynamic>>[
                <String, dynamic>{
                  'jobId': 'bulk-job',
                  'requestId': 'request-bulk-job',
                  'status': 'completed',
                },
              ],
              'summary': <String, dynamic>{
                'jobs': 1,
                'requests': 1,
                'quoteVersions': 2,
                'tokens': 1,
                'photos': 3,
                'invoicesPreserved': 1,
                'ambiguousPreserved': 0,
              },
            };
          }
          return <String, dynamic>{
            'operationId': 'bulk-operation',
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'jobId': 'bulk-job',
                'requestId': 'request-bulk-job',
                'status': 'deleted',
              },
            ],
          };
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JobsCalendarPage(
            jobDeletionService: service,
            refreshOnInit: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Delete marked test jobs'), findsOneWidget);
      expect(find.text('Delete all operational jobs'), findsOneWidget);

      await tester.ensureVisible(find.text('Delete all operational jobs'));
      await tester.tap(find.text('Delete all operational jobs'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Jobs 1 · Requests 1 · Quote versions 2 · Tokens 1 · Photos 3',
        ),
        findsOneWidget,
      );
      expect(find.text('bulk-job · completed'), findsOneWidget);
      final deleteButton = find.widgetWithText(
        FilledButton,
        'Delete permanently',
      );
      expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField).last,
        'DELETE SWIFT COURIER JOBS',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
      await tester.tap(deleteButton);
      await tester.pump();
      await tester.pump();

      expect(calls.first['selection'], 'all_operational');
      expect(calls.last['previewToken'], 'bulk-preview');
      expect(
        state.debugAllLoadedJobs().any((job) => job.jobId == 'bulk-job'),
        isFalse,
      );
    },
  );
}

DriverCustomerReplyMockData _job(String id) => DriverCustomerReplyMockData(
  jobId: id,
  customerName: 'Developer Test',
  jobTitle: 'Test job',
  scheduledAt: DateTime.utc(2026, 7, 20, 10),
  jobDateLabel: '',
  jobTimeLabel: '',
  address: '1 Test Road',
  phoneNumber: '07123456789',
  exactPinShared: false,
  checklistResponses: const <DriverChecklistResponse>[],
  customQuestionResponses: const <DriverCustomQuestionResponse>[],
  additionalNotes: '',
  status: 'completed',
  requestId: 'request-$id',
  requestStatus: 'completed',
  completedAt: DateTime.utc(2026, 7, 20, 11),
  isTestData: true,
  testMode: true,
);
