import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_mate_app/features/van_mate/models/van_business_profile_settings.dart';
import 'package:van_mate_app/features/van_mate/services/van_business_profile_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'business profile quick extra defaults persist through settings and legacy profile',
    () async {
      final storage = VanBusinessProfileStorage.instance;

      try {
        await storage.saveSettings(
          const VanBusinessProfileSettings(
            businessName: 'Van Mate',
            ownerName: 'Driver',
            businessType: '',
            phoneNumber: '',
            emailAddress: '',
            websiteOrSocialLink: '',
            addressLine1: '',
            addressLine2: '',
            townOrCity: '',
            postcode: '',
            bankName: '',
            accountName: '',
            sortCode: '',
            accountNumber: '',
            paymentNotes: '',
            vatRegistered: false,
            vatNumber: '',
            defaultInvoiceNotes: '',
            defaultPaymentTerms: '',
            thankYouMessage: '',
            defaultExtraHelperAmount: 20,
            defaultStairsAccessAmount: 10,
            defaultWaitingTimeAmount: 15,
            defaultCollectionDeliveryAmount: 12.5,
            defaultMileageRate: 1.75,
          ),
        );
      } catch (_) {
        // saveSettings writes local values before optional Firebase sync.
      }

      final settings = await storage.loadSettings();
      final profile = await storage.load();

      expect(settings.defaultExtraHelperAmount, 20);
      expect(settings.defaultStairsAccessAmount, 10);
      expect(settings.defaultWaitingTimeAmount, 15);
      expect(settings.defaultCollectionDeliveryAmount, 12.5);
      expect(settings.defaultMileageRate, 1.75);

      expect(profile.defaultExtraHelperAmount, 20);
      expect(profile.defaultStairsAccessAmount, 10);
      expect(profile.defaultWaitingTimeAmount, 15);
      expect(profile.defaultCollectionDeliveryAmount, 12.5);
      expect(profile.defaultMileageRate, 1.75);
    },
  );
}
