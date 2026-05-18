import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VanMatePremiumService extends ChangeNotifier {
  VanMatePremiumService._();

  static final VanMatePremiumService instance = VanMatePremiumService._();

  static const String _premiumEnabledKey = 'van_mate_is_premium';
  static const int freeRouteStopLimit = 10;
  static const int premiumRouteStopLimit = 25;

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;
  bool _isPremium = false;

  bool get isLoaded => _isLoaded;

  bool get isPremium => _isPremium;

  bool get canUseScanDrop => isPremium;

  bool get canUseRoadRoutePreview => isPremium;

  bool get canUseSmartAutoPlan => isPremium;

  bool get canUseRouteTemplates => isPremium;

  int get maxDropsPerRoute =>
      isPremium ? premiumRouteStopLimit : freeRouteStopLimit;

  bool canSaveRouteWithStopCount(int stopCount) {
    return stopCount <= maxDropsPerRoute;
  }

  String routeSaveLimitMessage({required int stopCount}) {
    if (isPremium) {
      return stopCount > premiumRouteStopLimit
          ? 'Premium routes support up to $premiumRouteStopLimit drops per saved route. Trim a few stops and save again.'
          : 'Premium routes support up to $premiumRouteStopLimit drops per saved route.';
    }

    return 'Free routes support up to $freeRouteStopLimit drops. Upgrade to Premium for larger routes and smarter planning.';
  }

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }

    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isPremium = _preferences?.getBool(_premiumEnabledKey) ?? false;
    _isLoaded = true;
    debugPrint('[Premium] loaded: isPremium=$_isPremium');
    notifyListeners();
  }

  Future<void> setPremiumEnabled(bool value) async {
    await ensureLoaded();

    if (_isPremium == value) {
      return;
    }

    _isPremium = value;
    await _preferences?.setBool(_premiumEnabledKey, value);
    debugPrint('[Premium] updated: isPremium=$_isPremium');
    notifyListeners();
  }
}
