import 'van_customer_journey.dart';
import 'van_customer_request_flow.dart';
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
    required this.questions,
    required this.extras,
    required this.availability,
    this.builtInQuestionKeys = const <String>{},
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
  final Set<String> builtInQuestionKeys;
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
const List<VanBusinessTemplateDefinition> kVanBusinessTemplateLibrary =
    <VanBusinessTemplateDefinition>[];

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
    this.builtInQuestionKeys = const <String>{},
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
  final Set<String> builtInQuestionKeys;
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
  final String pricingMode;

  bool get allowCustomerDropOff =>
      startHandover == VanStartHandover.customerDropsOff;
  bool get allowBusinessCollection =>
      startHandover == VanStartHandover.businessCollects;
  bool get allowCustomerCollection =>
      endHandover == VanEndHandover.customerCollects;
  bool get allowBusinessReturn => endHandover == VanEndHandover.businessReturns;

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
          builtInQuestionKeys: service.builtInQuestionKeys,
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
