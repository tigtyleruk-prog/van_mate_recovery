import 'van_customer_journey.dart';
import 'van_customer_request_flow.dart';
import 'van_custom_job_question.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_capability.dart';
import 'van_service_template.dart';

/// A business type's recommendation catalogue.
///
/// The pack suggests services and starting capabilities only. Runtime service
/// behaviour is always resolved from the universal capability library.
class VanStarterCapabilityPack {
  const VanStarterCapabilityPack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.colorValue,
    this.capabilities = const <VanStarterCapability>[],
    this.services = const <VanBusinessServiceRecommendation>[],
    this.featured = false,
    this.searchKeywords = const <String>[],
    this.searchAliases = const <VanBusinessSearchAlias>[],
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String iconKey;
  final int colorValue;
  final List<VanStarterCapability> capabilities;
  final List<VanBusinessServiceRecommendation> services;
  final bool featured;
  final List<String> searchKeywords;
  final List<VanBusinessSearchAlias> searchAliases;

  List<VanBusinessServiceRecommendation> get serviceRecommendations {
    if (services.isNotEmpty) return services;
    final grouped = <String, List<VanStarterCapability>>{};
    for (final capability in capabilities) {
      grouped.putIfAbsent(capability.serviceKey, () => []).add(capability);
    }
    return <VanBusinessServiceRecommendation>[
      for (final entry in grouped.entries)
        _legacyBusinessServiceRecommendation(entry.key, entry.value),
    ];
  }

  List<VanRecommendedServiceSetup> recommendationsFor(
    Iterable<String> selectedServiceIds, {
    Map<String, Set<String>> capabilityIdsByService =
        const <String, Set<String>>{},
  }) {
    final selectedIds = selectedServiceIds.toSet();
    return <VanRecommendedServiceSetup>[
      for (final service in serviceRecommendations)
        if (selectedIds.contains(service.id))
          VanRecommendedServiceSetup.fromRecommendation(
            pack: this,
            recommendation: service,
            capabilityIds:
                capabilityIdsByService[service.id] ??
                service.recommendedCapabilityIds.toSet(),
          ),
    ];
  }
}

/// A customer-facing search name that points to an existing capability pack.
/// Keywords are deliberately hidden from the interface.
class VanBusinessSearchAlias {
  const VanBusinessSearchAlias(this.label, {this.keywords = const <String>[]});

  final String label;
  final List<String> keywords;
}

class VanBusinessSearchResult {
  const VanBusinessSearchResult({required this.pack, required this.label});

  final VanStarterCapabilityPack pack;
  final String label;
}

/// A business type may recommend services, but it does not own their
/// behaviour. Behaviour comes from [recommendedCapabilityIds] and the
/// universal capability resolver.
class VanBusinessServiceRecommendation {
  const VanBusinessServiceRecommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.recommendedCapabilityIds,
    this.questions = const <VanServiceTemplateQuestion>[],
    this.extras = const <VanServiceTemplateExtra>[],
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
    this.requestPhotos = false,
    this.iconKey,
    this.colorValue,
  });

  final String id;
  final String name;
  final String description;
  final List<String> recommendedCapabilityIds;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requestPhotos;
  final String? iconKey;
  final int? colorValue;
}

/// Compatibility input for business packs created before universal service
/// capabilities were introduced. New packs should define [services] with
/// [VanBusinessServiceRecommendation] instead.
class VanStarterCapability {
  const VanStarterCapability({
    required this.id,
    required this.label,
    required this.description,
    required this.serviceKey,
    required this.serviceName,
    required this.journeyType,
    required this.requestType,
    this.allowCustomerDropOff = false,
    this.allowBusinessCollection = false,
    this.allowCustomerCollection = false,
    this.allowBusinessReturn = false,
    this.questions = const <VanServiceTemplateQuestion>[],
    this.extras = const <VanServiceTemplateExtra>[],
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
    this.requireAddress = false,
    this.requestPhotos = false,
    this.iconKey,
    this.colorValue,
  });

  final String id;
  final String label;
  final String description;
  final String serviceKey;
  final String serviceName;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final bool allowCustomerDropOff;
  final bool allowBusinessCollection;
  final bool allowCustomerCollection;
  final bool allowBusinessReturn;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requireAddress;
  final bool requestPhotos;
  final String? iconKey;
  final int? colorValue;

  List<String> get summaryTags => <String>[
    journeyType.selectorLabel,
    if (allowCustomerDropOff) 'Customer drop-off',
    if (allowBusinessCollection) 'Business collection',
    if (allowCustomerCollection) 'Customer collection',
    if (allowBusinessReturn) 'Business return',
    if (suggestedDurationMinutes != null) '$suggestedDurationMinutes min',
  ];
}

VanBusinessServiceRecommendation _legacyBusinessServiceRecommendation(
  String serviceKey,
  List<VanStarterCapability> capabilities,
) {
  final first = capabilities.first;
  final questions = <String, VanServiceTemplateQuestion>{};
  final extras = <String, VanServiceTemplateExtra>{};
  final statusNames = <String, String>{};
  final reminders = <int>{};
  final capabilityIds = <String>{};
  for (final capability in capabilities) {
    capabilityIds.addAll(_universalIdsForLegacyCapability(capability));
    for (final question in capability.questions) {
      questions[_normalized(question.text)] = question;
    }
    for (final extra in capability.extras) {
      extras[extra.key] = extra;
    }
    statusNames.addAll(capability.suggestedStatusNames);
    reminders.addAll(capability.suggestedReminderMinutes);
  }
  final durationValues = capabilities
      .map((item) => item.suggestedDurationMinutes)
      .whereType<int>();
  final duration = durationValues.isEmpty
      ? null
      : durationValues.reduce((left, right) => left > right ? left : right);
  final message = capabilities
      .map((item) => item.suggestedCustomerMessage.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  return VanBusinessServiceRecommendation(
    id: serviceKey,
    name: first.serviceName,
    description: capabilities.length == 1
        ? first.description
        : first.serviceName,
    recommendedCapabilityIds: capabilityIds.toList(growable: false),
    questions: questions.values.toList(growable: false),
    extras: extras.values.toList(growable: false),
    suggestedDurationMinutes: duration,
    suggestedNoticeHours: capabilities
        .map((item) => item.suggestedNoticeHours)
        .reduce((left, right) => left > right ? left : right),
    suggestedCustomerMessage: message,
    suggestedStatusNames: Map<String, String>.unmodifiable(statusNames),
    suggestedReminderMinutes: reminders.toList(growable: false)..sort(),
    requestPhotos: capabilities.any((item) => item.requestPhotos),
    iconKey: first.iconKey,
    colorValue: first.colorValue,
  );
}

Set<String> _universalIdsForLegacyCapability(VanStarterCapability capability) {
  final searchable = '${capability.id} ${capability.label}'.toLowerCase();
  final isDeliveryRecommendation =
      searchable.contains('delivery') && capability.requireAddress;
  final ids = <String>{
    VanServiceCapabilityIds.booking,
    VanServiceCapabilityIds.oneOff,
    if (capability.suggestedDurationMinutes != null)
      VanServiceCapabilityIds.estimatedDuration,
    if (capability.suggestedNoticeHours > 24) VanServiceCapabilityIds.leadTime,
  };
  ids.add(switch (capability.journeyType) {
    VanCustomerJourneyType.quote => VanServiceCapabilityIds.requestQuote,
    VanCustomerJourneyType.booking => VanServiceCapabilityIds.bookAppointment,
    VanCustomerJourneyType.order => VanServiceCapabilityIds.placeOrder,
  });
  ids.add(
    capability.journeyType == VanCustomerJourneyType.quote
        ? VanServiceCapabilityIds.customQuote
        : VanServiceCapabilityIds.fixedPrice,
  );
  if (capability.journeyType == VanCustomerJourneyType.booking) {
    ids.add(VanServiceCapabilityIds.appointmentRequired);
  }
  if (capability.allowCustomerDropOff) {
    ids.add(VanServiceCapabilityIds.customerDropsOff);
  }
  if (capability.allowBusinessCollection) {
    ids.add(VanServiceCapabilityIds.businessCollects);
  }
  if (capability.allowCustomerCollection) {
    ids.add(VanServiceCapabilityIds.customerCollects);
  }
  if (capability.allowBusinessReturn && !isDeliveryRecommendation) {
    ids.add(VanServiceCapabilityIds.businessReturns);
  }
  if (capability.requireAddress &&
      !capability.allowBusinessCollection &&
      !capability.allowBusinessReturn) {
    ids.add(VanServiceCapabilityIds.businessVisitsCustomer);
  }
  if (searchable.contains('walk')) ids.add(VanServiceCapabilityIds.walkIn);
  if (searchable.contains('pre-order') || searchable.contains('pre order')) {
    ids.add(VanServiceCapabilityIds.preOrder);
  }
  if (isDeliveryRecommendation) {
    ids.add(VanServiceCapabilityIds.localDelivery);
  }
  return ids;
}

class VanRecommendedServiceSetup {
  const VanRecommendedServiceSetup({
    required this.packId,
    required this.packName,
    required this.capabilityIds,
    required this.serviceKey,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.colorValue,
    required this.journeyType,
    required this.requestType,
    required this.allowCustomerDropOff,
    required this.allowBusinessCollection,
    required this.allowCustomerCollection,
    required this.allowBusinessReturn,
    required this.questions,
    required this.extras,
    required this.suggestedDurationMinutes,
    required this.suggestedNoticeHours,
    required this.suggestedCustomerMessage,
    required this.suggestedStatusNames,
    required this.suggestedReminderMinutes,
    required this.requireAddress,
    required this.requestPhotos,
    required this.builtInQuestionKeys,
    required this.pricingMode,
  });

  factory VanRecommendedServiceSetup.fromRecommendation({
    required VanStarterCapabilityPack pack,
    required VanBusinessServiceRecommendation recommendation,
    required Set<String> capabilityIds,
  }) {
    final resolved = resolveVanServiceCapabilities(
      capabilityIds,
      recommendedDurationMinutes: recommendation.suggestedDurationMinutes,
      recommendedNoticeHours: recommendation.suggestedNoticeHours,
    );
    final questions = <String, VanServiceTemplateQuestion>{};
    final extras = <String, VanServiceTemplateExtra>{};
    for (final question in <VanServiceTemplateQuestion>[
      ...resolved.questions,
      ...recommendation.questions,
    ]) {
      questions[_normalized(question.text)] = question;
    }
    for (final extra in <VanServiceTemplateExtra>[
      ...resolved.extras,
      ...recommendation.extras,
    ]) {
      extras[extra.key] = extra;
    }
    final reminderSet = <int>{
      ...recommendation.suggestedReminderMinutes,
      ...resolved.suggestedReminderMinutes,
    };
    if (reminderSet.isEmpty &&
        (resolved.journeyType != VanCustomerJourneyType.order ||
            resolved.builtInQuestionKeys.contains('preferred_date'))) {
      reminderSet.add(1440);
    }
    final reminders = reminderSet.toList(growable: false)..sort();
    final statusNames = recommendation.suggestedStatusNames.isNotEmpty
        ? recommendation.suggestedStatusNames
        : <String, String>{
            'received': '${recommendation.name} request received',
            'accepted': '${recommendation.name} confirmed',
            'ready': switch (resolved.journeyType) {
              VanCustomerJourneyType.order => 'Ready for fulfilment',
              VanCustomerJourneyType.booking => 'Service complete',
              VanCustomerJourneyType.quote => 'Work complete',
            },
          };
    return VanRecommendedServiceSetup(
      packId: pack.id,
      packName: pack.name,
      capabilityIds: resolved.capabilityIds,
      serviceKey: recommendation.id,
      name: recommendation.name,
      description: recommendation.description,
      category: pack.category,
      iconKey: recommendation.iconKey ?? pack.iconKey,
      colorValue: recommendation.colorValue ?? pack.colorValue,
      journeyType: resolved.journeyType,
      requestType: resolved.requestType,
      allowCustomerDropOff: resolved.allowCustomerDropOff,
      allowBusinessCollection: resolved.allowBusinessCollection,
      allowCustomerCollection: resolved.allowCustomerCollection,
      allowBusinessReturn: resolved.allowBusinessReturn,
      questions: questions.values.toList(growable: false),
      extras: extras.values.toList(growable: false),
      suggestedDurationMinutes: resolved.suggestedDurationMinutes,
      suggestedNoticeHours: resolved.suggestedNoticeHours,
      suggestedCustomerMessage: recommendation.suggestedCustomerMessage,
      suggestedStatusNames: statusNames,
      suggestedReminderMinutes: reminders,
      requireAddress: resolved.requireAddress,
      requestPhotos: recommendation.requestPhotos || resolved.requestPhotos,
      builtInQuestionKeys: resolved.builtInQuestionKeys,
      pricingMode: resolved.pricingMode,
    );
  }

  factory VanRecommendedServiceSetup.merge({
    required VanStarterCapabilityPack pack,
    required String serviceKey,
    required List<VanStarterCapability> capabilities,
  }) {
    final first = capabilities.first;
    final questions = <String, VanServiceTemplateQuestion>{};
    final extras = <String, VanServiceTemplateExtra>{};
    final statusNames = <String, String>{};
    final reminders = <int>{};
    for (final capability in capabilities) {
      for (final question in capability.questions) {
        questions[_normalized(question.text)] = question;
      }
      for (final extra in capability.extras) {
        extras[extra.key] = extra;
      }
      statusNames.addAll(capability.suggestedStatusNames);
      reminders.addAll(capability.suggestedReminderMinutes);
    }
    final durationValues = capabilities
        .map((item) => item.suggestedDurationMinutes)
        .whereType<int>();
    final duration = durationValues.isEmpty
        ? null
        : durationValues.reduce((left, right) => left > right ? left : right);
    final message = capabilities
        .map((item) => item.suggestedCustomerMessage.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return VanRecommendedServiceSetup.fromRecommendation(
      pack: pack,
      recommendation: VanBusinessServiceRecommendation(
        id: serviceKey,
        name: first.serviceName,
        description: capabilities.length == 1
            ? first.description
            : first.serviceName,
        recommendedCapabilityIds: capabilities
            .expand(_universalIdsForLegacyCapability)
            .toSet()
            .toList(growable: false),
        questions: questions.values.toList(growable: false),
        extras: extras.values.toList(growable: false),
        suggestedDurationMinutes: duration,
        suggestedNoticeHours: capabilities
            .map((item) => item.suggestedNoticeHours)
            .reduce((left, right) => left > right ? left : right),
        suggestedCustomerMessage: message,
        suggestedStatusNames: Map<String, String>.unmodifiable(statusNames),
        suggestedReminderMinutes: reminders.toList(growable: false)..sort(),
        requestPhotos: capabilities.any((item) => item.requestPhotos),
        iconKey: first.iconKey,
        colorValue: first.colorValue,
      ),
      capabilityIds: capabilities
          .expand(_universalIdsForLegacyCapability)
          .toSet(),
    );
  }

  final String packId;
  final String packName;
  final List<String> capabilityIds;
  final String serviceKey;
  final String name;
  final String description;
  final String category;
  final String iconKey;
  final int colorValue;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final bool allowCustomerDropOff;
  final bool allowBusinessCollection;
  final bool allowCustomerCollection;
  final bool allowBusinessReturn;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requireAddress;
  final bool requestPhotos;
  final Set<String> builtInQuestionKeys;
  final String pricingMode;

  VanQuoteExtraDefaults quoteExtraDefaults() {
    var defaults = VanQuoteExtraDefaults.empty();
    for (final extra in extras.where(
      (item) => isVanQuoteBuiltInExtraKey(item.key),
    )) {
      defaults = defaults.copyWithExtra(
        VanQuoteExtraDefault.fallback(extra.key).copyWith(
          label: extra.label,
          defaultPrice: extra.defaultPrice,
          enabled: extra.enabledByDefault,
        ),
      );
    }
    return defaults.copyWithCustomExtras(<VanQuoteExtraDefault>[
      for (final extra in extras)
        if (!isVanQuoteBuiltInExtraKey(extra.key))
          VanQuoteExtraDefault.custom(
            key: extra.key,
            label: extra.label,
            defaultPrice: extra.defaultPrice,
            enabled: extra.enabledByDefault,
          ),
    ]);
  }
}

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

VanServiceTemplateQuestion _transportQuestion(
  String libraryId,
  String text,
  VanCustomQuestionCategory category, {
  VanCustomQuestionAnswerType answerType =
      VanCustomQuestionAnswerType.shortText,
  List<String> choices = const <String>[],
  List<String> tags = const <String>[],
}) => VanServiceTemplateQuestion(
  libraryId: libraryId,
  text: text,
  category: category,
  answerType: answerType,
  choiceOptions: choices,
  tags: tags,
);

VanServiceTemplateExtra _transportExtra(
  String key,
  String label,
  String chargeUnit,
  List<String> tags, {
  bool enabled = true,
}) => VanServiceTemplateExtra(
  key: key,
  label: label,
  enabledByDefault: enabled,
  defaultChargeUnit: chargeUnit,
  tags: tags,
);

final List<VanServiceTemplateQuestion> _courierSharedQuestions =
    <VanServiceTemplateQuestion>[
      _transportQuestion(
        'transport.items.what',
        'What are we collecting?',
        VanCustomQuestionCategory.items,
      ),
      _transportQuestion(
        'transport.items.size',
        'Approximately how large is the item or package?',
        VanCustomQuestionCategory.sizeWeight,
      ),
      _transportQuestion(
        'transport.items.weight',
        'What is the approximate weight?',
        VanCustomQuestionCategory.sizeWeight,
      ),
      _transportQuestion(
        'transport.items.fragile',
        'Is the item fragile?',
        VanCustomQuestionCategory.fragileValuableItems,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.timing.restrictions',
        'Are there any collection or delivery time restrictions?',
        VanCustomQuestionCategory.timing,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      _transportQuestion(
        'transport.pod.signature',
        'Is a signature required on delivery?',
        VanCustomQuestionCategory.proofOfDelivery,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.instructions.collection_delivery',
        'Are there any special collection or delivery instructions?',
        VanCustomQuestionCategory.generalNotes,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      _transportQuestion(
        'transport.photos.items',
        'Would you like to upload a photo of the item or package?',
        VanCustomQuestionCategory.photosVideo,
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
    ];

final List<VanServiceTemplateExtra> _courierExtras = <VanServiceTemplateExtra>[
  _transportExtra(
    'custom_extra_urgent_collection',
    'Urgent collection',
    'Fixed',
    const <String>['urgent_work'],
  ),
  _transportExtra(
    'custom_extra_out_of_hours_delivery',
    'Out-of-hours delivery',
    'Fixed',
    const <String>['out_of_hours', 'delivery'],
  ),
  _transportExtra(
    'custom_extra_weekend_delivery',
    'Weekend delivery',
    'Fixed',
    const <String>['out_of_hours', 'delivery'],
  ),
  _transportExtra(
    kVanQuoteExtraWaitingTimeKey,
    'Waiting time',
    '30 Minutes',
    const <String>['time'],
  ),
  _transportExtra(
    'custom_extra_additional_stop',
    'Additional stop',
    'Stop',
    const <String>['delivery'],
  ),
  _transportExtra(
    'custom_extra_heavy_item',
    'Heavy-item surcharge',
    'Item',
    const <String>['items'],
  ),
  _transportExtra(
    'custom_extra_oversized_item',
    'Oversized-item surcharge',
    'Item',
    const <String>['items'],
  ),
  _transportExtra(
    kVanQuoteExtraMileageKey,
    'Mileage outside included area',
    'Mile',
    const <String>['travel'],
  ),
  _transportExtra(
    'custom_extra_signature_service',
    'Signature service',
    'Fixed',
    const <String>['delivery'],
  ),
];

List<String> _courierCapabilities({
  bool urgent = false,
  bool multiStop = false,
}) => <String>[
  VanServiceCapabilityIds.booking,
  VanServiceCapabilityIds.oneOff,
  VanServiceCapabilityIds.requestQuote,
  VanServiceCapabilityIds.customQuote,
  VanServiceCapabilityIds.businessCollects,
  VanServiceCapabilityIds.businessReturns,
  VanServiceCapabilityIds.photoUpload,
  VanServiceCapabilityIds.proofOfDelivery,
  VanServiceCapabilityIds.estimatedDuration,
  if (urgent) VanServiceCapabilityIds.sameDay,
  if (multiStop) VanServiceCapabilityIds.multipleStops,
];

VanBusinessServiceRecommendation _courierService(
  String id,
  String name,
  String description, {
  List<VanServiceTemplateQuestion> questions =
      const <VanServiceTemplateQuestion>[],
  List<VanServiceTemplateExtra> extras = const <VanServiceTemplateExtra>[],
  bool urgent = false,
  bool multiStop = false,
}) => VanBusinessServiceRecommendation(
  id: id,
  name: name,
  description: description,
  recommendedCapabilityIds: _courierCapabilities(
    urgent: urgent,
    multiStop: multiStop,
  ),
  questions: <VanServiceTemplateQuestion>[
    ..._courierSharedQuestions,
    ...questions,
  ],
  extras: <VanServiceTemplateExtra>[..._courierExtras, ...extras],
  suggestedDurationMinutes: 60,
  suggestedNoticeHours: urgent ? 0 : 24,
  suggestedStatusNames: const <String, String>{
    'received': 'Delivery request received',
    'review': 'Reviewing job details',
    'quoted': 'Quote sent or fixed price confirmed',
    'accepted': 'Delivery confirmed',
    'collection': 'Collected',
    'in_transit': 'In transit',
    'delivered': 'Delivered',
    'proof_of_delivery': 'Proof of delivery',
    'ready': 'Proof of delivery complete',
  },
  suggestedReminderMinutes: const <int>[60],
  requestPhotos: true,
);

final VanStarterCapabilityPack _courierTransportPack = VanStarterCapabilityPack(
  id: 'courier_business',
  name: 'Courier',
  description: 'Collection, delivery and multi-stop courier services.',
  category: 'Transport & Delivery',
  iconKey: 'local_shipping',
  colorValue: 0xFF2563EB,
  featured: true,
  searchKeywords: const <String>['parcel', 'documents', 'same day', 'delivery'],
  services: <VanBusinessServiceRecommendation>[
    _courierService(
      'same_day_delivery',
      'Same-day Delivery',
      'Urgent collection and delivery completed on the same day.',
      urgent: true,
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'courier.urgency',
          'How urgent is the delivery?',
          VanCustomQuestionCategory.timing,
        ),
        _transportQuestion(
          'courier.latest_delivery_time',
          'What is the latest acceptable delivery time?',
          VanCustomQuestionCategory.timing,
          answerType: VanCustomQuestionAnswerType.time,
        ),
      ],
    ),
    _courierService(
      'scheduled_delivery',
      'Scheduled Delivery',
      'Collection and delivery arranged for agreed time windows.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'courier.collection_window',
          'Is there a specific collection time window?',
          VanCustomQuestionCategory.collection,
        ),
        _transportQuestion(
          'courier.delivery_window',
          'Is there a specific delivery time window?',
          VanCustomQuestionCategory.delivery,
        ),
      ],
    ),
    _courierService(
      'multi_drop_delivery',
      'Multi-drop Delivery',
      'One collection run with deliveries to several stops.',
      multiStop: true,
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'transport.stops.count',
          'How many delivery stops are required?',
          VanCustomQuestionCategory.multipleStops,
        ),
        _transportQuestion(
          'transport.stops.order',
          'Do the stops need to be completed in a particular order?',
          VanCustomQuestionCategory.multipleStops,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'transport.stops.instructions',
          'Are there separate instructions for any stop?',
          VanCustomQuestionCategory.multipleStops,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
    ),
    _courierService(
      'parcel_collection_delivery',
      'Parcel Collection and Delivery',
      'Collect a parcel and deliver it directly to its destination.',
    ),
    _courierService(
      'legal_document_delivery',
      'Legal Document Delivery',
      'Secure, time-sensitive delivery of legal documents.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'legal.recipient_signature',
          'Does the recipient need to sign for the documents?',
          VanCustomQuestionCategory.proofOfDelivery,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'legal.proof_required',
          'Is proof of delivery required?',
          VanCustomQuestionCategory.proofOfDelivery,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'legal.confidential_timing',
          'Is the delivery confidential or time-sensitive?',
          VanCustomQuestionCategory.timing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _courierService(
      'medical_pharmacy_delivery',
      'Medical or Pharmacy Delivery',
      'Careful delivery for medicines and medical items.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'medical.temperature_control',
          'Does the item require temperature-controlled handling?',
          VanCustomQuestionCategory.medicalHandling,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'medical.handling_instructions',
          'Are there any special handling instructions?',
          VanCustomQuestionCategory.medicalHandling,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        _transportQuestion(
          'medical.recipient_id_signature',
          'Is identification or a signature required from the recipient?',
          VanCustomQuestionCategory.proofOfDelivery,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
      extras: <VanServiceTemplateExtra>[
        _transportExtra(
          'custom_extra_temperature_controlled',
          'Temperature-controlled handling',
          'Fixed',
          const <String>['delivery', 'items'],
        ),
      ],
    ),
  ],
);

final List<VanServiceTemplateQuestion> _manVanSharedQuestions =
    <VanServiceTemplateQuestion>[
      _transportQuestion(
        'transport.items.what',
        'What needs moving?',
        VanCustomQuestionCategory.items,
      ),
      _transportQuestion(
        'transport.items.count',
        'Approximately how many items are there?',
        VanCustomQuestionCategory.items,
      ),
      _transportQuestion(
        'transport.items.largest_heaviest',
        'What are the largest or heaviest items?',
        VanCustomQuestionCategory.sizeWeight,
      ),
      _transportQuestion(
        'transport.items.fragile_valuable',
        'Are any items fragile or particularly valuable?',
        VanCustomQuestionCategory.fragileValuableItems,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.collection_stairs',
        'Are there stairs at the collection address?',
        VanCustomQuestionCategory.stairsLifts,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.delivery_stairs',
        'Are there stairs at the delivery address?',
        VanCustomQuestionCategory.stairsLifts,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.lift',
        'Is a lift available at either address?',
        VanCustomQuestionCategory.stairsLifts,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.parking_both',
        'Is parking available close to both addresses?',
        VanCustomQuestionCategory.parking,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.labour.loading_help',
        'Will you need help loading and unloading?',
        VanCustomQuestionCategory.items,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.assembly.required',
        'Does anything require dismantling or reassembly?',
        VanCustomQuestionCategory.assembly,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.restrictions',
        'Are there any access restrictions or time limits?',
        VanCustomQuestionCategory.access,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      _transportQuestion(
        'transport.photos.items',
        'Would you like to upload photos of the items?',
        VanCustomQuestionCategory.photosVideo,
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
    ];

final List<VanServiceTemplateExtra> _manVanExtras = <VanServiceTemplateExtra>[
  _transportExtra(
    kVanQuoteExtraHelperKey,
    'Additional helper',
    'Hour',
    const <String>['labour'],
  ),
  _transportExtra(
    'custom_extra_additional_stop',
    'Extra stop',
    'Stop',
    const <String>['delivery'],
  ),
  _transportExtra(
    kVanQuoteExtraWaitingTimeKey,
    'Waiting time',
    '30 Minutes',
    const <String>['time'],
  ),
  _transportExtra(
    kVanQuoteExtraStairsKey,
    'Stairs surcharge',
    'Floor',
    const <String>['access'],
  ),
  _transportExtra(
    'custom_extra_heavy_oversized',
    'Heavy or oversized item',
    'Item',
    const <String>['items'],
  ),
  _transportExtra(
    'custom_extra_dismantling',
    'Dismantling',
    'Item',
    const <String>['assembly'],
  ),
  _transportExtra(
    'custom_extra_reassembly',
    'Reassembly',
    'Item',
    const <String>['assembly'],
  ),
  _transportExtra(
    'custom_extra_packing_materials',
    'Packing materials',
    'Fixed',
    const <String>['packing'],
  ),
  _transportExtra(
    'custom_extra_evening_booking',
    'Evening booking',
    'Fixed',
    const <String>['out_of_hours'],
  ),
  _transportExtra(
    'custom_extra_weekend_booking',
    'Weekend booking',
    'Fixed',
    const <String>['out_of_hours'],
  ),
  _transportExtra(
    kVanQuoteExtraMileageKey,
    'Mileage outside included area',
    'Mile',
    const <String>['travel'],
  ),
  _transportExtra(
    'custom_extra_long_carry',
    'Long carry from vehicle',
    'Fixed',
    const <String>['access'],
  ),
  _transportExtra(
    'custom_extra_packaging_disposal',
    'Disposal of packaging',
    'Fixed',
    const <String>['packing'],
  ),
  _transportExtra(
    'custom_extra_appliance_installation',
    'Appliance installation',
    'Fixed',
    const <String>['assembly'],
  ),
  _transportExtra('custom_extra_deposit', 'Deposit', 'Fixed', const <String>[
    'payment',
  ], enabled: false),
];

VanBusinessServiceRecommendation _manVanService(
  String id,
  String name,
  String description, {
  List<VanServiceTemplateQuestion> questions =
      const <VanServiceTemplateQuestion>[],
}) => VanBusinessServiceRecommendation(
  id: id,
  name: name,
  description: description,
  recommendedCapabilityIds: <String>[
    VanServiceCapabilityIds.booking,
    VanServiceCapabilityIds.oneOff,
    VanServiceCapabilityIds.requestQuote,
    VanServiceCapabilityIds.customQuote,
    VanServiceCapabilityIds.businessCollects,
    VanServiceCapabilityIds.businessReturns,
    VanServiceCapabilityIds.multipleStops,
    VanServiceCapabilityIds.photoUpload,
    VanServiceCapabilityIds.loadingUnloadingHelp,
    VanServiceCapabilityIds.dismantlingReassembly,
    VanServiceCapabilityIds.proofOfDelivery,
    VanServiceCapabilityIds.estimatedDuration,
  ],
  questions: <VanServiceTemplateQuestion>[
    ..._manVanSharedQuestions,
    ...questions,
  ],
  extras: _manVanExtras,
  suggestedDurationMinutes: 120,
  suggestedNoticeHours: 24,
  suggestedStatusNames: const <String, String>{
    'received': 'Move request received',
    'review': 'Reviewing details and photos',
    'quoted': 'Quote sent',
    'accepted': 'Move confirmed',
    'collection': 'Collected',
    'delivery': 'Delivered',
    'proof_of_delivery': 'Proof of delivery',
    'ready': 'Delivery complete',
  },
  suggestedReminderMinutes: const <int>[1440, 120],
  requestPhotos: true,
);

final VanStarterCapabilityPack _manVanTransportPack = VanStarterCapabilityPack(
  id: 'man_van_business',
  name: 'Man & Van',
  description: 'Flexible collection, delivery and smaller moving services.',
  category: 'Transport & Delivery',
  iconKey: 'local_shipping',
  colorValue: 0xFF0F766E,
  featured: true,
  searchKeywords: const <String>['moving', 'furniture', 'collection', 'van'],
  services: <VanBusinessServiceRecommendation>[
    _manVanService(
      'single_item_delivery',
      'Single Item Delivery',
      'Move one item safely between two locations.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.single.item',
          'What is the item?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'man_van.single.dimensions',
          'What are its approximate dimensions?',
          VanCustomQuestionCategory.sizeWeight,
        ),
        _transportQuestion(
          'man_van.single.help',
          'Will someone be available to help at either end?',
          VanCustomQuestionCategory.items,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _manVanService(
      'furniture_collection_delivery',
      'Furniture Collection and Delivery',
      'Collect and deliver furniture with optional assembly help.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.furniture.items',
          'What furniture is being collected?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'man_van.furniture.dismantling',
          'Does any item need dismantling?',
          VanCustomQuestionCategory.assembly,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.furniture.reassembly',
          'Does any item need reassembly at delivery?',
          VanCustomQuestionCategory.assembly,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _manVanService(
      'store_collection',
      'Store Collection',
      'Collect paid goods from a retailer and deliver them.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.store.name',
          'Which store is the item being collected from?',
          VanCustomQuestionCategory.collection,
        ),
        _transportQuestion(
          'man_van.store.paid',
          'Is the item already paid for?',
          VanCustomQuestionCategory.collection,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.store.reference',
          'Is there an order or collection reference?',
          VanCustomQuestionCategory.collection,
        ),
        _transportQuestion(
          'man_van.store.window',
          'Does the store have a collection time window?',
          VanCustomQuestionCategory.timing,
        ),
      ],
    ),
    _manVanService(
      'marketplace_collection',
      'Marketplace Collection',
      'Collect a marketplace purchase from its seller.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.marketplace.confirmed',
          'Has the seller confirmed the collection?',
          VanCustomQuestionCategory.collection,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.marketplace.payment',
          'Is payment already arranged?',
          VanCustomQuestionCategory.collection,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.marketplace.contact_reference',
          'Is there a contact name or collection reference?',
          VanCustomQuestionCategory.collection,
        ),
      ],
    ),
    _manVanService(
      'small_house_move',
      'Small House Move',
      'Move the contents of a small home.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'property.rooms.count',
          'Approximately how many rooms are being moved?',
          VanCustomQuestionCategory.property,
        ),
        _transportQuestion(
          'packing.ready',
          'Will everything be packed before arrival?',
          VanCustomQuestionCategory.packing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'transport.items.especially_heavy',
          'Are there any especially heavy items?',
          VanCustomQuestionCategory.sizeWeight,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _manVanService(
      'student_move',
      'Student Move',
      'Move belongings between home, storage and accommodation.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.student.item_count',
          'How many bags, boxes or pieces of furniture are being moved?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'man_van.student.route_type',
          'Is the move between accommodation, storage or home?',
          VanCustomQuestionCategory.property,
        ),
        _transportQuestion(
          'man_van.student.access',
          'Are there stairs or restricted access at either end?',
          VanCustomQuestionCategory.access,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _manVanService(
      'office_items_move',
      'Office Items Move',
      'Move desks, equipment or other office items.',
    ),
    _manVanService(
      'appliance_collection_delivery',
      'Appliance Collection and Delivery',
      'Collect and deliver a household appliance.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'man_van.appliance.item',
          'What appliance is being moved?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'man_van.appliance.disconnected',
          'Has it been disconnected?',
          VanCustomQuestionCategory.items,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.appliance.upstairs',
          'Does it need carrying upstairs?',
          VanCustomQuestionCategory.stairsLifts,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'man_van.appliance.installation',
          'Is installation required after delivery?',
          VanCustomQuestionCategory.assembly,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
  ],
);

final List<VanServiceTemplateQuestion> _removalsSharedQuestions =
    <VanServiceTemplateQuestion>[
      _transportQuestion(
        'removals.move.type',
        'What type of move is this?',
        VanCustomQuestionCategory.property,
      ),
      _transportQuestion(
        'property.rooms.count',
        'Approximately how many rooms are being moved?',
        VanCustomQuestionCategory.property,
      ),
      _transportQuestion(
        'removals.property.from_type',
        'What type of property are you moving from?',
        VanCustomQuestionCategory.property,
      ),
      _transportQuestion(
        'removals.property.to_type',
        'What type of property are you moving to?',
        VanCustomQuestionCategory.property,
      ),
      _transportQuestion(
        'removals.property.collection_floor',
        'What floor is the collection property on?',
        VanCustomQuestionCategory.stairsLifts,
      ),
      _transportQuestion(
        'removals.property.delivery_floor',
        'What floor is the delivery property on?',
        VanCustomQuestionCategory.stairsLifts,
      ),
      _transportQuestion(
        'transport.access.lift',
        'Is a lift available at either property?',
        VanCustomQuestionCategory.stairsLifts,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.parking_both',
        'Is parking available near both properties?',
        VanCustomQuestionCategory.parking,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.access.restrictions',
        'Are there any access restrictions?',
        VanCustomQuestionCategory.access,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      _transportQuestion(
        'transport.items.fragile_valuable',
        'Are there any especially large, heavy, fragile or valuable items?',
        VanCustomQuestionCategory.fragileValuableItems,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'packing.ready',
        'Will everything be packed before the move?',
        VanCustomQuestionCategory.packing,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'packing.service_requested',
        'Would you like a packing service?',
        VanCustomQuestionCategory.packing,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.assembly.required',
        'Does any furniture need dismantling or reassembly?',
        VanCustomQuestionCategory.assembly,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.stops.additional_addresses',
        'Are any additional collection or delivery addresses required?',
        VanCustomQuestionCategory.multipleStops,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.photos.items',
        'Would you like to upload photos or a short video of the items?',
        VanCustomQuestionCategory.photosVideo,
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
      _transportQuestion(
        'removals.survey.request',
        'Would you like to request a home or video survey?',
        VanCustomQuestionCategory.survey,
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      _transportQuestion(
        'transport.timing.restrictions',
        'Are there any preferred moving time restrictions?',
        VanCustomQuestionCategory.timing,
      ),
      _transportQuestion(
        'removals.notes',
        'Are there any other details the removals team should know?',
        VanCustomQuestionCategory.generalNotes,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
    ];

final List<VanServiceTemplateExtra> _removalsExtras = <VanServiceTemplateExtra>[
  _transportExtra(
    'custom_extra_packing_service',
    'Packing service',
    'Hour',
    const <String>['packing'],
  ),
  _transportExtra(
    'custom_extra_packing_materials',
    'Packing materials',
    'Fixed',
    const <String>['packing'],
  ),
  _transportExtra(
    'custom_extra_unpacking_service',
    'Unpacking service',
    'Hour',
    const <String>['packing', 'labour'],
  ),
  _transportExtra(
    'custom_extra_dismantling',
    'Furniture dismantling',
    'Item',
    const <String>['assembly'],
  ),
  _transportExtra(
    'custom_extra_reassembly',
    'Furniture reassembly',
    'Item',
    const <String>['assembly'],
  ),
  _transportExtra(
    kVanQuoteExtraHelperKey,
    'Additional movers',
    'Hour',
    const <String>['labour'],
  ),
  _transportExtra(
    'custom_extra_additional_vehicle',
    'Additional vehicle',
    'Day',
    const <String>['travel'],
  ),
  _transportExtra(
    'custom_extra_collection_point',
    'Extra collection point',
    'Stop',
    const <String>['travel'],
  ),
  _transportExtra(
    'custom_extra_delivery_point',
    'Extra delivery point',
    'Stop',
    const <String>['travel'],
  ),
  _transportExtra('custom_extra_storage', 'Storage', 'Day', const <String>[
    'storage',
  ]),
  _transportExtra(
    kVanQuoteExtraWaitingTimeKey,
    'Waiting time',
    '30 Minutes',
    const <String>['time'],
  ),
  _transportExtra(
    'custom_extra_weekend_move',
    'Weekend move',
    'Fixed',
    const <String>['out_of_hours'],
  ),
  _transportExtra(
    'custom_extra_evening_move',
    'Evening move',
    'Fixed',
    const <String>['out_of_hours'],
  ),
  _transportExtra(
    'custom_extra_heavy_item',
    'Heavy-item surcharge',
    'Item',
    const <String>['items'],
  ),
  _transportExtra(
    'custom_extra_specialist_item',
    'Specialist-item surcharge',
    'Item',
    const <String>['items'],
  ),
  _transportExtra(
    'custom_extra_long_carry',
    'Long-carry surcharge',
    'Fixed',
    const <String>['access'],
  ),
  _transportExtra(
    kVanQuoteExtraStairsKey,
    'Stairs surcharge',
    'Floor',
    const <String>['access'],
  ),
  _transportExtra(
    'custom_extra_disposal',
    'Disposal service',
    'Fixed',
    const <String>['items'],
  ),
  _transportExtra(
    'custom_extra_home_survey',
    'Home survey',
    'Fixed',
    const <String>['labour'],
  ),
  _transportExtra(
    'custom_extra_urgent_booking',
    'Urgent booking',
    'Fixed',
    const <String>['urgent_work'],
  ),
  _transportExtra('custom_extra_deposit', 'Deposit', 'Fixed', const <String>[
    'payment',
  ]),
];

VanBusinessServiceRecommendation _removalsService(
  String id,
  String name,
  String description, {
  List<VanServiceTemplateQuestion> questions =
      const <VanServiceTemplateQuestion>[],
  bool onSiteOnly = false,
}) => VanBusinessServiceRecommendation(
  id: id,
  name: name,
  description: description,
  recommendedCapabilityIds: <String>[
    VanServiceCapabilityIds.booking,
    VanServiceCapabilityIds.oneOff,
    VanServiceCapabilityIds.requestQuote,
    VanServiceCapabilityIds.customQuote,
    if (onSiteOnly)
      VanServiceCapabilityIds.businessVisitsCustomer
    else ...<String>[
      VanServiceCapabilityIds.businessCollects,
      VanServiceCapabilityIds.businessReturns,
      VanServiceCapabilityIds.multipleStops,
      VanServiceCapabilityIds.multipleVehicles,
      VanServiceCapabilityIds.proofOfDelivery,
    ],
    VanServiceCapabilityIds.teamMembers,
    VanServiceCapabilityIds.photoUpload,
    VanServiceCapabilityIds.videoUpload,
    VanServiceCapabilityIds.siteSurvey,
    VanServiceCapabilityIds.packingService,
    VanServiceCapabilityIds.dismantlingReassembly,
    VanServiceCapabilityIds.leadTime,
    VanServiceCapabilityIds.estimatedDuration,
  ],
  questions: <VanServiceTemplateQuestion>[
    ..._removalsSharedQuestions,
    ...questions,
  ],
  extras: _removalsExtras,
  suggestedDurationMinutes: 240,
  suggestedNoticeHours: 48,
  suggestedStatusNames: const <String, String>{
    'received': 'Removal enquiry received',
    'review': 'Reviewing information and uploads',
    'survey': 'Survey arranged',
    'quoted': 'Quote sent',
    'accepted': 'Move confirmed',
    'packing': 'Packing in progress',
    'moving': 'Move in progress',
    'delivery': 'Delivered',
    'ready': 'Completion confirmed',
  },
  suggestedReminderMinutes: const <int>[2880, 1440],
  requestPhotos: true,
);

final VanStarterCapabilityPack
_removalsTransportPack = VanStarterCapabilityPack(
  id: 'removals_business',
  name: 'Removals',
  description: 'Home, office, packing and storage removal services.',
  category: 'Transport & Delivery',
  iconKey: 'inventory_2',
  colorValue: 0xFF7C3AED,
  featured: true,
  searchKeywords: const <String>[
    'moving house',
    'office move',
    'packing',
    'storage',
  ],
  services: <VanBusinessServiceRecommendation>[
    _removalsService(
      'house_move',
      'House Move',
      'Full or partial moves between houses.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.house.scope',
          'Is this a full or partial house move?',
          VanCustomQuestionCategory.property,
        ),
        _transportQuestion(
          'removals.house.outbuildings',
          'Are sheds, garages, lofts or outdoor items included?',
          VanCustomQuestionCategory.items,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.house.white_goods',
          'Are white goods included?',
          VanCustomQuestionCategory.items,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'flat_apartment_move',
      'Flat or Apartment Move',
      'Move into or out of a flat or apartment.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.flat.lift_working',
          'Is there a working lift?',
          VanCustomQuestionCategory.stairsLifts,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.flat.lift_booking',
          'Is lift access restricted or bookable?',
          VanCustomQuestionCategory.stairsLifts,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.flat.narrow_access',
          'Are there narrow corridors or staircases?',
          VanCustomQuestionCategory.access,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'office_move',
      'Office Move',
      'Move workstations, equipment and office contents.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.office.workstations',
          'Approximately how many desks or workstations are being moved?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'removals.office.special_items',
          'Are filing cabinets, safes or IT equipment included?',
          VanCustomQuestionCategory.items,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.office.out_of_hours',
          'Does the move need to happen outside business hours?',
          VanCustomQuestionCategory.timing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.office.approval',
          'Is building management approval required?',
          VanCustomQuestionCategory.access,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'packing_service',
      'Packing Service',
      'Professional packing without transport.',
      onSiteOnly: true,
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.packing.scope',
          'Which rooms or items require packing?',
          VanCustomQuestionCategory.packing,
        ),
        _transportQuestion(
          'removals.packing.materials',
          'Would you like the business to supply packing materials?',
          VanCustomQuestionCategory.packing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
        _transportQuestion(
          'removals.packing.specialist',
          'Are there fragile or specialist items requiring extra protection?',
          VanCustomQuestionCategory.fragileValuableItems,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'packing_and_removal',
      'Packing and Removal',
      'Packing and moving provided as one service.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.packing.schedule',
          'Should packing be completed on the same day or beforehand?',
          VanCustomQuestionCategory.timing,
        ),
        _transportQuestion(
          'removals.packing.unpacking',
          'Would you like unpacking included at the destination?',
          VanCustomQuestionCategory.packing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'storage_collection',
      'Storage Collection',
      'Collect belongings from a storage facility.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.storage.facility',
          'Which storage facility is being collected from?',
          VanCustomQuestionCategory.collection,
        ),
        _transportQuestion(
          'removals.storage.access',
          'Is there a unit number or access code?',
          VanCustomQuestionCategory.access,
        ),
        _transportQuestion(
          'removals.storage.notice',
          'Does the facility require advance notice or identification?',
          VanCustomQuestionCategory.timing,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
    _removalsService(
      'storage_delivery',
      'Storage Delivery',
      'Deliver belongings to or from storage.',
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.storage.destination',
          'Is delivery going to a home, office or another storage facility?',
          VanCustomQuestionCategory.delivery,
        ),
        _transportQuestion(
          'removals.storage.restrictions',
          'Are there any access or booking restrictions?',
          VanCustomQuestionCategory.access,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
    ),
    _removalsService(
      'internal_property_move',
      'Internal Property Move',
      'Move items between rooms or floors at one property.',
      onSiteOnly: true,
      questions: <VanServiceTemplateQuestion>[
        _transportQuestion(
          'removals.internal.items',
          'Which items are being moved?',
          VanCustomQuestionCategory.items,
        ),
        _transportQuestion(
          'removals.internal.route',
          'Which rooms or floors are they moving between?',
          VanCustomQuestionCategory.property,
        ),
        _transportQuestion(
          'removals.internal.access',
          'Are stairs, narrow doorways or dismantling involved?',
          VanCustomQuestionCategory.access,
          answerType: VanCustomQuestionAnswerType.yesNo,
        ),
      ],
    ),
  ],
);

const _bakeryPack = VanStarterCapabilityPack(
  id: 'bakery_business',
  name: 'Bakery',
  description: 'Orders, collections, delivery and celebration cakes.',
  category: 'Food & local business',
  iconKey: 'sparkle',
  colorValue: 0xFFFFA95C,
  featured: true,
  searchKeywords: <String>[
    'cake',
    'cakes',
    'bakery',
    'bread',
    'pastry',
    'baking',
  ],
  searchAliases: <VanBusinessSearchAlias>[
    VanBusinessSearchAlias('Wedding Cakes'),
    VanBusinessSearchAlias('Cupcakes', keywords: <String>['cupcake']),
  ],
  capabilities: <VanStarterCapability>[
    VanStarterCapability(
      id: 'walk_in',
      label: 'Walk-in purchases',
      description: 'Simple counter orders without a handover journey.',
      serviceKey: 'walk_in',
      serviceName: 'Walk-in Purchases',
      journeyType: VanCustomerJourneyType.order,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 10,
      suggestedCustomerMessage: 'Your order will be prepared for your visit.',
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'What would you like to order?'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(
          text: 'Allergies or dietary requirements',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'click_collect',
      label: 'Click & Collect',
      description: 'Customers order ahead and collect when ready.',
      serviceKey: 'click_collect',
      serviceName: 'Click & Collect',
      journeyType: VanCustomerJourneyType.order,
      requestType: VanCustomerRequestType.quoteRequest,
      allowCustomerCollection: true,
      suggestedDurationMinutes: 15,
      suggestedCustomerMessage:
          "We'll prepare your order and let you know when it's ready to collect.",
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'What would you like to order?'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(text: 'Preferred date'),
        VanServiceTemplateQuestion(
          text: 'Preferred collection time',
          answerType: VanCustomQuestionAnswerType.time,
        ),
        VanServiceTemplateQuestion(
          text: 'Allergies or dietary requirements',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_gift_box',
          label: 'Gift box',
          defaultPrice: 4,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_rush_order',
          label: 'Rush order',
          defaultPrice: 15,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'pre_orders',
      label: 'Pre-orders',
      description: 'Advance orders with a requested date and time.',
      serviceKey: 'pre_orders',
      serviceName: 'Pre-orders',
      journeyType: VanCustomerJourneyType.order,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 20,
      suggestedCustomerMessage:
          "We'll confirm your pre-order date and collection details.",
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'What would you like to order?'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(text: 'Preferred date'),
        VanServiceTemplateQuestion(text: 'Preferred time'),
        VanServiceTemplateQuestion(
          text: 'Allergies or dietary requirements',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_rush_order',
          label: 'Rush order',
          defaultPrice: 15,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'local_delivery',
      label: 'Local Delivery',
      description: 'Local orders delivered by your business.',
      serviceKey: 'local_delivery',
      serviceName: 'Local Delivery',
      journeyType: VanCustomerJourneyType.order,
      requestType: VanCustomerRequestType.quoteRequest,
      allowBusinessReturn: true,
      requireAddress: true,
      suggestedDurationMinutes: 45,
      suggestedCustomerMessage:
          "We'll deliver your order to the address you provide.",
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: kVanQuoteExtraMileageKey,
          label: 'Delivery mileage',
          defaultPrice: 1,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_timed_delivery',
          label: 'Timed delivery',
          defaultPrice: 10,
        ),
      ],
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'What would you like to order?'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(text: 'Address'),
        VanServiceTemplateQuestion(text: 'Preferred date'),
        VanServiceTemplateQuestion(
          text: 'Preferred delivery time',
          answerType: VanCustomQuestionAnswerType.time,
        ),
        VanServiceTemplateQuestion(
          text: 'Delivery instructions',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        VanServiceTemplateQuestion(
          text: 'Allergies or dietary requirements',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'celebration_cakes',
      label: 'Wedding / Celebration Cakes',
      description: 'Bespoke cakes that need a quote and design conversation.',
      serviceKey: 'celebration_cakes',
      serviceName: 'Wedding & Celebration Cakes',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      allowCustomerCollection: true,
      suggestedDurationMinutes: 60,
      suggestedNoticeHours: 168,
      suggestedCustomerMessage:
          "We'll discuss your design, provide a quote and confirm collection details.",
      suggestedStatusNames: <String, String>{
        'received': 'Cake enquiry received',
        'accepted': 'Cake booked',
        'ready': 'Ready for collection',
      },
      suggestedReminderMinutes: <int>[10080, 1440],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_deposit',
          label: 'Deposit',
          defaultPrice: 50,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_design_consultation',
          label: 'Design consultation',
          defaultPrice: 25,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_extra_tiers',
          label: 'Extra tiers',
          defaultPrice: 40,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_fondant',
          label: 'Fondant finish',
          defaultPrice: 20,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_sugar_flowers',
          label: 'Sugar flowers',
          defaultPrice: 25,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_wedding_cake_delivery',
          label: 'Delivery',
          defaultPrice: 30,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_cake_stand_hire',
          label: 'Cake stand hire',
          defaultPrice: 20,
        ),
      ],
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'Occasion'),
        VanServiceTemplateQuestion(text: 'Event date'),
        VanServiceTemplateQuestion(text: 'Number of servings'),
        VanServiceTemplateQuestion(text: 'Theme / Colours'),
        VanServiceTemplateQuestion(
          text: 'Inspiration photos',
          answerType: VanCustomQuestionAnswerType.photoUploadRequest,
        ),
        VanServiceTemplateQuestion(
          text: 'Collection or delivery',
          answerType: VanCustomQuestionAnswerType.multipleChoice,
          choiceOptions: <String>['Collection', 'Delivery'],
        ),
        VanServiceTemplateQuestion(
          text: 'Allergies or dietary requirements',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        VanServiceTemplateQuestion(
          text: 'Additional notes',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ],
      requestPhotos: true,
    ),
    VanStarterCapability(
      id: 'corporate_orders',
      label: 'Corporate Orders',
      description: 'Larger repeat or event orders for organisations.',
      serviceKey: 'corporate_orders',
      serviceName: 'Corporate Orders',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 30,
      suggestedCustomerMessage:
          "We'll review your requirements and confirm pricing and fulfilment.",
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'Company name'),
        VanServiceTemplateQuestion(text: 'What would you like to order?'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(text: 'Required date'),
        VanServiceTemplateQuestion(text: 'Allergies or dietary notes?'),
      ],
    ),
  ],
);

const _dogGroomerPack = VanStarterCapabilityPack(
  id: 'dog_groomer_business',
  name: 'Dog Groomer',
  description: 'Grooming appointments with flexible pet handovers.',
  category: 'Pets',
  iconKey: 'pet',
  colorValue: 0xFF9B8CFF,
  featured: true,
  searchKeywords: <String>['dog', 'dogs', 'groomer', 'grooming', 'pet', 'pets'],
  searchAliases: <VanBusinessSearchAlias>[
    VanBusinessSearchAlias('Dog Grooming'),
  ],
  services: <VanBusinessServiceRecommendation>[
    VanBusinessServiceRecommendation(
      id: 'full_groom',
      name: 'Full Groom',
      description: 'A complete grooming appointment for the customer’s dog.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 90,
      suggestedReminderMinutes: <int>[1440, 120],
    ),
    VanBusinessServiceRecommendation(
      id: 'nail_clipping',
      name: 'Nail Clipping',
      description: 'A short appointment for nail trimming.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerVisitsBusiness,
        VanServiceCapabilityIds.fixedPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      suggestedDurationMinutes: 20,
    ),
    VanBusinessServiceRecommendation(
      id: 'bath_brush',
      name: 'Bath and Brush',
      description: 'A bath, dry and brush-out without a full groom.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 60,
    ),
    VanBusinessServiceRecommendation(
      id: 'puppy_package',
      name: 'Puppy Groom',
      description: 'A gentle introductory grooming appointment for puppies.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fixedPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 60,
    ),
    VanBusinessServiceRecommendation(
      id: 'deshedding_treatment',
      name: 'De-shedding Treatment',
      description: 'A focused treatment to remove loose undercoat and hair.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 75,
    ),
    VanBusinessServiceRecommendation(
      id: 'customer_drop_off_collection',
      name: 'Customer Drop-off and Collection',
      description: 'A grooming appointment where the customer handles travel.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 90,
    ),
    VanBusinessServiceRecommendation(
      id: 'collection_return',
      name: 'Collection and Return Service',
      description: 'Collect the dog, complete the groom and return them home.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.businessCollects,
        VanServiceCapabilityIds.businessReturns,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _dogGroomingQuestions,
      extras: <VanServiceTemplateExtra>[
        ..._dogGroomingExtras,
        VanServiceTemplateExtra(
          key: kVanQuoteExtraCollectionDeliveryKey,
          label: 'Pet collection and return',
          defaultPrice: 15,
        ),
      ],
      suggestedDurationMinutes: 120,
    ),
  ],
  capabilities: <VanStarterCapability>[
    VanStarterCapability(
      id: 'customer_drops_pet',
      label: 'Customer drops pet off',
      description: 'The customer brings their pet to you.',
      serviceKey: 'dog_grooming',
      serviceName: 'Dog Grooming',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowCustomerDropOff: true,
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 90,
      suggestedStatusNames: <String, String>{
        'received': 'Grooming requested',
        'accepted': 'Grooming confirmed',
        'ready': 'Ready to collect',
      },
      suggestedReminderMinutes: <int>[1440, 120],
    ),
    VanStarterCapability(
      id: 'business_collects_pet',
      label: 'We collect pets',
      description: 'Your business collects the pet from the customer.',
      serviceKey: 'dog_grooming',
      serviceName: 'Dog Grooming',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowBusinessCollection: true,
      requireAddress: true,
      questions: _dogGroomingQuestions,
      suggestedDurationMinutes: 90,
      extras: <VanServiceTemplateExtra>[
        ..._dogGroomingExtras,
        VanServiceTemplateExtra(
          key: kVanQuoteExtraCollectionDeliveryKey,
          label: 'Pet collection',
          defaultPrice: 10,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'customer_collects_pet',
      label: 'Customer collects pets',
      description: 'The customer collects their pet when ready.',
      serviceKey: 'dog_grooming',
      serviceName: 'Dog Grooming',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowCustomerCollection: true,
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 90,
    ),
    VanStarterCapability(
      id: 'business_returns_pet',
      label: 'We return pets',
      description: 'Your business returns the pet after grooming.',
      serviceKey: 'dog_grooming',
      serviceName: 'Dog Grooming',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowBusinessReturn: true,
      requireAddress: true,
      questions: _dogGroomingQuestions,
      extras: _dogGroomingExtras,
      suggestedDurationMinutes: 90,
    ),
  ],
);

const List<VanServiceTemplateQuestion> _dogGroomingQuestions =
    <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'Pet Name'),
      VanServiceTemplateQuestion(text: 'Breed'),
      VanServiceTemplateQuestion(text: 'Weight'),
      VanServiceTemplateQuestion(
        text: 'Temperament',
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      VanServiceTemplateQuestion(
        text: 'Health conditions or allergies',
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      VanServiceTemplateQuestion(text: 'Preferred date'),
      VanServiceTemplateQuestion(text: 'Preferred time'),
    ];

const List<VanServiceTemplateExtra> _dogGroomingExtras =
    <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: 'custom_extra_nail_trim',
        label: 'Nail trim',
        defaultPrice: 8,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_teeth_clean',
        label: 'Teeth clean',
        defaultPrice: 10,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_flea_treatment',
        label: 'Flea treatment',
        defaultPrice: 12,
      ),
    ];

const _photographyPack = VanStarterCapabilityPack(
  id: 'photography_business',
  name: 'Photography',
  description: 'Studio, mobile, wedding and print services.',
  category: 'Events & other',
  iconKey: 'sparkle',
  colorValue: 0xFF67C6FF,
  featured: true,
  searchKeywords: <String>[
    'photo',
    'photos',
    'photographer',
    'photography',
    'studio',
    'wedding',
    'prints',
    'restoration',
  ],
  searchAliases: <VanBusinessSearchAlias>[
    VanBusinessSearchAlias('Photographer'),
    VanBusinessSearchAlias('Wedding Photographer'),
  ],
  capabilities: <VanStarterCapability>[
    VanStarterCapability(
      id: 'studio',
      label: 'Portrait session',
      description: 'A planned portrait session at your studio.',
      serviceKey: 'portrait_session',
      serviceName: 'Portrait Session',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 60,
      questions: _photographyQuestions,
    ),
    VanStarterCapability(
      id: 'mobile',
      label: 'Family photoshoot',
      description: 'A family shoot at home or at a chosen location.',
      serviceKey: 'family_photoshoot',
      serviceName: 'Family Photoshoot',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.quoteRequest,
      requireAddress: true,
      suggestedDurationMinutes: 90,
      questions: _photographyQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: kVanQuoteExtraMileageKey,
          label: 'Travel mileage',
          defaultPrice: 1,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'events',
      label: 'Event photography',
      description: 'Photography coverage for parties and business events.',
      serviceKey: 'event_photography',
      serviceName: 'Event Photography',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      requireAddress: true,
      suggestedDurationMinutes: 180,
      suggestedNoticeHours: 72,
      questions: _photographyQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_additional_hour',
          label: 'Additional hour',
          defaultPrice: 75,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'products',
      label: 'Product photography',
      description: 'Clean product images for shops, menus and catalogues.',
      serviceKey: 'product_photography',
      serviceName: 'Product Photography',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 120,
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'Number of products'),
        VanServiceTemplateQuestion(text: 'Where will the images be used?'),
        VanServiceTemplateQuestion(text: 'Preferred image style'),
        VanServiceTemplateQuestion(text: 'Required date'),
      ],
    ),
    VanStarterCapability(
      id: 'business_headshots',
      label: 'Business headshots',
      description: 'Professional headshots for individuals or staff teams.',
      serviceKey: 'business_headshots',
      serviceName: 'Business Headshots',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.quoteRequest,
      requireAddress: true,
      suggestedDurationMinutes: 90,
      questions: <VanServiceTemplateQuestion>[
        ..._photographyQuestions,
        VanServiceTemplateQuestion(text: 'Number of people'),
      ],
    ),
    VanStarterCapability(
      id: 'editing',
      label: 'Photo editing',
      description: "Retouch and prepare a customer's existing digital images.",
      serviceKey: 'photo_editing',
      serviceName: 'Photo Editing',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 60,
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(
          text: 'Describe the edits you need',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        VanServiceTemplateQuestion(text: 'Number of images'),
        VanServiceTemplateQuestion(text: 'Required file format'),
      ],
    ),
    VanStarterCapability(
      id: 'weddings',
      label: 'Weddings',
      description: 'Wedding coverage that starts with a quote.',
      serviceKey: 'wedding_photography',
      serviceName: 'Wedding Photography',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      requireAddress: true,
      suggestedDurationMinutes: 480,
      suggestedNoticeHours: 168,
      requestPhotos: true,
      questions: _weddingPhotographyQuestions,
      suggestedStatusNames: <String, String>{
        'received': 'Wedding enquiry received',
        'accepted': 'Wedding booked',
        'ready': 'Gallery ready',
      },
      suggestedReminderMinutes: <int>[10080, 1440],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_engagement_shoot',
          label: 'Engagement shoot',
          defaultPrice: 150,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_second_photographer',
          label: 'Second photographer',
          defaultPrice: 250,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'prints',
      label: 'Prints',
      description: 'Customers order photographic prints.',
      serviceKey: 'photo_prints',
      serviceName: 'Photo Prints',
      journeyType: VanCustomerJourneyType.order,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 15,
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'Print size'),
        VanServiceTemplateQuestion(text: 'Quantity'),
        VanServiceTemplateQuestion(text: 'Finish'),
      ],
    ),
    VanStarterCapability(
      id: 'restoration',
      label: 'Photo restoration',
      description: 'Quote for restoring damaged or old photographs.',
      serviceKey: 'photo_restoration',
      serviceName: 'Photo Restoration',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.quoteRequest,
      requestPhotos: true,
      suggestedDurationMinutes: 60,
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(
          text: 'Describe the restoration you need',
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        VanServiceTemplateQuestion(
          text: 'Photos',
          answerType: VanCustomQuestionAnswerType.photoUploadRequest,
        ),
      ],
    ),
  ],
);

const List<VanServiceTemplateQuestion> _photographyQuestions =
    <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'Preferred date'),
      VanServiceTemplateQuestion(text: 'Preferred time'),
      VanServiceTemplateQuestion(text: 'Location'),
      VanServiceTemplateQuestion(
        text: 'Tell us about the shoot',
        answerType: VanCustomQuestionAnswerType.longText,
      ),
    ];

const List<VanServiceTemplateQuestion> _weddingPhotographyQuestions =
    <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(
        text: 'Wedding date',
        answerType: VanCustomQuestionAnswerType.date,
      ),
      VanServiceTemplateQuestion(text: 'Venue'),
      VanServiceTemplateQuestion(text: 'Number of guests'),
      VanServiceTemplateQuestion(text: 'Photography style'),
      VanServiceTemplateQuestion(
        text: 'Additional requests',
        answerType: VanCustomQuestionAnswerType.longText,
      ),
    ];

const _garagePack = VanStarterCapabilityPack(
  id: 'garage_business',
  name: 'Garage',
  description: 'MOTs, repairs, servicing and vehicle support.',
  category: 'Trades',
  iconKey: 'work',
  colorValue: 0xFF66D6B5,
  featured: true,
  searchKeywords: <String>[
    'garage',
    'mechanic',
    'car',
    'vehicle',
    'mot',
    'repair',
    'servicing',
  ],
  searchAliases: <VanBusinessSearchAlias>[
    VanBusinessSearchAlias('Mechanic'),
    VanBusinessSearchAlias('Car Repair'),
  ],
  services: <VanBusinessServiceRecommendation>[
    VanBusinessServiceRecommendation(
      id: 'mot',
      name: 'MOT',
      description: 'Book an MOT appointment.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fixedPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      suggestedDurationMinutes: 60,
      suggestedReminderMinutes: <int>[1440, 120],
    ),
    VanBusinessServiceRecommendation(
      id: 'interim_service',
      name: 'Interim Service',
      description: 'Routine checks and maintenance between full services.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_oil_upgrade',
          label: 'Oil upgrade',
          defaultPrice: 25,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_courtesy_vehicle',
          label: 'Courtesy car',
          defaultPrice: 25,
        ),
      ],
      suggestedDurationMinutes: 120,
    ),
    VanBusinessServiceRecommendation(
      id: 'full_service',
      name: 'Full Service',
      description: 'A comprehensive vehicle service and maintenance check.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_oil_upgrade',
          label: 'Oil upgrade',
          defaultPrice: 25,
        ),
        VanServiceTemplateExtra(
          key: 'custom_extra_courtesy_vehicle',
          label: 'Courtesy car',
          defaultPrice: 25,
        ),
      ],
      suggestedDurationMinutes: 180,
    ),
    VanBusinessServiceRecommendation(
      id: 'vehicle_repairs',
      name: 'Vehicle Repairs',
      description: 'Diagnose and quote for vehicle repairs.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.requestQuote,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.customQuote,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_courtesy_vehicle',
          label: 'Courtesy car',
          defaultPrice: 25,
        ),
      ],
      suggestedDurationMinutes: 120,
      requestPhotos: true,
    ),
    VanBusinessServiceRecommendation(
      id: 'diagnostics',
      name: 'Diagnostics',
      description: 'Investigate warning lights, faults and running issues.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerVisitsBusiness,
        VanServiceCapabilityIds.fixedPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      suggestedDurationMinutes: 60,
      requestPhotos: true,
    ),
    VanBusinessServiceRecommendation(
      id: 'tyres',
      name: 'Tyres',
      description: 'Tyre fitting, repair and replacement.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerVisitsBusiness,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      suggestedDurationMinutes: 45,
    ),
    VanBusinessServiceRecommendation(
      id: 'brakes',
      name: 'Brakes',
      description: 'Brake inspections, pad replacement and repairs.',
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      suggestedDurationMinutes: 90,
    ),
    VanBusinessServiceRecommendation(
      id: 'vehicle_collection_return',
      name: 'Vehicle Collection and Return',
      description: "Collect the customer's vehicle and return it after work.",
      recommendedCapabilityIds: <String>[
        VanServiceCapabilityIds.booking,
        VanServiceCapabilityIds.appointmentRequired,
        VanServiceCapabilityIds.bookAppointment,
        VanServiceCapabilityIds.businessCollects,
        VanServiceCapabilityIds.businessReturns,
        VanServiceCapabilityIds.fromPrice,
        VanServiceCapabilityIds.oneOff,
        VanServiceCapabilityIds.estimatedDuration,
      ],
      questions: _garageQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: kVanQuoteExtraMileageKey,
          label: 'Collection mileage',
          defaultPrice: 1,
        ),
      ],
      suggestedDurationMinutes: 90,
    ),
  ],
  capabilities: <VanStarterCapability>[
    VanStarterCapability(
      id: 'mot',
      label: 'MOT',
      description: 'Book an MOT appointment.',
      serviceKey: 'mot',
      serviceName: 'MOT',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowCustomerDropOff: true,
      allowCustomerCollection: true,
      suggestedDurationMinutes: 60,
      questions: _garageQuestions,
      suggestedStatusNames: <String, String>{
        'received': 'MOT requested',
        'accepted': 'MOT booked',
        'ready': 'Vehicle ready',
      },
      suggestedReminderMinutes: <int>[1440, 120],
    ),
    VanStarterCapability(
      id: 'repairs',
      label: 'Repairs',
      description: 'Diagnose and quote for vehicle repairs.',
      serviceKey: 'vehicle_repairs',
      serviceName: 'Vehicle Repairs',
      journeyType: VanCustomerJourneyType.quote,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowCustomerDropOff: true,
      allowCustomerCollection: true,
      requestPhotos: true,
      suggestedDurationMinutes: 120,
      questions: _garageQuestions,
    ),
    VanStarterCapability(
      id: 'servicing',
      label: 'Servicing',
      description: 'Book routine vehicle servicing.',
      serviceKey: 'vehicle_servicing',
      serviceName: 'Vehicle Servicing',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.dropOffPickupRequest,
      allowCustomerDropOff: true,
      allowCustomerCollection: true,
      suggestedDurationMinutes: 120,
      questions: _garageQuestions,
    ),
    VanStarterCapability(
      id: 'collection_service',
      label: 'Collection service',
      description: 'Collect and return customer vehicles.',
      serviceKey: 'vehicle_collection',
      serviceName: 'Vehicle Collection Service',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.pickupDeliveryRequest,
      allowBusinessCollection: true,
      allowBusinessReturn: true,
      requireAddress: true,
      suggestedDurationMinutes: 60,
      iconKey: 'van',
      questions: _garageQuestions,
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: kVanQuoteExtraMileageKey,
          label: 'Collection mileage',
          defaultPrice: 1,
        ),
      ],
    ),
    VanStarterCapability(
      id: 'courtesy_vehicle',
      label: 'Courtesy vehicle',
      description: 'Customers can request a courtesy vehicle.',
      serviceKey: 'courtesy_vehicle',
      serviceName: 'Courtesy Vehicle',
      journeyType: VanCustomerJourneyType.booking,
      requestType: VanCustomerRequestType.quoteRequest,
      suggestedDurationMinutes: 30,
      questions: <VanServiceTemplateQuestion>[
        VanServiceTemplateQuestion(text: 'Vehicle Details'),
        VanServiceTemplateQuestion(text: 'Driving licence number'),
        VanServiceTemplateQuestion(text: 'Required date'),
      ],
      extras: <VanServiceTemplateExtra>[
        VanServiceTemplateExtra(
          key: 'custom_extra_courtesy_vehicle',
          label: 'Courtesy vehicle hire',
          defaultPrice: 25,
        ),
      ],
    ),
  ],
);

const List<VanServiceTemplateQuestion> _garageQuestions =
    <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'Vehicle Details'),
      VanServiceTemplateQuestion(text: 'Registration number'),
      VanServiceTemplateQuestion(text: 'Current mileage'),
      VanServiceTemplateQuestion(
        text: 'Describe the issue',
        answerType: VanCustomQuestionAnswerType.longText,
      ),
      VanServiceTemplateQuestion(text: 'Preferred date'),
    ];

enum _StarterServiceKind {
  appointment,
  mobileAppointment,
  quote,
  recurring,
  order,
  delivery,
  collectionDelivery,
  digital,
  walkIn,
  hire,
}

class _StarterServiceSeed {
  const _StarterServiceSeed(
    this.name,
    this.kind, {
    this.description,
    this.durationMinutes,
    this.noticeHours,
    this.extraCapabilityIds = const <String>[],
  });

  final String name;
  final _StarterServiceKind kind;
  final String? description;
  final int? durationMinutes;
  final int? noticeHours;
  final List<String> extraCapabilityIds;
}

const Map<String, List<_StarterServiceSeed>>
_expandedServiceSeeds = <String, List<_StarterServiceSeed>>{
  'man_van': <_StarterServiceSeed>[
    _StarterServiceSeed('Small Home Move', _StarterServiceKind.quote),
    _StarterServiceSeed('Single-item Move', _StarterServiceKind.quote),
    _StarterServiceSeed('Student Move', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Store Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Furniture Transport',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed('Office Move', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Loading and Unloading Help',
      _StarterServiceKind.mobileAppointment,
    ),
  ],
  'removals': <_StarterServiceSeed>[
    _StarterServiceSeed('House Removal', _StarterServiceKind.quote),
    _StarterServiceSeed('Flat Removal', _StarterServiceKind.quote),
    _StarterServiceSeed('Office Removal', _StarterServiceKind.quote),
    _StarterServiceSeed('Packing Service', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Furniture Dismantling and Assembly',
      _StarterServiceKind.quote,
    ),
    _StarterServiceSeed('Storage Move', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Long-distance Removal',
      _StarterServiceKind.collectionDelivery,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.nationwideDelivery],
    ),
  ],
  'courier': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Same-day Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Collect and deliver an item within the same day.',
      durationMinutes: 90,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.sameDay],
    ),
    _StarterServiceSeed(
      'Scheduled Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Arrange a collection and delivery for a future date.',
      noticeHours: 48,
    ),
    _StarterServiceSeed(
      'Collection and Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Collect an item and take it to its destination.',
    ),
    _StarterServiceSeed(
      'Collection Only',
      _StarterServiceKind.mobileAppointment,
      description: 'Collect an item from the customer or supplier.',
    ),
    _StarterServiceSeed(
      'Delivery Only',
      _StarterServiceKind.delivery,
      description: 'Deliver an item that is already ready to dispatch.',
    ),
    _StarterServiceSeed(
      'Multi-drop Route',
      _StarterServiceKind.collectionDelivery,
      description: 'Complete a route containing several delivery stops.',
    ),
    _StarterServiceSeed(
      'Urgent Express Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Prioritise a time-critical collection and delivery.',
      extraCapabilityIds: <String>[VanServiceCapabilityIds.sameDay],
    ),
    _StarterServiceSeed(
      'Local Delivery',
      _StarterServiceKind.delivery,
      description: 'Deliver an order within the local area.',
    ),
    _StarterServiceSeed(
      'Long-distance Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Transport an item beyond the normal local area.',
      extraCapabilityIds: <String>[VanServiceCapabilityIds.nationwideDelivery],
    ),
    _StarterServiceSeed(
      'Business-to-business Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Move documents or goods between business locations.',
    ),
    _StarterServiceSeed(
      'Regular Contract Runs',
      _StarterServiceKind.recurring,
      description: 'Provide a repeating collection and delivery route.',
    ),
    _StarterServiceSeed(
      'Large-item Delivery',
      _StarterServiceKind.collectionDelivery,
      description: 'Collect and deliver bulky or oversized items.',
      durationMinutes: 120,
    ),
  ],
  'multi_drop_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Multi-drop Route', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Scheduled Delivery Round',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed('Retail Delivery Round', _StarterServiceKind.recurring),
    _StarterServiceSeed('Business Contract Run', _StarterServiceKind.recurring),
    _StarterServiceSeed(
      'Ad-hoc Multi-drop Delivery',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Same-day Multi-drop Route',
      _StarterServiceKind.collectionDelivery,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.sameDay],
    ),
  ],
  'furniture_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Store-to-home Delivery',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Marketplace Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Single-item Delivery',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Multiple-item Delivery',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Room-of-choice Delivery',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed('Delivery and Assembly', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Long-distance Furniture Delivery',
      _StarterServiceKind.collectionDelivery,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.nationwideDelivery],
    ),
  ],
  'store_collections': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Retail Store Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Marketplace Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Click-and-collect Pickup',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Bulky-item Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed(
      'Same-day Store Collection',
      _StarterServiceKind.collectionDelivery,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.sameDay],
    ),
    _StarterServiceSeed(
      'Scheduled Store Collection',
      _StarterServiceKind.collectionDelivery,
    ),
    _StarterServiceSeed('Multi-store Collection', _StarterServiceKind.quote),
  ],
  'same_day_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Urgent Parcel', _StarterServiceKind.delivery),
    _StarterServiceSeed('Same-day Documents', _StarterServiceKind.delivery),
    _StarterServiceSeed('Forgotten Item', _StarterServiceKind.delivery),
    _StarterServiceSeed('Retail Order', _StarterServiceKind.delivery),
    _StarterServiceSeed('Medical Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Business Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Evening Delivery', _StarterServiceKind.delivery),
  ],
  'pet_transport': <_StarterServiceSeed>[
    _StarterServiceSeed('Vet Appointment Trip', _StarterServiceKind.quote),
    _StarterServiceSeed('Groomer Trip', _StarterServiceKind.quote),
    _StarterServiceSeed('Pet Relocation', _StarterServiceKind.quote),
    _StarterServiceSeed('Airport Pet Transfer', _StarterServiceKind.quote),
    _StarterServiceSeed('Rescue Transport', _StarterServiceKind.quote),
    _StarterServiceSeed('Regular Day-care Run', _StarterServiceKind.recurring),
    _StarterServiceSeed(
      'Emergency Pet Transport',
      _StarterServiceKind.quote,
      extraCapabilityIds: <String>[VanServiceCapabilityIds.sameDay],
    ),
  ],
  'bakery_cupcake_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Cake Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Cupcake Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Wedding Cake Delivery', _StarterServiceKind.quote),
    _StarterServiceSeed('Wholesale Bakery Run', _StarterServiceKind.recurring),
    _StarterServiceSeed(
      'Same-day Bakery Delivery',
      _StarterServiceKind.delivery,
    ),
    _StarterServiceSeed('Event Order Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Regular Shop Delivery', _StarterServiceKind.recurring),
  ],
  'florist_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Bouquet Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed(
      'Same-day Flower Delivery',
      _StarterServiceKind.delivery,
    ),
    _StarterServiceSeed('Wedding Flower Delivery', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Funeral Flower Delivery',
      _StarterServiceKind.delivery,
    ),
    _StarterServiceSeed(
      'Corporate Flower Delivery',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed('Flower Subscription', _StarterServiceKind.recurring),
    _StarterServiceSeed('Event Flower Delivery', _StarterServiceKind.delivery),
  ],
  'gardening': <_StarterServiceSeed>[
    _StarterServiceSeed('Lawn Mowing', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Hedge Trimming', _StarterServiceKind.quote),
    _StarterServiceSeed('Garden Tidy-up', _StarterServiceKind.quote),
    _StarterServiceSeed('Planting and Borders', _StarterServiceKind.quote),
    _StarterServiceSeed('Weeding', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Green Waste Removal', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Regular Garden Maintenance',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed('Seasonal Garden Clearance', _StarterServiceKind.quote),
  ],
  'cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed('Regular Home Cleaning', _StarterServiceKind.recurring),
    _StarterServiceSeed('Deep Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'One-off Home Cleaning',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Office Cleaning', _StarterServiceKind.recurring),
    _StarterServiceSeed('End of Tenancy Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Move-in Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('After-builders Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Holiday Let Changeover',
      _StarterServiceKind.recurring,
    ),
  ],
  'window_cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Exterior Window Cleaning',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Interior Window Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Full Window Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('Conservatory Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Commercial Window Cleaning',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'Regular Window Cleaning',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'One-off Window Cleaning',
      _StarterServiceKind.mobileAppointment,
    ),
  ],
  'pressure_washing': <_StarterServiceSeed>[
    _StarterServiceSeed('Driveway Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Patio Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Decking Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Wall and Render Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Soft Washing', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Commercial Pressure Washing',
      _StarterServiceKind.quote,
    ),
    _StarterServiceSeed('Graffiti Removal', _StarterServiceKind.quote),
  ],
  'house_clearance': <_StarterServiceSeed>[
    _StarterServiceSeed('Full House Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Partial House Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Garage Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Loft Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Garden Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Probate Clearance', _StarterServiceKind.quote),
    _StarterServiceSeed('Office Clearance', _StarterServiceKind.quote),
  ],
  'carpet_cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Single-room Carpet Clean',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Whole-home Carpet Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('Stairs and Landing Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('Upholstery Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Commercial Carpet Cleaning',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'Stain Treatment',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed(
      'End of Tenancy Carpet Clean',
      _StarterServiceKind.quote,
    ),
  ],
  'oven_cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Single Oven Clean',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed(
      'Double Oven Clean',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Range Cooker Clean', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Hob and Extractor Clean',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('AGA Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed('Commercial Kitchen Clean', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'End of Tenancy Oven Clean',
      _StarterServiceKind.mobileAppointment,
    ),
  ],
  'end_of_tenancy_cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed('Studio Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('Flat Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('House Clean', _StarterServiceKind.quote),
    _StarterServiceSeed('Furnished Property Clean', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Unfurnished Property Clean',
      _StarterServiceKind.quote,
    ),
    _StarterServiceSeed('Landlord Refresh Clean', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Clean with Carpet Treatment',
      _StarterServiceKind.quote,
    ),
  ],
  'gutter_cleaning': <_StarterServiceSeed>[
    _StarterServiceSeed('Gutter Cleaning', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Gutter Inspection',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Minor Gutter Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Downpipe Clearing', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Commercial Gutter Cleaning',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'Regular Gutter Maintenance',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'Emergency Gutter Clearance',
      _StarterServiceKind.quote,
    ),
  ],
  'handyman': <_StarterServiceSeed>[
    _StarterServiceSeed('Furniture Assembly', _StarterServiceKind.quote),
    _StarterServiceSeed('TV and Shelf Mounting', _StarterServiceKind.quote),
    _StarterServiceSeed('Minor Home Repairs', _StarterServiceKind.quote),
    _StarterServiceSeed('Door and Lock Repairs', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Sealant Replacement',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Flat-pack Assembly', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Property Maintenance Visit',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed('Moving-in Job List', _StarterServiceKind.quote),
  ],
  'electrician': <_StarterServiceSeed>[
    _StarterServiceSeed('Electrical Fault Finding', _StarterServiceKind.quote),
    _StarterServiceSeed('Sockets and Switches', _StarterServiceKind.quote),
    _StarterServiceSeed('Lighting Installation', _StarterServiceKind.quote),
    _StarterServiceSeed('Consumer Unit Work', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Electrical Safety Certificate',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Emergency Electrician', _StarterServiceKind.quote),
    _StarterServiceSeed('EV Charger Installation', _StarterServiceKind.quote),
  ],
  'plumber': <_StarterServiceSeed>[
    _StarterServiceSeed('Leak Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Blocked Drain', _StarterServiceKind.quote),
    _StarterServiceSeed('Tap and Toilet Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Radiator Work', _StarterServiceKind.quote),
    _StarterServiceSeed('Heating Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Bathroom Installation', _StarterServiceKind.quote),
    _StarterServiceSeed('Emergency Plumber', _StarterServiceKind.quote),
  ],
  'painter_decorator': <_StarterServiceSeed>[
    _StarterServiceSeed('Single-room Painting', _StarterServiceKind.quote),
    _StarterServiceSeed('Full Interior Painting', _StarterServiceKind.quote),
    _StarterServiceSeed('Exterior Painting', _StarterServiceKind.quote),
    _StarterServiceSeed('Wallpaper Hanging', _StarterServiceKind.quote),
    _StarterServiceSeed('Commercial Decorating', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Paint Touch-ups',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Woodwork Painting', _StarterServiceKind.quote),
  ],
  'carpenter': <_StarterServiceSeed>[
    _StarterServiceSeed('Fitted Storage', _StarterServiceKind.quote),
    _StarterServiceSeed('Door Fitting', _StarterServiceKind.quote),
    _StarterServiceSeed('Skirting and Architraves', _StarterServiceKind.quote),
    _StarterServiceSeed('Furniture Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Decking', _StarterServiceKind.quote),
    _StarterServiceSeed('Bespoke Carpentry', _StarterServiceKind.quote),
    _StarterServiceSeed('Kitchen Fitting', _StarterServiceKind.quote),
  ],
  'tiler': <_StarterServiceSeed>[
    _StarterServiceSeed('Bathroom Tiling', _StarterServiceKind.quote),
    _StarterServiceSeed('Kitchen Splashback', _StarterServiceKind.quote),
    _StarterServiceSeed('Floor Tiling', _StarterServiceKind.quote),
    _StarterServiceSeed('Wall Tiling', _StarterServiceKind.quote),
    _StarterServiceSeed('Regrouting', _StarterServiceKind.quote),
    _StarterServiceSeed('Tile Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Outdoor Tiling', _StarterServiceKind.quote),
  ],
  'plasterer': <_StarterServiceSeed>[
    _StarterServiceSeed('Room Skimming', _StarterServiceKind.quote),
    _StarterServiceSeed('Patch Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Ceiling Plastering', _StarterServiceKind.quote),
    _StarterServiceSeed('Full-room Plastering', _StarterServiceKind.quote),
    _StarterServiceSeed('External Rendering', _StarterServiceKind.quote),
    _StarterServiceSeed('Dry Lining', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Plaster Inspection',
      _StarterServiceKind.mobileAppointment,
    ),
  ],
  'roofer': <_StarterServiceSeed>[
    _StarterServiceSeed('Roof Repair', _StarterServiceKind.quote),
    _StarterServiceSeed('Roof Leak Repair', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Roof Inspection',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Flat Roof Work', _StarterServiceKind.quote),
    _StarterServiceSeed('Tile Replacement', _StarterServiceKind.quote),
    _StarterServiceSeed('Fascia and Soffit Work', _StarterServiceKind.quote),
    _StarterServiceSeed('Emergency Roof Repair', _StarterServiceKind.quote),
  ],
  'meal_prep': <_StarterServiceSeed>[
    _StarterServiceSeed('Weekly Meal Prep', _StarterServiceKind.recurring),
    _StarterServiceSeed('Family Meal Prep', _StarterServiceKind.order),
    _StarterServiceSeed('Fitness Meal Plan', _StarterServiceKind.recurring),
    _StarterServiceSeed('Dietary Meal Plan', _StarterServiceKind.recurring),
    _StarterServiceSeed('Corporate Lunches', _StarterServiceKind.order),
    _StarterServiceSeed('One-off Batch Cooking', _StarterServiceKind.order),
    _StarterServiceSeed('Meal Subscription', _StarterServiceKind.recurring),
  ],
  'cake_orders': <_StarterServiceSeed>[
    _StarterServiceSeed('Birthday Cake', _StarterServiceKind.order),
    _StarterServiceSeed('Wedding Cake', _StarterServiceKind.quote),
    _StarterServiceSeed('Cupcake Order', _StarterServiceKind.order),
    _StarterServiceSeed('Corporate Cake Order', _StarterServiceKind.quote),
    _StarterServiceSeed('Celebration Cake', _StarterServiceKind.quote),
    _StarterServiceSeed('Traybake Order', _StarterServiceKind.order),
    _StarterServiceSeed('Custom Cake Design', _StarterServiceKind.quote),
  ],
  'farm_shop_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Produce Box', _StarterServiceKind.delivery),
    _StarterServiceSeed('Fruit and Veg Box', _StarterServiceKind.delivery),
    _StarterServiceSeed('Meat Box', _StarterServiceKind.delivery),
    _StarterServiceSeed('Dairy Delivery', _StarterServiceKind.delivery),
    _StarterServiceSeed('Farm Shop Hamper', _StarterServiceKind.delivery),
    _StarterServiceSeed(
      'Weekly Box Subscription',
      _StarterServiceKind.recurring,
    ),
    _StarterServiceSeed(
      'Local Farm Shop Delivery',
      _StarterServiceKind.delivery,
    ),
  ],
  'catering': <_StarterServiceSeed>[
    _StarterServiceSeed('Private Party Catering', _StarterServiceKind.quote),
    _StarterServiceSeed('Wedding Catering', _StarterServiceKind.quote),
    _StarterServiceSeed('Corporate Catering', _StarterServiceKind.quote),
    _StarterServiceSeed('Buffet Catering', _StarterServiceKind.quote),
    _StarterServiceSeed('Canape Service', _StarterServiceKind.quote),
    _StarterServiceSeed('Funeral Catering', _StarterServiceKind.quote),
    _StarterServiceSeed('Event Catering with Staff', _StarterServiceKind.quote),
  ],
  'event_setup': <_StarterServiceSeed>[
    _StarterServiceSeed('Venue Setup', _StarterServiceKind.quote),
    _StarterServiceSeed('Event Breakdown', _StarterServiceKind.quote),
    _StarterServiceSeed('Wedding Setup', _StarterServiceKind.quote),
    _StarterServiceSeed('Corporate Event Setup', _StarterServiceKind.quote),
    _StarterServiceSeed('Stage and Seating Setup', _StarterServiceKind.quote),
    _StarterServiceSeed('Decor Setup', _StarterServiceKind.quote),
    _StarterServiceSeed('Full Setup and Pack-down', _StarterServiceKind.quote),
  ],
  'balloon_delivery': <_StarterServiceSeed>[
    _StarterServiceSeed('Balloon Bouquet', _StarterServiceKind.delivery),
    _StarterServiceSeed('Balloon Arch', _StarterServiceKind.hire),
    _StarterServiceSeed('Balloon Garland', _StarterServiceKind.hire),
    _StarterServiceSeed('Number Balloons', _StarterServiceKind.delivery),
    _StarterServiceSeed('Wedding Balloons', _StarterServiceKind.hire),
    _StarterServiceSeed('Corporate Balloon Display', _StarterServiceKind.hire),
    _StarterServiceSeed(
      'Same-day Balloon Delivery',
      _StarterServiceKind.delivery,
    ),
  ],
  'party_hire': <_StarterServiceSeed>[
    _StarterServiceSeed('Table and Chair Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('Inflatable Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('Marquee Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('Party Decor Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('PA System Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('Event Lighting Hire', _StarterServiceKind.hire),
    _StarterServiceSeed('Complete Party Package', _StarterServiceKind.hire),
  ],
  'dj': <_StarterServiceSeed>[
    _StarterServiceSeed('Wedding DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('Birthday Party DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('Corporate Event DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('School Event DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('Club Night DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('Karaoke DJ', _StarterServiceKind.quote),
    _StarterServiceSeed('DJ Equipment Hire', _StarterServiceKind.hire),
  ],
  'dog_walking': <_StarterServiceSeed>[
    _StarterServiceSeed('Solo Dog Walk', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed(
      'Group Dog Walk',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Puppy Walk', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed(
      'Senior Dog Walk',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Adventure Walk', _StarterServiceKind.quote),
    _StarterServiceSeed('Regular Weekly Walks', _StarterServiceKind.recurring),
    _StarterServiceSeed(
      'Same-day Dog Walk',
      _StarterServiceKind.mobileAppointment,
    ),
  ],
  'pet_sitting': <_StarterServiceSeed>[
    _StarterServiceSeed('Home Visit', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Overnight Pet Sitting', _StarterServiceKind.quote),
    _StarterServiceSeed(
      'Day Pet Sitting',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Cat Sitting', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Puppy Sitting', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed(
      'Medication Visit',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Holiday Pet Care', _StarterServiceKind.recurring),
  ],
  'mobile_hairdresser': <_StarterServiceSeed>[
    _StarterServiceSeed(
      'Cut and Blow-dry',
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed('Hair Colour', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Hair Styling', _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Bridal Hair', _StarterServiceKind.quote),
    _StarterServiceSeed(
      "Children's Haircut",
      _StarterServiceKind.mobileAppointment,
    ),
    _StarterServiceSeed("Men's Haircut", _StarterServiceKind.mobileAppointment),
    _StarterServiceSeed('Group Booking', _StarterServiceKind.quote),
  ],
  'beautician': <_StarterServiceSeed>[
    _StarterServiceSeed('Nail Treatment', _StarterServiceKind.appointment),
    _StarterServiceSeed('Makeup Appointment', _StarterServiceKind.appointment),
    _StarterServiceSeed('Facial', _StarterServiceKind.appointment),
    _StarterServiceSeed('Brows and Lashes', _StarterServiceKind.appointment),
    _StarterServiceSeed('Waxing', _StarterServiceKind.appointment),
    _StarterServiceSeed('Massage', _StarterServiceKind.appointment),
    _StarterServiceSeed('Bridal Beauty', _StarterServiceKind.quote),
  ],
};

List<VanBusinessServiceRecommendation> _expandedRecommendationsForTemplate(
  VanServiceTemplate template,
) {
  final seeds =
      _expandedServiceSeeds[template.id] ??
      <_StarterServiceSeed>[
        _StarterServiceSeed(
          'Standard ${template.name}',
          _StarterServiceKind.mobileAppointment,
        ),
        _StarterServiceSeed(
          'One-off ${template.name}',
          _StarterServiceKind.quote,
        ),
        _StarterServiceSeed(
          'Scheduled ${template.name}',
          _StarterServiceKind.appointment,
        ),
        _StarterServiceSeed(
          'Regular ${template.name}',
          _StarterServiceKind.recurring,
        ),
        _StarterServiceSeed(
          'Business ${template.name}',
          _StarterServiceKind.quote,
        ),
      ];
  final templateRequestsPhotos = template.questions.any(
    (question) =>
        question.answerType == VanCustomQuestionAnswerType.photoUploadRequest,
  );
  return <VanBusinessServiceRecommendation>[
    for (final seed in seeds)
      VanBusinessServiceRecommendation(
        id: _serviceSeedId(seed.name),
        name: seed.name,
        description: seed.description ?? _serviceSeedDescription(seed),
        recommendedCapabilityIds: _serviceSeedCapabilities(seed),
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            text: 'Tell us what you need for ${seed.name.toLowerCase()}',
            answerType: VanCustomQuestionAnswerType.longText,
          ),
          ...template.questions,
        ],
        extras: template.extras,
        suggestedDurationMinutes:
            seed.durationMinutes ?? template.suggestedDurationMinutes,
        suggestedNoticeHours:
            seed.noticeHours ?? _serviceSeedNoticeHours(seed.kind),
        suggestedCustomerMessage:
            "We'll review your ${seed.name.toLowerCase()} request and confirm the details.",
        suggestedStatusNames: <String, String>{
          'received': '${seed.name} request received',
          'accepted': '${seed.name} confirmed',
          'ready': _serviceSeedReadyStatus(seed.kind),
        },
        suggestedReminderMinutes: _serviceSeedReminderMinutes(seed.kind),
        requestPhotos: templateRequestsPhotos,
      ),
  ];
}

String _serviceSeedId(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _serviceSeedDescription(_StarterServiceSeed seed) => switch (seed.kind) {
  _StarterServiceKind.appointment =>
    'Book a ${seed.name.toLowerCase()} appointment at your premises.',
  _StarterServiceKind.mobileAppointment =>
    "Book ${seed.name.toLowerCase()} at the customer's location.",
  _StarterServiceKind.quote =>
    'Request a tailored quote for ${seed.name.toLowerCase()}.',
  _StarterServiceKind.recurring =>
    'Arrange ${seed.name.toLowerCase()} as a regular repeating service.',
  _StarterServiceKind.order =>
    'Order ${seed.name.toLowerCase()} ahead for a chosen date.',
  _StarterServiceKind.delivery =>
    'Arrange ${seed.name.toLowerCase()} with delivery details and timing.',
  _StarterServiceKind.collectionDelivery =>
    'Arrange collection and delivery for ${seed.name.toLowerCase()}.',
  _StarterServiceKind.digital =>
    'Request ${seed.name.toLowerCase()} with digital delivery.',
  _StarterServiceKind.walkIn =>
    'Offer ${seed.name.toLowerCase()} to customers visiting your premises.',
  _StarterServiceKind.hire =>
    'Request a quote and date for ${seed.name.toLowerCase()}.',
};

List<String> _serviceSeedCapabilities(_StarterServiceSeed seed) {
  final base = switch (seed.kind) {
    _StarterServiceKind.appointment => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.appointmentRequired,
      VanServiceCapabilityIds.bookAppointment,
      VanServiceCapabilityIds.customerVisitsBusiness,
      VanServiceCapabilityIds.fromPrice,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.estimatedDuration,
    },
    _StarterServiceKind.mobileAppointment => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.appointmentRequired,
      VanServiceCapabilityIds.bookAppointment,
      VanServiceCapabilityIds.businessVisitsCustomer,
      VanServiceCapabilityIds.fromPrice,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.estimatedDuration,
    },
    _StarterServiceKind.quote => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.businessVisitsCustomer,
      VanServiceCapabilityIds.customQuote,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.estimatedDuration,
    },
    _StarterServiceKind.recurring => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.appointmentRequired,
      VanServiceCapabilityIds.bookAppointment,
      VanServiceCapabilityIds.businessVisitsCustomer,
      VanServiceCapabilityIds.fromPrice,
      VanServiceCapabilityIds.recurring,
      VanServiceCapabilityIds.estimatedDuration,
    },
    _StarterServiceKind.order => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.preOrder,
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.fixedPrice,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.preparationTime,
    },
    _StarterServiceKind.delivery => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.preOrder,
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.localDelivery,
      VanServiceCapabilityIds.fixedPrice,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.preparationTime,
    },
    _StarterServiceKind.collectionDelivery => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.businessCollects,
      VanServiceCapabilityIds.businessReturns,
      VanServiceCapabilityIds.customQuote,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.estimatedDuration,
    },
    _StarterServiceKind.digital => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.digitalDelivery,
      VanServiceCapabilityIds.customQuote,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.leadTime,
    },
    _StarterServiceKind.walkIn => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.walkIn,
      VanServiceCapabilityIds.placeOrder,
      VanServiceCapabilityIds.customerVisitsBusiness,
      VanServiceCapabilityIds.fixedPrice,
      VanServiceCapabilityIds.oneOff,
    },
    _StarterServiceKind.hire => <String>{
      VanServiceCapabilityIds.booking,
      VanServiceCapabilityIds.preOrder,
      VanServiceCapabilityIds.requestQuote,
      VanServiceCapabilityIds.localDelivery,
      VanServiceCapabilityIds.customQuote,
      VanServiceCapabilityIds.depositRequired,
      VanServiceCapabilityIds.oneOff,
      VanServiceCapabilityIds.leadTime,
    },
  };
  base.addAll(seed.extraCapabilityIds);
  final ordered = base.toList(growable: false)..sort();
  return ordered;
}

int _serviceSeedNoticeHours(_StarterServiceKind kind) => switch (kind) {
  _StarterServiceKind.hire => 72,
  _StarterServiceKind.recurring => 48,
  _StarterServiceKind.order || _StarterServiceKind.delivery => 24,
  _ => 24,
};

List<int> _serviceSeedReminderMinutes(_StarterServiceKind kind) =>
    switch (kind) {
      _StarterServiceKind.hire => <int>[10080, 1440],
      _StarterServiceKind.appointment ||
      _StarterServiceKind.mobileAppointment ||
      _StarterServiceKind.recurring => <int>[1440, 120],
      _StarterServiceKind.delivery ||
      _StarterServiceKind.collectionDelivery ||
      _StarterServiceKind.order => <int>[1440],
      _ => const <int>[],
    };

String _serviceSeedReadyStatus(_StarterServiceKind kind) => switch (kind) {
  _StarterServiceKind.delivery ||
  _StarterServiceKind.collectionDelivery => 'Delivery complete',
  _StarterServiceKind.order ||
  _StarterServiceKind.hire => 'Ready for fulfilment',
  _StarterServiceKind.digital => 'Files ready',
  _ => 'Service complete',
};

final List<VanStarterCapabilityPack> kVanStarterCapabilityPacks =
    <VanStarterCapabilityPack>[
      _bakeryPack,
      _dogGroomerPack,
      _photographyPack,
      _garagePack,
      _courierTransportPack,
      _manVanTransportPack,
      _removalsTransportPack,
      for (final category in kVanServiceTemplateCategories)
        for (final template in category.services)
          if (!const <String>{
            'bakery',
            'photographer',
            'mobile_mechanic',
            'courier',
            'man_van',
            'removals',
            'same_day_delivery',
            'multi_drop_delivery',
            'store_collections',
            'furniture_delivery',
          }.contains(template.id))
            _legacyTemplateCapabilityPack(category, template),
    ];

VanStarterCapabilityPack? findVanStarterCapabilityPackById(String id) {
  final normalized = id.trim();
  for (final pack in kVanStarterCapabilityPacks) {
    if (pack.id == normalized) return pack;
  }
  return null;
}

List<VanBusinessSearchResult> searchVanStarterCapabilityPacks(
  String query, {
  int limit = 12,
}) {
  final normalizedQuery = _normalized(query);
  if (normalizedQuery.isEmpty || limit <= 0) {
    return const <VanBusinessSearchResult>[];
  }
  final queryTerms = _searchTerms(normalizedQuery);
  final matches = <_ScoredBusinessSearchResult>[];
  var sequence = 0;

  for (final pack in kVanStarterCapabilityPacks) {
    final sharedSearchText = <String>[
      pack.name,
      pack.category,
      ...pack.searchKeywords,
      ...pack.serviceRecommendations.map((item) => item.name),
    ].join(' ');
    final candidates = <VanBusinessSearchAlias>[
      VanBusinessSearchAlias(pack.name),
      ...pack.searchAliases,
    ];
    for (final candidate in candidates) {
      final score = _businessSearchScore(
        query: normalizedQuery,
        queryTerms: queryTerms,
        label: candidate.label,
        searchableText: '$sharedSearchText ${candidate.keywords.join(' ')}',
      );
      if (score == null) continue;
      matches.add(
        _ScoredBusinessSearchResult(
          result: VanBusinessSearchResult(pack: pack, label: candidate.label),
          score: score,
          sequence: sequence++,
        ),
      );
    }
  }

  matches.sort((left, right) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) return byScore;
    final byLabel = left.result.label.compareTo(right.result.label);
    if (byLabel != 0) return byLabel;
    return left.sequence.compareTo(right.sequence);
  });
  final seen = <String>{};
  return <VanBusinessSearchResult>[
    for (final match in matches)
      if (seen.add(_normalized(match.result.label))) match.result,
  ].take(limit).toList(growable: false);
}

VanStarterCapabilityPack? findBestVanStarterCapabilityPack(String value) {
  final match = searchVanStarterCapabilityPacks(value, limit: 1);
  return match.isEmpty ? null : match.first.pack;
}

class _ScoredBusinessSearchResult {
  const _ScoredBusinessSearchResult({
    required this.result,
    required this.score,
    required this.sequence,
  });

  final VanBusinessSearchResult result;
  final int score;
  final int sequence;
}

int? _businessSearchScore({
  required String query,
  required Set<String> queryTerms,
  required String label,
  required String searchableText,
}) {
  final normalizedLabel = _normalized(label);
  final labelTerms = _searchTerms(normalizedLabel);
  final allTerms = _searchTerms(_normalized(searchableText));
  if (normalizedLabel == query) return 1000;
  if (normalizedLabel.startsWith(query)) return 900;
  if (queryTerms.every(labelTerms.contains)) return 850;
  if (normalizedLabel.contains(query)) return 800;
  if (queryTerms.every(allTerms.contains)) return 700;
  if (queryTerms.every(
    (queryTerm) => allTerms.any((term) => term.startsWith(queryTerm)),
  )) {
    return 620;
  }
  if (_normalized(searchableText).contains(query)) return 600;
  return null;
}

Set<String> _searchTerms(String value) => _normalized(
  value,
).split(' ').where((item) => item.isNotEmpty).map(_singularSearchTerm).toSet();

String _singularSearchTerm(String value) {
  if (value.length > 4 && value.endsWith('ies')) {
    return '${value.substring(0, value.length - 3)}y';
  }
  if (value.length > 4 &&
      (value.endsWith('ches') ||
          value.endsWith('shes') ||
          value.endsWith('xes') ||
          value.endsWith('zes'))) {
    return value.substring(0, value.length - 2);
  }
  if (value.length > 3 && value.endsWith('s')) {
    return value.substring(0, value.length - 1);
  }
  return value;
}

VanStarterCapabilityPack _legacyTemplateCapabilityPack(
  VanServiceTemplateCategory category,
  VanServiceTemplate template,
) {
  final categoryName = switch (category.id) {
    'transport_delivery' => 'Transport & delivery',
    'property_services' => 'Home & property',
    'trades' => 'Trades',
    'food_local' => 'Food & local business',
    _ => 'Events & other',
  };
  final iconKey = switch (category.id) {
    'transport_delivery' => 'van',
    'property_services' => 'home',
    'events_other' when template.id.contains('dog') => 'pet',
    _ => 'work',
  };
  final metadata = _legacySearchMetadata(template.id);
  return VanStarterCapabilityPack(
    id: '${template.id}_business',
    name: template.name,
    description: template.description,
    category: categoryName,
    iconKey: iconKey,
    colorValue: 0xFF4F8CFF,
    searchKeywords: <String>[
      template.id.replaceAll('_', ' '),
      ...metadata.keywords,
    ],
    searchAliases: metadata.aliases,
    services: _expandedRecommendationsForTemplate(template),
  );
}

({List<String> keywords, List<VanBusinessSearchAlias> aliases})
_legacySearchMetadata(String templateId) => switch (templateId) {
  'plumber' => (
    keywords: <String>[
      'plumbing',
      'pipes',
      'leak',
      'boiler',
      'heating',
      'bathroom',
      'emergency',
    ],
    aliases: const <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Emergency Plumber'),
      VanBusinessSearchAlias('Heating Engineer', keywords: <String>['plumber']),
      VanBusinessSearchAlias(
        'Bathroom Installer',
        keywords: <String>['plumber'],
      ),
    ],
  ),
  'gardening' => (
    keywords: <String>['gardener', 'garden', 'lawn', 'grass', 'hedge'],
    aliases: const <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Gardener'),
      VanBusinessSearchAlias('Lawn Care'),
    ],
  ),
  'window_cleaning' => (
    keywords: <String>['window', 'windows', 'cleaner', 'cleaning', 'glass'],
    aliases: const <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Window Cleaner'),
    ],
  ),
  'cleaning' => (
    keywords: <String>['cleaner', 'cleaning', 'housekeeping', 'domestic'],
    aliases: const <VanBusinessSearchAlias>[VanBusinessSearchAlias('Cleaner')],
  ),
  'man_van' => (
    keywords: <String>['removals', 'moving', 'transport', 'courier', 'van'],
    aliases: const <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Moving Service'),
    ],
  ),
  'cake_orders' => (
    keywords: <String>['cake', 'cakes', 'bakery', 'wedding', 'cupcake'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  'catering' => (
    keywords: <String>['cake', 'food', 'party', 'event', 'buffet'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  'mobile_hairdresser' => (
    keywords: <String>['hair', 'hairdresser', 'barber', 'salon', 'stylist'],
    aliases: const <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Hairdresser'),
    ],
  ),
  'electrician' => (
    keywords: <String>['electrical', 'electric', 'wiring', 'lights'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  'courier' => (
    keywords: <String>['delivery', 'parcel', 'transport', 'driver', 'van'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  'dog_walking' || 'pet_sitting' || 'pet_transport' => (
    keywords: <String>['dog', 'dogs', 'pet', 'pets', 'animal'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  'beautician' => (
    keywords: <String>['beauty', 'wellness', 'nails', 'makeup'],
    aliases: const <VanBusinessSearchAlias>[],
  ),
  _ => (keywords: const <String>[], aliases: const <VanBusinessSearchAlias>[]),
};
