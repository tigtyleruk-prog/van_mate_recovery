class VanRoutePreviewSummary {
  VanRoutePreviewSummary({
    required this.remainingStopsCount,
    required this.estimatedDurationMinutes,
    required this.estimatedDistanceMeters,
    required this.estimatedFinishTime,
    required this.calculatedAt,
    required List<String> basedOnStopIds,
    required this.provider,
    this.needsRefresh = false,
  }) : basedOnStopIds = List<String>.unmodifiable(basedOnStopIds);

  final int remainingStopsCount;
  final int? estimatedDurationMinutes;
  final double? estimatedDistanceMeters;
  final DateTime? estimatedFinishTime;
  final DateTime calculatedAt;
  final List<String> basedOnStopIds;
  final String provider;
  final bool needsRefresh;

  bool get hasEstimatedRouteData =>
      estimatedDurationMinutes != null &&
      estimatedDistanceMeters != null &&
      estimatedFinishTime != null;

  VanRoutePreviewSummary copyWith({
    int? remainingStopsCount,
    int? estimatedDurationMinutes,
    double? estimatedDistanceMeters,
    DateTime? estimatedFinishTime,
    DateTime? calculatedAt,
    List<String>? basedOnStopIds,
    String? provider,
    bool? needsRefresh,
  }) {
    return VanRoutePreviewSummary(
      remainingStopsCount: remainingStopsCount ?? this.remainingStopsCount,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      estimatedDistanceMeters:
          estimatedDistanceMeters ?? this.estimatedDistanceMeters,
      estimatedFinishTime: estimatedFinishTime ?? this.estimatedFinishTime,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      basedOnStopIds:
          basedOnStopIds ?? List<String>.unmodifiable(this.basedOnStopIds),
      provider: provider ?? this.provider,
      needsRefresh: needsRefresh ?? this.needsRefresh,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'remainingStopsCount': remainingStopsCount,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'estimatedDistanceMeters': estimatedDistanceMeters,
      'estimatedFinishTime': estimatedFinishTime?.toIso8601String(),
      'calculatedAt': calculatedAt.toIso8601String(),
      'basedOnStopIds': basedOnStopIds,
      'provider': provider,
      'needsRefresh': needsRefresh,
    };
  }

  factory VanRoutePreviewSummary.fromJson(Map<String, dynamic> json) {
    return VanRoutePreviewSummary(
      remainingStopsCount: _readInt(json['remainingStopsCount']),
      estimatedDurationMinutes: _readNullableInt(
        json['estimatedDurationMinutes'],
      ),
      estimatedDistanceMeters: _readNullableDouble(
        json['estimatedDistanceMeters'],
      ),
      estimatedFinishTime: _readDateTime(json['estimatedFinishTime']),
      calculatedAt: _readDateTime(json['calculatedAt']) ?? DateTime.now(),
      basedOnStopIds: _readStringList(json['basedOnStopIds']),
      provider: _readString(
        json['provider'],
        fallback: 'google_routes_preview',
      ),
      needsRefresh: _readBool(json['needsRefresh']),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? fallback : parsed;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString().trim());
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true';
  }
}
