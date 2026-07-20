import 'van_customer_request_flow.dart';
import 'van_customer_journey.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_template.dart';
import 'van_service_handover.dart';

class VanJobService {
  const VanJobService({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.requestPhotos,
    required this.requireAddress,
    required this.requestExactPinAfterQuoteAccepted,
    this.requestType = VanCustomerRequestType.quoteRequest,
    this.customerJourneyType = VanCustomerJourneyType.quote,
    this.startHandover,
    this.endHandover,
    this.allowedStartHandoverOptions = const <VanStartHandover>[],
    this.allowedEndHandoverOptions = const <VanEndHandover>[],
    this.businessDropOffInstructions = '',
    this.businessCollectionInstructions = '',
    this.requestFlowOptions,
    required this.linkedQuestionIds,
    this.disabledLinkedQuestionIds = const <String>[],
    required this.quoteExtraDefaults,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.category = 'General',
    this.iconKey = 'work',
    this.colorValue = 0xFF4F8CFF,
    this.isDraft = false,
    this.optionalQuestionIds = const <String>[],
    this.workingDays = const <int>[1, 2, 3, 4, 5],
    this.businessStartMinutes = 9 * 60,
    this.businessEndMinutes = 17 * 60,
    this.noticeHours = 24,
    this.maxBookingsPerDay = 8,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final bool requestPhotos;
  final bool requireAddress;
  final bool requestExactPinAfterQuoteAccepted;
  final VanCustomerRequestType requestType;
  final VanCustomerJourneyType customerJourneyType;
  VanServiceFlow get serviceFlow => requestType.serviceFlow;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final List<VanStartHandover> allowedStartHandoverOptions;
  final List<VanEndHandover> allowedEndHandoverOptions;
  final String businessDropOffInstructions;
  final String businessCollectionInstructions;
  final VanCustomerRequestFlowOptions? requestFlowOptions;
  final List<String> linkedQuestionIds;
  final List<String> disabledLinkedQuestionIds;
  final VanQuoteExtraDefaults quoteExtraDefaults;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final String category;
  final String iconKey;
  final int colorValue;
  final bool isDraft;
  final List<String> optionalQuestionIds;
  final List<int> workingDays;
  final int businessStartMinutes;
  final int businessEndMinutes;
  final int noticeHours;
  final int maxBookingsPerDay;

  bool get hasDescription => description.trim().isNotEmpty;
  int get linkedQuestionCount => linkedQuestionIds.length;
  int get enabledQuoteExtraCount => quoteExtraDefaults.enabledExtras.length;
  VanCustomerRequestFlowOptions get effectiveRequestFlowOptions =>
      requestFlowOptions ??
      VanCustomerRequestFlowOptions.defaultsFor(requestType);
  VanServiceHandoverConfig get effectiveHandover =>
      VanServiceHandoverConfig.resolve(
        requestType: requestType,
        startValue: startHandover?.storageKey,
        endValue: endHandover?.storageKey,
        allowedStartValues: allowedStartHandoverOptions.map(
          (value) => value.storageKey,
        ),
        allowedEndValues: allowedEndHandoverOptions.map(
          (value) => value.storageKey,
        ),
      );

  VanJobService copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    bool? requestPhotos,
    bool? requireAddress,
    bool? requestExactPinAfterQuoteAccepted,
    VanCustomerRequestType? requestType,
    VanCustomerJourneyType? customerJourneyType,
    VanStartHandover? startHandover,
    VanEndHandover? endHandover,
    List<VanStartHandover>? allowedStartHandoverOptions,
    List<VanEndHandover>? allowedEndHandoverOptions,
    String? businessDropOffInstructions,
    String? businessCollectionInstructions,
    VanCustomerRequestFlowOptions? requestFlowOptions,
    List<String>? linkedQuestionIds,
    List<String>? disabledLinkedQuestionIds,
    VanQuoteExtraDefaults? quoteExtraDefaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    String? category,
    String? iconKey,
    int? colorValue,
    bool? isDraft,
    List<String>? optionalQuestionIds,
    List<int>? workingDays,
    int? businessStartMinutes,
    int? businessEndMinutes,
    int? noticeHours,
    int? maxBookingsPerDay,
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
      requestType: requestType ?? this.requestType,
      customerJourneyType: customerJourneyType ?? this.customerJourneyType,
      startHandover: startHandover ?? this.startHandover,
      endHandover: endHandover ?? this.endHandover,
      allowedStartHandoverOptions:
          allowedStartHandoverOptions ?? this.allowedStartHandoverOptions,
      allowedEndHandoverOptions:
          allowedEndHandoverOptions ?? this.allowedEndHandoverOptions,
      businessDropOffInstructions:
          businessDropOffInstructions ?? this.businessDropOffInstructions,
      businessCollectionInstructions:
          businessCollectionInstructions ?? this.businessCollectionInstructions,
      requestFlowOptions: requestFlowOptions ?? this.requestFlowOptions,
      linkedQuestionIds: linkedQuestionIds ?? this.linkedQuestionIds,
      disabledLinkedQuestionIds:
          disabledLinkedQuestionIds ?? this.disabledLinkedQuestionIds,
      quoteExtraDefaults: quoteExtraDefaults ?? this.quoteExtraDefaults,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      category: category ?? this.category,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isDraft: isDraft ?? this.isDraft,
      optionalQuestionIds: optionalQuestionIds ?? this.optionalQuestionIds,
      workingDays: workingDays ?? this.workingDays,
      businessStartMinutes: businessStartMinutes ?? this.businessStartMinutes,
      businessEndMinutes: businessEndMinutes ?? this.businessEndMinutes,
      noticeHours: noticeHours ?? this.noticeHours,
      maxBookingsPerDay: maxBookingsPerDay ?? this.maxBookingsPerDay,
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
      'requestType': serviceFlow.requestType.storageKey,
      'serviceFlow': serviceFlow.storageKey,
      'customerJourneyType': customerJourneyType.storageKey,
      'startHandover': effectiveHandover.start.storageKey,
      'endHandover': effectiveHandover.end.storageKey,
      'allowedStartHandoverOptions': effectiveHandover.allowedStarts
          .map((value) => value.storageKey)
          .toList(growable: false),
      'allowedEndHandoverOptions': effectiveHandover.allowedEnds
          .map((value) => value.storageKey)
          .toList(growable: false),
      'businessDropOffInstructions': businessDropOffInstructions,
      'businessCollectionInstructions': businessCollectionInstructions,
      'requestFlowOptions': effectiveRequestFlowOptions.toJson(),
      'linkedQuestionIds': linkedQuestionIds,
      'disabledLinkedQuestionIds': disabledLinkedQuestionIds,
      'quoteExtraDefaults': quoteExtraDefaults.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isArchived': isArchived,
      'category': category,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'isDraft': isDraft,
      'optionalQuestionIds': optionalQuestionIds,
      'workingDays': workingDays,
      'businessStartMinutes': businessStartMinutes,
      'businessEndMinutes': businessEndMinutes,
      'noticeHours': noticeHours,
      'maxBookingsPerDay': maxBookingsPerDay,
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

    List<int> readIntList(String key, List<int> fallback) {
      final raw = json[key];
      if (raw is! List) return fallback;
      final values =
          raw
              .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
              .whereType<int>()
              .where((item) => item >= 1 && item <= 7)
              .toSet()
              .toList(growable: false)
            ..sort();
      return values.isEmpty ? fallback : List<int>.unmodifiable(values);
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      return raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;
    }

    final now = DateTime.now();
    final createdAt = readDate('createdAt', fallback: now);
    final updatedAt = readDate('updatedAt', fallback: createdAt);
    final name = readText('name', fallback: 'Service');
    final id = readText('id', fallback: now.microsecondsSinceEpoch.toString());
    final requestTypeFallback = defaultVanCustomerRequestTypeForService(
      serviceId: id,
      serviceName: name,
    );
    final legacyRequestType = vanCustomerRequestTypeFromStorage(
      json['requestType'],
      fallback: requestTypeFallback,
    );
    final resolvedServiceFlow = vanServiceFlowFromStorage(
      json['serviceFlow'],
      legacyRequestType: legacyRequestType,
    );
    final resolvedRequestType = resolvedServiceFlow.requestType;
    final legacyJourney = switch (legacyRequestType) {
      VanCustomerRequestType.bookingRequest => VanCustomerJourneyType.booking,
      VanCustomerRequestType.orderRequest => VanCustomerJourneyType.order,
      VanCustomerRequestType.quoteRequest ||
      VanCustomerRequestType.pickupDeliveryRequest ||
      VanCustomerRequestType.dropOffPickupRequest =>
        VanCustomerJourneyType.quote,
    };
    final handover = VanServiceHandoverConfig.resolve(
      requestType: resolvedRequestType,
      startValue: json['startHandover'],
      endValue: json['endHandover'],
      allowedStartValues: json['allowedStartHandoverOptions'],
      allowedEndValues: json['allowedEndHandoverOptions'],
      legacyMode: json['handoverMode'] ?? json['transportMode'],
    );
    VanQuoteExtraDefaults readQuoteExtraDefaults() {
      final raw =
          json['quoteExtraDefaults'] ??
          json['quoteExtras'] ??
          json['extraDefaults'];
      if (raw is Map) {
        final template = findVanServiceTemplateForService(
          serviceId: readText('id'),
          serviceName: name,
        );
        return VanQuoteExtraDefaults.fromJson(
          Map<String, dynamic>.from(raw),
          legacyIncludedBuiltInKeys:
              template?.quoteExtraDefaults().includedBuiltInKeys ??
              const <String>{},
        );
      }
      return findVanServiceTemplateForService(
            serviceId: readText('id'),
            serviceName: name,
          )?.quoteExtraDefaults() ??
          VanQuoteExtraDefaults.empty();
    }

    return VanJobService(
      id: id,
      name: name,
      description: readText('description'),
      isActive: json['isActive'] == false ? false : true,
      requestPhotos: json['requestPhotos'] == true,
      requireAddress: json['requireAddress'] == false ? false : true,
      requestExactPinAfterQuoteAccepted:
          json['requestExactPinAfterQuoteAccepted'] == true,
      requestType: resolvedRequestType,
      customerJourneyType: vanCustomerJourneyTypeFromStorage(
        json['customerJourneyType'],
        fallback: legacyJourney,
      ),
      startHandover: handover.start,
      endHandover: handover.end,
      allowedStartHandoverOptions: handover.allowedStarts,
      allowedEndHandoverOptions: handover.allowedEnds,
      businessDropOffInstructions: readText('businessDropOffInstructions'),
      businessCollectionInstructions: readText(
        'businessCollectionInstructions',
      ),
      requestFlowOptions: VanCustomerRequestFlowOptions.fromJson(
        json['requestFlowOptions'],
        requestType: resolvedRequestType,
      ),
      linkedQuestionIds: readStringList('linkedQuestionIds'),
      disabledLinkedQuestionIds: readStringList('disabledLinkedQuestionIds'),
      quoteExtraDefaults: readQuoteExtraDefaults(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: json['isArchived'] == true,
      category: readText('category', fallback: 'General'),
      iconKey: readText('iconKey', fallback: 'work'),
      colorValue: readInt('colorValue', 0xFF4F8CFF),
      isDraft: json['isDraft'] == true,
      optionalQuestionIds: readStringList('optionalQuestionIds'),
      workingDays: readIntList('workingDays', const <int>[1, 2, 3, 4, 5]),
      businessStartMinutes: readInt('businessStartMinutes', 9 * 60),
      businessEndMinutes: readInt('businessEndMinutes', 17 * 60),
      noticeHours: readInt('noticeHours', 24),
      maxBookingsPerDay: readInt('maxBookingsPerDay', 8),
    );
  }
}
