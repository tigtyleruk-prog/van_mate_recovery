class VanQuestionTemplate {
  const VanQuestionTemplate({
    required this.id,
    required this.name,
    required this.selectedQuestionIds,
    required this.isActive,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final List<String> selectedQuestionIds;
  final bool isActive;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasDescription => description.trim().isNotEmpty;
  int get questionCount => selectedQuestionIds.length;

  VanQuestionTemplate copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? selectedQuestionIds,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VanQuestionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      selectedQuestionIds: selectedQuestionIds ?? this.selectedQuestionIds,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'selectedQuestionIds': selectedQuestionIds,
      'isActive': isActive,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VanQuestionTemplate.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key, {DateTime? fallback}) {
      final raw = (json[key]?.toString().trim() ?? '');
      if (raw.isEmpty) {
        return fallback ?? DateTime.now();
      }
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }

    String readText(String key) {
      return (json[key]?.toString().trim() ?? '');
    }

    List<String> readIds(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <String>[];
      }
      final values = <String>[];
      for (final item in raw) {
        final value = item.toString().trim();
        if (value.isNotEmpty) {
          values.add(value);
        }
      }
      return List<String>.unmodifiable(values);
    }

    final createdAt = readDate('createdAt');
    final updatedAt = readDate('updatedAt', fallback: createdAt);
    final resolvedId = readText('id').isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : readText('id');
    final name = readText('name');

    return VanQuestionTemplate(
      id: resolvedId,
      name: name.isEmpty ? 'Custom template' : name,
      description: readText('description'),
      selectedQuestionIds: readIds('selectedQuestionIds'),
      isActive: json['isActive'] == false ? false : true,
      isArchived: json['isArchived'] == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
