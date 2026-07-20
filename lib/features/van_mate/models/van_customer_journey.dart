import 'van_customer_request_flow.dart';

enum VanCustomerJourneyType { quote, booking, order }

VanCustomerJourneyType defaultVanCustomerJourneyTypeForService({
  required String serviceId,
  required String serviceName,
}) {
  return switch (defaultVanCustomerRequestTypeForService(
    serviceId: serviceId,
    serviceName: serviceName,
  )) {
    VanCustomerRequestType.bookingRequest => VanCustomerJourneyType.booking,
    VanCustomerRequestType.orderRequest => VanCustomerJourneyType.order,
    VanCustomerRequestType.quoteRequest ||
    VanCustomerRequestType.pickupDeliveryRequest ||
    VanCustomerRequestType.dropOffPickupRequest => VanCustomerJourneyType.quote,
  };
}

VanCustomerJourneyType vanCustomerJourneyTypeFromStorage(
  Object? value, {
  VanCustomerJourneyType fallback = VanCustomerJourneyType.quote,
}) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'quote' => VanCustomerJourneyType.quote,
    'booking' => VanCustomerJourneyType.booking,
    'order' => VanCustomerJourneyType.order,
    _ => fallback,
  };
}

extension VanCustomerJourneyTypeX on VanCustomerJourneyType {
  String get storageKey => name;

  String get selectorLabel => switch (this) {
    VanCustomerJourneyType.quote => 'Request a quote',
    VanCustomerJourneyType.booking => 'Make a booking',
    VanCustomerJourneyType.order => 'Place an order',
  };

  String get description => switch (this) {
    VanCustomerJourneyType.quote =>
      'Customers ask for a price before accepting the work.',
    VanCustomerJourneyType.booking =>
      'Customers ask you to confirm a booking for this service.',
    VanCustomerJourneyType.order =>
      'Customers place an order for this service.',
  };

  VanCustomerJourneyCopy get copy => switch (this) {
    VanCustomerJourneyType.quote => VanCustomerJourneyCopy.quote,
    VanCustomerJourneyType.booking => VanCustomerJourneyCopy.booking,
    VanCustomerJourneyType.order => VanCustomerJourneyCopy.order,
  };
}

class VanCustomerJourneyCopy {
  const VanCustomerJourneyCopy({
    required this.customerAction,
    required this.requestNoun,
    required this.submitAction,
    required this.receivedHeading,
    required this.businessAction,
    required this.acceptedLabel,
    required this.declinedLabel,
  });

  static const quote = VanCustomerJourneyCopy(
    customerAction: 'Request a quote',
    requestNoun: 'Quote request',
    submitAction: 'Request quote',
    receivedHeading: 'Quote request received',
    businessAction: 'Create quote',
    acceptedLabel: 'Quote accepted',
    declinedLabel: 'Quote declined',
  );

  static const booking = VanCustomerJourneyCopy(
    customerAction: 'Make a booking',
    requestNoun: 'Booking request',
    submitAction: 'Request booking',
    receivedHeading: 'Booking request received',
    businessAction: 'Confirm booking',
    acceptedLabel: 'Booking confirmed',
    declinedLabel: 'Booking declined',
  );

  static const order = VanCustomerJourneyCopy(
    customerAction: 'Place an order',
    requestNoun: 'Order request',
    submitAction: 'Place order',
    receivedHeading: 'Order received',
    businessAction: 'Confirm order',
    acceptedLabel: 'Order confirmed',
    declinedLabel: 'Order declined',
  );

  final String customerAction;
  final String requestNoun;
  final String submitAction;
  final String receivedHeading;
  final String businessAction;
  final String acceptedLabel;
  final String declinedLabel;

  String headingForService(String serviceName) {
    final service = serviceName.trim();
    if (service.isEmpty) return customerAction;
    return switch (this) {
      quote => 'Request a quote for $service',
      booking => 'Book $service',
      order => 'Order $service',
      _ => customerAction,
    };
  }

  String get successMessage => switch (this) {
    quote => 'Your quote request has been sent to the business.',
    booking => 'Your booking request has been sent to the business.',
    order => 'Your order has been sent to the business.',
    _ => 'Your request has been sent to the business.',
  };
}
