import 'van_customer_request_flow.dart';

enum VanCustomerJourneyType { quote, booking, order, preOrder }

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
    'preorder' || 'pre_order' || 'pre-order' => VanCustomerJourneyType.preOrder,
    _ => fallback,
  };
}

extension VanCustomerJourneyTypeX on VanCustomerJourneyType {
  String get storageKey => name;

  String get selectorLabel => switch (this) {
    VanCustomerJourneyType.quote => 'Request a quote',
    VanCustomerJourneyType.booking => 'Make a booking',
    VanCustomerJourneyType.order => 'Place an order',
    VanCustomerJourneyType.preOrder => 'Place a Pre Order',
  };

  String get description => switch (this) {
    VanCustomerJourneyType.quote =>
      'Customers ask for a price before accepting the work.',
    VanCustomerJourneyType.booking =>
      'Customers ask you to confirm a booking for this service.',
    VanCustomerJourneyType.order =>
      'Customers request a custom-made or made-to-order product.',
    VanCustomerJourneyType.preOrder =>
      'Customers place a Pre Order for an existing product to collect or receive.',
  };

  VanCustomerJourneyCopy get copy => switch (this) {
    VanCustomerJourneyType.quote => VanCustomerJourneyCopy.quote,
    VanCustomerJourneyType.booking => VanCustomerJourneyCopy.booking,
    VanCustomerJourneyType.order => VanCustomerJourneyCopy.order,
    VanCustomerJourneyType.preOrder => VanCustomerJourneyCopy.preOrder,
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
    customerAction: 'Request an Order',
    requestNoun: 'Order request',
    submitAction: 'Send order request',
    receivedHeading: 'Order request received',
    businessAction: 'Review order request',
    acceptedLabel: 'Order request confirmed',
    declinedLabel: 'Order request declined',
  );

  static const preOrder = VanCustomerJourneyCopy(
    customerAction: 'Place a Pre Order',
    requestNoun: 'Pre Order',
    submitAction: 'Place Pre Order',
    receivedHeading: 'Pre Order received',
    businessAction: 'Review Pre Order',
    acceptedLabel: 'Pre Order confirmed',
    declinedLabel: 'Pre Order declined',
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
      order => 'Request an order for $service',
      preOrder => 'Place a Pre Order for $service',
      _ => customerAction,
    };
  }

  String get successMessage => switch (this) {
    quote => 'Your quote request has been sent to the business.',
    booking => 'Your booking request has been sent to the business.',
    order => 'Your order has been sent to the business.',
    preOrder => 'Your Pre Order has been sent to the business.',
    _ => 'Your request has been sent to the business.',
  };
}
