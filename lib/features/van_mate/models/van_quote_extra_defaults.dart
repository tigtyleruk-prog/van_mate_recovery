import 'package:flutter/foundation.dart';

const String kVanQuoteExtraHelperKey = 'helper';
const String kVanQuoteExtraWaitingTimeKey = 'waiting_time';
const String kVanQuoteExtraStairsKey = 'stairs';
const String kVanQuoteExtraMileageKey = 'mileage';
const String kVanQuoteExtraCollectionDeliveryKey = 'collection_delivery';
const String kVanQuoteExtraCustomKey = 'custom';

const List<String> kVanQuoteExtraDefaultOrder = <String>[
  kVanQuoteExtraHelperKey,
  kVanQuoteExtraWaitingTimeKey,
  kVanQuoteExtraStairsKey,
  kVanQuoteExtraMileageKey,
  kVanQuoteExtraCollectionDeliveryKey,
  kVanQuoteExtraCustomKey,
];

const Map<String, String> kVanQuoteExtraDefaultLabels = <String, String>{
  kVanQuoteExtraHelperKey: 'Extra helper',
  kVanQuoteExtraWaitingTimeKey: 'Waiting time',
  kVanQuoteExtraStairsKey: 'Stairs / access',
  kVanQuoteExtraMileageKey: 'Mileage',
  kVanQuoteExtraCollectionDeliveryKey: 'Collection / delivery',
  kVanQuoteExtraCustomKey: 'Custom extra',
};

const Map<String, double> kVanQuoteExtraDefaultPrices = <String, double>{
  kVanQuoteExtraHelperKey: 20,
  kVanQuoteExtraWaitingTimeKey: 10,
  kVanQuoteExtraStairsKey: 10,
  kVanQuoteExtraMileageKey: 0,
  kVanQuoteExtraCollectionDeliveryKey: 0,
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
      'label': resolvedLabel,
      'defaultPrice': defaultPrice,
      'enabled': enabled,
    };
  }
}

@immutable
class VanQuoteExtraDefaults {
  const VanQuoteExtraDefaults({required this.extras});

  factory VanQuoteExtraDefaults.defaults() {
    return VanQuoteExtraDefaults(
      extras: <String, VanQuoteExtraDefault>{
        for (final key in kVanQuoteExtraDefaultOrder)
          key: VanQuoteExtraDefault.fallback(key),
      },
    );
  }

  factory VanQuoteExtraDefaults.fromJson(Map<String, dynamic> json) {
    final fallback = VanQuoteExtraDefaults.defaults();
    final rawExtras = json['extras'];
    final source = rawExtras is Map ? rawExtras : json;
    final extras = <String, VanQuoteExtraDefault>{};

    for (final key in kVanQuoteExtraDefaultOrder) {
      final value =
          source[key] ??
          (key == kVanQuoteExtraCustomKey ? source['custom_extra'] : null);
      if (value is Map) {
        extras[key] = VanQuoteExtraDefault.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
      } else if (key == kVanQuoteExtraCustomKey) {
        extras[key] = VanQuoteExtraDefault.fromJson(
          key,
          _legacyCustomExtraJson(source, fallback.extraForKey(key)),
        );
      } else {
        extras[key] = fallback.extraForKey(key);
      }
    }

    return VanQuoteExtraDefaults(extras: extras);
  }

  final Map<String, VanQuoteExtraDefault> extras;

  VanQuoteExtraDefault extraForKey(String key) {
    return extras[key] ?? VanQuoteExtraDefault.fallback(key);
  }

  List<VanQuoteExtraDefault> get orderedExtras {
    return <VanQuoteExtraDefault>[
      for (final key in kVanQuoteExtraDefaultOrder) extraForKey(key),
    ];
  }

  List<VanQuoteExtraDefault> get enabledExtras {
    return orderedExtras
        .where((extra) => extra.enabled)
        .toList(growable: false);
  }

  VanQuoteExtraDefaults copyWithExtra(VanQuoteExtraDefault extra) {
    return VanQuoteExtraDefaults(
      extras: <String, VanQuoteExtraDefault>{...extras, extra.key: extra},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'extras': <String, dynamic>{
        for (final key in kVanQuoteExtraDefaultOrder)
          key: extraForKey(key).toJson(),
      },
    };
  }
}

Map<String, dynamic> _legacyCustomExtraJson(
  Map<dynamic, dynamic> source,
  VanQuoteExtraDefault fallback,
) {
  Object? firstPresent(List<String> keys) {
    for (final key in keys) {
      if (source.containsKey(key)) {
        return source[key];
      }
    }
    return null;
  }

  final label =
      firstPresent(<String>[
        'customLabel',
        'customExtraLabel',
        'custom_extra_label',
        'customName',
        'customExtraName',
      ]) ??
      fallback.label;
  final price =
      firstPresent(<String>[
        'customPrice',
        'customExtraPrice',
        'custom_extra_price',
        'customAmount',
        'customExtraAmount',
      ]) ??
      fallback.defaultPrice;
  final enabled =
      firstPresent(<String>[
        'customEnabled',
        'customExtraEnabled',
        'custom_extra_enabled',
      ]) ??
      fallback.enabled;

  return <String, dynamic>{
    'label': label,
    'defaultPrice': price,
    'enabled': enabled,
  };
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
    return <String>[
      for (final key in kVanQuoteExtraDefaultOrder)
        if (items.containsKey(key)) items[key]!.quoteExtraLabel,
    ];
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
