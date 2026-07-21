import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/pages/van_booking_link_page.dart';

void main() {
  testWidgets('public booking form renders a manually configured service', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 7, 21);
    final question = VanCustomJobQuestion(
      id: 'manual-question',
      questionText: 'What should we know?',
      helperText: 'Optional supporting detail.',
      answerType: VanCustomQuestionAnswerType.longText,
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    final service = VanJobService(
      id: 'manual-service',
      name: 'Manual Booking Service',
      description: 'Configured without a template.',
      isActive: true,
      requestPhotos: false,
      requireAddress: false,
      requestExactPinAfterQuoteAccepted: false,
      linkedQuestionIds: <String>[question.id],
      quoteExtraDefaults: VanQuoteExtraDefaults.empty(),
      createdAt: now,
      updatedAt: now,
      creationSource: 'blank',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VanBookingLinkCustomerFormPage(
          profile: const VanBusinessProfile.defaults().copyWith(
            businessName: 'Manual Test Business',
          ),
          activeServices: <VanJobService>[service],
          questionLookup: <String, VanCustomJobQuestion>{question.id: question},
          bookingLinkActive: true,
          bookingLinkUrl: '',
          bookingLinkTitle: 'Manual Test Business',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manual Booking Service'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text(question.questionText),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(question.questionText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
