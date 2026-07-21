import 'van_customer_request_flow.dart';

enum VanStartHandover { customerDropsOff, businessCollects }

enum VanEndHandover { customerCollects, businessReturns }

extension VanStartHandoverX on VanStartHandover {
  String get storageKey => name;
  String get label => switch (this) {
    VanStartHandover.customerDropsOff => 'Customer drops off',
    VanStartHandover.businessCollects => 'Business collects',
  };
  String get calendarLabel => switch (this) {
    VanStartHandover.customerDropsOff => 'Customer drop-off',
    VanStartHandover.businessCollects => 'Business collection',
  };
  bool get needsCustomerAddress => this == VanStartHandover.businessCollects;
}

extension VanEndHandoverX on VanEndHandover {
  String get storageKey => name;
  String get label => switch (this) {
    VanEndHandover.customerCollects => 'Customer collects',
    VanEndHandover.businessReturns => 'Business returns',
  };
  String get calendarLabel => switch (this) {
    VanEndHandover.customerCollects => 'Customer collection',
    VanEndHandover.businessReturns => 'Business return',
  };
  bool get needsCustomerAddress => this == VanEndHandover.businessReturns;
}

VanStartHandover? tryVanStartHandoverFromStorage(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'customerdropsoff' ||
    'customer_drop_off' ||
    'customerdropoff' => VanStartHandover.customerDropsOff,
    'businesscollects' ||
    'business_collects' ||
    'businesscollection' => VanStartHandover.businessCollects,
    _ => null,
  };
}

VanEndHandover? tryVanEndHandoverFromStorage(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'customercollects' ||
    'customer_collects' ||
    'customercollection' => VanEndHandover.customerCollects,
    'businessreturns' ||
    'business_returns' ||
    'businessreturn' => VanEndHandover.businessReturns,
    _ => null,
  };
}

bool vanRequestTypeSupportsHandover(VanCustomerRequestType requestType) {
  return requestType == VanCustomerRequestType.dropOffPickupRequest ||
      requestType == VanCustomerRequestType.pickupDeliveryRequest;
}

class VanServiceHandoverConfig {
  const VanServiceHandoverConfig({
    required this.start,
    required this.end,
    required this.allowedStarts,
    required this.allowedEnds,
  });

  final VanStartHandover start;
  final VanEndHandover end;
  final List<VanStartHandover> allowedStarts;
  final List<VanEndHandover> allowedEnds;

  bool get customerChoosesStart => allowedStarts.length > 1;
  bool get customerChoosesEnd => allowedEnds.length > 1;

  factory VanServiceHandoverConfig.fromCapabilities({
    required bool allowCustomerDropOff,
    required bool allowBusinessCollection,
    required bool allowCustomerCollection,
    required bool allowBusinessReturn,
    VanStartHandover? preferredStart,
    VanEndHandover? preferredEnd,
  }) {
    final starts = <VanStartHandover>[
      if (allowCustomerDropOff) VanStartHandover.customerDropsOff,
      if (allowBusinessCollection) VanStartHandover.businessCollects,
    ];
    final ends = <VanEndHandover>[
      if (allowCustomerCollection) VanEndHandover.customerCollects,
      if (allowBusinessReturn) VanEndHandover.businessReturns,
    ];
    return VanServiceHandoverConfig(
      start: preferredStart != null && starts.contains(preferredStart)
          ? preferredStart
          : starts.isEmpty
          ? VanStartHandover.customerDropsOff
          : starts.first,
      end: preferredEnd != null && ends.contains(preferredEnd)
          ? preferredEnd
          : ends.isEmpty
          ? VanEndHandover.customerCollects
          : ends.first,
      allowedStarts: List<VanStartHandover>.unmodifiable(starts),
      allowedEnds: List<VanEndHandover>.unmodifiable(ends),
    );
  }

  static VanServiceHandoverConfig resolve({
    required VanCustomerRequestType requestType,
    Object? startValue,
    Object? endValue,
    Object? allowedStartValues,
    Object? allowedEndValues,
    Object? legacyMode,
  }) {
    final normalizedLegacy = legacyMode?.toString().trim().toLowerCase() ?? '';
    final legacyBusinessMoves =
        requestType == VanCustomerRequestType.pickupDeliveryRequest ||
        normalizedLegacy == 'businesscollectreturn' ||
        normalizedLegacy == 'business_collect_return';
    final legacyCustomerChooses =
        normalizedLegacy == 'customerchooses' ||
        normalizedLegacy == 'customer_chooses';
    final fallbackStart = legacyBusinessMoves
        ? VanStartHandover.businessCollects
        : VanStartHandover.customerDropsOff;
    final fallbackEnd = legacyBusinessMoves
        ? VanEndHandover.businessReturns
        : VanEndHandover.customerCollects;
    final start = tryVanStartHandoverFromStorage(startValue) ?? fallbackStart;
    final end = tryVanEndHandoverFromStorage(endValue) ?? fallbackEnd;
    final starts = _readAllowedStarts(allowedStartValues);
    final ends = _readAllowedEnds(allowedEndValues);
    return VanServiceHandoverConfig(
      start: start,
      end: end,
      allowedStarts: starts.isNotEmpty
          ? _withSelected(starts, start)
          : legacyCustomerChooses
          ? VanStartHandover.values
          : <VanStartHandover>[start],
      allowedEnds: ends.isNotEmpty
          ? _withSelected(ends, end)
          : legacyCustomerChooses
          ? VanEndHandover.values
          : <VanEndHandover>[end],
    );
  }

  static List<T> _withSelected<T>(List<T> values, T selected) =>
      List<T>.unmodifiable(<T>{selected, ...values});

  static List<VanStartHandover> _readAllowedStarts(Object? value) {
    if (value is! Iterable) return const <VanStartHandover>[];
    return List<VanStartHandover>.unmodifiable(
      value.map(tryVanStartHandoverFromStorage).whereType<VanStartHandover>(),
    );
  }

  static List<VanEndHandover> _readAllowedEnds(Object? value) {
    if (value is! Iterable) return const <VanEndHandover>[];
    return List<VanEndHandover>.unmodifiable(
      value.map(tryVanEndHandoverFromStorage).whereType<VanEndHandover>(),
    );
  }
}

String vanBusinessHandoverSummary(VanStartHandover start, VanEndHandover end) {
  return switch ((start, end)) {
    (VanStartHandover.customerDropsOff, VanEndHandover.customerCollects) =>
      'Customer drops off and collects',
    (VanStartHandover.customerDropsOff, VanEndHandover.businessReturns) =>
      'Customer drops off; business returns',
    (VanStartHandover.businessCollects, VanEndHandover.customerCollects) =>
      'Business collects; customer collects',
    (VanStartHandover.businessCollects, VanEndHandover.businessReturns) =>
      'Business collects and returns',
  };
}

String vanCustomerHandoverSummary(VanStartHandover start, VanEndHandover end) {
  return switch ((start, end)) {
    (VanStartHandover.customerDropsOff, VanEndHandover.customerCollects) =>
      "You'll drop off your item and collect it when ready.",
    (VanStartHandover.customerDropsOff, VanEndHandover.businessReturns) =>
      "You'll drop off your item. We'll return it when finished.",
    (VanStartHandover.businessCollects, VanEndHandover.customerCollects) =>
      "We'll collect your item. You'll collect it when ready.",
    (VanStartHandover.businessCollects, VanEndHandover.businessReturns) =>
      "We'll collect your item and return it when finished.",
  };
}
