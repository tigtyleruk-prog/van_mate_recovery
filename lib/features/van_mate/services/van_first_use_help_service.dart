import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VanMateFirstUseHelpKeys {
  static const String seenEmergencyPinHelp = 'van_help_emergency_pin_seen';
  static const String seenUnmatchedLocationsHelp =
      'van_help_unmatched_location_seen';
  static const String seenRequestExactPinHelp = 'van_help_exact_pin_seen';
  static const String seenManageDropHelp = 'van_help_manage_drop_seen';
  static const String seenRoutePreviewHelp = 'van_help_today_route_seen';
  static const String seenPremiumRouteSummaryHelp =
      'van_help_premium_summary_seen';

  static const Map<String, List<String>> _legacyKeyAliases =
      <String, List<String>>{
        seenEmergencyPinHelp: <String>['seenEmergencyPinHelp'],
        seenUnmatchedLocationsHelp: <String>['seenUnmatchedLocationsHelp'],
        seenRequestExactPinHelp: <String>['seenRequestExactPinHelp'],
        seenManageDropHelp: <String>['seenManageDropHelp'],
        seenRoutePreviewHelp: <String>['seenRoutePreviewHelp'],
        seenPremiumRouteSummaryHelp: <String>[],
      };

  static Iterable<String> allKnownKeysFor(String key) sync* {
    yield key;
    final aliases = _legacyKeyAliases[key];
    if (aliases == null) {
      return;
    }

    for (final alias in aliases) {
      yield alias;
    }
  }
}

class VanMateFirstUseHelpService {
  VanMateFirstUseHelpService._();

  static final VanMateFirstUseHelpService instance =
      VanMateFirstUseHelpService._();

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }

    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isLoaded = true;
    debugPrint('[FirstUseHelp] loaded');
  }

  Future<bool> hasSeen(String key) async {
    await ensureLoaded();
    for (final candidate in VanMateFirstUseHelpKeys.allKnownKeysFor(key)) {
      if (_preferences?.getBool(candidate) == true) {
        return true;
      }
    }
    return false;
  }

  Future<void> markSeen(String key) async {
    await ensureLoaded();
    for (final candidate in VanMateFirstUseHelpKeys.allKnownKeysFor(key)) {
      if (_preferences?.getBool(candidate) == true) {
        return;
      }
    }

    for (final candidate in VanMateFirstUseHelpKeys.allKnownKeysFor(key)) {
      await _preferences?.setBool(candidate, true);
    }
    debugPrint('[FirstUseHelp] marked seen: $key');
  }
}
