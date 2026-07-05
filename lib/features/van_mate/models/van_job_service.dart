class VanJobService {
  const VanJobService({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.requestPhotos,
    required this.requireAddress,
    required this.requestExactPinAfterQuoteAccepted,
    required this.linkedQuestionIds,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool requestPhotos;
  final bool requireAddress;
  final bool requestExactPinAfterQuoteAccepted;
  final List<String> linkedQuestionIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  bool get hasDescription => description.trim().isNotEmpty;
  int get linkedQuestionCount => linkedQuestionIds.length;

  VanJobService copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    bool? requestPhotos,
    bool? requireAddress,
    bool? requestExactPinAfterQuoteAccepted,
    List<String>? linkedQuestionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return VanJobService(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      requestPhotos: requestPhotos ?? this.requestPhotos,
      requireAddress: requireAddress ?? this.requireAddress,
      requestExactPinAfterQuoteAccepted:
          requestExactPinAfterQuoteAccepted ??
          this.requestExactPinAfterQuoteAccepted,
      linkedQuestionIds: linkedQuestionIds ?? this.linkedQuestionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      'requestPhotos': requestPhotos,
      'requireAddress': requireAddress,
      'requestExactPinAfterQuoteAccepted': requestExactPinAfterQuoteAccepted,
      'linkedQuestionIds': linkedQuestionIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  factory VanJobService.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key, {DateTime? fallback}) {
      final raw = (json[key]?.toString().trim() ?? '');
      if (raw.isEmpty) {
        return fallback ?? DateTime.now();
      }
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }

    String readText(String key, {String fallback = ''}) {
      final value = (json[key]?.toString().trim() ?? '');
      return value.isEmpty ? fallback : value;
    }

    List<String> readStringList(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <String>[];
      }
      return List<String>.unmodifiable(
        raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      );
    }

    final now = DateTime.now();
    final createdAt = readDate('createdAt', fallback: now);
    final updatedAt = readDate('updatedAt', fallback: createdAt);
    final name = readText('name', fallback: 'Service');

    return VanJobService(
      id: readText('id', fallback: now.microsecondsSinceEpoch.toString()),
      name: name,
      description: readText('description'),
      isActive: json['isActive'] == false ? false : true,
      requestPhotos: json['requestPhotos'] == true,
      requireAddress: json['requireAddress'] == false ? false : true,
      requestExactPinAfterQuoteAccepted:
          json['requestExactPinAfterQuoteAccepted'] == true,
      linkedQuestionIds: readStringList('linkedQuestionIds'),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: json['isArchived'] == true,
    );
  }
}
