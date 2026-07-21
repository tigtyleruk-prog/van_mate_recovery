import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile.dart';
import 'package:van_mate_app/features/van_mate/models/van_custom_job_question.dart';
import 'package:van_mate_app/features/van_mate/models/van_job_service.dart';
import 'package:van_mate_app/features/van_mate/models/van_quote_extra_defaults.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_custom_job_questions_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_job_services_storage.dart';
import 'package:van_mate_app/features/van_mate/services/van_quote_extra_defaults_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'business profiles isolate services questions and quote extras',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'van_business_name': "Dave's Delivery Services",
      });

      final profileScope = VanBusinessProfileScopeStorage.instance;
      final businessProfileStorage = VanBusinessProfileStorage.instance;
      final servicesStorage = VanJobServicesStorage.instance;
      final questionsStorage = VanCustomJobQuestionsStorage.instance;
      final extrasStorage = VanQuoteExtraDefaultsStorage.instance;

      final defaultProfile = await profileScope.activeProfile();
      expect(defaultProfile.name, "Dave's Delivery Services");
      await businessProfileStorage.save(
        const VanBusinessProfile.defaults().copyWith(
          businessName: "Dave's Delivery Services",
        ),
        syncCloud: false,
      );

      final gardeningProfile = await profileScope.addProfile(
        "Dave's Gardening",
      );
      await businessProfileStorage.save(
        const VanBusinessProfile.defaults().copyWith(
          businessName: "Dave's Gardening",
        ),
        syncCloud: false,
      );

      final now = DateTime(2026, 7, 10);
      final gardeningQuestions = <VanCustomJobQuestion>[
        VanCustomJobQuestion(
          id: 'manual_question',
          questionText: 'What should we know?',
          helperText: 'Add any useful details.',
          answerType: VanCustomQuestionAnswerType.longText,
          isActive: true,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await questionsStorage.saveAll(gardeningQuestions, syncCloud: false);

      final gardeningExtras = VanQuoteExtraDefaults.empty()
          .copyWithCustomExtras(<VanQuoteExtraDefault>[
            VanQuoteExtraDefault.custom(
              key: 'custom_extra_soil_disposal',
              label: 'Soil disposal',
              defaultPrice: 20,
            ),
          ]);
      await extrasStorage.saveForService(
        serviceKey: 'manual-service',
        serviceName: 'Manual service',
        defaults: gardeningExtras,
      );
      await servicesStorage.saveAll(<VanJobService>[
        VanJobService(
          id: 'manual-service',
          name: 'Manual service',
          description: 'Configured without a seeded template.',
          isActive: true,
          requestPhotos: true,
          requireAddress: true,
          requestExactPinAfterQuoteAccepted: true,
          linkedQuestionIds: gardeningQuestions
              .map((question) => question.id)
              .toList(growable: false),
          quoteExtraDefaults: gardeningExtras,
          createdAt: now,
          updatedAt: now,
        ),
      ], syncCloud: false);

      await profileScope.switchProfile(defaultProfile.id);
      expect(await servicesStorage.loadAll(), isEmpty);
      expect(await questionsStorage.loadAll(), isEmpty);
      expect(
        (await businessProfileStorage.load()).businessName,
        "Dave's Delivery Services",
      );
      final defaultExtras = await extrasStorage.loadForService(
        serviceKey: 'manual-service',
        serviceName: 'Manual service',
        preferLocal: true,
      );
      expect(
        defaultExtras.enabledExtras.map((extra) => extra.resolvedLabel),
        isNot(contains('Soil disposal')),
      );

      await profileScope.switchProfile(gardeningProfile.id);
      final restoredServices = await servicesStorage.loadAll();
      final restoredQuestions = await questionsStorage.loadAll();
      final restoredExtras = await extrasStorage.loadForService(
        serviceKey: 'manual-service',
        serviceName: 'Manual service',
        preferLocal: true,
      );

      expect(restoredServices.single.name, 'Manual service');
      expect(
        restoredQuestions.map((question) => question.questionText),
        contains('What should we know?'),
      );
      expect(
        restoredExtras.enabledExtras.map((extra) => extra.resolvedLabel),
        contains('Soil disposal'),
      );
      expect(
        restoredExtras.extraForKey('custom_extra_soil_disposal').defaultPrice,
        20,
      );
    },
  );
}
