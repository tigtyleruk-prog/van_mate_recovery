import 'package:flutter/foundation.dart';

const String kVanQuoteExtraHelperKey = 'helper';
const String kVanQuoteExtraWaitingTimeKey = 'waiting_time';
const String kVanQuoteExtraStairsKey = 'stairs';
const String kVanQuoteExtraMileageKey = 'mileage';
const String kVanQuoteExtraCollectionDeliveryKey = 'collection_delivery';
const String kVanQuoteExtraThirdPersonKey = 'third_person';
const String kVanQuoteExtraCustomKey = 'custom';
const String kVanQuoteCustomExtraKeyPrefix = 'custom_extra_';

const List<String> kVanQuoteExtraDefaultOrder = <String>[
  kVanQuoteExtraHelperKey,
  kVanQuoteExtraWaitingTimeKey,
  kVanQuoteExtraStairsKey,
  kVanQuoteExtraMileageKey,
  kVanQuoteExtraCollectionDeliveryKey,
  kVanQuoteExtraThirdPersonKey,
];

const Map<String, String> kVanQuoteExtraDefaultLabels = <String, String>{
  kVanQuoteExtraHelperKey: 'Extra helper',
  kVanQuoteExtraWaitingTimeKey: 'Waiting time',
  kVanQuoteExtraStairsKey: 'Stairs / access',
  kVanQuoteExtraMileageKey: 'Mileage',
  kVanQuoteExtraCollectionDeliveryKey: 'Collection / delivery',
  kVanQuoteExtraThirdPersonKey: '3rd person',
  kVanQuoteExtraCustomKey: 'Custom extra',
};

const Map<String, double> kVanQuoteExtraDefaultPrices = <String, double>{
  kVanQuoteExtraHelperKey: 20,
  kVanQuoteExtraWaitingTimeKey: 10,
  kVanQuoteExtraStairsKey: 10,
  kVanQuoteExtraMileageKey: 0,
  kVanQuoteExtraCollectionDeliveryKey: 0,
  kVanQuoteExtraThirdPersonKey: 20,
  kVanQuoteExtraCustomKey: 0,
};

@immutable
class VanQuoteExtraDefault {
  const VanQuoteExtraDefault({
    required this.key,
    required this.label,
    required this.defaultPrice,
    required this.enabled,
  });

  factory VanQuoteExtraDefault.fallback(String key) {
    return VanQuoteExtraDefault(
      key: key,
      label: kVanQuoteExtraDefaultLabels[key] ?? 'Extra',
      defaultPrice: kVanQuoteExtraDefaultPrices[key] ?? 0,
      enabled: true,
    );
  }

  factory VanQuoteExtraDefault.custom({
    required String key,
    required String label,
    required double defaultPrice,
    bool enabled = true,
  }) {
    return VanQuoteExtraDefault(
      key: normalizeVanQuoteCustomExtraKey(key, label: label),
      label: label,
      defaultPrice: defaultPrice < 0 ? 0 : defaultPrice,
      enabled: enabled,
    );
  }

  factory VanQuoteExtraDefault.fromJson(String key, Map<String, dynamic> json) {
    final fallback = VanQuoteExtraDefault.fallback(key);
    final label = json['label']?.toString().trim() ?? '';
    final priceValue = json['defaultPrice'] ?? json['price'] ?? json['amount'];
    final price = _jsonPrice(priceValue, fallback.defaultPrice);

    return fallback.copyWith(
      label: label.isEmpty ? fallback.label : label,
      defaultPrice: price < 0 ? 0 : price,
      enabled: _jsonEnabled(json['enabled'], fallback: fallback.enabled),
    );
  }

  final String key;
  final String label;
  final double defaultPrice;
  final bool enabled;

  String get resolvedLabel {
    final cleaned = label.trim();
    return cleaned.isEmpty
        ? (kVanQuoteExtraDefaultLabels[key] ?? 'Extra')
        : cleaned;
  }

  VanQuoteExtraDefault copyWith({
    String? label,
    double? defaultPrice,
    bool? enabled,
  }) {
    return VanQuoteExtraDefault(
      key: key,
      label: label ?? this.label,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'label': resolvedLabel,
      'defaultPrice': defaultPrice,
      'enabled': enabled,
    };
  }
}

@immutable
class VanQuoteExtraDefaults {
  const VanQuoteExtraDefaults({
    required this.extras,
    this.customExtras = const <VanQuoteExtraDefault>[],
    this.extraOrder = const <String>[],
    this.deletedBuiltInKeys = const <String>{},
    this.includedBuiltInKeys = const <String>{},
  });

  factory VanQuoteExtraDefaults.defaults() {
    return VanQuoteExtraDefaults(
      extras: <String, VanQuoteExtraDefault>{
        for (final key in kVanQuoteExtraDefaultOrder)
          key: VanQuoteExtraDefault.fallback(key),
      },
      includedBuiltInKeys: kVanQuoteExtraDefaultOrder.toSet(),
    );
  }

  factory VanQuoteExtraDefaults.empty() {
    return const VanQuoteExtraDefaults(
      extras: <String, VanQuoteExtraDefault>{},
    );
  }

  factory VanQuoteExtraDefaults.starterForServiceName(String serviceName) {
    final normalized = serviceName.trim().toLowerCase();
    if (normalized.contains('garden')) {
      return _serviceStarterDefaults(
        enabledBuiltInKeys: const <String>{},
        customExtras: <VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_green_waste',
            label: 'Green waste',
            defaultPrice: 20,
          ),
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_extra_hour',
            label: 'Extra hour',
            defaultPrice: 30,
          ),
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_materials',
            label: 'Materials',
            defaultPrice: 25,
          ),
        ],
      );
    }
    if (normalized.contains('clean')) {
      return _serviceStarterDefaults(
        enabledBuiltInKeys: const <String>{},
        customExtras: <VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_oven_clean',
            label: 'Oven clean',
            defaultPrice: 40,
          ),
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_deep_clean',
            label: 'Deep clean',
            defaultPrice: 50,
          ),
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_extra_room',
            label: 'Extra room',
            defaultPrice: 15,
          ),
        ],
      );
    }
    if (normalized.contains('man') && normalized.contains('van') ||
        normalized.contains('removal') ||
        normalized.contains('move')) {
      return _serviceStarterDefaults(
        enabledBuiltInKeys: const <String>{
          kVanQuoteExtraHelperKey,
          kVanQuoteExtraStairsKey,
          kVanQuoteExtraMileageKey,
        },
        customExtras: <VanQuoteExtraDefault>[
          VanQuoteExtraDefault.custom(
            key: 'custom_extra_second_van',
            label: 'Second van',
            defaultPrice: 50,
          ),
        ],
      );
    }
    return VanQuoteExtraDefaults.empty();
  }

  factory VanQuoteExtraDefaults.fromJson(
    Map<String, dynamic> json, {
    Set<String>? legacyIncludedBuiltInKeys,
  }) {
    final fallback = VanQuoteExtraDefaults.defaults();
    final rawExtras = json['extras'];
    final source = rawExtras is Map ? rawExtras : json;
    final extras = <String, VanQuoteExtraDefault>{};

    for (final key in kVanQuoteExtraDefaultOrder) {
      final value = source[key];
      if (value is Map) {
        extras[key] = VanQuoteExtraDefault.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
      } else {
        extras[key] = fallback.extraForKey(key);
      }
    }

    final customExtras = _customExtrasFromJson(json, source);
    final explicitIncludedBuiltIns = _includedBuiltInKeysFromJson(json, source);
    final includedBuiltIns =
        explicitIncludedBuiltIns ??
        (legacyIncludedBuiltInKeys == null
            ? kVanQuoteExtraDefaultOrder.toSet()
            : _migrateLegacyIncludedBuiltIns(
                source,
                templateKeys: legacyIncludedBuiltInKeys,
              ));
    return VanQuoteExtraDefaults(
      extras: extras,
      customExtras: customExtras,
      extraOrder: _extraOrderFromJson(json, source),
      deletedBuiltInKeys: _deletedBuiltInKeysFromJson(json, source),
      includedBuiltInKeys: includedBuiltIns,
    );
  }

  final Map<String, VanQuoteExtraDefault> extras;
  final List<VanQuoteExtraDefault> customExtras;
  final List<String> extraOrder;
  final Set<String> deletedBuiltInKeys;
  final Set<String> includedBuiltInKeys;

  VanQuoteExtraDefault extraForKey(String key) {
    final normalized = key.trim().toLowerCase();
    for (final extra in customExtras) {
      if (extra.key.trim().toLowerCase() == normalized) {
        return extra;
      }
    }
    return extras[normalized] ?? VanQuoteExtraDefault.fallback(normalized);
  }

  bool isBuiltInExtraDeleted(String key) {
    return deletedBuiltInKeys.contains(_normalizeVanQuoteExtraKey(key));
  }

  List<VanQuoteExtraDefault> get orderedExtras {
    return <VanQuoteExtraDefault>[
      for (final key in _normalizedExtraOrder(
        extraOrder,
        customExtras: customExtras,
        deletedBuiltInKeys: deletedBuiltInKeys,
        includedBuiltInKeys: includedBuiltInKeys,
      ))
        extraForKey(key),
    ];
  }

  List<VanQuoteExtraDefault> get enabledExtras {
    return orderedExtras.where((extra) => extra.enabled).toList();
  }

  VanQuoteExtraDefaults copyWithExtra(VanQuoteExtraDefault extra) {
    if (isVanQuoteCustomExtraKey(extra.key) &&
        !kVanQuoteExtraDefaultOrder.contains(extra.key)) {
      final normalized = normalizeVanQuoteCustomExtra(
        extra,
        fallbackIndex: customExtras.length,
      );
      final updatedCustomExtras = <VanQuoteExtraDefault>[];
      var replaced = false;
      for (final existing in customExtras) {
        if (existing.key == normalized.key) {
          updatedCustomExtras.add(normalized);
          replaced = true;
        } else {
          updatedCustomExtras.add(existing);
        }
      }
      if (!replaced) {
        updatedCustomExtras.add(normalized);
      }
      return copyWithCustomExtras(updatedCustomExtras);
    }

    final normalizedKey = _normalizeVanQuoteExtraKey(extra.key);
    final updatedDeletedKeys = <String>{...deletedBuiltInKeys}
      ..remove(normalizedKey);
    final updatedIncludedKeys = <String>{...includedBuiltInKeys}
      ..add(normalizedKey);
    final updatedExtras = <String, VanQuoteExtraDefault>{
      ...extras,
      normalizedKey: VanQuoteExtraDefault(
        key: normalizedKey,
        label: extra.label,
        defaultPrice: extra.defaultPrice,
        enabled: extra.enabled,
      ),
    };
    return VanQuoteExtraDefaults(
      extras: updatedExtras,
      customExtras: customExtras,
      extraOrder: _normalizedExtraOrder(
        extraOrder,
        customExtras: customExtras,
        deletedBuiltInKeys: updatedDeletedKeys,
        includedBuiltInKeys: updatedIncludedKeys,
      ),
      deletedBuiltInKeys: updatedDeletedKeys,
      includedBuiltInKeys: updatedIncludedKeys,
    );
  }

  VanQuoteExtraDefaults copyWithCustomExtras(
    List<VanQuoteExtraDefault> updatedCustomExtras,
  ) {
    final normalizedCustomExtras = normalizeVanQuoteCustomExtras(
      updatedCustomExtras,
    );
    return VanQuoteExtraDefaults(
      extras: extras,
      customExtras: normalizedCustomExtras,
      extraOrder: _normalizedExtraOrder(
        extraOrder,
        customExtras: normalizedCustomExtras,
        deletedBuiltInKeys: deletedBuiltInKeys,
        includedBuiltInKeys: includedBuiltInKeys,
      ),
      deletedBuiltInKeys: deletedBuiltInKeys,
      includedBuiltInKeys: includedBuiltInKeys,
    );
  }

  VanQuoteExtraDefaults copyWithOrder(List<String> updatedOrder) {
    return VanQuoteExtraDefaults(
      extras: extras,
      customExtras: customExtras,
      extraOrder: _normalizedExtraOrder(
        updatedOrder,
        customExtras: customExtras,
        deletedBuiltInKeys: deletedBuiltInKeys,
        includedBuiltInKeys: includedBuiltInKeys,
      ),
      deletedBuiltInKeys: deletedBuiltInKeys,
      includedBuiltInKeys: includedBuiltInKeys,
    );
  }

  VanQuoteExtraDefaults deleteBuiltInExtra(String key) {
    final normalizedKey = _normalizeVanQuoteExtraKey(key);
    if (!isVanQuoteBuiltInExtraKey(normalizedKey)) {
      return this;
    }
    final updatedDeletedKeys = <String>{...deletedBuiltInKeys}
      ..add(normalizedKey);
    final currentOrder = orderedExtras
        .map((extra) => extra.key)
        .where((extraKey) => extraKey != normalizedKey)
        .toList(growable: false);
    return VanQuoteExtraDefaults(
      extras: extras,
      customExtras: customExtras,
      extraOrder: _normalizedExtraOrder(
        currentOrder,
        customExtras: customExtras,
        deletedBuiltInKeys: updatedDeletedKeys,
        includedBuiltInKeys: includedBuiltInKeys,
      ),
      deletedBuiltInKeys: updatedDeletedKeys,
      includedBuiltInKeys: includedBuiltInKeys,
    );
  }

  VanQuoteExtraDefaults resetBuiltInDefaults() {
    return VanQuoteExtraDefaults(
      extras: <String, VanQuoteExtraDefault>{
        for (final key in kVanQuoteExtraDefaultOrder)
          key: VanQuoteExtraDefault.fallback(key),
      },
      customExtras: customExtras,
      extraOrder: _normalizedExtraOrder(
        <String>[
          ...kVanQuoteExtraDefaultOrder,
          for (final extra in orderedExtras)
            if (!isVanQuoteBuiltInExtraKey(extra.key)) extra.key,
        ],
        customExtras: customExtras,
        deletedBuiltInKeys: const <String>{},
        includedBuiltInKeys: kVanQuoteExtraDefaultOrder.toSet(),
      ),
      deletedBuiltInKeys: const <String>{},
      includedBuiltInKeys: kVanQuoteExtraDefaultOrder.toSet(),
    );
  }

  VanQuoteExtraDefaults resetToStarter(VanQuoteExtraDefaults starter) {
    final starterCustomKeys = starter.customExtras
        .map((extra) => extra.key)
        .toSet();
    final userCustomExtras = customExtras
        .where((extra) => !starterCustomKeys.contains(extra.key))
        .toList(growable: false);
    return VanQuoteExtraDefaults(
      extras: starter.extras,
      customExtras: <VanQuoteExtraDefault>[
        ...starter.customExtras,
        ...userCustomExtras,
      ],
      extraOrder: <String>[
        ...starter.orderedExtras.map((extra) => extra.key),
        ...userCustomExtras.map((extra) => extra.key),
      ],
      includedBuiltInKeys: starter.includedBuiltInKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'extras': <String, dynamic>{
        for (final key in kVanQuoteExtraDefaultOrder)
          if (includedBuiltInKeys.contains(key)) key: extraForKey(key).toJson(),
      },
      'customExtras': <Map<String, dynamic>>[
        for (final extra in normalizeVanQuoteCustomExtras(customExtras))
          extra.toJson(),
      ],
      'extraOrder': <String>[for (final extra in orderedExtras) extra.key],
      'deletedBuiltInKeys': <String>[
        for (final key in kVanQuoteExtraDefaultOrder)
          if (deletedBuiltInKeys.contains(key)) key,
      ],
      'includedBuiltInKeys': <String>[
        for (final key in kVanQuoteExtraDefaultOrder)
          if (includedBuiltInKeys.contains(key)) key,
      ],
    };
  }
}

VanQuoteExtraDefaults _serviceStarterDefaults({
  required Set<String> enabledBuiltInKeys,
  required List<VanQuoteExtraDefault> customExtras,
}) {
  var defaults = VanQuoteExtraDefaults.empty();
  for (final key in enabledBuiltInKeys) {
    defaults = defaults.copyWithExtra(VanQuoteExtraDefault.fallback(key));
  }
  return defaults.copyWithCustomExtras(customExtras);
}

List<VanQuoteExtraDefault> _customExtrasFromJson(
  Map<String, dynamic> json,
  Map<dynamic, dynamic> source,
) {
  final customExtras = <VanQuoteExtraDefault>[];
  final rawCustomExtras =
      json['customExtras'] ??
      json['custom_extras'] ??
      source['customExtras'] ??
      source['custom_extras'];

  if (rawCustomExtras is List) {
    for (var index = 0; index < rawCustomExtras.length; index++) {
      final item = rawCustomExtras[index];
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      final label = map['label']?.toString().trim() ?? '';
      if (label.isEmpty) {
        continue;
      }
      final rawKey =
          map['key']?.toString().trim() ?? map['id']?.toString().trim() ?? '';
      customExtras.add(
        VanQuoteExtraDefault.custom(
          key: rawKey.isEmpty
              ? buildVanQuoteCustomExtraKey(label: label, index: index)
              : rawKey,
          label: label,
          defaultPrice: _jsonPrice(
            map['defaultPrice'] ?? map['price'] ?? map['amount'],
            0,
          ),
          enabled: _jsonEnabled(map['enabled'], fallback: true),
        ),
      );
    }
  }

  final legacyCustom = _legacyCustomExtraFromJson(source);
  if (legacyCustom != null &&
      !customExtras.any(
        (extra) =>
            extra.key == legacyCustom.key ||
            extra.resolvedLabel.trim().toLowerCase() ==
                legacyCustom.resolvedLabel.trim().toLowerCase(),
      )) {
    customExtras.add(legacyCustom);
  }

  return normalizeVanQuoteCustomExtras(customExtras);
}

List<String> _extraOrderFromJson(
  Map<String, dynamic> json,
  Map<dynamic, dynamic> source,
) {
  return _stringListFromJson(
    json['extraOrder'] ??
        json['extra_order'] ??
        json['quoteExtraOrder'] ??
        json['quote_extra_order'] ??
        source['extraOrder'] ??
        source['extra_order'] ??
        source['quoteExtraOrder'] ??
        source['quote_extra_order'],
  );
}

Set<String> _deletedBuiltInKeysFromJson(
  Map<String, dynamic> json,
  Map<dynamic, dynamic> source,
) {
  return _stringListFromJson(
    json['deletedBuiltInKeys'] ??
        json['deletedBuiltIns'] ??
        json['deletedExtraKeys'] ??
        json['deleted_built_in_keys'] ??
        json['deleted_built_ins'] ??
        source['deletedBuiltInKeys'] ??
        source['deletedBuiltIns'] ??
        source['deletedExtraKeys'] ??
        source['deleted_built_in_keys'] ??
        source['deleted_built_ins'],
  ).where(isVanQuoteBuiltInExtraKey).toSet();
}

Set<String>? _includedBuiltInKeysFromJson(
  Map<String, dynamic> json,
  Map<dynamic, dynamic> source,
) {
  final raw =
      json['includedBuiltInKeys'] ??
      json['included_built_in_keys'] ??
      source['includedBuiltInKeys'] ??
      source['included_built_in_keys'];
  if (raw == null) {
    return null;
  }
  return _stringListFromJson(raw).where(isVanQuoteBuiltInExtraKey).toSet();
}

Set<String> _migrateLegacyIncludedBuiltIns(
  Map<dynamic, dynamic> source, {
  required Set<String> templateKeys,
}) {
  final included = <String>{...templateKeys.where(isVanQuoteBuiltInExtraKey)};
  for (final key in kVanQuoteExtraDefaultOrder) {
    if (included.contains(key)) {
      continue;
    }
    final raw = source[key];
    if (raw is! Map) {
      continue;
    }
    final saved = VanQuoteExtraDefault.fromJson(
      key,
      Map<String, dynamic>.from(raw),
    );
    final fallback = VanQuoteExtraDefault.fallback(key);
    final labelWasEdited =
        saved.resolvedLabel.trim() != fallback.resolvedLabel.trim();
    final priceWasEdited = saved.defaultPrice != fallback.defaultPrice;
    if (labelWasEdited || priceWasEdited) {
      included.add(key);
    }
  }
  return included;
}

List<String> _stringListFromJson(Object? value) {
  if (value is Iterable) {
    return <String>[
      for (final item in value)
        if (item.toString().trim().isNotEmpty)
          _normalizeVanQuoteExtraKey(item.toString()),
    ];
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return const <String>[];
  }
  return raw
      .split(',')
      .map(_normalizeVanQuoteExtraKey)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _normalizedExtraOrder(
  Iterable<String> requestedOrder, {
  required Iterable<VanQuoteExtraDefault> customExtras,
  required Set<String> deletedBuiltInKeys,
  required Set<String> includedBuiltInKeys,
}) {
  final customKeys = <String>{
    for (final extra in customExtras) _normalizeVanQuoteExtraKey(extra.key),
  };
  final ordered = <String>[];
  final seen = <String>{};

  void addIfActive(String rawKey) {
    final key = _normalizeVanQuoteExtraKey(rawKey);
    if (key.isEmpty || seen.contains(key)) {
      return;
    }
    if (isVanQuoteBuiltInExtraKey(key)) {
      if (deletedBuiltInKeys.contains(key) ||
          !includedBuiltInKeys.contains(key)) {
        return;
      }
      ordered.add(key);
      seen.add(key);
      return;
    }
    if (customKeys.contains(key)) {
      ordered.add(key);
      seen.add(key);
    }
  }

  for (final key in requestedOrder) {
    addIfActive(key);
  }
  for (final key in includedBuiltInKeys) {
    addIfActive(key);
  }
  for (final key in customKeys) {
    addIfActive(key);
  }
  return ordered;
}

VanQuoteExtraDefault? _legacyCustomExtraFromJson(Map<dynamic, dynamic> source) {
  Object? firstPresent(List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return source[key];
      }
    }
    return null;
  }

  final rawCustomMap =
      source[kVanQuoteExtraCustomKey] ?? source['custom_extra'];
  if (rawCustomMap is Map) {
    final extra = VanQuoteExtraDefault.fromJson(
      kVanQuoteExtraCustomKey,
      Map<String, dynamic>.from(rawCustomMap),
    );
    return _shouldKeepLegacyCustomExtra(extra)
        ? VanQuoteExtraDefault.custom(
            key: buildVanQuoteCustomExtraKey(
              label: extra.resolvedLabel,
              index: 0,
            ),
            label: extra.resolvedLabel,
            defaultPrice: extra.defaultPrice,
            enabled: extra.enabled,
          )
        : null;
  }

  final label = firstPresent(<String>[
    'customLabel',
    'customExtraLabel',
    'custom_extra_label',
    'customName',
    'customExtraName',
  ])?.toString().trim();
  final hasLegacyLabel = label != null && label.isNotEmpty;
  final price = firstPresent(<String>[
    'customPrice',
    'customExtraPrice',
    'custom_extra_price',
    'customAmount',
    'customExtraAmount',
  ]);
  final enabled = firstPresent(<String>[
    'customEnabled',
    'customExtraEnabled',
    'custom_extra_enabled',
  ]);

  if (!hasLegacyLabel && price == null && enabled == null) {
    return null;
  }

  final resolvedLabel = hasLegacyLabel
      ? label
      : kVanQuoteExtraDefaultLabels[kVanQuoteExtraCustomKey]!;
  final extra = VanQuoteExtraDefault.custom(
    key: buildVanQuoteCustomExtraKey(label: resolvedLabel, index: 0),
    label: resolvedLabel,
    defaultPrice: _jsonPrice(price, 0),
    enabled: _jsonEnabled(enabled, fallback: true),
  );
  return _shouldKeepLegacyCustomExtra(extra) ? extra : null;
}

bool _shouldKeepLegacyCustomExtra(VanQuoteExtraDefault extra) {
  final label = extra.resolvedLabel.trim();
  return label.isNotEmpty &&
      (label != kVanQuoteExtraDefaultLabels[kVanQuoteExtraCustomKey] ||
          extra.defaultPrice > 0);
}

double _jsonPrice(Object? value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  final cleaned = value?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
  if (cleaned == null || cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
    return fallback;
  }
  return double.tryParse(cleaned) ?? fallback;
}

bool _jsonEnabled(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  return fallback;
}

bool isVanQuoteCustomExtraKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == kVanQuoteExtraCustomKey ||
      normalized.startsWith(kVanQuoteCustomExtraKeyPrefix);
}

bool isVanQuoteBuiltInExtraKey(String key) {
  return kVanQuoteExtraDefaultOrder.contains(_normalizeVanQuoteExtraKey(key));
}

String _normalizeVanQuoteExtraKey(String key) => key.trim().toLowerCase();

String normalizeVanQuoteCustomExtraKey(String key, {required String label}) {
  final normalized = key
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (normalized.startsWith(kVanQuoteCustomExtraKeyPrefix) &&
      normalized.length > kVanQuoteCustomExtraKeyPrefix.length) {
    return normalized;
  }
  return buildVanQuoteCustomExtraKey(label: label, index: 0);
}

String buildVanQuoteCustomExtraKey({
  required String label,
  required int index,
}) {
  final slug = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final suffix = slug.isEmpty ? 'item_${index + 1}' : slug;
  return '$kVanQuoteCustomExtraKeyPrefix$suffix';
}

List<VanQuoteExtraDefault> normalizeVanQuoteCustomExtras(
  Iterable<VanQuoteExtraDefault> extras,
) {
  final normalized = <VanQuoteExtraDefault>[];
  final usedKeys = <String>{};
  var index = 0;
  for (final extra in extras) {
    final label = _cleanLabel(extra.resolvedLabel);
    if (label.isEmpty) {
      continue;
    }
    var key = normalizeVanQuoteCustomExtraKey(extra.key, label: label);
    if (usedKeys.contains(key)) {
      key = '${key}_${index + 1}';
    }
    usedKeys.add(key);
    normalized.add(
      VanQuoteExtraDefault.custom(
        key: key,
        label: label,
        defaultPrice: extra.defaultPrice,
        enabled: extra.enabled,
      ),
    );
    index++;
  }
  return normalized;
}

VanQuoteExtraDefault normalizeVanQuoteCustomExtra(
  VanQuoteExtraDefault extra, {
  required int fallbackIndex,
}) {
  final normalized = normalizeVanQuoteCustomExtras(<VanQuoteExtraDefault>[
    extra.key.trim().isEmpty || extra.key == kVanQuoteExtraCustomKey
        ? VanQuoteExtraDefault.custom(
            key: buildVanQuoteCustomExtraKey(
              label: extra.resolvedLabel,
              index: fallbackIndex,
            ),
            label: extra.resolvedLabel,
            defaultPrice: extra.defaultPrice,
            enabled: extra.enabled,
          )
        : extra,
  ]);
  return normalized.isEmpty
      ? VanQuoteExtraDefault.custom(
          key: buildVanQuoteCustomExtraKey(label: 'custom extra', index: 0),
          label: 'Custom extra',
          defaultPrice: 0,
        )
      : normalized.first;
}

@immutable
class VanQuoteExtraSelection {
  const VanQuoteExtraSelection({
    required this.key,
    required this.label,
    required this.amount,
    this.quantity,
    this.rate,
    this.unitLabel,
  });

  final String key;
  final String label;
  final double amount;
  final double? quantity;
  final double? rate;
  final String? unitLabel;

  String get chipLabel => '${_cleanLabel(label)} ${_formatMoney(amount)}';

  String get quoteExtraLabel {
    final quantityValue = quantity;
    final rateValue = rate;
    final unit = unitLabel?.trim() ?? '';
    if (quantityValue != null && rateValue != null && unit.isNotEmpty) {
      final quantityUnit = unit == 'h' ? 'h' : ' $unit';
      final rateUnit = unit == 'h' ? 'hr' : 'mile';
      return '${_cleanLabel(label)} - ${_formatQuantity(quantityValue)}$quantityUnit x ${_formatMoney(rateValue)}/$rateUnit = ${_formatMoney(amount)}';
    }
    return '${_cleanLabel(label)} - ${_formatMoney(amount)}';
  }

  VanQuoteExtraSelection copyWith({
    String? label,
    double? amount,
    double? quantity,
    double? rate,
    String? unitLabel,
  }) {
    return VanQuoteExtraSelection(
      key: key,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      unitLabel: unitLabel ?? this.unitLabel,
    );
  }
}

@immutable
class VanQuoteExtraSelections {
  const VanQuoteExtraSelections({required this.items});

  factory VanQuoteExtraSelections.empty() {
    return const VanQuoteExtraSelections(
      items: <String, VanQuoteExtraSelection>{},
    );
  }

  final Map<String, VanQuoteExtraSelection> items;

  bool get isEmpty => items.isEmpty;

  double get total {
    return items.values.fold<double>(0, (sum, item) => sum + item.amount);
  }

  VanQuoteExtraSelection? selectionForKey(String key) => items[key];

  VanQuoteExtraSelections toggleFixed(VanQuoteExtraDefault extra) {
    if (items.containsKey(extra.key)) {
      return remove(extra.key);
    }
    return upsert(
      VanQuoteExtraSelection(
        key: extra.key,
        label: extra.resolvedLabel,
        amount: _nonNegative(extra.defaultPrice),
      ),
    );
  }

  VanQuoteExtraSelections applyQuantity({
    required VanQuoteExtraDefault extra,
    required double quantity,
  }) {
    if (quantity <= 0) {
      return remove(extra.key);
    }
    final rate = _nonNegative(extra.defaultPrice);
    final unitLabel = extra.key == kVanQuoteExtraWaitingTimeKey ? 'h' : 'miles';
    return upsert(
      VanQuoteExtraSelection(
        key: extra.key,
        label: extra.resolvedLabel,
        amount: quantity * rate,
        quantity: quantity,
        rate: rate,
        unitLabel: unitLabel,
      ),
    );
  }

  VanQuoteExtraSelections applyCustom({
    required VanQuoteExtraDefault extra,
    required String label,
    required double price,
  }) {
    if (price <= 0) {
      return remove(extra.key);
    }
    final cleanedLabel = _cleanLabel(label).isEmpty
        ? extra.resolvedLabel
        : _cleanLabel(label);
    return upsert(
      VanQuoteExtraSelection(
        key: extra.key,
        label: cleanedLabel,
        amount: price,
      ),
    );
  }

  VanQuoteExtraSelections upsert(VanQuoteExtraSelection selection) {
    return VanQuoteExtraSelections(
      items: <String, VanQuoteExtraSelection>{
        ...items,
        selection.key: selection,
      },
    );
  }

  VanQuoteExtraSelections remove(String key) {
    final updated = <String, VanQuoteExtraSelection>{...items}..remove(key);
    return VanQuoteExtraSelections(items: updated);
  }

  List<String> get quoteExtras {
    final orderedItems = <VanQuoteExtraSelection>[
      for (final key in kVanQuoteExtraDefaultOrder)
        if (items.containsKey(key)) items[key]!,
      for (final item in items.values)
        if (!kVanQuoteExtraDefaultOrder.contains(item.key)) item,
    ];
    return <String>[for (final item in orderedItems) item.quoteExtraLabel];
  }
}

bool isQuantityVanQuoteExtraKey(String key) {
  return key == kVanQuoteExtraWaitingTimeKey || key == kVanQuoteExtraMileageKey;
}

double _nonNegative(double value) => value < 0 ? 0 : value;

String _cleanLabel(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _formatMoney(double value) => '£${value.toStringAsFixed(2)}';

String _formatQuantity(double value) {
  final asFixed = value.toStringAsFixed(2);
  return asFixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
