import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advanced service editor keeps post-setup question flexibility', () {
    final wizard = File(
      'lib/features/van_mate/pages/van_service_wizard_page.dart',
    ).readAsStringSync();
    final questionEditor = File(
      'lib/features/van_mate/pages/van_service_question_editor_page.dart',
    ).readAsStringSync();

    expect(wizard, contains("'Choose questions'"));
    expect(wizard, contains("'Configure questions'"));
    expect(wizard, contains("'What would you like to ask your customers?'"));
    expect(wizard, contains("title: 'Suggested for your business'"));
    expect(wizard, contains("title: 'Browse more questions'"));
    expect(wizard, contains("'Selected Questions'"));
    expect(wizard, contains("'Configure extras'"));
    expect(wizard, contains("label: 'Address'"));
    expect(wizard, contains("label: 'Measurements'"));
    expect(wizard, contains("label: 'Vehicle Details'"));
    expect(wizard, contains("label: 'Mileage'"));
    expect(wizard, contains("label: 'Emergency Call-out'"));
    expect(wizard, contains("label: 'Gift Wrapping'"));
    expect(wizard, contains("'Create Custom Question'"));
    expect(wizard, contains("'Add Custom Extra'"));
    expect(wizard, isNot(contains('_configuringQuestions')));
    expect(wizard, contains('_configuringExtras'));
    expect(questionEditor, contains("label: 'Answer options'"));
    expect(questionEditor, contains('choiceOptions.length < 2'));
  });

  test('business capability packs are browsed only inside the wizard', () {
    final servicesPage = File(
      'lib/features/van_mate/pages/van_job_types_services_page.dart',
    ).readAsStringSync();
    final wizard = File(
      'lib/features/van_mate/pages/van_service_wizard_page.dart',
    ).readAsStringSync();

    expect(servicesPage, contains("label: const Text('Create Service')"));
    expect(servicesPage, isNot(contains("'Suggested Services'")));
    expect(servicesPage, isNot(contains('_addServiceFromTemplate')));
    expect(wizard, contains("'Set Up My Business'"));
    expect(wizard, contains("label: const Text('Choose Business Type')"));
    expect(wizard, isNot(contains("'How would you like to start?'")));
    expect(wizard, isNot(contains("'Create From Scratch'")));
    expect(wizard, isNot(contains('Create one service from scratch instead')));
    expect(wizard, contains('kVanStarterCapabilityPacks'));
    expect(wizard, contains("hintText: 'Search businesses...'"));
    expect(wizard, contains("title: 'Popular businesses'"));
    expect(wizard, contains("'Browse businesses'"));
    expect(wizard, contains('_recentBusinessChoices'));
    expect(wizard, contains('_BusinessCategoryCard'));
    expect(wizard, contains("'Which services do you offer?'"));
    expect(wizard, contains('_createRecommendedServices'));
    expect(wizard, contains("creationSource: 'capabilityBuilder'"));
    expect(wizard, contains("label: const Text('Review Business')"));
    expect(wizard, contains('_ServiceCapabilitiesCard'));
    expect(wizard, contains("label: const Text('Choose Pricing Extras')"));
    expect(wizard, contains("label: const Text('Add Custom Extra')"));
    expect(wizard, contains("'When are these services available?'"));
    expect(wizard, contains("'Review business'"));
    expect(servicesPage, contains('reviewServiceIds'));
    expect(servicesPage, contains("'Service Features'"));
    expect(servicesPage, contains("'Customer Questions'"));
    expect(servicesPage, contains("'Pricing Extras'"));
    expect(servicesPage, contains("'Use Defaults & Continue'"));
    expect(wizard, isNot(contains('recommended capabilities')));
    expect(wizard, isNot(contains('Choose service capabilities')));
    expect(wizard, contains('kVanServiceCapabilities'));
    expect(wizard, contains('VanServiceWizardBuildResult'));
    expect(servicesPage, contains('result is VanServiceWizardBuildResult'));
    expect(wizard, contains('existingServiceIds'));
    expect(wizard, contains("service.id.startsWith("));
    expect(servicesPage, contains("label: 'Edit existing'"));
    expect(servicesPage, contains('SnackBarBehavior.floating'));
    expect(servicesPage, contains('VanJobServiceDetailPage'));
    expect(wizard, contains('if (existingMatch != null)'));
    expect(wizard, contains('existingMatches.add(existingMatch)'));
    expect(wizard, contains('...existingServices'));
  });

  test('selected built-ins are published to both customer experiences', () {
    final cloud = File(
      'lib/features/van_mate/services/van_booking_link_cloud_service.dart',
    ).readAsStringSync();
    final hostedPage = File('web/booking_link.html').readAsStringSync();
    final functions = File('functions/index.js').readAsStringSync();

    expect(cloud, contains("'showPhoneNumber'"));
    expect(cloud, contains("'builtInQuestionSettings'"));
    expect(cloud, contains("'maxCustomerPhotos'"));
    expect(cloud, contains("'customerMessage'"));
    expect(cloud, contains("'appointmentDurationMinutes'"));
    expect(hostedPage, contains('service.showPhoneNumber !== false'));
    expect(hostedPage, contains('readText(service.customerMessage)'));
    expect(hostedPage, contains('photoLimitForService'));
    expect(functions, contains('selectedService.requirePhoneNumber !== false'));
    expect(functions, contains('photoSettings && photoSettings.required'));
  });
}
