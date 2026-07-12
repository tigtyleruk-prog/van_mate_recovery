enum VanCustomerRequestType {
  quoteRequest,
  bookingRequest,
  orderRequest,
  dropOffPickupRequest,
  pickupDeliveryRequest,
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
    return VanCustomerRequestFlowOptions(
      showFulfilmentChoice: requestType == VanCustomerRequestType.orderRequest,
      askPreferredDate:
          requestType != VanCustomerRequestType.dropOffPickupRequest,
      askPreferredTime:
          requestType != VanCustomerRequestType.dropOffPickupRequest,
      showPickupAddress:
          requestType == VanCustomerRequestType.pickupDeliveryRequest,
      showDeliveryAddress:
          requestType == VanCustomerRequestType.pickupDeliveryRequest,
      showDropOffDate:
          requestType == VanCustomerRequestType.dropOffPickupRequest,
      showDropOffTime:
          requestType == VanCustomerRequestType.dropOffPickupRequest,
      showPickUpDate:
          requestType == VanCustomerRequestType.dropOffPickupRequest,
      showPickUpTime:
          requestType == VanCustomerRequestType.dropOffPickupRequest,
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
  String get storageKey => switch (this) {
    VanCustomerRequestType.quoteRequest => 'quoteRequest',
    VanCustomerRequestType.bookingRequest => 'bookingRequest',
    VanCustomerRequestType.orderRequest => 'orderRequest',
    VanCustomerRequestType.dropOffPickupRequest => 'dropOffPickupRequest',
    VanCustomerRequestType.pickupDeliveryRequest => 'pickupDeliveryRequest',
  };

  String get label => switch (this) {
    VanCustomerRequestType.quoteRequest => 'Quote request',
    VanCustomerRequestType.bookingRequest => 'Booking request',
    VanCustomerRequestType.orderRequest => 'Order request',
    VanCustomerRequestType.dropOffPickupRequest => 'Drop-off / pick-up',
    VanCustomerRequestType.pickupDeliveryRequest => 'Pickup / delivery',
  };

  String get customerActionLabel => switch (this) {
    VanCustomerRequestType.quoteRequest => 'Request a quote',
    VanCustomerRequestType.bookingRequest => 'Request a booking',
    VanCustomerRequestType.orderRequest => 'Place an order',
    VanCustomerRequestType.dropOffPickupRequest => 'Request a booking',
    VanCustomerRequestType.pickupDeliveryRequest => 'Request pickup / delivery',
  };

  String get description => switch (this) {
    VanCustomerRequestType.quoteRequest =>
      'For quote-led work such as removals, gardening, trades and repairs.',
    VanCustomerRequestType.bookingRequest =>
      'For appointments, cleaning and mobile services.',
    VanCustomerRequestType.orderRequest =>
      'For cakes, food, gifts and other made-to-order products.',
    VanCustomerRequestType.dropOffPickupRequest =>
      'For services with separate drop-off and pick-up times.',
    VanCustomerRequestType.pickupDeliveryRequest =>
      'For courier, collection and delivery services.',
  };
}

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
  final value = '${serviceId.trim()} ${serviceName.trim()}'
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ');

  if (_containsAny(value, const <String>[
    'cake',
    'cupcake',
    'bakery',
    'meal prep',
    'farm shop',
    'catering',
    'balloon',
    'florist',
    'gift',
  ])) {
    return VanCustomerRequestType.orderRequest;
  }
  if (_containsAny(value, const <String>[
    'pet sitting',
    'dog sitting',
    'childmind',
    'ironing',
    'alteration',
  ])) {
    return VanCustomerRequestType.dropOffPickupRequest;
  }
  if (_containsAny(value, const <String>[
    'courier',
    'delivery',
    'man van',
    'man & van',
    'removal',
    'transport',
    'store collection',
  ])) {
    return VanCustomerRequestType.pickupDeliveryRequest;
  }
  if (_containsAny(value, const <String>[
    'cleaning',
    'dog walking',
    'hairdresser',
    'beautician',
    'groom',
    'appointment',
  ])) {
    return VanCustomerRequestType.bookingRequest;
  }
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
  return switch (requestType) {
    VanCustomerRequestType.orderRequest =>
      text == 'collection or delivery' || text == 'delivery address',
    VanCustomerRequestType.pickupDeliveryRequest =>
      text == 'collection address' ||
          text == 'pickup address' ||
          text == 'delivery address',
    VanCustomerRequestType.dropOffPickupRequest =>
      text == 'drop off date' ||
          text == 'drop off time' ||
          text == 'pick up date' ||
          text == 'pick up time',
    VanCustomerRequestType.quoteRequest ||
    VanCustomerRequestType.bookingRequest => false,
  };
}

bool _containsAny(String value, List<String> terms) {
  return terms.any(value.contains);
}
