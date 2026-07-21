import 'van_customer_journey.dart';
import 'van_customer_request_flow.dart';
import 'van_custom_job_question.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_capability.dart';
import 'van_service_handover.dart';
import 'van_service_template.dart';

/// An explicit per-day schedule used only by seeded template definitions.
class VanTemplateDayAvailability {
  const VanTemplateDayAvailability({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });

  final int day;
  final int startMinutes;
  final int endMinutes;
}

/// The central schema for adding a verified business type back to the app.
///
/// Every field that can affect a generated service is explicit. No behaviour
/// is inferred from display names, keywords, or generic fallback generators.
class VanBusinessTemplateDefinition {
  const VanBusinessTemplateDefinition({
    required this.categoryId,
    required this.categoryName,
    required this.businessTypeId,
    required this.businessTypeName,
    required this.description,
    required this.iconKey,
    required this.colorValue,
    required this.services,
    this.featured = false,
    this.searchKeywords = const <String>[],
    this.searchAliases = const <VanBusinessSearchAlias>[],
  });

  final String categoryId;
  final String categoryName;
  final String businessTypeId;
  final String businessTypeName;
  final String description;
  final String iconKey;
  final int colorValue;
  final List<VanBusinessServiceTemplateDefinition> services;
  final bool featured;
  final List<String> searchKeywords;
  final List<VanBusinessSearchAlias> searchAliases;
}

class VanBusinessServiceTemplateDefinition {
  const VanBusinessServiceTemplateDefinition({
    required this.serviceId,
    required this.name,
    required this.description,
    required this.featureIds,
    required this.bookingOptionIds,
    required this.customerJourney,
    required this.requestType,
    required this.startHandover,
    required this.endHandover,
    required this.requestFlowOptions,
    required this.questions,
    required this.extras,
    required this.availability,
    this.builtInQuestionKeys = const <String>{},
    this.builtInQuestionSettings = const <String, Map<String, dynamic>>{},
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.maximumBookingsPerDay = 8,
    this.requestPhotos = false,
    this.requireAddress = false,
    this.pricingMode = VanServiceCapabilityIds.customQuote,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
  });

  final String serviceId;
  final String name;
  final String description;
  final List<String> featureIds;
  final List<String> bookingOptionIds;
  final VanCustomerJourneyType customerJourney;
  final VanCustomerRequestType requestType;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions requestFlowOptions;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final bool requestPhotos;
  final bool requireAddress;
  final String pricingMode;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
}

/// Intentionally empty after the controlled seeded-library reset.
///
/// Future packs must be added here using [VanBusinessTemplateDefinition].
const List<VanBusinessTemplateDefinition>
kVanBusinessTemplateLibrary = <VanBusinessTemplateDefinition>[
  VanBusinessTemplateDefinition(
    categoryId: 'transport_delivery',
    categoryName: 'Transport & Delivery',
    businessTypeId: 'courier',
    businessTypeName: 'Courier',
    description:
        'Collection and delivery services for parcels, documents and other suitable items.',
    iconKey: 'local_shipping',
    colorValue: 0xFF4F8CFF,
    featured: true,
    searchKeywords: <String>['courier', 'parcel delivery', 'document delivery'],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Delivery service'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'courier_same_day_delivery',
        name: 'Same-day Delivery',
        description:
            'Collection and delivery on the same day for parcels, documents and other suitable items.',
        featureIds: <String>[
          VanServiceCapabilityIds.sameDay,
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.proofOfDelivery,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: false,
          askPreferredTime: false,
          showPickupAddress: true,
          showDeliveryAddress: true,
          showDropOffDate: true,
          showDropOffTime: true,
          showPickUpDate: true,
          showPickUpTime: true,
          showNotes: true,
        ),
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help identify the items and handling needs.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_items',
            text: 'What are we collecting and delivering?',
            helperText:
                'List the items and anything the courier should know about them.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['courier', 'same-day', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_size_weight',
            text:
                'What is the approximate size and weight of the item or items?',
            helperText: 'Estimates are fine; include dimensions where known.',
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['courier', 'same-day', 'size', 'weight'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_special_handling',
            text: 'Do any items need fragile or special handling?',
            helperText:
                'Add any handling instructions in Notes if you choose Yes.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['courier', 'same-day', 'fragile'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_recipient_available',
            text: 'Will someone be available at the delivery address?',
            helperText: 'This helps the courier plan the delivery handover.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.delivery,
            tags: <String>['courier', 'same-day', 'delivery'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_proof',
            text: 'What proof of delivery do you need?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.proofOfDelivery,
            choiceOptions: <String>[
              'No proof needed',
              'Photo proof',
              'Recipient signature',
            ],
            tags: <String>['courier', 'same-day', 'proof-of-delivery'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_additional_stop',
            label: 'Additional stop',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_heavy_oversized',
            label: 'Heavy or oversized item',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_out_of_hours',
            label: 'Evening or out-of-hours delivery',
          ),
        ],
        availability: <VanTemplateDayAvailability>[
          VanTemplateDayAvailability(
            day: 1,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 2,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 3,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 4,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 5,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 6,
            startMinutes: 540,
            endMinutes: 1020,
          ),
        ],
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 2,
        maximumBookingsPerDay: 12,
        requestPhotos: true,
        requireAddress: false,
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'courier_scheduled_delivery',
        name: 'Scheduled Delivery',
        description:
            'Pre-arranged collection and delivery on a chosen date and time window.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.proofOfDelivery,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: false,
          askPreferredTime: false,
          showPickupAddress: true,
          showDeliveryAddress: true,
          showDropOffDate: true,
          showDropOffTime: true,
          showPickUpDate: true,
          showPickUpTime: true,
          showNotes: true,
        ),
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help identify the items and handling needs.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_items',
            text: 'What are we collecting and delivering?',
            helperText:
                'List the items and anything the courier should know about them.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['courier', 'scheduled', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_size_weight',
            text:
                'What is the approximate size and weight of the item or items?',
            helperText: 'Estimates are fine; include dimensions where known.',
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['courier', 'scheduled', 'size', 'weight'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_special_handling',
            text: 'Do any items need fragile or special handling?',
            helperText:
                'Add any handling instructions in Notes if you choose Yes.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['courier', 'scheduled', 'fragile'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_access',
            text: 'Are there any collection or delivery access restrictions?',
            helperText:
                'Include parking, loading bays, stairs, gate codes or restricted access.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['courier', 'scheduled', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_proof',
            text: 'What proof of delivery do you need?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.proofOfDelivery,
            choiceOptions: <String>[
              'No proof needed',
              'Photo proof',
              'Recipient signature',
            ],
            tags: <String>['courier', 'scheduled', 'proof-of-delivery'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_additional_stop',
            label: 'Additional stop',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_heavy_oversized',
            label: 'Heavy or oversized item',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_weekend_holiday',
            label: 'Weekend or bank holiday delivery',
          ),
        ],
        availability: <VanTemplateDayAvailability>[
          VanTemplateDayAvailability(
            day: 1,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 2,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 3,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 4,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 5,
            startMinutes: 540,
            endMinutes: 1020,
          ),
        ],
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 8,
        requestPhotos: true,
        requireAddress: false,
      ),
    ],
  ),
];

class VanStarterCapabilityPack {
  const VanStarterCapabilityPack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.colorValue,
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
  final List<VanBusinessServiceRecommendation> services;
  final bool featured;
  final List<String> searchKeywords;
  final List<VanBusinessSearchAlias> searchAliases;

  List<VanBusinessServiceRecommendation> get serviceRecommendations => services;

  List<VanRecommendedServiceSetup> recommendationsFor(
    Iterable<String> selectedServiceIds, {
    Map<String, Set<String>> capabilityIdsByService =
        const <String, Set<String>>{},
  }) {
    final selectedIds = selectedServiceIds.toSet();
    return <VanRecommendedServiceSetup>[
      for (final service in services)
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

class VanBusinessServiceRecommendation {
  const VanBusinessServiceRecommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.recommendedCapabilityIds,
    this.journeyType = VanCustomerJourneyType.quote,
    this.requestType = VanCustomerRequestType.quoteRequest,
    this.startHandover,
    this.endHandover,
    this.requestFlowOptions,
    this.builtInQuestionKeys = const <String>{},
    this.builtInQuestionSettings = const <String, Map<String, dynamic>>{},
    this.questions = const <VanServiceTemplateQuestion>[],
    this.extras = const <VanServiceTemplateExtra>[],
    this.availability = const <VanTemplateDayAvailability>[],
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.maximumBookingsPerDay = 8,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
    this.requestPhotos = false,
    this.requireAddress = false,
    this.pricingMode = VanServiceCapabilityIds.customQuote,
    this.iconKey,
    this.colorValue,
  });

  final String id;
  final String name;
  final String description;
  final List<String> recommendedCapabilityIds;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions? requestFlowOptions;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requestPhotos;
  final bool requireAddress;
  final String pricingMode;
  final String? iconKey;
  final int? colorValue;
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
    required this.startHandover,
    required this.endHandover,
    required this.requestFlowOptions,
    required this.questions,
    required this.extras,
    required this.availability,
    required this.suggestedDurationMinutes,
    required this.suggestedNoticeHours,
    required this.maximumBookingsPerDay,
    required this.suggestedCustomerMessage,
    required this.suggestedStatusNames,
    required this.suggestedReminderMinutes,
    required this.requireAddress,
    required this.requestPhotos,
    required this.builtInQuestionKeys,
    required this.builtInQuestionSettings,
    required this.pricingMode,
  });

  factory VanRecommendedServiceSetup.fromRecommendation({
    required VanStarterCapabilityPack pack,
    required VanBusinessServiceRecommendation recommendation,
    required Set<String> capabilityIds,
  }) {
    final explicitIds =
        capabilityIds
            .where((id) => findVanServiceCapability(id) != null)
            .toList(growable: false)
          ..sort();
    return VanRecommendedServiceSetup(
      packId: pack.id,
      packName: pack.name,
      capabilityIds: explicitIds,
      serviceKey: recommendation.id,
      name: recommendation.name,
      description: recommendation.description,
      category: pack.category,
      iconKey: recommendation.iconKey ?? pack.iconKey,
      colorValue: recommendation.colorValue ?? pack.colorValue,
      journeyType: recommendation.journeyType,
      requestType: recommendation.requestType,
      startHandover: recommendation.startHandover,
      endHandover: recommendation.endHandover,
      requestFlowOptions:
          recommendation.requestFlowOptions ??
          VanCustomerRequestFlowOptions.defaultsFor(recommendation.requestType),
      questions: List<VanServiceTemplateQuestion>.unmodifiable(
        recommendation.questions,
      ),
      extras: List<VanServiceTemplateExtra>.unmodifiable(recommendation.extras),
      availability: List<VanTemplateDayAvailability>.unmodifiable(
        recommendation.availability,
      ),
      suggestedDurationMinutes: recommendation.suggestedDurationMinutes,
      suggestedNoticeHours: recommendation.suggestedNoticeHours,
      maximumBookingsPerDay: recommendation.maximumBookingsPerDay,
      suggestedCustomerMessage: recommendation.suggestedCustomerMessage,
      suggestedStatusNames: Map<String, String>.unmodifiable(
        recommendation.suggestedStatusNames,
      ),
      suggestedReminderMinutes: List<int>.unmodifiable(
        recommendation.suggestedReminderMinutes,
      ),
      requireAddress: recommendation.requireAddress,
      requestPhotos: recommendation.requestPhotos,
      builtInQuestionKeys: Set<String>.unmodifiable(
        recommendation.builtInQuestionKeys,
      ),
      builtInQuestionSettings: Map<String, Map<String, dynamic>>.unmodifiable({
        for (final entry in recommendation.builtInQuestionSettings.entries)
          entry.key: Map<String, dynamic>.unmodifiable(entry.value),
      }),
      pricingMode: recommendation.pricingMode,
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
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions requestFlowOptions;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requireAddress;
  final bool requestPhotos;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final String pricingMode;

  bool get allowCustomerDropOff =>
      startHandover == VanStartHandover.customerDropsOff;
  bool get allowBusinessCollection =>
      startHandover == VanStartHandover.businessCollects;
  bool get allowCustomerCollection =>
      endHandover == VanEndHandover.customerCollects;
  bool get allowBusinessReturn => endHandover == VanEndHandover.businessReturns;
  bool get allowBusinessDelivery =>
      endHandover == VanEndHandover.businessDelivers;

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

VanStarterCapabilityPack _packFromDefinition(
  VanBusinessTemplateDefinition definition,
) {
  return VanStarterCapabilityPack(
    id: definition.businessTypeId,
    name: definition.businessTypeName,
    description: definition.description,
    category: definition.categoryName,
    iconKey: definition.iconKey,
    colorValue: definition.colorValue,
    featured: definition.featured,
    searchKeywords: definition.searchKeywords,
    searchAliases: definition.searchAliases,
    services: <VanBusinessServiceRecommendation>[
      for (final service in definition.services)
        VanBusinessServiceRecommendation(
          id: service.serviceId,
          name: service.name,
          description: service.description,
          recommendedCapabilityIds: <String>{
            ...service.featureIds,
            ...service.bookingOptionIds,
          }.toList(growable: false),
          journeyType: service.customerJourney,
          requestType: service.requestType,
          startHandover: service.startHandover,
          endHandover: service.endHandover,
          requestFlowOptions: service.requestFlowOptions,
          builtInQuestionKeys: service.builtInQuestionKeys,
          builtInQuestionSettings: service.builtInQuestionSettings,
          questions: service.questions,
          extras: service.extras,
          availability: service.availability,
          suggestedDurationMinutes: service.suggestedDurationMinutes,
          suggestedNoticeHours: service.suggestedNoticeHours,
          maximumBookingsPerDay: service.maximumBookingsPerDay,
          suggestedCustomerMessage: service.suggestedCustomerMessage,
          suggestedStatusNames: service.suggestedStatusNames,
          suggestedReminderMinutes: service.suggestedReminderMinutes,
          requestPhotos: service.requestPhotos,
          requireAddress: service.requireAddress,
          pricingMode: service.pricingMode,
        ),
    ],
  );
}

final List<VanStarterCapabilityPack> kVanStarterCapabilityPacks =
    List<VanStarterCapabilityPack>.unmodifiable(
      kVanBusinessTemplateLibrary.map(_packFromDefinition),
    );

VanStarterCapabilityPack? findVanStarterCapabilityPackById(String id) {
  final normalized = id.trim();
  if (normalized.isEmpty) return null;
  for (final pack in kVanStarterCapabilityPacks) {
    if (pack.id == normalized) return pack;
  }
  return null;
}

List<VanBusinessSearchResult> searchVanStarterCapabilityPacks(String query) {
  final normalized = _normalizeSearch(query);
  if (normalized.isEmpty) return const <VanBusinessSearchResult>[];
  final results = <VanBusinessSearchResult>[];
  for (final pack in kVanStarterCapabilityPacks) {
    final terms = <String>[
      pack.name,
      pack.description,
      pack.category,
      ...pack.searchKeywords,
    ].map(_normalizeSearch);
    if (terms.any((term) => term.contains(normalized))) {
      results.add(VanBusinessSearchResult(pack: pack, label: pack.name));
      continue;
    }
    for (final alias in pack.searchAliases) {
      final aliasTerms = <String>[
        alias.label,
        ...alias.keywords,
      ].map(_normalizeSearch);
      if (aliasTerms.any((term) => term.contains(normalized))) {
        results.add(VanBusinessSearchResult(pack: pack, label: alias.label));
        break;
      }
    }
  }
  return List<VanBusinessSearchResult>.unmodifiable(results);
}

VanStarterCapabilityPack? findBestVanStarterCapabilityPack(String query) {
  final results = searchVanStarterCapabilityPacks(query);
  return results.isEmpty ? null : results.first.pack;
}

String _normalizeSearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
