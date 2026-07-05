class VanDefaultNewJobQuestionSet {
  const VanDefaultNewJobQuestionSet({
    required this.id,
    required this.title,
    required this.questions,
    required this.isDefaultForNewJob,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String defaultId = 'default_new_job';
  static const String defaultTitle = 'Default New Job questions';

  static const List<String> starterQuestions = <String>[
    'Can the van park close to the door?',
    'What needs collecting or delivering?',
    'Are there stairs, lifts or access issues?',
    'Anything else the driver should know?',
  ];

  static const List<String> quickPickQuestions = <String>[
    'Can the van park close to the door?',
    'What needs collecting or delivering?',
    'Are there stairs, lifts or access issues?',
    'Anything else the driver should know?',
    'Is there someone available to help load?',
    'Are there any access restrictions?',
    'Is there a gate code or entry instruction?',
    'Is the item heavy or awkward?',
    'Preferred date/time?',
    'Photos required?',
  ];

  final String id;
  final String title;
  final List<String> questions;
  final bool isDefaultForNewJob;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasQuestions =>
      questions.any((question) => question.trim().isNotEmpty);

  VanDefaultNewJobQuestionSet copyWith({
    String? id,
    String? title,
    List<String>? questions,
    bool? isDefaultForNewJob,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VanDefaultNewJobQuestionSet(
      id: id ?? this.id,
      title: title ?? this.title,
      questions: questions ?? this.questions,
      isDefaultForNewJob: isDefaultForNewJob ?? this.isDefaultForNewJob,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'questions': questions,
      'updatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isDefaultForNewJob': isDefaultForNewJob,
    };
  }

  factory VanDefaultNewJobQuestionSet.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key, {DateTime? fallback}) {
      final raw = json[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return fallback ?? DateTime.now();
      }
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }

    String readText(String key) {
      return json[key]?.toString().trim() ?? '';
    }

    List<String> readQuestions(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const <String>[];
      }

      final values = <String>[];
      for (final item in raw) {
        final text = item is Map
            ? item['questionText']?.toString().trim() ?? ''
            : item.toString().trim();
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
      return List<String>.unmodifiable(values);
    }

    final createdAt = readDate('createdAt');
    final updatedAt = readDate('updatedAt', fallback: createdAt);
    final resolvedId = readText('id').isEmpty ? defaultId : readText('id');
    final resolvedTitle = readText('title').isEmpty
        ? defaultTitle
        : readText('title');

    return VanDefaultNewJobQuestionSet(
      id: resolvedId,
      title: resolvedTitle,
      questions: readQuestions('questions'),
      isDefaultForNewJob: json['isDefaultForNewJob'] == false ? false : true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory VanDefaultNewJobQuestionSet.starter({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    return VanDefaultNewJobQuestionSet(
      id: defaultId,
      title: defaultTitle,
      questions: List<String>.unmodifiable(starterQuestions),
      isDefaultForNewJob: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
