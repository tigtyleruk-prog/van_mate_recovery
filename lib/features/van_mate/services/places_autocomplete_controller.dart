import 'dart:async';

import 'package:flutter/foundation.dart';

import 'places_search_service.dart';

class PlacesAutocompleteController extends ChangeNotifier {
  PlacesAutocompleteController({
    required PlacesSearchService searchService,
    Duration debounceDuration = const Duration(milliseconds: 350),
  }) : _searchService = searchService,
       _debounceDuration = debounceDuration;

  final PlacesSearchService _searchService;
  final Duration _debounceDuration;

  Timer? _debounceTimer;
  int _requestId = 0;
  String _lastCompletedQuery = '';
  String? _sessionId;

  List<PlacesAutocompleteSuggestion> _suggestions =
      const <PlacesAutocompleteSuggestion>[];
  bool _isSearching = false;
  String? _errorText;

  List<PlacesAutocompleteSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;
  String? get errorText => _errorText;
  bool get supportsAutocomplete => _searchService.supportsAutocomplete;
  bool get hasSuggestions => _suggestions.isNotEmpty;

  void handleQueryChanged(
    String query, {
    double? originLatitude,
    double? originLongitude,
    void Function()? onChanged,
  }) {
    _debounceTimer?.cancel();

    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      _lastCompletedQuery = '';
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: null,
        onChanged: onChanged,
      );
      if (normalizedQuery.isEmpty) {
        unawaited(_clearSession());
      }
      return;
    }

    _setState(isSearching: true, errorText: null, onChanged: onChanged);

    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(
        _search(
          normalizedQuery,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          onChanged: onChanged,
        ),
      );
    });
  }

  Future<void> forceSearch(
    String query, {
    double? originLatitude,
    double? originLongitude,
    void Function()? onChanged,
  }) async {
    _debounceTimer?.cancel();

    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      _lastCompletedQuery = '';
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: normalizedQuery.isEmpty
            ? null
            : 'Type at least two letters to search Google places.',
        onChanged: onChanged,
      );
      return;
    }

    _setState(isSearching: true, errorText: null, onChanged: onChanged);
    await _search(
      normalizedQuery,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      onChanged: onChanged,
    );
  }

  Future<PlacesSearchResult?> selectSuggestion(
    PlacesAutocompleteSuggestion suggestion, {
    void Function()? onChanged,
  }) async {
    final sessionId = _sessionId ?? _searchService.createSessionId();
    _sessionId = sessionId;
    _setState(isSearching: true, errorText: null, onChanged: onChanged);

    try {
      final result = await _searchService.fetchPlaceDetails(
        placeId: suggestion.placeId,
        sessionId: sessionId,
      );
      if (!result.isValid) {
        throw const PlacesSearchException(
          'Google place details did not return a usable result.',
        );
      }

      _sessionId = null;
      _lastCompletedQuery = '';
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: null,
        onChanged: onChanged,
      );
      return result;
    } on PlacesSearchException catch (error) {
      _setState(
        isSearching: false,
        errorText: error.message,
        onChanged: onChanged,
      );
      return null;
    } catch (_) {
      _setState(
        isSearching: false,
        errorText: 'Google place details could not load right now.',
        onChanged: onChanged,
      );
      return null;
    }
  }

  void clearSuggestions({
    void Function()? onChanged,
    bool clearSession = false,
  }) {
    _debounceTimer?.cancel();
    _lastCompletedQuery = '';
    _setState(
      suggestions: const <PlacesAutocompleteSuggestion>[],
      isSearching: false,
      errorText: null,
      onChanged: onChanged,
    );

    if (clearSession) {
      unawaited(_clearSession());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_clearSession());
    super.dispose();
  }

  Future<void> _search(
    String normalizedQuery, {
    double? originLatitude,
    double? originLongitude,
    void Function()? onChanged,
  }) async {
    if (!supportsAutocomplete) {
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: null,
        onChanged: onChanged,
      );
      return;
    }

    if (_lastCompletedQuery == normalizedQuery && _suggestions.isNotEmpty) {
      _setState(isSearching: false, onChanged: onChanged);
      return;
    }

    final sessionId = _sessionId ?? _searchService.createSessionId();
    _sessionId = sessionId;
    final activeRequestId = ++_requestId;

    try {
      final suggestions = await _searchService.autocomplete(
        query: normalizedQuery,
        sessionId: sessionId,
        originLatitude: originLatitude,
        originLongitude: originLongitude,
      );

      if (activeRequestId != _requestId) {
        return;
      }

      _lastCompletedQuery = normalizedQuery;
      _setState(
        suggestions: suggestions.where((item) => item.isValid).toList(),
        isSearching: false,
        errorText: null,
        onChanged: onChanged,
      );
    } on PlacesSearchException catch (error) {
      if (activeRequestId != _requestId) {
        return;
      }
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: error.message,
        onChanged: onChanged,
      );
    } catch (_) {
      if (activeRequestId != _requestId) {
        return;
      }
      _setState(
        suggestions: const <PlacesAutocompleteSuggestion>[],
        isSearching: false,
        errorText: 'Google place search could not complete right now.',
        onChanged: onChanged,
      );
    }
  }

  Future<void> _clearSession() async {
    final sessionId = _sessionId;
    _sessionId = null;
    if (sessionId == null) {
      return;
    }

    await _searchService.clearSession(sessionId);
  }

  void _setState({
    List<PlacesAutocompleteSuggestion>? suggestions,
    bool? isSearching,
    String? errorText,
    void Function()? onChanged,
  }) {
    if (suggestions != null) {
      _suggestions = suggestions;
    }
    if (isSearching != null) {
      _isSearching = isSearching;
    }
    _errorText = errorText;
    notifyListeners();
    onChanged?.call();
  }
}
