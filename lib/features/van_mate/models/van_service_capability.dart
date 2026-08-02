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
  static const exactPin = 'exact_pin';
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

class VanCapabilityMovementChoice {
  const VanCapabilityMovementChoice({required this.value, required this.label});

  final String value;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'value': value,
    'label': label,
  };
}

class VanCapabilityMovementChoiceGroup {
  const VanCapabilityMovementChoiceGroup({
    required this.id,
    required this.heading,
    required this.options,
  });

  final String id;
  final String heading;
  final List<VanCapabilityMovementChoice> options;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'heading': heading,
    'options': options.map((option) => option.toJson()).toList(growable: false),
  };
}

/// The resolved, serializable behaviour contract shared by service surfaces.
///
/// This is deliberately a description of behaviour rather than another job
/// model. Legacy services can use the same contract with their journey and
/// request type supplied as fallbacks.
class VanCapabilityContract {
  const VanCapabilityContract({
    required this.capabilityIds,
    required this.journeyType,
    required this.requestType,
    required this.responseDocumentType,
    required this.calendarPresentation,
    required this.movementChoiceGroups,
    required this.movementCapabilityIds,
    required this.recommendedBuiltInQuestionKeys,
    required this.requireAddress,
    required this.addressHeading,
    required this.addressFieldLabel,
    required this.addressHint,
    required this.addressRequiredMessage,
    required this.requestPhotos,
    required this.requestVideos,
    required this.appointmentRequired,
    required this.sameDay,
    required this.leadTime,
    required this.preparationTime,
    required this.noticeHours,
    required this.exactTimeRequired,
    required this.requiresExactPinAfterAcceptance,
    required this.exactPinTiming,
    required this.pricingMode,
    required this.depositRequired,
    required this.payInFull,
    required this.operationCapabilityIds,
  });

  final List<String> capabilityIds;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final String responseDocumentType;
  final String calendarPresentation;
  final List<VanCapabilityMovementChoiceGroup> movementChoiceGroups;
  final List<String> movementCapabilityIds;
  final List<String> recommendedBuiltInQuestionKeys;
  final bool requireAddress;
  final String addressHeading;
  final String addressFieldLabel;
  final String addressHint;
  final String addressRequiredMessage;
  final bool requestPhotos;
  final bool requestVideos;
  final bool appointmentRequired;
  final bool sameDay;
  final bool leadTime;
  final bool preparationTime;
  final int noticeHours;
  final bool exactTimeRequired;
  final bool requiresExactPinAfterAcceptance;
  final String exactPinTiming;
  final String pricingMode;
  final bool depositRequired;
  final bool payInFull;
  final List<String> operationCapabilityIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'capabilityIds': capabilityIds,
    'journeyType': journeyType.storageKey,
    'requestType': requestType.storageKey,
    'responseDocumentType': responseDocumentType,
    'calendarPresentation': calendarPresentation,
    'movementChoiceGroups': movementChoiceGroups
        .map((group) => group.toJson())
        .toList(growable: false),
    'movementCapabilityIds': movementCapabilityIds,
    'recommendedBuiltInQuestionKeys': recommendedBuiltInQuestionKeys,
    'requireAddress': requireAddress,
    'addressHeading': addressHeading,
    'addressFieldLabel': addressFieldLabel,
    'addressHint': addressHint,
    'addressRequiredMessage': addressRequiredMessage,
    'requestPhotos': requestPhotos,
    'requestVideos': requestVideos,
    'appointmentRequired': appointmentRequired,
    'sameDay': sameDay,
    'leadTime': leadTime,
    'preparationTime': preparationTime,
    'noticeHours': noticeHours,
    'exactTimeRequired': exactTimeRequired,
    'requiresExactPinAfterAcceptance': requiresExactPinAfterAcceptance,
    'exactPinTiming': exactPinTiming,
    'pricingMode': pricingMode,
    'depositRequired': depositRequired,
    'payInFull': payInFull,
    'operationCapabilityIds': operationCapabilityIds,
  };
}

VanCapabilityContract resolveVanCapabilityContract(
  Iterable<String> selectedCapabilityIds, {
  VanCustomerJourneyType? journeyTypeOverride,
  VanCustomerRequestType? requestTypeOverride,
  int recommendedNoticeHours = 24,
}) {
  final ids = selectedCapabilityIds
      .where((id) => findVanServiceCapability(id) != null)
      .toSet();
  final journey =
      journeyTypeOverride ??
      (ids.contains(VanServiceCapabilityIds.requestQuote)
          ? VanCustomerJourneyType.quote
          : ids.contains(VanServiceCapabilityIds.bookAppointment)
          ? VanCustomerJourneyType.booking
          : ids.contains(VanServiceCapabilityIds.preOrder)
          ? VanCustomerJourneyType.preOrder
          : VanCustomerJourneyType.order);
  final requestType =
      requestTypeOverride ??
      switch (journey) {
        VanCustomerJourneyType.quote => VanCustomerRequestType.quoteRequest,
        VanCustomerJourneyType.booking => VanCustomerRequestType.bookingRequest,
        VanCustomerJourneyType.order ||
        VanCustomerJourneyType.preOrder => VanCustomerRequestType.orderRequest,
      };
  final movementIds =
      ids
          .where(
            (id) =>
                findVanServiceCapability(id)?.group ==
                VanServiceCapabilityGroup.fulfilment,
          )
          .toList()
        ..sort();
  final receiveOptions = <VanCapabilityMovementChoice>[
    if (ids.contains(VanServiceCapabilityIds.customerVisitsBusiness))
      const VanCapabilityMovementChoice(value: 'collection', label: 'Collect'),
    if (ids.contains(VanServiceCapabilityIds.businessVisitsCustomer))
      const VanCapabilityMovementChoice(
        value: 'businessVisit',
        label: 'Business visit',
      ),
    if (ids.contains(VanServiceCapabilityIds.localDelivery))
      const VanCapabilityMovementChoice(
        value: 'localDelivery',
        label: 'Local delivery',
      ),
    if (ids.contains(VanServiceCapabilityIds.nationwideDelivery))
      const VanCapabilityMovementChoice(
        value: 'nationwideDelivery',
        label: 'Nationwide delivery',
      ),
    if (ids.contains(VanServiceCapabilityIds.digitalDelivery))
      const VanCapabilityMovementChoice(
        value: 'digitalDelivery',
        label: 'Digital delivery',
      ),
  ];
  final intakeOptions = <VanCapabilityMovementChoice>[
    if (ids.contains(VanServiceCapabilityIds.customerDropsOff))
      const VanCapabilityMovementChoice(
        value: 'customerDropsOff',
        label: "I'll drop it off",
      ),
    if (ids.contains(VanServiceCapabilityIds.businessCollects))
      const VanCapabilityMovementChoice(
        value: 'businessCollects',
        label: 'Please collect it',
      ),
  ];
  final completionOptions = <VanCapabilityMovementChoice>[
    if (ids.contains(VanServiceCapabilityIds.customerCollects))
      const VanCapabilityMovementChoice(
        value: 'customerCollects',
        label: "I'll collect it",
      ),
    if (ids.contains(VanServiceCapabilityIds.businessReturns))
      const VanCapabilityMovementChoice(
        value: 'businessReturns',
        label: 'Please return it',
      ),
  ];
  final movementChoiceGroups = <VanCapabilityMovementChoiceGroup>[
    if (intakeOptions.isNotEmpty)
      VanCapabilityMovementChoiceGroup(
        id: 'intake',
        heading: 'How would you like to get your item to us?',
        options: List<VanCapabilityMovementChoice>.unmodifiable(intakeOptions),
      ),
    if (completionOptions.isNotEmpty)
      VanCapabilityMovementChoiceGroup(
        id: 'completion',
        heading: 'How would you like to receive your completed item?',
        options: List<VanCapabilityMovementChoice>.unmodifiable(
          completionOptions,
        ),
      ),
    if (receiveOptions.isNotEmpty)
      VanCapabilityMovementChoiceGroup(
        id: 'receive',
        heading: 'How would you like to receive your order?',
        options: List<VanCapabilityMovementChoice>.unmodifiable(receiveOptions),
      ),
  ];
  final requireAddress =
      ids.contains(VanServiceCapabilityIds.businessVisitsCustomer) ||
      ids.contains(VanServiceCapabilityIds.businessCollects) ||
      ids.contains(VanServiceCapabilityIds.businessReturns) ||
      ids.contains(VanServiceCapabilityIds.localDelivery) ||
      ids.contains(VanServiceCapabilityIds.nationwideDelivery);
  final businessVisitsCustomer = ids.contains(
    VanServiceCapabilityIds.businessVisitsCustomer,
  );
  final businessCollects = ids.contains(
    VanServiceCapabilityIds.businessCollects,
  );
  final businessReturns = ids.contains(VanServiceCapabilityIds.businessReturns);
  final nationwideDelivery = ids.contains(
    VanServiceCapabilityIds.nationwideDelivery,
  );
  final appointmentRequired = ids.contains(
    VanServiceCapabilityIds.appointmentRequired,
  );
  final leadTime = ids.contains(VanServiceCapabilityIds.leadTime);
  final preparationTime = ids.contains(VanServiceCapabilityIds.preparationTime);
  final requiresExactPinAfterAcceptance = ids.contains(
    VanServiceCapabilityIds.exactPin,
  );
  final pricingMode = ids.contains(VanServiceCapabilityIds.customQuote)
      ? VanServiceCapabilityIds.customQuote
      : ids.contains(VanServiceCapabilityIds.fromPrice)
      ? VanServiceCapabilityIds.fromPrice
      : VanServiceCapabilityIds.fixedPrice;
  final recommendsPreferredTiming =
      appointmentRequired || journey == VanCustomerJourneyType.preOrder;
  final recommendedBuiltIns = <String>[
    if (requireAddress) 'address',
    if (ids.contains(VanServiceCapabilityIds.photoUpload)) 'photos',
    if (recommendsPreferredTiming) 'preferred_date',
    if (recommendsPreferredTiming) 'preferred_time',
    if (recommendsPreferredTiming) 'flexible_timing',
    if (requiresExactPinAfterAcceptance) 'exact_pin',
  ];
  final orderedIds = ids.toList()..sort();
  final operationIds =
      ids
          .where(
            (id) =>
                findVanServiceCapability(id)?.group ==
                VanServiceCapabilityGroup.operations,
          )
          .toList()
        ..sort();
  final noticeHours = (leadTime || preparationTime)
      ? recommendedNoticeHours < 48
            ? 48
            : recommendedNoticeHours
      : recommendedNoticeHours;
  return VanCapabilityContract(
    capabilityIds: orderedIds,
    journeyType: journey,
    requestType: requestType,
    responseDocumentType: journey == VanCustomerJourneyType.preOrder
        ? 'orderSummary'
        : journey == VanCustomerJourneyType.booking
        ? 'bookingConfirmation'
        : 'quote',
    calendarPresentation: journey == VanCustomerJourneyType.preOrder
        ? 'compactTimed'
        : requestType == VanCustomerRequestType.dropOffPickupRequest ||
              requestType == VanCustomerRequestType.pickupDeliveryRequest
        ? 'handover'
        : 'appointment',
    movementChoiceGroups: List<VanCapabilityMovementChoiceGroup>.unmodifiable(
      movementChoiceGroups,
    ),
    movementCapabilityIds: movementIds,
    recommendedBuiltInQuestionKeys: List<String>.unmodifiable(
      recommendedBuiltIns,
    ),
    requireAddress: requireAddress,
    addressHeading: businessCollects
        ? 'Collection address'
        : businessReturns
        ? 'Return address'
        : nationwideDelivery
        ? 'Nationwide delivery address'
        : businessVisitsCustomer
        ? 'Service address'
        : 'Address or postcode',
    addressFieldLabel: businessCollects
        ? 'Collection address'
        : businessReturns
        ? 'Return address'
        : nationwideDelivery
        ? 'Nationwide delivery address'
        : businessVisitsCustomer
        ? 'Service address'
        : 'Address',
    addressHint: businessCollects
        ? 'Where should the business collect from?'
        : businessReturns
        ? 'Where should the business return it?'
        : nationwideDelivery
        ? 'Where should the order be sent?'
        : businessVisitsCustomer
        ? 'Where will the work take place?'
        : 'Enter address',
    addressRequiredMessage: businessCollects
        ? 'Please add the collection address.'
        : businessReturns
        ? 'Please add the return address.'
        : nationwideDelivery
        ? 'Please add the nationwide delivery address.'
        : businessVisitsCustomer
        ? 'Please add the service address.'
        : 'Please add an address or postcode for this service.',
    requestPhotos:
        ids.contains(VanServiceCapabilityIds.photoUpload) ||
        ids.contains(VanServiceCapabilityIds.videoUpload),
    requestVideos: ids.contains(VanServiceCapabilityIds.videoUpload),
    appointmentRequired: appointmentRequired,
    sameDay: ids.contains(VanServiceCapabilityIds.sameDay),
    leadTime: leadTime,
    preparationTime: preparationTime,
    noticeHours: noticeHours,
    exactTimeRequired: journey == VanCustomerJourneyType.preOrder,
    requiresExactPinAfterAcceptance: requiresExactPinAfterAcceptance,
    exactPinTiming: requiresExactPinAfterAcceptance
        ? 'afterAcceptance'
        : 'none',
    pricingMode: pricingMode,
    depositRequired: ids.contains(VanServiceCapabilityIds.depositRequired),
    payInFull: ids.contains(VanServiceCapabilityIds.payInFull),
    operationCapabilityIds: operationIds,
  );
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
    label: 'Pre Order',
    description:
        'Customers order an existing product ahead of collection or delivery.',
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
    label: 'Order Request',
    description:
        'Customers request a custom-made or made-to-order product for confirmation.',
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
    id: VanServiceCapabilityIds.exactPin,
    label: 'Exact Pin',
    description:
        'Ask the customer to confirm the exact location after acceptance.',
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
    required this.allowBusinessDelivery,
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
  final bool allowBusinessDelivery;
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
  final contract = resolveVanCapabilityContract(
    selectedCapabilityIds,
    recommendedNoticeHours: recommendedNoticeHours,
  );
  final ids = contract.capabilityIds.toSet();
  final journey = contract.journeyType;
  final requestType = contract.requestType;
  final appointment = contract.appointmentRequired;
  final pricingMode = contract.pricingMode;
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
    // Delivery is an explicit handover destination. Do not infer it from
    // legacy fulfilment capabilities because doing so would reinterpret
    // existing saved services when their capability selection is edited.
    allowBusinessDelivery: false,
    requireAddress: contract.requireAddress,
    requestPhotos: contract.requestPhotos,
    builtInQuestionKeys: <String>{
      if (contract.appointmentRequired) 'preferred_date',
      if (contract.appointmentRequired) 'preferred_time',
      if (contract.requiresExactPinAfterAcceptance) 'exact_pin',
    },
    questions: const <VanServiceTemplateQuestion>[],
    extras: const <VanServiceTemplateExtra>[],
    suggestedDurationMinutes:
        recommendedDurationMinutes ?? (appointment ? 60 : 30),
    suggestedNoticeHours: contract.noticeHours,
    suggestedReminderMinutes: const <int>[],
    pricingMode: pricingMode,
  );
}
