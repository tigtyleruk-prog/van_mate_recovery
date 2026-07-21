class VanCustomJobQuestion {
  const VanCustomJobQuestion({
    required this.id,
    required this.questionText,
    required this.answerType,
    required this.isActive,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    this.helperText = '',
    this.libraryQuestionId = '',
    this.tags = const <String>[],
    this.category,
    this.choiceOptions = const <String>[],
  });

  final String id;
  final String questionText;
  final String helperText;
  final String libraryQuestionId;
  final List<String> tags;
  final VanCustomQuestionAnswerType answerType;
  final VanCustomQuestionCategory? category;
  final List<String> choiceOptions;
  final bool isActive;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasHelperText => helperText.trim().isNotEmpty;
  bool get hasCategory => category != null;
  bool get isMultipleChoice =>
      answerType == VanCustomQuestionAnswerType.multipleChoice;
  bool get hasChoices => choiceOptions.isNotEmpty;

  VanCustomJobQuestion copyWith({
    String? id,
    String? questionText,
    String? helperText,
    String? libraryQuestionId,
    List<String>? tags,
    VanCustomQuestionAnswerType? answerType,
    VanCustomQuestionCategory? category,
    bool clearCategory = false,
    List<String>? choiceOptions,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VanCustomJobQuestion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      helperText: helperText ?? this.helperText,
      libraryQuestionId: libraryQuestionId ?? this.libraryQuestionId,
      tags: tags ?? this.tags,
      answerType: answerType ?? this.answerType,
      category: clearCategory ? null : (category ?? this.category),
      choiceOptions: choiceOptions ?? this.choiceOptions,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'questionText': questionText,
      'helperText': helperText,
      'libraryQuestionId': libraryQuestionId,
      'tags': tags,
      'answerType': answerType.storageKey,
      'category': category?.storageKey,
      'choiceOptions': choiceOptions,
      'isActive': isActive,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VanCustomJobQuestion.fromJson(Map<String, dynamic> json) {
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

    List<String> readChoices(String key) {
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
    final questionText = readText('questionText');

    return VanCustomJobQuestion(
      id: resolvedId,
      questionText: questionText,
      helperText: readText('helperText'),
      libraryQuestionId: readText('libraryQuestionId'),
      tags: readChoices('tags'),
      answerType: VanCustomQuestionAnswerType.fromStorageKey(
        readText('answerType'),
      ),
      category: VanCustomQuestionCategory.fromStorageKey(readText('category')),
      choiceOptions: readChoices('choiceOptions'),
      isActive: json['isActive'] == false ? false : true,
      isArchived: json['isArchived'] == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum VanCustomQuestionAnswerType {
  shortText('short_text', 'Short text'),
  longText('long_text', 'Long text'),
  yesNo('yes_no', 'Yes / No'),
  multipleChoice('multiple_choice', 'Multiple choice'),
  photoUploadRequest('photo_requested', 'Photo upload/request'),
  date('date', 'Date'),
  time('time', 'Time');

  const VanCustomQuestionAnswerType(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static VanCustomQuestionAnswerType fromStorageKey(String raw) {
    for (final value in VanCustomQuestionAnswerType.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return VanCustomQuestionAnswerType.shortText;
  }
}

enum VanCustomQuestionCategory {
  items('items', 'Items'),
  sizeWeight('size_weight', 'Size and Weight'),
  access('access', 'Access'),
  parking('parking', 'Parking'),
  stairsLifts('stairs_lifts', 'Stairs and Lifts'),
  collection('collection', 'Collection'),
  delivery('delivery', 'Delivery'),
  timing('timing', 'Timing'),
  photosVideo('photos_video', 'Photos and Video'),
  fragileValuableItems('fragile_valuable_items', 'Fragile and Valuable Items'),
  packing('packing', 'Packing'),
  assembly('assembly', 'Assembly'),
  multipleStops('multiple_stops', 'Multiple Stops'),
  proofOfDelivery('proof_of_delivery', 'Proof of Delivery'),
  property('property', 'Property'),
  survey('survey', 'Survey'),
  medicalHandling('medical_handling', 'Medical Handling'),
  generalNotes('general_notes', 'General Notes'),
  loading('loading', 'Loading'),
  photos('photos', 'Photos'),
  customerDetails('customer_details', 'Customer details'),
  collectionDelivery('collection_delivery', 'Collection & Delivery'),
  jobDetails('job_details', 'Job details'),
  gardening('gardening', 'Gardening'),
  courierDelivery('courier_delivery', 'Courier / Delivery'),
  other('other', 'Other');

  const VanCustomQuestionCategory(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static VanCustomQuestionCategory? fromStorageKey(String raw) {
    for (final value in VanCustomQuestionCategory.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return null;
  }
}
