import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlacesSearchService {
  static const MethodChannel _platform = MethodChannel(
    'van_mate/google_services',
  );

  final math.Random _random = math.Random();

  bool get supportsAutocomplete {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  String createSessionId() {
    final randomPart = _random.nextInt(999999).toString().padLeft(6, '0');
    return 'van_places_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  Future<List<PlacesAutocompleteSuggestion>> autocomplete({
    required String query,
    required String sessionId,
    double? originLatitude,
    double? originLongitude,
  }) async {
    final normalizedQuery = query.trim();
    final normalizedSessionId = sessionId.trim();

    if (normalizedQuery.isEmpty || normalizedSessionId.isEmpty) {
      return const <PlacesAutocompleteSuggestion>[];
    }

    if (!supportsAutocomplete) {
      throw const PlacesSearchException(
        'Google place autocomplete is currently available on Android builds only.',
      );
    }

    try {
      final rawResults = await _platform
          .invokeListMethod<dynamic>('autocompletePlaces', <String, dynamic>{
            'query': normalizedQuery,
            'sessionId': normalizedSessionId,
            ...?originLatitude == null
                ? null
                : <String, dynamic>{'originLat': originLatitude},
            ...?originLongitude == null
                ? null
                : <String, dynamic>{'originLng': originLongitude},
          });

      if (rawResults == null) {
        return const <PlacesAutocompleteSuggestion>[];
      }

      return rawResults
          .map(
            (item) => item is Map
                ? PlacesAutocompleteSuggestion.fromPlatformMap(
                    Map<String, dynamic>.from(item),
                  )
                : null,
          )
          .whereType<PlacesAutocompleteSuggestion>()
          .toList(growable: false);
    } on MissingPluginException {
      throw const PlacesSearchException(
        'Google place autocomplete is currently available on Android builds only.',
      );
    } on PlatformException catch (error) {
      throw PlacesSearchException(_messageForPlatformError(error));
    }
  }

  Future<PlacesSearchResult> fetchPlaceDetails({
    required String placeId,
    required String sessionId,
  }) async {
    final normalizedPlaceId = placeId.trim();
    final normalizedSessionId = sessionId.trim();

    if (normalizedPlaceId.isEmpty || normalizedSessionId.isEmpty) {
      throw const PlacesSearchException(
        'Google place details need a valid place selection.',
      );
    }

    if (!supportsAutocomplete) {
      throw const PlacesSearchException(
        'Google place autocomplete is currently available on Android builds only.',
      );
    }

    try {
      final rawResult = await _platform.invokeMapMethod<String, dynamic>(
        'fetchAutocompletePlaceDetails',
        <String, dynamic>{
          'placeId': normalizedPlaceId,
          'sessionId': normalizedSessionId,
        },
      );

      final resultMap = rawResult == null
          ? null
          : Map<String, dynamic>.from(rawResult);
      final result = resultMap == null
          ? null
          : PlacesSearchResult.fromPlatformMap(resultMap);

      if (result == null) {
        throw const PlacesSearchException(
          'Google place details did not return a usable result.',
        );
      }

      return result;
    } on MissingPluginException {
      throw const PlacesSearchException(
        'Google place autocomplete is currently available on Android builds only.',
      );
    } on PlatformException catch (error) {
      throw PlacesSearchException(_messageForPlatformError(error));
    }
  }

  Future<void> clearSession(String sessionId) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty || !supportsAutocomplete) {
      return;
    }

    try {
      await _platform.invokeMethod<void>(
        'clearAutocompleteSession',
        <String, dynamic>{'sessionId': normalizedSessionId},
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  String _messageForPlatformError(PlatformException error) {
    switch (error.code) {
      case 'places_api_key_missing':
        return 'Google place search is not configured yet. Add a Maps/Places Android key to Van Mate.';
      case 'places_api_access_denied':
        return 'Google place search is blocked for this Android key. Enable Places API (New) and confirm the app package name and SHA-1 match.';
      case 'places_network_error':
        return 'Google place search could not reach Google right now. Check the connection and try again.';
      case 'places_invalid_session':
        return 'Google place search needs a fresh autocomplete session. Try searching again.';
      case 'places_details_failed':
      case 'places_autocomplete_failed':
      default:
        final message = error.message?.trim() ?? '';
        if (message.isNotEmpty) {
          return message;
        }
        return 'Google place search could not complete right now.';
    }
  }
}

class PlacesAutocompleteSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;

  const PlacesAutocompleteSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });

  factory PlacesAutocompleteSuggestion.fromPlatformMap(
    Map<String, dynamic> json,
  ) {
    return PlacesAutocompleteSuggestion(
      placeId: _readString(json['placeId']),
      primaryText: _readString(json['primaryText']),
      secondaryText: _readString(json['secondaryText']),
      fullText: _readString(json['fullText']),
    );
  }

  bool get isValid => placeId.isNotEmpty && primaryText.isNotEmpty;

  static String _readString(dynamic value) => value?.toString().trim() ?? '';
}

class PlacesSearchResult {
  final String placeId;
  final String primaryText;
  final String address;
  final double latitude;
  final double longitude;

  const PlacesSearchResult({
    required this.placeId,
    required this.primaryText,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlacesSearchResult.fromPlatformMap(
    Map<String, dynamic> json,
  ) {
    final latitude = _readDouble(json['latitude']);
    final longitude = _readDouble(json['longitude']);

    if (latitude == null || longitude == null) {
      return const PlacesSearchResult(
        placeId: '',
        primaryText: '',
        address: '',
        latitude: 0,
        longitude: 0,
      );
    }

    return PlacesSearchResult(
      placeId: _readString(json['placeId']),
      primaryText: _readString(json['displayName']),
      address: _readString(json['address']),
      latitude: latitude,
      longitude: longitude,
    );
  }

  bool get isValid => placeId.isNotEmpty && primaryText.isNotEmpty;

  static String _readString(dynamic value) => value?.toString().trim() ?? '';

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }
}

class PlacesSearchException implements Exception {
  final String message;

  const PlacesSearchException(this.message);

  @override
  String toString() => message;
}
