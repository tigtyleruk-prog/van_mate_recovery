import 'van_customer_request_flow.dart';
import 'van_customer_journey.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_template.dart';
import 'van_service_handover.dart';

class VanServiceDaySchedule {
  const VanServiceDaySchedule({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;

  VanServiceDaySchedule copyWith({int? startMinutes, int? endMinutes}) {
    return VanServiceDaySchedule(
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  factory VanServiceDaySchedule.fromJson(Map<String, dynamic> json) {
    int readMinutes(String key, int fallback) {
      final raw = json[key];
      return (raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback)
          .clamp(0, 24 * 60 - 1);
    }

    return VanServiceDaySchedule(
      startMinutes: readMinutes('startMinutes', 9 * 60),
      endMinutes: readMinutes('endMinutes', 17 * 60),
    );
  }
}

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
    this.availabilityByDay,
    this.noticeHours = 24,
    this.maxBookingsPerDay = 8,
    this.selectedBuiltInQuestionKeys,
    this.builtInQuestionSettings = const <String, Map<String, dynamic>>{},
    this.maxCustomerPhotos = 5,
    this.extraChargeUnits = const <String, String>{},
    this.creationSource = '',
    this.starterTemplateId = '',
    this.starterPackId = '',
    this.starterCapabilityIds = const <String>[],
    this.serviceCapabilityIds = const <String>[],
    this.capabilitySchemaVersion = 0,
    this.capabilityGeneratedQuestionIds = const <String>[],
    this.capabilityGeneratedQuestionKeys = const <String, String>{},
    this.capabilityGeneratedExtraKeys = const <String>[],
    this.capabilityGeneratedBuiltInQuestionKeys = const <String>[],
    this.pricingMode = '',
    this.suggestedReminderMinutes = const <int>[],
    this.suggestedStatusNames = const <String, String>{},
    this.appointmentDurationMinutes = 60,
    this.customerMessage = '',
    this.wizardStep = 0,
    bool? allowCustomerDropOff,
    bool? allowBusinessCollection,
    bool? allowCustomerCollection,
    bool? allowBusinessReturn,
  }) : _allowCustomerDropOff = allowCustomerDropOff,
       _allowBusinessCollection = allowBusinessCollection,
       _allowCustomerCollection = allowCustomerCollection,
       _allowBusinessReturn = allowBusinessReturn;

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
  final Map<int, VanServiceDaySchedule>? availabilityByDay;
  final int noticeHours;
  final int maxBookingsPerDay;
  final List<String>? selectedBuiltInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final int maxCustomerPhotos;
  final Map<String, String> extraChargeUnits;
  final String creationSource;
  final String starterTemplateId;
  final String starterPackId;
  final List<String> starterCapabilityIds;
  final List<String> serviceCapabilityIds;
  final int capabilitySchemaVersion;
  final List<String> capabilityGeneratedQuestionIds;
  final Map<String, String> capabilityGeneratedQuestionKeys;
  final List<String> capabilityGeneratedExtraKeys;
  final List<String> capabilityGeneratedBuiltInQuestionKeys;
  final String pricingMode;
  final List<int> suggestedReminderMinutes;
  final Map<String, String> suggestedStatusNames;
  final int appointmentDurationMinutes;
  final String customerMessage;
  final int wizardStep;
  final bool? _allowCustomerDropOff;
  final bool? _allowBusinessCollection;
  final bool? _allowCustomerCollection;
  final bool? _allowBusinessReturn;

  bool get isCapabilityDriven => capabilitySchemaVersion > 0;

  bool get hasExplicitHandoverCapabilities =>
      _allowCustomerDropOff != null ||
      _allowBusinessCollection != null ||
      _allowCustomerCollection != null ||
      _allowBusinessReturn != null;

  bool get allowCustomerDropOff => hasExplicitHandoverCapabilities
      ? _allowCustomerDropOff ?? false
      : _legacyAllowsStart(VanStartHandover.customerDropsOff);
  bool get allowBusinessCollection => hasExplicitHandoverCapabilities
      ? _allowBusinessCollection ?? false
      : _legacyAllowsStart(VanStartHandover.businessCollects);
  bool get allowCustomerCollection => hasExplicitHandoverCapabilities
      ? _allowCustomerCollection ?? false
      : _legacyAllowsEnd(VanEndHandover.customerCollects);
  bool get allowBusinessReturn => hasExplicitHandoverCapabilities
      ? _allowBusinessReturn ?? false
      : _legacyAllowsEnd(VanEndHandover.businessReturns);

  bool _legacyAllowsStart(VanStartHandover value) {
    if (!vanRequestTypeSupportsHandover(requestType)) return false;
    if (allowedStartHandoverOptions.isNotEmpty) {
      return allowedStartHandoverOptions.contains(value);
    }
    return requestType == VanCustomerRequestType.pickupDeliveryRequest
        ? value == VanStartHandover.businessCollects
        : value == VanStartHandover.customerDropsOff;
  }

  bool _legacyAllowsEnd(VanEndHandover value) {
    if (!vanRequestTypeSupportsHandover(requestType)) return false;
    if (allowedEndHandoverOptions.isNotEmpty) {
      return allowedEndHandoverOptions.contains(value);
    }
    return requestType == VanCustomerRequestType.pickupDeliveryRequest
        ? value == VanEndHandover.businessReturns
        : value == VanEndHandover.customerCollects;
  }

  bool get hasHandoverConfiguration =>
      (allowCustomerDropOff || allowBusinessCollection) &&
      (allowCustomerCollection || allowBusinessReturn);

  bool get hasDescription => description.trim().isNotEmpty;
  int get linkedQuestionCount => linkedQuestionIds.length;
  int get configuredQuestionCount =>
      linkedQuestionIds.length + effectiveSelectedBuiltInQuestionKeys.length;
  int get enabledQuoteExtraCount => quoteExtraDefaults.enabledExtras.length;
  Map<int, VanServiceDaySchedule> get effectiveAvailabilityByDay {
    final configured = availabilityByDay;
    if (configured != null) {
      return Map<int, VanServiceDaySchedule>.unmodifiable(configured);
    }
    return Map<int, VanServiceDaySchedule>.unmodifiable({
      for (final day in workingDays)
        day: VanServiceDaySchedule(
          startMinutes: businessStartMinutes,
          endMinutes: businessEndMinutes,
        ),
    });
  }

  VanCustomerRequestFlowOptions get effectiveRequestFlowOptions =>
      requestFlowOptions ??
      VanCustomerRequestFlowOptions.defaultsFor(requestType);
  VanServiceHandoverConfig get effectiveHandover =>
      VanServiceHandoverConfig.fromCapabilities(
        allowCustomerDropOff: allowCustomerDropOff,
        allowBusinessCollection: allowBusinessCollection,
        allowCustomerCollection: allowCustomerCollection,
        allowBusinessReturn: allowBusinessReturn,
        preferredStart: startHandover,
        preferredEnd: endHandover,
      );

  Set<String> get effectiveSelectedBuiltInQuestionKeys {
    final configured = selectedBuiltInQuestionKeys;
    if (configured != null) return configured.toSet();
    final flow = effectiveRequestFlowOptions;
    return <String>{
      'phone',
      'email',
      if (requireAddress) 'address',
      if (flow.askPreferredDate) 'preferred_date',
      if (flow.askPreferredTime) 'preferred_time',
      if (requestPhotos) 'photos',
    };
  }

  bool showsBuiltInQuestion(String key) =>
      effectiveSelectedBuiltInQuestionKeys.contains(key);

  bool requiresBuiltInQuestion(String key, {bool legacyDefault = false}) {
    final configured = builtInQuestionSettings[key]?['required'];
    if (configured is bool) return configured;
    if (selectedBuiltInQuestionKeys == null) return legacyDefault;
    return false;
  }

  String builtInQuestionHelper(String key) =>
      builtInQuestionSettings[key]?['helperText']?.toString().trim() ?? '';

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
    Map<int, VanServiceDaySchedule>? availabilityByDay,
    bool clearAvailabilityByDay = false,
    int? noticeHours,
    int? maxBookingsPerDay,
    List<String>? selectedBuiltInQuestionKeys,
    bool clearSelectedBuiltInQuestionKeys = false,
    Map<String, Map<String, dynamic>>? builtInQuestionSettings,
    int? maxCustomerPhotos,
    Map<String, String>? extraChargeUnits,
    String? creationSource,
    String? starterTemplateId,
    String? starterPackId,
    List<String>? starterCapabilityIds,
    List<String>? serviceCapabilityIds,
    int? capabilitySchemaVersion,
    List<String>? capabilityGeneratedQuestionIds,
    Map<String, String>? capabilityGeneratedQuestionKeys,
    List<String>? capabilityGeneratedExtraKeys,
    List<String>? capabilityGeneratedBuiltInQuestionKeys,
    String? pricingMode,
    List<int>? suggestedReminderMinutes,
    Map<String, String>? suggestedStatusNames,
    int? appointmentDurationMinutes,
    String? customerMessage,
    int? wizardStep,
    bool? allowCustomerDropOff,
    bool? allowBusinessCollection,
    bool? allowCustomerCollection,
    bool? allowBusinessReturn,
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
      availabilityByDay: clearAvailabilityByDay
          ? null
          : availabilityByDay ?? this.availabilityByDay,
      noticeHours: noticeHours ?? this.noticeHours,
      maxBookingsPerDay: maxBookingsPerDay ?? this.maxBookingsPerDay,
      selectedBuiltInQuestionKeys: clearSelectedBuiltInQuestionKeys
          ? null
          : (selectedBuiltInQuestionKeys ?? this.selectedBuiltInQuestionKeys),
      builtInQuestionSettings:
          builtInQuestionSettings ?? this.builtInQuestionSettings,
      maxCustomerPhotos: maxCustomerPhotos ?? this.maxCustomerPhotos,
      extraChargeUnits: extraChargeUnits ?? this.extraChargeUnits,
      creationSource: creationSource ?? this.creationSource,
      starterTemplateId: starterTemplateId ?? this.starterTemplateId,
      starterPackId: starterPackId ?? this.starterPackId,
      starterCapabilityIds: starterCapabilityIds ?? this.starterCapabilityIds,
      serviceCapabilityIds: serviceCapabilityIds ?? this.serviceCapabilityIds,
      capabilitySchemaVersion:
          capabilitySchemaVersion ?? this.capabilitySchemaVersion,
      capabilityGeneratedQuestionIds:
          capabilityGeneratedQuestionIds ?? this.capabilityGeneratedQuestionIds,
      capabilityGeneratedQuestionKeys:
          capabilityGeneratedQuestionKeys ??
          this.capabilityGeneratedQuestionKeys,
      capabilityGeneratedExtraKeys:
          capabilityGeneratedExtraKeys ?? this.capabilityGeneratedExtraKeys,
      capabilityGeneratedBuiltInQuestionKeys:
          capabilityGeneratedBuiltInQuestionKeys ??
          this.capabilityGeneratedBuiltInQuestionKeys,
      pricingMode: pricingMode ?? this.pricingMode,
      suggestedReminderMinutes:
          suggestedReminderMinutes ?? this.suggestedReminderMinutes,
      suggestedStatusNames: suggestedStatusNames ?? this.suggestedStatusNames,
      appointmentDurationMinutes:
          appointmentDurationMinutes ?? this.appointmentDurationMinutes,
      customerMessage: customerMessage ?? this.customerMessage,
      wizardStep: wizardStep ?? this.wizardStep,
      allowCustomerDropOff: allowCustomerDropOff ?? _allowCustomerDropOff,
      allowBusinessCollection:
          allowBusinessCollection ?? _allowBusinessCollection,
      allowCustomerCollection:
          allowCustomerCollection ?? _allowCustomerCollection,
      allowBusinessReturn: allowBusinessReturn ?? _allowBusinessReturn,
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
      'requestType': requestType.storageKey,
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
      if (availabilityByDay != null)
        'availabilityByDay': <String, dynamic>{
          for (final entry in availabilityByDay!.entries)
            '${entry.key}': entry.value.toJson(),
        },
      'noticeHours': noticeHours,
      'maxBookingsPerDay': maxBookingsPerDay,
      'selectedBuiltInQuestionKeys': selectedBuiltInQuestionKeys,
      'builtInQuestionSettings': builtInQuestionSettings,
      'maxCustomerPhotos': maxCustomerPhotos,
      'extraChargeUnits': extraChargeUnits,
      'creationSource': creationSource,
      'starterTemplateId': starterTemplateId,
      'starterPackId': starterPackId,
      'starterCapabilityIds': starterCapabilityIds,
      'serviceCapabilityIds': serviceCapabilityIds,
      'capabilitySchemaVersion': capabilitySchemaVersion,
      'capabilityGeneratedQuestionIds': capabilityGeneratedQuestionIds,
      'capabilityGeneratedQuestionKeys': capabilityGeneratedQuestionKeys,
      'capabilityGeneratedExtraKeys': capabilityGeneratedExtraKeys,
      'capabilityGeneratedBuiltInQuestionKeys':
          capabilityGeneratedBuiltInQuestionKeys,
      'pricingMode': pricingMode,
      'suggestedReminderMinutes': suggestedReminderMinutes,
      'suggestedStatusNames': suggestedStatusNames,
      'appointmentDurationMinutes': appointmentDurationMinutes,
      'customerMessage': customerMessage,
      'wizardStep': wizardStep,
      'allowCustomerDropOff': allowCustomerDropOff,
      'allowBusinessCollection': allowBusinessCollection,
      'allowCustomerCollection': allowCustomerCollection,
      'allowBusinessReturn': allowBusinessReturn,
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

    List<int> readPositiveIntList(String key) {
      final raw = json[key];
      if (raw is! List) return const <int>[];
      final values = raw
          .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
          .whereType<int>()
          .where((item) => item > 0)
          .toSet()
          .toList(growable: false);
      return List<int>.unmodifiable(values);
    }

    int readInt(String key, int fallback) {
      final raw = json[key];
      return raw is num ? raw.toInt() : int.tryParse('$raw') ?? fallback;
    }

    bool? readNullableBool(String key) {
      if (!json.containsKey(key) || json[key] == null) return null;
      final raw = json[key];
      if (raw is bool) return raw;
      return switch (raw.toString().trim().toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => null,
      };
    }

    List<String>? readNullableStringList(String key) {
      if (!json.containsKey(key) || json[key] is! List) return null;
      return readStringList(key);
    }

    Map<String, Map<String, dynamic>> readNestedMap(String key) {
      final raw = json[key];
      if (raw is! Map) return const <String, Map<String, dynamic>>{};
      return Map<String, Map<String, dynamic>>.unmodifiable({
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key.toString(): Map<String, dynamic>.unmodifiable(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      });
    }

    Map<String, String> readStringMap(String key) {
      final raw = json[key];
      if (raw is! Map) return const <String, String>{};
      return Map<String, String>.unmodifiable({
        for (final entry in raw.entries)
          if (entry.value?.toString().trim().isNotEmpty == true)
            entry.key.toString(): entry.value.toString().trim(),
      });
    }

    Map<int, VanServiceDaySchedule>? readAvailabilityByDay() {
      if (!json.containsKey('availabilityByDay')) return null;
      final raw = json['availabilityByDay'];
      if (raw is! Map) return null;
      final schedules = <int, VanServiceDaySchedule>{};
      for (final entry in raw.entries) {
        final day = int.tryParse(entry.key.toString());
        if (day == null || day < 1 || day > 7 || entry.value is! Map) {
          continue;
        }
        schedules[day] = VanServiceDaySchedule.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      return schedules.isEmpty
          ? null
          : Map<int, VanServiceDaySchedule>.unmodifiable(schedules);
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
    final storedCapabilitySchemaVersion = readInt('capabilitySchemaVersion', 0);
    final resolvedServiceFlow = vanServiceFlowFromStorage(
      json['serviceFlow'],
      legacyRequestType: legacyRequestType,
    );
    final resolvedRequestType = storedCapabilitySchemaVersion > 0
        ? legacyRequestType
        : resolvedServiceFlow.requestType;
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
    final storedAvailabilityByDay = readAvailabilityByDay();
    final legacyWorkingDays = readIntList('workingDays', const <int>[
      1,
      2,
      3,
      4,
      5,
    ]);
    final effectiveWorkingDays = storedAvailabilityByDay == null
        ? legacyWorkingDays
        : (storedAvailabilityByDay.keys.toList()..sort());
    final firstStoredSchedule = effectiveWorkingDays.isEmpty
        ? null
        : storedAvailabilityByDay?[effectiveWorkingDays.first];
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
      workingDays: effectiveWorkingDays,
      businessStartMinutes: json.containsKey('businessStartMinutes')
          ? readInt('businessStartMinutes', 9 * 60)
          : firstStoredSchedule?.startMinutes ?? 9 * 60,
      businessEndMinutes: json.containsKey('businessEndMinutes')
          ? readInt('businessEndMinutes', 17 * 60)
          : firstStoredSchedule?.endMinutes ?? 17 * 60,
      availabilityByDay: storedAvailabilityByDay,
      noticeHours: readInt('noticeHours', 24),
      maxBookingsPerDay: readInt('maxBookingsPerDay', 8),
      selectedBuiltInQuestionKeys: readNullableStringList(
        'selectedBuiltInQuestionKeys',
      ),
      builtInQuestionSettings: readNestedMap('builtInQuestionSettings'),
      maxCustomerPhotos: readInt('maxCustomerPhotos', 5).clamp(1, 5),
      extraChargeUnits: readStringMap('extraChargeUnits'),
      creationSource: readText('creationSource'),
      starterTemplateId: readText('starterTemplateId'),
      starterPackId: readText('starterPackId'),
      starterCapabilityIds: readStringList('starterCapabilityIds'),
      serviceCapabilityIds: readStringList('serviceCapabilityIds'),
      capabilitySchemaVersion: storedCapabilitySchemaVersion,
      capabilityGeneratedQuestionIds: readStringList(
        'capabilityGeneratedQuestionIds',
      ),
      capabilityGeneratedQuestionKeys: readStringMap(
        'capabilityGeneratedQuestionKeys',
      ),
      capabilityGeneratedExtraKeys: readStringList(
        'capabilityGeneratedExtraKeys',
      ),
      capabilityGeneratedBuiltInQuestionKeys: readStringList(
        'capabilityGeneratedBuiltInQuestionKeys',
      ),
      pricingMode: readText('pricingMode'),
      suggestedReminderMinutes: readPositiveIntList('suggestedReminderMinutes'),
      suggestedStatusNames: readStringMap('suggestedStatusNames'),
      appointmentDurationMinutes: readInt(
        'appointmentDurationMinutes',
        60,
      ).clamp(5, 24 * 60),
      customerMessage: readText('customerMessage'),
      wizardStep: readInt('wizardStep', 0).clamp(0, 7),
      allowCustomerDropOff: readNullableBool('allowCustomerDropOff'),
      allowBusinessCollection: readNullableBool('allowBusinessCollection'),
      allowCustomerCollection: readNullableBool('allowCustomerCollection'),
      allowBusinessReturn: readNullableBool('allowBusinessReturn'),
    );
  }
}
