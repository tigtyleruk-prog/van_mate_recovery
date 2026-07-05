import 'package:shared_preferences/shared_preferences.dart';

class VanBusinessHubOnboardingStorage {
  VanBusinessHubOnboardingStorage._();

  static final VanBusinessHubOnboardingStorage instance =
      VanBusinessHubOnboardingStorage._();

  static const String _jobTypesOnboardingDismissedKey =
      'van_job_types_onboarding_dismissed_v1';
  static const String _questionLibraryOnboardingDismissedKey =
      'van_question_library_onboarding_dismissed_v1';
  static const String _serviceDetailSettingsHelpDismissedKey =
      'van_service_detail_settings_help_dismissed_v1';

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isLoaded = true;
  }

  Future<bool> shouldShowJobTypesOnboarding() async {
    await ensureLoaded();
    return !(_preferences?.getBool(_jobTypesOnboardingDismissedKey) ?? false);
  }

  Future<bool> shouldShowQuestionLibraryOnboarding() async {
    await ensureLoaded();
    return !(_preferences?.getBool(_questionLibraryOnboardingDismissedKey) ??
        false);
  }

  Future<bool> shouldShowServiceDetailSettingsHelp() async {
    await ensureLoaded();
    return !(_preferences?.getBool(_serviceDetailSettingsHelpDismissedKey) ??
        false);
  }

  Future<void> dismissJobTypesOnboarding() async {
    await ensureLoaded();
    await _preferences?.setBool(_jobTypesOnboardingDismissedKey, true);
  }

  Future<void> dismissQuestionLibraryOnboarding() async {
    await ensureLoaded();
    await _preferences?.setBool(_questionLibraryOnboardingDismissedKey, true);
  }

  Future<void> dismissServiceDetailSettingsHelp() async {
    await ensureLoaded();
    await _preferences?.setBool(_serviceDetailSettingsHelpDismissedKey, true);
  }
}
