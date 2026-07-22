import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final detail = File(
    'lib/features/van_mate/pages/job_detail_page.dart',
  ).readAsStringSync();
  final incoming = File(
    'lib/features/van_mate/pages/van_incoming_requests_page.dart',
  ).readAsStringSync();
  final calendar = File(
    'lib/features/van_mate/pages/jobs_calendar_page.dart',
  ).readAsStringSync();
  final state = File(
    'lib/features/van_mate/pages/driver_customer_reply_mock_page.dart',
  ).readAsStringSync();

  test('all active normal deletion routes share confirmDriverJobDelete', () {
    expect(detail, contains('confirmDriverJobDelete(context, job: reply)'));
    expect(calendar, contains('confirmDriverJobDelete(context, job: job)'));
    expect(incoming, contains('confirmDriverJobDelete(context, job: job)'));
    expect(incoming, isNot(contains('state.deleteIncomingRequest(')));
  });

  test('active state deletion uses the canonical callable service', () {
    expect(state, contains('_jobDeletionService.deleteOne('));
    expect(state, contains('applyConfirmedJobDeletionResults('));
    expect(
      state,
      contains(
        "@Deprecated('Use the canonical server-authoritative deleteJob flow.')",
      ),
    );
    expect(calendar, isNot(contains('debugClearAllSavedJobFlowData')));
  });

  test('developer modes use preview and the same execution service', () {
    expect(calendar, contains('VanJobDeletionSelection.testJobs'));
    expect(calendar, contains('VanJobDeletionSelection.allOperational'));
    expect(calendar, contains('service.preview(selection: selection)'));
    expect(calendar, contains('service.execute('));
  });
}
