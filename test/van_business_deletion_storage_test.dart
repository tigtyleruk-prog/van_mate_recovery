import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_deletion_service.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_scope_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'profile deletion switches safely and creates setup fallback when last',
    () async {
      final now = DateTime(2026, 7, 20);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'van_business_profiles_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'default_business',
            'name': 'Delivery Team',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
          <String, dynamic>{
            'id': 'garden_team_42',
            'name': 'Garden Team',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        ]),
        'van_active_business_profile_id_v1': 'default_business',
      });

      final storage = VanBusinessProfileScopeStorage.instance;
      final switched = await storage.deleteProfile('default_business');
      expect(switched.requiresBusinessSetup, isFalse);
      expect(switched.activeProfile.id, 'garden_team_42');
      expect(
        (await storage.loadProfiles()).map((profile) => profile.id),
        <String>['garden_team_42'],
      );

      final setup = await storage.deleteProfile('garden_team_42');
      expect(setup.requiresBusinessSetup, isTrue);
      expect(setup.activeProfile.id, 'default_business');
      expect(setup.activeProfile.name, 'New business');
      expect((await storage.loadProfiles()).length, 1);
    },
  );

  test('configuration cleanup removes active copies after archiving', () {
    expect(
      isBusinessDeletionConfigurationKey(
        'van_job_services_v1_business_garden_team_42',
        businessProfileId: 'garden_team_42',
      ),
      isTrue,
    );
    expect(
      isBusinessDeletionConfigurationKey(
        'van_business_profile_settings_bank_name_business_garden_team_42',
        businessProfileId: 'garden_team_42',
      ),
      isTrue,
    );
    expect(
      isBusinessDeletionConfigurationKey(
        'van_expenses_v1_business_garden_team_42',
        businessProfileId: 'garden_team_42',
      ),
      isTrue,
    );
    expect(
      isBusinessDeletionConfigurationKey(
        'van_invoice_next_number_business_garden_team_42',
        businessProfileId: 'garden_team_42',
      ),
      isTrue,
    );
    expect(
      isBusinessDeletionConfigurationKey(
        'van_job_services_v1_business_other_team',
        businessProfileId: 'garden_team_42',
      ),
      isFalse,
    );
  });

  test('local archive retains invoices, expenses and completed jobs only', () {
    final archive = buildDeletedBusinessFinancialArchive(
      businessProfileId: 'garden_team_42',
      businessName: 'Garden Team',
      archivedAt: DateTime.utc(2026, 7, 20),
      driverState: <String, dynamic>{
        'invoiceHistory': <Map<String, dynamic>>[
          <String, dynamic>{'jobKey': 'invoice-job'},
        ],
        'jobs': <Map<String, dynamic>>[
          <String, dynamic>{'jobId': 'done', 'status': 'completed'},
          <String, dynamic>{'jobId': 'active', 'status': 'pending'},
        ],
      },
      expenses: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'expense-1', 'amount': 25},
      ],
    );

    expect(archive['readOnly'], isTrue);
    expect((archive['invoices'] as List), hasLength(1));
    expect((archive['expenses'] as List), hasLength(1));
    expect((archive['completedJobs'] as List), hasLength(1));
    expect(((archive['completedJobs'] as List).single as Map)['jobId'], 'done');
  });
}
