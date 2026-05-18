class TodayRouteSummary {
  const TodayRouteSummary({
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.estimatedFinish,
    required this.calculatedAt,
    required this.stopCount,
    required this.summaryHash,
    required this.provider,
    required this.fromCache,
    this.summaryError,
    this.legDistanceMeters = const <double>[],
    this.legDurationSeconds = const <int>[],
  });

  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final DateTime estimatedFinish;
  final DateTime calculatedAt;
  final int stopCount;
  final String summaryHash;
  final String provider;
  final bool fromCache;
  final String? summaryError;
  final List<double> legDistanceMeters;
  final List<int> legDurationSeconds;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);

  double get totalDistanceMiles => totalDistanceMeters / 1609.344;

  bool get hasError => summaryError?.trim().isNotEmpty == true;

  bool get canShiftFromFirstStop {
    return stopCount > 1 &&
        legDistanceMeters.length == stopCount - 1 &&
        legDurationSeconds.length == stopCount - 1;
  }

  TodayRouteSummary? shiftAfterRemovingFirstStop({
    required String summaryHash,
    DateTime? calculatedAt,
  }) {
    if (!canShiftFromFirstStop) {
      return null;
    }

    final remainingLegDistances = legDistanceMeters.sublist(1);
    final remainingLegDurations = legDurationSeconds.sublist(1);
    final nextDurationSeconds =
        totalDurationSeconds -
        (legDurationSeconds.isNotEmpty ? legDurationSeconds.first : 0);
    final nextDistanceMeters =
        totalDistanceMeters -
        (legDistanceMeters.isNotEmpty ? legDistanceMeters.first : 0);
    final nextCalculatedAt = calculatedAt ?? DateTime.now();
    final nextDuration = Duration(
      seconds: nextDurationSeconds < 0 ? 0 : nextDurationSeconds,
    );

    return TodayRouteSummary(
      totalDistanceMeters: nextDistanceMeters < 0 ? 0 : nextDistanceMeters,
      totalDurationSeconds: nextDuration.inSeconds,
      estimatedFinish: nextCalculatedAt.add(nextDuration),
      calculatedAt: nextCalculatedAt,
      stopCount: stopCount - 1,
      summaryHash: summaryHash,
      provider: provider,
      fromCache: true,
      summaryError: null,
      legDistanceMeters: List<double>.unmodifiable(remainingLegDistances),
      legDurationSeconds: List<int>.unmodifiable(remainingLegDurations),
    );
  }

  Map<String, dynamic> toCacheMap({String? error}) {
    return <String, dynamic>{
      'premiumSummaryHash': summaryHash,
      'premiumDistanceMeters': totalDistanceMeters,
      'premiumDurationSeconds': totalDurationSeconds,
      'premiumEstimatedFinishIso': estimatedFinish.toIso8601String(),
      'premiumCalculatedAt': calculatedAt.toIso8601String(),
      'premiumStopCount': stopCount,
      'premiumProvider': provider,
      'premiumSummaryError': error ?? '',
      'premiumLegDistanceMeters': legDistanceMeters,
      'premiumLegDurationSeconds': legDurationSeconds,
    };
  }

  factory TodayRouteSummary.fromFunctionResponse(
    Map<String, dynamic> data, {
    bool fromCache = false,
  }) {
    return TodayRouteSummary(
      totalDistanceMeters: _readDouble(data['totalDistanceMeters']),
      totalDurationSeconds: _readInt(data['totalDurationSeconds']),
      estimatedFinish:
          _readDateTime(data['estimatedFinishIso']) ?? DateTime.now(),
      calculatedAt: _readDateTime(data['calculatedAt']) ?? DateTime.now(),
      stopCount: _readInt(data['stopCount']),
      summaryHash: _readString(data['summaryHash']),
      provider: _readString(data['provider'], fallback: 'google_routes'),
      fromCache: fromCache || _readBool(data['fromCache']),
      summaryError: _readNullableString(data['summaryError']),
      legDistanceMeters: _readDoubleList(data['legDistanceMeters']),
      legDurationSeconds: _readIntList(data['legDurationSeconds']),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? fallback : parsed;
  }

  static String? _readNullableString(dynamic value) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? null : parsed;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true';
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static List<double> _readDoubleList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) {
            if (item is double) return item;
            if (item is int) return item.toDouble();
            return double.tryParse(item.toString().trim()) ?? 0;
          })
          .toList(growable: false);
    }
    return const <double>[];
  }

  static List<int> _readIntList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) {
            if (item is int) return item;
            if (item is double) return item.round();
            return int.tryParse(item.toString().trim()) ?? 0;
          })
          .toList(growable: false);
    }
    return const <int>[];
  }
}
