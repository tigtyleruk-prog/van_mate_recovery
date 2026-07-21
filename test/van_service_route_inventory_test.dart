import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing-service edit entry points share the guided editor helper', () {
    final source = File(
      'lib/features/van_mate/pages/van_job_types_services_page.dart',
    ).readAsStringSync();

    expect(source, contains('Future<bool?> openVanExistingServiceEditor('));
    expect(source, contains('Future<void> _editService('));
    expect(source, contains('Future<void> _configureService({'));
    expect(source, contains('class VanServiceConfigurationPage'));
    expect(source, contains('Future<bool?> openVanServiceConfiguration('));
    expect(
      RegExp(r'openVanServiceConfiguration\(').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
    expect(
      source,
      contains('this.existingServiceConfiguration = true'),
      reason: 'Existing edits must be staged until final save.',
    );
    expect(source, isNot(contains('VanJobServiceEditorPage(initialService:')));
    expect(source, isNot(contains('VanJobServiceEditorPage(duplicateFrom:')));
  });

  test('legacy wizard remains present during the redirect phase', () {
    final source = File(
      'lib/features/van_mate/pages/van_service_wizard_page.dart',
    ).readAsStringSync();

    expect(source, contains("'Basic information'"));
    expect(source, contains("'Review'"));
  });
}
