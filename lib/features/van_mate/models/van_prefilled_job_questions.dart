import 'van_custom_job_question.dart';

class VanPrefilledJobQuestions {
  VanPrefilledJobQuestions._();

  static final DateTime _fixedDate = DateTime(2026, 1, 1);
  static const Set<String> deprecatedDuplicatePresetIds = <String>{
    'prefill_photos_items',
    'prefill_photos_access',
    'prefill_photos_parking',
    'prefill_photos_awkward_items',
    'prefill_customer_contact_name',
    'prefill_customer_contact_phone',
    'prefill_customer_contact_email',
  };

  static final List<VanCustomJobQuestion> all = <VanCustomJobQuestion>[
    // Access
    _build(
      id: 'prefill_access_rear_access',
      text: 'Is there rear access?',
      category: VanCustomQuestionCategory.access,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_access_gate_code',
      text: 'Is there a gate code or entry code?',
      category: VanCustomQuestionCategory.access,
    ),
    _build(
      id: 'prefill_access_restrictions',
      text: 'Are there any access restrictions?',
      category: VanCustomQuestionCategory.access,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_access_narrow_road',
      text: 'Is the road narrow or difficult for vans?',
      category: VanCustomQuestionCategory.access,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_access_height_restriction',
      text: 'Is there a height restriction?',
      category: VanCustomQuestionCategory.access,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_access_loading_bay',
      text: 'Is there a loading bay?',
      category: VanCustomQuestionCategory.access,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_access_preferred_entrance',
      text: 'Is there a preferred entrance?',
      category: VanCustomQuestionCategory.access,
    ),

    // Parking
    _build(
      id: 'prefill_parking_available',
      text: 'Is parking available?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_parking_close_to_door',
      text: 'Can the van park close to the door?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_parking_best_place',
      text: 'Where is the best place to park?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_parking_time_limit',
      text: 'Is there a time limit for loading?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_parking_permit',
      text: 'Is a permit needed?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_parking_large_van_space',
      text: 'Is there space for a large van?',
      category: VanCustomQuestionCategory.parking,
      type: VanCustomQuestionAnswerType.yesNo,
    ),

    // Loading
    _build(
      id: 'prefill_loading_help',
      text: 'Is help available for loading?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_stairs',
      text: 'Are there stairs at collection?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_lift',
      text: 'Is there a lift?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_floor',
      text: 'Which floor is collection from?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.shortText,
    ),
    _build(
      id: 'prefill_loading_delivery_floor',
      text: 'Which floor is delivery to?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.shortText,
    ),
    _build(
      id: 'prefill_loading_property_type',
      text: 'Is this a house, flat, storage unit, or business?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.shortText,
    ),
    _build(
      id: 'prefill_loading_stairs_delivery',
      text: 'Are there stairs at delivery?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_tight_access',
      text: 'Are there tight doorways or narrow hallways?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_heavy',
      text: 'Are there heavy or awkward items?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_fragile',
      text: 'Are any items fragile?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_dismantling',
      text: 'Does anything need dismantling?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_packed',
      text: 'Are items already packed?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_loading_valuable',
      text: 'Is anything especially valuable or delicate?',
      category: VanCustomQuestionCategory.loading,
      type: VanCustomQuestionAnswerType.yesNo,
    ),

    // Collection & Delivery
    _build(
      id: 'prefill_cd_collection_address',
      text: 'Collection address?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_cd_delivery_address',
      text: 'Delivery address?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_cd_collection_postcode',
      text: 'Collection postcode?',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    _build(
      id: 'prefill_cd_delivery_postcode',
      text: 'Delivery postcode?',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    _build(
      id: 'prefill_cd_collection_date',
      text: 'Preferred collection date?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.date,
    ),
    _build(
      id: 'prefill_cd_delivery_date',
      text: 'Preferred delivery date?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.date,
    ),
    _build(
      id: 'prefill_cd_time_window',
      text: 'Preferred time window?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.time,
    ),
    _build(
      id: 'prefill_cd_multiple_stops',
      text: 'Are there multiple stops?',
      category: VanCustomQuestionCategory.collectionDelivery,
      type: VanCustomQuestionAnswerType.yesNo,
    ),

    // Job details
    _build(
      id: 'prefill_job_what_needs_doing',
      text: 'What needs collecting or delivering?',
      category: VanCustomQuestionCategory.jobDetails,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_job_urgent',
      text: 'Is the job urgent?',
      category: VanCustomQuestionCategory.jobDetails,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_job_special_instructions',
      text: 'Any notes for the driver?',
      category: VanCustomQuestionCategory.jobDetails,
      type: VanCustomQuestionAnswerType.longText,
    ),

    // Courier / Delivery
    _build(
      id: 'prefill_courier_item',
      text: 'What is being collected/delivered?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_courier_fragile',
      text: 'Is it fragile?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_courier_deadline',
      text: 'Is there a delivery deadline?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.date,
    ),
    _build(
      id: 'prefill_courier_signed_for',
      text: 'Does it need signing for?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.yesNo,
    ),
    _build(
      id: 'prefill_courier_contact_arrival',
      text: 'Contact on arrival?',
      category: VanCustomQuestionCategory.courierDelivery,
    ),
    _build(
      id: 'prefill_courier_safe_place',
      text: 'Safe place if no answer?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.longText,
    ),
    _build(
      id: 'prefill_courier_delivery_type',
      text: 'Business or residential delivery?',
      category: VanCustomQuestionCategory.courierDelivery,
      type: VanCustomQuestionAnswerType.multipleChoice,
      choices: <String>['Business', 'Residential'],
    ),
  ];

  static List<VanCustomJobQuestion> byCategory(
    VanCustomQuestionCategory category,
  ) {
    return all
        .where((question) => question.category == category)
        .toList(growable: false);
  }

  static VanCustomJobQuestion? findById(String id) {
    for (final question in all) {
      if (question.id == id) {
        return question;
      }
    }
    return null;
  }

  static bool isPrefilledId(String id) => id.startsWith('prefill_');

  static bool isDeprecatedDuplicatePresetId(String id) {
    return deprecatedDuplicatePresetIds.contains(id.trim());
  }

  static VanCustomJobQuestion _build({
    required String id,
    required String text,
    required VanCustomQuestionCategory category,
    VanCustomQuestionAnswerType type = VanCustomQuestionAnswerType.shortText,
    List<String> choices = const <String>[],
  }) {
    return VanCustomJobQuestion(
      id: id,
      questionText: text,
      helperText: '',
      answerType: type,
      category: category,
      choiceOptions: choices,
      isActive: true,
      isArchived: false,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );
  }
}
