import 'van_customer_journey.dart';
import 'van_customer_request_flow.dart';
import 'van_service_template.dart';

/// Stable, business-agnostic capability identifiers stored on new services.
abstract final class VanServiceCapabilityIds {
  static const booking = 'booking';
  static const appointmentRequired = 'appointment_required';
  static const walkIn = 'walk_in';
  static const preOrder = 'pre_order';
  static const sameDay = 'same_day';
  static const recurring = 'recurring';
  static const oneOff = 'one_off';

  static const placeOrder = 'place_order';
  static const requestQuote = 'request_quote';
  static const bookAppointment = 'book_appointment';

  static const customerVisitsBusiness = 'customer_visits_business';
  static const customerDropsOff = 'customer_drops_off';
  static const customerCollects = 'customer_collects';
  static const businessVisitsCustomer = 'business_visits_customer';
  static const businessCollects = 'business_collects';
  static const businessReturns = 'business_returns';
  static const localDelivery = 'local_delivery';
  static const nationwideDelivery = 'nationwide_delivery';
  static const digitalDelivery = 'digital_delivery';

  static const fixedPrice = 'fixed_price';
  static const fromPrice = 'from_price';
  static const customQuote = 'custom_quote';
  static const depositRequired = 'deposit_required';
  static const payInFull = 'pay_in_full';

  static const estimatedDuration = 'estimated_duration';
  static const preparationTime = 'preparation_time';
  static const leadTime = 'lead_time';

  static const multipleStops = 'multiple_stops';
  static const photoUpload = 'photo_upload';
  static const videoUpload = 'video_upload';
  static const proofOfDelivery = 'proof_of_delivery';
  static const loadingUnloadingHelp = 'loading_unloading_help';
  static const dismantlingReassembly = 'dismantling_reassembly';
  static const packingService = 'packing_service';
  static const siteSurvey = 'site_survey';
  static const teamMembers = 'team_members';
  static const multipleVehicles = 'multiple_vehicles';
}

enum VanServiceCapabilityGroup {
  booking,
  customerJourney,
  fulfilment,
  pricing,
  timing,
  operations,
}

extension VanServiceCapabilityGroupX on VanServiceCapabilityGroup {
  String get label => switch (this) {
    VanServiceCapabilityGroup.booking => 'Booking',
    VanServiceCapabilityGroup.customerJourney => 'Customer journey',
    VanServiceCapabilityGroup.fulfilment => 'Fulfilment',
    VanServiceCapabilityGroup.pricing => 'Pricing',
    VanServiceCapabilityGroup.timing => 'Timing',
    VanServiceCapabilityGroup.operations => 'Service options',
  };
}

class VanServiceCapabilityDefinition {
  const VanServiceCapabilityDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.group,
    this.exclusiveSet,
  });

  final String id;
  final String label;
  final String description;
  final VanServiceCapabilityGroup group;

  /// Selecting one capability removes other selections in the same set.
  final String? exclusiveSet;
}

const List<VanServiceCapabilityDefinition>
kVanServiceCapabilities = <VanServiceCapabilityDefinition>[
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.booking,
    label: 'Booking',
    description: 'Customers can submit a request for this service.',
    group: VanServiceCapabilityGroup.booking,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.appointmentRequired,
    label: 'Appointment required',
    description: 'Collect a preferred date and time.',
    group: VanServiceCapabilityGroup.booking,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.walkIn,
    label: 'Walk-in',
    description: 'Customers can visit without arranging a time.',
    group: VanServiceCapabilityGroup.booking,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.preOrder,
    label: 'Pre-order',
    description: 'Customers order ahead for a later date.',
    group: VanServiceCapabilityGroup.booking,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.sameDay,
    label: 'Same day',
    description: 'The service can be requested for the same day.',
    group: VanServiceCapabilityGroup.booking,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.recurring,
    label: 'Recurring',
    description: 'Customers can request repeat service.',
    group: VanServiceCapabilityGroup.booking,
    exclusiveSet: 'frequency',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.oneOff,
    label: 'One-off',
    description: 'The service is normally requested once.',
    group: VanServiceCapabilityGroup.booking,
    exclusiveSet: 'frequency',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.placeOrder,
    label: 'Place an order',
    description: 'Customers submit an order for confirmation.',
    group: VanServiceCapabilityGroup.customerJourney,
    exclusiveSet: 'journey',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.requestQuote,
    label: 'Request a quote',
    description: 'Customers ask for a price before accepting.',
    group: VanServiceCapabilityGroup.customerJourney,
    exclusiveSet: 'journey',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.bookAppointment,
    label: 'Book appointment',
    description: 'Customers request an appointment for confirmation.',
    group: VanServiceCapabilityGroup.customerJourney,
    exclusiveSet: 'journey',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.customerVisitsBusiness,
    label: 'Customer visits business',
    description: 'The service happens at your premises.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.customerDropsOff,
    label: 'Customer drops off',
    description: 'The customer leaves an item or pet with you.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.customerCollects,
    label: 'Customer collects',
    description: 'The customer collects when the service is complete.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.businessVisitsCustomer,
    label: 'Business visits customer',
    description: 'You carry out the service at the customer location.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.businessCollects,
    label: 'Business collects',
    description: 'You collect an item or pet from the customer.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.businessReturns,
    label: 'Business returns',
    description: 'You return the item or pet after the service.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.localDelivery,
    label: 'Local delivery',
    description: 'Deliver orders within your local area.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.nationwideDelivery,
    label: 'Nationwide delivery',
    description: 'Send orders using a national delivery service.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.digitalDelivery,
    label: 'Digital delivery',
    description: 'Deliver files or access electronically.',
    group: VanServiceCapabilityGroup.fulfilment,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.fixedPrice,
    label: 'Fixed price',
    description: 'The service has a set starting price.',
    group: VanServiceCapabilityGroup.pricing,
    exclusiveSet: 'base_pricing',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.fromPrice,
    label: 'From price',
    description: 'Show a starting price that can vary.',
    group: VanServiceCapabilityGroup.pricing,
    exclusiveSet: 'base_pricing',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.customQuote,
    label: 'Custom quote',
    description: 'Price each customer request individually.',
    group: VanServiceCapabilityGroup.pricing,
    exclusiveSet: 'base_pricing',
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.depositRequired,
    label: 'Deposit required',
    description: 'Recommend a deposit during quoting.',
    group: VanServiceCapabilityGroup.pricing,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.payInFull,
    label: 'Pay in full',
    description: 'Recommend full payment for the service.',
    group: VanServiceCapabilityGroup.pricing,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.estimatedDuration,
    label: 'Estimated duration',
    description: 'Set an expected appointment or job duration.',
    group: VanServiceCapabilityGroup.timing,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.preparationTime,
    label: 'Preparation time',
    description: 'Allow time to prepare an order before fulfilment.',
    group: VanServiceCapabilityGroup.timing,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.leadTime,
    label: 'Lead time',
    description: 'Require advance notice before the service date.',
    group: VanServiceCapabilityGroup.timing,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.multipleStops,
    label: 'Multiple stops',
    description: 'The job can include more than one collection or delivery.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.photoUpload,
    label: 'Photo upload',
    description: 'Customers can attach photos to help plan the job.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.videoUpload,
    label: 'Video upload',
    description: 'Customers can provide a short planning video.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.proofOfDelivery,
    label: 'Proof of delivery',
    description: 'Completion can include delivery evidence.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.loadingUnloadingHelp,
    label: 'Loading and unloading help',
    description: 'Customers can request help at either end of the job.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.dismantlingReassembly,
    label: 'Dismantling and reassembly',
    description: 'Furniture can be dismantled or rebuilt as part of the job.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.packingService,
    label: 'Packing service',
    description: 'Packing can be included in the service.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.siteSurvey,
    label: 'Home or site survey',
    description: 'A survey can be arranged before quoting.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.teamMembers,
    label: 'Team members',
    description: 'The job can be planned for multiple team members.',
    group: VanServiceCapabilityGroup.operations,
  ),
  VanServiceCapabilityDefinition(
    id: VanServiceCapabilityIds.multipleVehicles,
    label: 'Multiple vehicles',
    description: 'The job can require more than one vehicle.',
    group: VanServiceCapabilityGroup.operations,
  ),
];

VanServiceCapabilityDefinition? findVanServiceCapability(String id) {
  final normalized = id.trim();
  for (final capability in kVanServiceCapabilities) {
    if (capability.id == normalized) return capability;
  }
  return null;
}

Set<String> toggleVanServiceCapability(
  Iterable<String> current,
  String capabilityId,
  bool selected,
) {
  final next = current.toSet();
  final definition = findVanServiceCapability(capabilityId);
  if (!selected) {
    next.remove(capabilityId);
    return next;
  }
  final exclusiveSet = definition?.exclusiveSet;
  if (exclusiveSet != null) {
    next.removeWhere(
      (id) => findVanServiceCapability(id)?.exclusiveSet == exclusiveSet,
    );
  }
  next.add(capabilityId);
  return next;
}

class VanResolvedServiceCapabilities {
  const VanResolvedServiceCapabilities({
    required this.capabilityIds,
    required this.journeyType,
    required this.requestType,
    required this.allowCustomerDropOff,
    required this.allowBusinessCollection,
    required this.allowCustomerCollection,
    required this.allowBusinessReturn,
    required this.requireAddress,
    required this.requestPhotos,
    required this.builtInQuestionKeys,
    required this.questions,
    required this.extras,
    required this.suggestedDurationMinutes,
    required this.suggestedNoticeHours,
    required this.suggestedReminderMinutes,
    required this.pricingMode,
  });

  final List<String> capabilityIds;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final bool allowCustomerDropOff;
  final bool allowBusinessCollection;
  final bool allowCustomerCollection;
  final bool allowBusinessReturn;
  final bool requireAddress;
  final bool requestPhotos;
  final Set<String> builtInQuestionKeys;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final List<int> suggestedReminderMinutes;
  final String pricingMode;
}

VanResolvedServiceCapabilities resolveVanServiceCapabilities(
  Iterable<String> selectedCapabilityIds, {
  int? recommendedDurationMinutes,
  int recommendedNoticeHours = 24,
}) {
  final ids = selectedCapabilityIds
      .where((id) => findVanServiceCapability(id) != null)
      .toSet();
  final journey = ids.contains(VanServiceCapabilityIds.requestQuote)
      ? VanCustomerJourneyType.quote
      : ids.contains(VanServiceCapabilityIds.bookAppointment)
      ? VanCustomerJourneyType.booking
      : VanCustomerJourneyType.order;
  final requestType = switch (journey) {
    VanCustomerJourneyType.quote => VanCustomerRequestType.quoteRequest,
    VanCustomerJourneyType.booking => VanCustomerRequestType.bookingRequest,
    VanCustomerJourneyType.order => VanCustomerRequestType.orderRequest,
  };
  // Capabilities describe behaviour only. Questions, customer-detail fields,
  // extras and availability must be explicitly declared by a future verified
  // template or added manually by the user.
  final requireAddress =
      ids.contains(VanServiceCapabilityIds.businessVisitsCustomer) ||
      ids.contains(VanServiceCapabilityIds.businessCollects) ||
      ids.contains(VanServiceCapabilityIds.businessReturns) ||
      ids.contains(VanServiceCapabilityIds.localDelivery) ||
      ids.contains(VanServiceCapabilityIds.nationwideDelivery);

  final appointment = ids.contains(VanServiceCapabilityIds.appointmentRequired);
  final leadTime =
      ids.contains(VanServiceCapabilityIds.leadTime) ||
      ids.contains(VanServiceCapabilityIds.preparationTime);
  final pricingMode = ids.contains(VanServiceCapabilityIds.customQuote)
      ? VanServiceCapabilityIds.customQuote
      : ids.contains(VanServiceCapabilityIds.fromPrice)
      ? VanServiceCapabilityIds.fromPrice
      : VanServiceCapabilityIds.fixedPrice;
  final hasStartHandover =
      ids.contains(VanServiceCapabilityIds.customerDropsOff) ||
      ids.contains(VanServiceCapabilityIds.businessCollects);
  final hasEndHandover =
      ids.contains(VanServiceCapabilityIds.customerCollects) ||
      ids.contains(VanServiceCapabilityIds.businessReturns);
  final hasCompleteHandover = hasStartHandover && hasEndHandover;
  final orderedCapabilityIds = ids.toList(growable: false)..sort();
  return VanResolvedServiceCapabilities(
    capabilityIds: orderedCapabilityIds,
    journeyType: journey,
    requestType: requestType,
    allowCustomerDropOff:
        hasCompleteHandover &&
        ids.contains(VanServiceCapabilityIds.customerDropsOff),
    allowBusinessCollection:
        hasCompleteHandover &&
        ids.contains(VanServiceCapabilityIds.businessCollects),
    allowCustomerCollection:
        hasCompleteHandover &&
        ids.contains(VanServiceCapabilityIds.customerCollects),
    allowBusinessReturn:
        hasCompleteHandover &&
        ids.contains(VanServiceCapabilityIds.businessReturns),
    requireAddress: requireAddress,
    requestPhotos:
        ids.contains(VanServiceCapabilityIds.photoUpload) ||
        ids.contains(VanServiceCapabilityIds.videoUpload),
    builtInQuestionKeys: const <String>{},
    questions: const <VanServiceTemplateQuestion>[],
    extras: const <VanServiceTemplateExtra>[],
    suggestedDurationMinutes:
        recommendedDurationMinutes ?? (appointment ? 60 : 30),
    suggestedNoticeHours: leadTime
        ? recommendedNoticeHours < 48
              ? 48
              : recommendedNoticeHours
        : recommendedNoticeHours,
    suggestedReminderMinutes: const <int>[],
    pricingMode: pricingMode,
  );
}
