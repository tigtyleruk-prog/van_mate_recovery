import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/van_place.dart';
import '../models/van_route_stop.dart';

enum VanPreferredNavigationApp {
  askEveryTime('ask_every_time', 'Ask every time'),
  googleMaps('google_maps', 'Google Maps'),
  waze('waze', 'Waze'),
  systemDefault('system_default', 'System default');

  const VanPreferredNavigationApp(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static VanPreferredNavigationApp fromStorage(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    for (final app in values) {
      if (app.storageValue == normalized) {
        return app;
      }
    }

    return VanPreferredNavigationApp.googleMaps;
  }
}

class VanNavigationTarget {
  const VanNavigationTarget({
    required this.label,
    this.latitude,
    this.longitude,
    this.address,
    this.postcodeArea,
  });

  final String label;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? postcodeArea;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get resolvedQuery {
    if (hasCoordinates) {
      return '$latitude,$longitude';
    }

    final parts = <String>[
      if (postcodeArea?.trim().isNotEmpty == true) postcodeArea!.trim(),
      if (address?.trim().isNotEmpty == true) address!.trim(),
    ];
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return label.trim();
  }

  factory VanNavigationTarget.fromPlace(VanPlace place) {
    return VanNavigationTarget(
      label: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      address: place.address,
      postcodeArea: place.postcodeArea,
    );
  }

  factory VanNavigationTarget.fromStop(VanRouteStop stop) {
    return VanNavigationTarget(
      label: stop.name,
      latitude: stop.latitude,
      longitude: stop.longitude,
      address: stop.address,
      postcodeArea: stop.postcodeArea,
    );
  }

  factory VanNavigationTarget.fromCoordinates({
    required double latitude,
    required double longitude,
    String label = 'Selected location',
  }) {
    return VanNavigationTarget(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class VanMateNavigationService extends ChangeNotifier {
  VanMateNavigationService._();

  static final VanMateNavigationService instance = VanMateNavigationService._();
  static const MethodChannel _navigationChannel = MethodChannel(
    'van_mate/navigation',
  );

  static const String _preferredNavigationAppKey =
      'van_mate_preferred_navigation_app';

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;
  VanPreferredNavigationApp _preferredNavigationApp =
      VanPreferredNavigationApp.googleMaps;

  bool get isLoaded => _isLoaded;

  VanPreferredNavigationApp get preferredNavigationApp =>
      _preferredNavigationApp;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }

    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _preferredNavigationApp = VanPreferredNavigationApp.fromStorage(
      _preferences?.getString(_preferredNavigationAppKey),
    );
    _isLoaded = true;
    debugPrint(
      '[Navigation] loaded: preferredApp=${_preferredNavigationApp.storageValue}',
    );
    notifyListeners();
  }

  Future<void> setPreferredNavigationApp(
    VanPreferredNavigationApp value,
  ) async {
    await ensureLoaded();

    if (_preferredNavigationApp == value) {
      return;
    }

    _preferredNavigationApp = value;
    await _preferences?.setString(
      _preferredNavigationAppKey,
      value.storageValue,
    );
    debugPrint(
      '[Navigation] updated: preferredApp=${_preferredNavigationApp.storageValue}',
    );
    notifyListeners();
  }

  String describePreferredNavigationApp(VanPreferredNavigationApp app) {
    switch (app) {
      case VanPreferredNavigationApp.askEveryTime:
        return 'Opens the Android app chooser with compatible navigation apps.';
      case VanPreferredNavigationApp.googleMaps:
        return 'Tries Google Maps first, then falls back to the chooser if needed.';
      case VanPreferredNavigationApp.waze:
        return 'Tries Waze first, then falls back to the chooser if needed.';
      case VanPreferredNavigationApp.systemDefault:
        return 'Opens the device default navigation handler.';
    }
  }

  Future<void> openNavigationForPlace(
    BuildContext context,
    VanPlace place,
  ) async {
    await openNavigation(context, VanNavigationTarget.fromPlace(place));
  }

  Future<void> openNavigationForStop(
    BuildContext context,
    VanRouteStop stop,
  ) async {
    await openNavigation(context, VanNavigationTarget.fromStop(stop));
  }

  Future<void> openNavigationForCoordinates(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String label = 'Selected location',
  }) async {
    await openNavigation(
      context,
      VanNavigationTarget.fromCoordinates(
        latitude: latitude,
        longitude: longitude,
        label: label,
      ),
    );
  }

  Future<void> openNavigation(
    BuildContext context,
    VanNavigationTarget target,
  ) async {
    await ensureLoaded();
    final app = _preferredNavigationApp;
    final launched = switch (app) {
      VanPreferredNavigationApp.askEveryTime =>
        await _launchAndroidChooser(target) ||
            await _launchGenericChooserUri(target),
      VanPreferredNavigationApp.googleMaps => await _launchGoogleMapsFirst(
        target,
      ),
      VanPreferredNavigationApp.waze => await _launchWazeFirst(target),
      VanPreferredNavigationApp.systemDefault => await _launchSystemDefaultUri(
        target,
      ),
    };

    if (!context.mounted || launched) {
      return;
    }

    _showNavigationFailure(context);
  }

  Future<bool> _launchGoogleMapsFirst(VanNavigationTarget target) async {
    final directUri = _buildGoogleMapsUri(target);
    if (directUri != null) {
      final launched = await launchUrl(
        directUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return true;
      }
    }

    return _launchGenericChooserUri(target);
  }

  Future<bool> _launchWazeFirst(VanNavigationTarget target) async {
    final wazeUri = _buildWazeUri(target);
    if (wazeUri != null) {
      final launched = await launchUrl(
        wazeUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return true;
      }
    }

    return _launchGenericChooserUri(target);
  }

  Future<bool> _launchSystemDefaultUri(VanNavigationTarget target) async {
    return _launchGenericChooserUri(target);
  }

  Future<bool> _launchAndroidChooser(VanNavigationTarget target) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final args = <String, Object?>{
      'latitude': target.latitude,
      'longitude': target.longitude,
      'query': target.resolvedQuery,
    };

    try {
      final result = await _navigationChannel.invokeMethod<bool>(
        'openNavigationChooser',
        args,
      );
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchGenericChooserUri(VanNavigationTarget target) async {
    final uri = _buildGenericChooserUri(target);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri _buildGenericChooserUri(VanNavigationTarget target) {
    final query = target.resolvedQuery;
    if (kIsWeb) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }

    if (target.hasCoordinates) {
      return Uri(
        scheme: 'geo',
        path: '${target.latitude},${target.longitude}',
        queryParameters: <String, String>{'q': query},
      );
    }

    return Uri(
      scheme: 'geo',
      path: '0,0',
      queryParameters: <String, String>{'q': query},
    );
  }

  Uri? _buildGoogleMapsUri(VanNavigationTarget target) {
    final query = target.resolvedQuery;
    if (query.trim().isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(
        'comgooglemaps://?daddr=${Uri.encodeComponent(query)}&directionsmode=driving',
      );
    }

    return Uri.parse('google.navigation:q=${Uri.encodeComponent(query)}');
  }

  Uri? _buildWazeUri(VanNavigationTarget target) {
    final query = target.resolvedQuery;
    if (query.trim().isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
      });
    }

    if (target.hasCoordinates) {
      return Uri.parse(
        'waze://?ll=${target.latitude},${target.longitude}&navigate=yes',
      );
    }

    return Uri.parse('waze://?q=${Uri.encodeComponent(query)}&navigate=yes');
  }

  void _showNavigationFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open your navigation app just now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
