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

  test('service creation is the only production legacy-wizard entry', () {
    final servicesSource = File(
      'lib/features/van_mate/pages/van_job_types_services_page.dart',
    ).readAsStringSync();
    final wizardSource = File(
      'lib/features/van_mate/pages/van_service_wizard_page.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'VanServiceCreationEntryPage\(',
      ).allMatches(servicesSource).length,
      1,
      reason: 'Only the new-service identity/preflight route may enter it.',
    );
    expect(
      servicesSource,
      contains('builder: (_) => const VanServiceCreationEntryPage()'),
    );
    expect(servicesSource, isNot(contains('class VanJobServiceEditorPage')));
    expect(
      servicesSource,
      isNot(contains('class _LegacyVanJobServiceEditorPage')),
    );
    expect(
      servicesSource,
      isNot(contains('class _VanServiceFeaturesEditorPage')),
    );
    expect(wizardSource, contains("_creationSource == 'blank' &&"));
    expect(wizardSource, contains("'Continue to Service Features'"));
  });
}
