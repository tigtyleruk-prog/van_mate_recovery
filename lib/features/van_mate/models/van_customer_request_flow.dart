enum VanCustomerRequestType {
  quoteRequest,
  bookingRequest,
  orderRequest,
  dropOffPickupRequest,
  pickupDeliveryRequest,
}

enum VanServiceFlow { standard, pickupDelivery, dropOffPickup }

const List<VanServiceFlow> kVanServiceFlows = VanServiceFlow.values;

extension VanServiceFlowX on VanServiceFlow {
  String get storageKey => switch (this) {
    VanServiceFlow.standard => 'standard',
    VanServiceFlow.pickupDelivery => 'pickupDelivery',
    VanServiceFlow.dropOffPickup => 'dropOffPickup',
  };

  String get label => switch (this) {
    VanServiceFlow.standard => 'Standard service',
    VanServiceFlow.pickupDelivery => 'Pickup / delivery',
    VanServiceFlow.dropOffPickup => 'Drop-off / pick-up',
  };

  String get description => switch (this) {
    VanServiceFlow.standard =>
      'For services carried out at one location without a handover journey.',
    VanServiceFlow.pickupDelivery =>
      'For services that collect from one address and deliver to another.',
    VanServiceFlow.dropOffPickup =>
      'For services where an item or pet is dropped off and collected later.',
  };

  VanCustomerRequestType get requestType => switch (this) {
    VanServiceFlow.standard => VanCustomerRequestType.quoteRequest,
    VanServiceFlow.pickupDelivery =>
      VanCustomerRequestType.pickupDeliveryRequest,
    VanServiceFlow.dropOffPickup => VanCustomerRequestType.dropOffPickupRequest,
  };
}

VanServiceFlow vanServiceFlowFromStorage(
  Object? value, {
  VanCustomerRequestType legacyRequestType =
      VanCustomerRequestType.quoteRequest,
}) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'pickupdelivery' ||
    'pickupdeliveryrequest' => VanServiceFlow.pickupDelivery,
    'dropoffpickup' || 'dropoffpickuprequest' => VanServiceFlow.dropOffPickup,
    'standard' => VanServiceFlow.standard,
    _ => legacyRequestType.serviceFlow,
  };
}

class VanCustomerRequestFlowOptions {
  const VanCustomerRequestFlowOptions({
    required this.showFulfilmentChoice,
    required this.askPreferredDate,
    required this.askPreferredTime,
    required this.showPickupAddress,
    required this.showDeliveryAddress,
    required this.showDropOffDate,
    required this.showDropOffTime,
    required this.showPickUpDate,
    required this.showPickUpTime,
    required this.showNotes,
  });

  final bool showFulfilmentChoice;
  final bool askPreferredDate;
  final bool askPreferredTime;
  final bool showPickupAddress;
  final bool showDeliveryAddress;
  final bool showDropOffDate;
  final bool showDropOffTime;
  final bool showPickUpDate;
  final bool showPickUpTime;
  final bool showNotes;

  factory VanCustomerRequestFlowOptions.defaultsFor(
    VanCustomerRequestType requestType,
  ) {
    final serviceFlow = requestType.serviceFlow;
    return VanCustomerRequestFlowOptions(
      showFulfilmentChoice: false,
      askPreferredDate: serviceFlow != VanServiceFlow.dropOffPickup,
      askPreferredTime: serviceFlow != VanServiceFlow.dropOffPickup,
      showPickupAddress: serviceFlow == VanServiceFlow.pickupDelivery,
      showDeliveryAddress: serviceFlow == VanServiceFlow.pickupDelivery,
      showDropOffDate: serviceFlow == VanServiceFlow.dropOffPickup,
      showDropOffTime: serviceFlow == VanServiceFlow.dropOffPickup,
      showPickUpDate: serviceFlow == VanServiceFlow.dropOffPickup,
      showPickUpTime: serviceFlow == VanServiceFlow.dropOffPickup,
      showNotes: true,
    );
  }

  VanCustomerRequestFlowOptions copyWith({
    bool? showFulfilmentChoice,
    bool? askPreferredDate,
    bool? askPreferredTime,
    bool? showPickupAddress,
    bool? showDeliveryAddress,
    bool? showDropOffDate,
    bool? showDropOffTime,
    bool? showPickUpDate,
    bool? showPickUpTime,
    bool? showNotes,
  }) {
    return VanCustomerRequestFlowOptions(
      showFulfilmentChoice: showFulfilmentChoice ?? this.showFulfilmentChoice,
      askPreferredDate: askPreferredDate ?? this.askPreferredDate,
      askPreferredTime: askPreferredTime ?? this.askPreferredTime,
      showPickupAddress: showPickupAddress ?? this.showPickupAddress,
      showDeliveryAddress: showDeliveryAddress ?? this.showDeliveryAddress,
      showDropOffDate: showDropOffDate ?? this.showDropOffDate,
      showDropOffTime: showDropOffTime ?? this.showDropOffTime,
      showPickUpDate: showPickUpDate ?? this.showPickUpDate,
      showPickUpTime: showPickUpTime ?? this.showPickUpTime,
      showNotes: showNotes ?? this.showNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'showFulfilmentChoice': showFulfilmentChoice,
      'askPreferredDate': askPreferredDate,
      'askPreferredTime': askPreferredTime,
      'showPickupAddress': showPickupAddress,
      'showDeliveryAddress': showDeliveryAddress,
      'showDropOffDate': showDropOffDate,
      'showDropOffTime': showDropOffTime,
      'showPickUpDate': showPickUpDate,
      'showPickUpTime': showPickUpTime,
      'showNotes': showNotes,
    };
  }

  factory VanCustomerRequestFlowOptions.fromJson(
    Object? value, {
    required VanCustomerRequestType requestType,
  }) {
    final fallback = VanCustomerRequestFlowOptions.defaultsFor(requestType);
    if (value is! Map) {
      return fallback;
    }
    final json = Map<String, dynamic>.from(value);
    bool readBool(String key, bool defaultValue) {
      final raw = json[key];
      return raw is bool ? raw : defaultValue;
    }

    return VanCustomerRequestFlowOptions(
      showFulfilmentChoice: readBool(
        'showFulfilmentChoice',
        fallback.showFulfilmentChoice,
      ),
      askPreferredDate: readBool('askPreferredDate', fallback.askPreferredDate),
      askPreferredTime: readBool('askPreferredTime', fallback.askPreferredTime),
      showPickupAddress: readBool(
        'showPickupAddress',
        fallback.showPickupAddress,
      ),
      showDeliveryAddress: readBool(
        'showDeliveryAddress',
        fallback.showDeliveryAddress,
      ),
      showDropOffDate: readBool('showDropOffDate', fallback.showDropOffDate),
      showDropOffTime: readBool('showDropOffTime', fallback.showDropOffTime),
      showPickUpDate: readBool('showPickUpDate', fallback.showPickUpDate),
      showPickUpTime: readBool('showPickUpTime', fallback.showPickUpTime),
      showNotes: readBool('showNotes', fallback.showNotes),
    );
  }
}

extension VanCustomerRequestTypeX on VanCustomerRequestType {
  VanServiceFlow get serviceFlow => switch (this) {
    VanCustomerRequestType.pickupDeliveryRequest =>
      VanServiceFlow.pickupDelivery,
    VanCustomerRequestType.dropOffPickupRequest => VanServiceFlow.dropOffPickup,
    VanCustomerRequestType.quoteRequest ||
    VanCustomerRequestType.bookingRequest ||
    VanCustomerRequestType.orderRequest => VanServiceFlow.standard,
  };

  String get storageKey => switch (this) {
    VanCustomerRequestType.quoteRequest => 'quoteRequest',
    VanCustomerRequestType.bookingRequest => 'bookingRequest',
    VanCustomerRequestType.orderRequest => 'orderRequest',
    VanCustomerRequestType.dropOffPickupRequest => 'dropOffPickupRequest',
    VanCustomerRequestType.pickupDeliveryRequest => 'pickupDeliveryRequest',
  };
}

VanServiceFlow defaultVanServiceFlowForService({
  required String serviceId,
  required String serviceName,
}) => defaultVanCustomerRequestTypeForService(
  serviceId: serviceId,
  serviceName: serviceName,
).serviceFlow;

VanCustomerRequestType vanCustomerRequestTypeFromStorage(
  Object? value, {
  VanCustomerRequestType fallback = VanCustomerRequestType.quoteRequest,
}) {
  final normalized = value?.toString().trim() ?? '';
  for (final type in VanCustomerRequestType.values) {
    if (type.storageKey == normalized) {
      return type;
    }
  }
  return fallback;
}

VanCustomerRequestType defaultVanCustomerRequestTypeForService({
  required String serviceId,
  required String serviceName,
}) {
  // Names and legacy IDs no longer recreate seeded journey behaviour.
  return VanCustomerRequestType.quoteRequest;
}

bool isVanCustomerRequestBuiltInQuestion(
  VanCustomerRequestType requestType,
  String questionText,
) {
  final text = questionText
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) {
    return false;
  }
  if (text == 'preferred date' ||
      text == 'preferred time' ||
      text == 'preferred date time') {
    return true;
  }
  return switch (requestType.serviceFlow) {
    VanServiceFlow.pickupDelivery =>
      text == 'collection address' ||
          text == 'pickup address' ||
          text == 'delivery address',
    VanServiceFlow.dropOffPickup =>
      text == 'drop off date' ||
          text == 'drop off time' ||
          text == 'pick up date' ||
          text == 'pick up time' ||
          text == 'event date' ||
          text == 'event time' ||
          text == 'location',
    VanServiceFlow.standard => false,
  };
}
