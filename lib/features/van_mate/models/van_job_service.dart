import 'van_customer_request_flow.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_template.dart';

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
    this.requestFlowOptions,
    required this.linkedQuestionIds,
    this.disabledLinkedQuestionIds = const <String>[],
    required this.quoteExtraDefaults,
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
  final VanCustomerRequestType requestType;
  final VanCustomerRequestFlowOptions? requestFlowOptions;
  final List<String> linkedQuestionIds;
  final List<String> disabledLinkedQuestionIds;
  final VanQuoteExtraDefaults quoteExtraDefaults;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  bool get hasDescription => description.trim().isNotEmpty;
  int get linkedQuestionCount => linkedQuestionIds.length;
  int get enabledQuoteExtraCount => quoteExtraDefaults.enabledExtras.length;
  VanCustomerRequestFlowOptions get effectiveRequestFlowOptions =>
      requestFlowOptions ??
      VanCustomerRequestFlowOptions.defaultsFor(requestType);

  VanJobService copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    bool? requestPhotos,
    bool? requireAddress,
    bool? requestExactPinAfterQuoteAccepted,
    VanCustomerRequestType? requestType,
    VanCustomerRequestFlowOptions? requestFlowOptions,
    List<String>? linkedQuestionIds,
    List<String>? disabledLinkedQuestionIds,
    VanQuoteExtraDefaults? quoteExtraDefaults,
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
      requestType: requestType ?? this.requestType,
      requestFlowOptions: requestFlowOptions ?? this.requestFlowOptions,
      linkedQuestionIds: linkedQuestionIds ?? this.linkedQuestionIds,
      disabledLinkedQuestionIds:
          disabledLinkedQuestionIds ?? this.disabledLinkedQuestionIds,
      quoteExtraDefaults: quoteExtraDefaults ?? this.quoteExtraDefaults,
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
      'requestType': requestType.storageKey,
      'requestFlowOptions': effectiveRequestFlowOptions.toJson(),
      'linkedQuestionIds': linkedQuestionIds,
      'disabledLinkedQuestionIds': disabledLinkedQuestionIds,
      'quoteExtraDefaults': quoteExtraDefaults.toJson(),
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
    final id = readText('id', fallback: now.microsecondsSinceEpoch.toString());
    final requestTypeFallback = defaultVanCustomerRequestTypeForService(
      serviceId: id,
      serviceName: name,
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
      requestType: vanCustomerRequestTypeFromStorage(
        json['requestType'],
        fallback: requestTypeFallback,
      ),
      requestFlowOptions: VanCustomerRequestFlowOptions.fromJson(
        json['requestFlowOptions'],
        requestType: vanCustomerRequestTypeFromStorage(
          json['requestType'],
          fallback: requestTypeFallback,
        ),
      ),
      linkedQuestionIds: readStringList('linkedQuestionIds'),
      disabledLinkedQuestionIds: readStringList('disabledLinkedQuestionIds'),
      quoteExtraDefaults: readQuoteExtraDefaults(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: json['isArchived'] == true,
    );
  }
}
