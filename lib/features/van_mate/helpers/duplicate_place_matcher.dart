import 'package:geolocator/geolocator.dart';

class DuplicatePlaceRecord<T> {
  const DuplicatePlaceRecord({
    required this.source,
    required this.id,
    required this.name,
    required this.address,
    required this.postcode,
    required this.typeKey,
    required this.typeFamily,
    required this.latitude,
    required this.longitude,
    this.aliases = const <String>[],
  });

  final T source;
  final String id;
  final String name;
  final String address;
  final String postcode;
  final String typeKey;
  final String typeFamily;
  final double? latitude;
  final double? longitude;
  final List<String> aliases;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class DuplicatePlaceMatch<T> {
  const DuplicatePlaceMatch({
    required this.source,
    required this.distanceMeters,
    required this.reason,
  });

  final T source;
  final double? distanceMeters;
  final String reason;
}

class DuplicatePlaceMatcher {
  static const double exactDistanceThresholdMeters = 25;
  static const double possibleDistanceThresholdMeters = 50;
  static const double extendedDistanceThresholdMeters = 120;

  const DuplicatePlaceMatcher();

  DuplicatePlaceMatch<T>? findDuplicate<T>({
    required DuplicatePlaceRecord<T> candidate,
    required Iterable<DuplicatePlaceRecord<T>> existing,
    String? excludeId,
  }) {
    _RankedDuplicateMatch<T>? bestMatch;

    for (final entry in existing) {
      final normalizedId = entry.id.trim();
      if (normalizedId.isEmpty) continue;
      if (excludeId != null && normalizedId == excludeId.trim()) {
        continue;
      }

      final rankedMatch = _evaluateMatch(candidate, entry);
      if (rankedMatch == null) continue;
      if (bestMatch == null || rankedMatch.isBetterThan(bestMatch)) {
        bestMatch = rankedMatch;
      }
    }

    return bestMatch?.toPublicMatch();
  }

  _RankedDuplicateMatch<T>? _evaluateMatch<T>(
    DuplicatePlaceRecord<T> candidate,
    DuplicatePlaceRecord<T> existing,
  ) {
    final distanceMeters = _distanceBetween(candidate, existing);
    final hasCoordinates = distanceMeters != null;
    final typeCompatible = _areTypesCompatible(candidate, existing);
    final postcodeMatch = _normalizedPostcode(candidate.postcode).isNotEmpty &&
        _normalizedPostcode(candidate.postcode) ==
            _normalizedPostcode(existing.postcode);
    final addressMatch = _normalizedAddress(candidate.address).isNotEmpty &&
        _normalizedAddress(candidate.address) ==
            _normalizedAddress(existing.address);
    final confidentNameMatch = _hasConfidentNameMatch(candidate, existing);
    final candidateHasConfidentName =
        _hasConfidentName(candidate.name) ||
        candidate.aliases.any(_hasConfidentName);
    final existingHasConfidentNames =
        _hasConfidentName(existing.name) ||
        existing.aliases.any(_hasConfidentName);
    final hasDistinctConfidentNames =
        candidateHasConfidentName &&
        existingHasConfidentNames &&
        !confidentNameMatch;

    if (!hasCoordinates) {
      if (addressMatch && postcodeMatch) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 220,
          distanceMeters: null,
          reason: 'matched exact address and postcode',
        );
      }
      if (confidentNameMatch &&
          (addressMatch || postcodeMatch || typeCompatible)) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: typeCompatible ? 205 : 195,
          distanceMeters: null,
          reason: addressMatch || postcodeMatch
              ? 'matched the same place details'
              : 'matched the same place name and type',
        );
      }
      return null;
    }

    if (distanceMeters <= exactDistanceThresholdMeters) {
      if (typeCompatible && !hasDistinctConfidentNames) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 320 - distanceMeters.round(),
          distanceMeters: distanceMeters,
          reason: 'same type/family within ${distanceMeters.round()}m',
        );
      }
      if (addressMatch || postcodeMatch || confidentNameMatch) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 300 - distanceMeters.round(),
          distanceMeters: distanceMeters,
          reason: 'same place details within ${distanceMeters.round()}m',
        );
      }
      return null;
    }

    if (distanceMeters <= possibleDistanceThresholdMeters) {
      if (addressMatch && postcodeMatch) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 270 - distanceMeters.round(),
          distanceMeters: distanceMeters,
          reason: 'same address and postcode within ${distanceMeters.round()}m',
        );
      }
      if (confidentNameMatch && (addressMatch || postcodeMatch)) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 250 - distanceMeters.round(),
          distanceMeters: distanceMeters,
          reason: 'same place name and location details within ${distanceMeters.round()}m',
        );
      }
      if (confidentNameMatch && typeCompatible) {
        return _RankedDuplicateMatch<T>(
          source: existing.source,
          score: 225 - distanceMeters.round(),
          distanceMeters: distanceMeters,
          reason: 'same place name and compatible type within ${distanceMeters.round()}m',
        );
      }
      return null;
    }

    if (distanceMeters <= extendedDistanceThresholdMeters &&
        confidentNameMatch &&
        (addressMatch || postcodeMatch)) {
      return _RankedDuplicateMatch<T>(
        source: existing.source,
        score: 180 - distanceMeters.round(),
        distanceMeters: distanceMeters,
        reason: 'same place name and location details nearby',
      );
    }

    return null;
  }

  double? _distanceBetween<T>(
    DuplicatePlaceRecord<T> candidate,
    DuplicatePlaceRecord<T> existing,
  ) {
    if (!candidate.hasCoordinates || !existing.hasCoordinates) {
      return null;
    }

    return Geolocator.distanceBetween(
      candidate.latitude!,
      candidate.longitude!,
      existing.latitude!,
      existing.longitude!,
    );
  }

  bool _areTypesCompatible<T>(
    DuplicatePlaceRecord<T> candidate,
    DuplicatePlaceRecord<T> existing,
  ) {
    final candidateType = _normalizeType(candidate.typeKey);
    final existingType = _normalizeType(existing.typeKey);
    final candidateFamily = _normalizeType(candidate.typeFamily);
    final existingFamily = _normalizeType(existing.typeFamily);

    if (candidateType.isEmpty || existingType.isEmpty) {
      return false;
    }
    if (candidateType == existingType) {
      return true;
    }
    if (candidateFamily.isNotEmpty && candidateFamily == existingFamily) {
      return true;
    }

    return false;
  }

  bool _hasConfidentNameMatch<T>(
    DuplicatePlaceRecord<T> candidate,
    DuplicatePlaceRecord<T> existing,
  ) {
    final candidateNames = <String>{
      _normalizedName(candidate.name),
      ...candidate.aliases.map(_normalizedName),
    }..removeWhere((value) => value.isEmpty);
    final existingNames = <String>{
      _normalizedName(existing.name),
      ...existing.aliases.map(_normalizedName),
    }..removeWhere((value) => value.isEmpty);

    if (candidateNames.isEmpty || existingNames.isEmpty) {
      return false;
    }

    for (final candidateName in candidateNames) {
      if (_isLowConfidenceName(candidateName)) {
        continue;
      }
      if (existingNames.contains(candidateName)) {
        return true;
      }
    }

    return false;
  }

  bool _hasConfidentName(String value) {
    final normalized = _normalizedName(value);
    return normalized.isNotEmpty && !_isLowConfidenceName(normalized);
  }

  String _normalizedName(String value) => _normalizeText(value);

  String _normalizedAddress(String value) => _normalizeText(value);

  String _normalizedPostcode(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _normalizeType(String value) => _normalizeText(value);

  String _normalizeText(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }

    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isLowConfidenceName(String normalizedName) {
    if (normalizedName.isEmpty || normalizedName.length < 6) {
      return true;
    }

    const lowConfidencePrefixes = <String>[
      'lay by',
      'layby',
      'parking',
      'drop',
      'site',
      'entrance',
      'place',
      'spot',
    ];

    for (final prefix in lowConfidencePrefixes) {
      if (normalizedName == prefix || normalizedName.startsWith('$prefix ')) {
        return true;
      }
    }

    return false;
  }
}

class _RankedDuplicateMatch<T> {
  const _RankedDuplicateMatch({
    required this.source,
    required this.score,
    required this.distanceMeters,
    required this.reason,
  });

  final T source;
  final int score;
  final double? distanceMeters;
  final String reason;

  bool isBetterThan(_RankedDuplicateMatch<T> other) {
    if (score != other.score) {
      return score > other.score;
    }

    final thisDistance = distanceMeters ?? double.infinity;
    final otherDistance = other.distanceMeters ?? double.infinity;
    return thisDistance < otherDistance;
  }

  DuplicatePlaceMatch<T> toPublicMatch() {
    return DuplicatePlaceMatch<T>(
      source: source,
      distanceMeters: distanceMeters,
      reason: reason,
    );
  }
}
