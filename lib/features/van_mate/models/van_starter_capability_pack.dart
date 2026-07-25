import 'van_customer_journey.dart';
import 'van_customer_request_flow.dart';
import 'van_custom_job_question.dart';
import 'van_quote_extra_defaults.dart';
import 'van_service_capability.dart';
import 'van_service_handover.dart';
import 'van_service_template.dart';

/// An explicit per-day schedule used only by seeded template definitions.
class VanTemplateDayAvailability {
  const VanTemplateDayAvailability({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
  });

  final int day;
  final int startMinutes;
  final int endMinutes;
}

/// The central schema for adding a verified business type back to the app.
///
/// Every field that can affect a generated service is explicit. No behaviour
/// is inferred from display names, keywords, or generic fallback generators.
class VanBusinessTemplateDefinition {
  const VanBusinessTemplateDefinition({
    required this.categoryId,
    required this.categoryName,
    required this.businessTypeId,
    required this.businessTypeName,
    required this.description,
    required this.iconKey,
    required this.colorValue,
    required this.services,
    this.featured = false,
    this.searchKeywords = const <String>[],
    this.searchAliases = const <VanBusinessSearchAlias>[],
  });

  final String categoryId;
  final String categoryName;
  final String businessTypeId;
  final String businessTypeName;
  final String description;
  final String iconKey;
  final int colorValue;
  final List<VanBusinessServiceTemplateDefinition> services;
  final bool featured;
  final List<String> searchKeywords;
  final List<VanBusinessSearchAlias> searchAliases;
}

class VanBusinessServiceTemplateDefinition {
  const VanBusinessServiceTemplateDefinition({
    required this.serviceId,
    required this.name,
    required this.description,
    required this.featureIds,
    required this.bookingOptionIds,
    required this.customerJourney,
    required this.requestType,
    required this.startHandover,
    required this.endHandover,
    required this.requestFlowOptions,
    required this.questions,
    required this.extras,
    required this.availability,
    this.builtInQuestionKeys = const <String>{},
    this.builtInQuestionSettings = const <String, Map<String, dynamic>>{},
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.maximumBookingsPerDay = 8,
    this.requestPhotos = false,
    this.requireAddress = false,
    this.pricingMode = VanServiceCapabilityIds.customQuote,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
  });

  final String serviceId;
  final String name;
  final String description;
  final List<String> featureIds;
  final List<String> bookingOptionIds;
  final VanCustomerJourneyType customerJourney;
  final VanCustomerRequestType requestType;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions requestFlowOptions;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final bool requestPhotos;
  final bool requireAddress;
  final String pricingMode;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
}

/// Intentionally empty after the controlled seeded-library reset.
///
/// Future packs must be added here using [VanBusinessTemplateDefinition].
const VanCustomerRequestFlowOptions _removalsPickupDeliveryFlow =
    VanCustomerRequestFlowOptions(
      showFulfilmentChoice: false,
      askPreferredDate: false,
      askPreferredTime: false,
      showPickupAddress: true,
      showDeliveryAddress: true,
      showDropOffDate: true,
      showDropOffTime: true,
      showPickUpDate: true,
      showPickUpTime: true,
      showNotes: true,
    );

const List<VanTemplateDayAvailability> _removalsMondayToSaturday =
    <VanTemplateDayAvailability>[
      VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
    ];

const VanCustomerRequestFlowOptions _cleaningStandardQuoteFlow =
    VanCustomerRequestFlowOptions(
      showFulfilmentChoice: false,
      askPreferredDate: true,
      askPreferredTime: true,
      showPickupAddress: false,
      showDeliveryAddress: false,
      showDropOffDate: false,
      showDropOffTime: false,
      showPickUpDate: false,
      showPickUpTime: false,
      showNotes: false,
    );

const List<VanTemplateDayAvailability> _cleaningMondayToSaturday =
    <VanTemplateDayAvailability>[
      VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
    ];

const List<VanTemplateDayAvailability> _cleaningMondayToFriday =
    <VanTemplateDayAvailability>[
      VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
      VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
    ];

const List<String> _cleaningPropertyTypeOptions = <String>[
  'House',
  'Flat / apartment',
  'Bungalow',
  'Other',
  'Unsure',
];

const List<String> _cleaningSupplyOptions = <String>[
  'Business supplies both',
  'Customer supplies both',
  'Customer supplies products only',
  'Customer supplies equipment only',
  'Please advise',
];

const List<VanBusinessTemplateDefinition>
kVanBusinessTemplateLibrary = <VanBusinessTemplateDefinition>[
  VanBusinessTemplateDefinition(
    categoryId: 'transport_delivery',
    categoryName: 'Transport & Delivery',
    businessTypeId: 'courier',
    businessTypeName: 'Courier',
    description:
        'Collection and delivery services for parcels, documents and other suitable items.',
    iconKey: 'local_shipping',
    colorValue: 0xFF4F8CFF,
    featured: true,
    searchKeywords: <String>['courier', 'parcel delivery', 'document delivery'],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Delivery service'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'courier_same_day_delivery',
        name: 'Same-day Delivery',
        description:
            'Collection and delivery on the same day for parcels, documents and other suitable items.',
        featureIds: <String>[
          VanServiceCapabilityIds.sameDay,
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.proofOfDelivery,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: false,
          askPreferredTime: false,
          showPickupAddress: true,
          showDeliveryAddress: true,
          showDropOffDate: true,
          showDropOffTime: true,
          showPickUpDate: true,
          showPickUpTime: true,
          showNotes: true,
        ),
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help identify the items and handling needs.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_items',
            text: 'What are we collecting and delivering?',
            helperText:
                'List the items and anything the courier should know about them.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['courier', 'same-day', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_size_weight',
            text:
                'What is the approximate size and weight of the item or items?',
            helperText: 'Estimates are fine; include dimensions where known.',
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['courier', 'same-day', 'size', 'weight'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_special_handling',
            text: 'Do any items need fragile or special handling?',
            helperText:
                'Add any handling instructions in Notes if you choose Yes.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['courier', 'same-day', 'fragile'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_recipient_available',
            text: 'Will someone be available at the delivery address?',
            helperText: 'This helps the courier plan the delivery handover.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.delivery,
            tags: <String>['courier', 'same-day', 'delivery'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_same_day_proof',
            text: 'What proof of delivery do you need?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.proofOfDelivery,
            choiceOptions: <String>[
              'No proof needed',
              'Photo proof',
              'Recipient signature',
            ],
            tags: <String>['courier', 'same-day', 'proof-of-delivery'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_additional_stop',
            label: 'Additional stop',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_heavy_oversized',
            label: 'Heavy or oversized item',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_same_day_out_of_hours',
            label: 'Evening or out-of-hours delivery',
          ),
        ],
        availability: <VanTemplateDayAvailability>[
          VanTemplateDayAvailability(
            day: 1,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 2,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 3,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 4,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 5,
            startMinutes: 480,
            endMinutes: 1200,
          ),
          VanTemplateDayAvailability(
            day: 6,
            startMinutes: 540,
            endMinutes: 1020,
          ),
        ],
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 2,
        maximumBookingsPerDay: 12,
        requestPhotos: true,
        requireAddress: false,
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'courier_scheduled_delivery',
        name: 'Scheduled Delivery',
        description:
            'Pre-arranged collection and delivery on a chosen date and time window.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.proofOfDelivery,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: false,
          askPreferredTime: false,
          showPickupAddress: true,
          showDeliveryAddress: true,
          showDropOffDate: true,
          showDropOffTime: true,
          showPickUpDate: true,
          showPickUpTime: true,
          showNotes: true,
        ),
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help identify the items and handling needs.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_items',
            text: 'What are we collecting and delivering?',
            helperText:
                'List the items and anything the courier should know about them.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['courier', 'scheduled', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_size_weight',
            text:
                'What is the approximate size and weight of the item or items?',
            helperText: 'Estimates are fine; include dimensions where known.',
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['courier', 'scheduled', 'size', 'weight'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_special_handling',
            text: 'Do any items need fragile or special handling?',
            helperText:
                'Add any handling instructions in Notes if you choose Yes.',
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['courier', 'scheduled', 'fragile'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_access',
            text: 'Are there any collection or delivery access restrictions?',
            helperText:
                'Include parking, loading bays, stairs, gate codes or restricted access.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['courier', 'scheduled', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'courier_scheduled_proof',
            text: 'What proof of delivery do you need?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.proofOfDelivery,
            choiceOptions: <String>[
              'No proof needed',
              'Photo proof',
              'Recipient signature',
            ],
            tags: <String>['courier', 'scheduled', 'proof-of-delivery'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_additional_stop',
            label: 'Additional stop',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_heavy_oversized',
            label: 'Heavy or oversized item',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_courier_scheduled_weekend_holiday',
            label: 'Weekend or bank holiday delivery',
          ),
        ],
        availability: <VanTemplateDayAvailability>[
          VanTemplateDayAvailability(
            day: 1,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 2,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 3,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 4,
            startMinutes: 540,
            endMinutes: 1020,
          ),
          VanTemplateDayAvailability(
            day: 5,
            startMinutes: 540,
            endMinutes: 1020,
          ),
        ],
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 8,
        requestPhotos: true,
        requireAddress: false,
      ),
    ],
  ),
  VanBusinessTemplateDefinition(
    categoryId: 'removals_moving',
    categoryName: 'Removals & Moving',
    businessTypeId: 'removals_man_with_van',
    businessTypeName: 'Removals / Man with a Van',
    description:
        'Moving, furniture delivery and clearance services for local customers.',
    iconKey: 'local_shipping',
    colorValue: 0xFF7C5CFC,
    featured: true,
    searchKeywords: <String>[
      'removals',
      'man with a van',
      'house move',
      'furniture delivery',
      'clearance',
    ],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Man & Van'),
      VanBusinessSearchAlias('Removal service'),
      VanBusinessSearchAlias('Moving service'),
      VanBusinessSearchAlias('House removals'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'removals_man_with_van_general',
        name: 'Man with a Van',
        description:
            'Flexible collection and delivery for boxes, furniture and smaller moves.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.multipleStops,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.loadingUnloadingHelp,
          VanServiceCapabilityIds.dismantlingReassembly,
          VanServiceCapabilityIds.teamMembers,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: _removalsPickupDeliveryFlow,
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help estimate the load and handling needs.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'removals_man_with_van_items',
            text: 'What needs moving?',
            helperText:
                'List the boxes, furniture or other items that need moving.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['removals', 'man-with-a-van', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_man_with_van_load_size',
            text: 'Roughly how much needs moving?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.sizeWeight,
            choiceOptions: <String>[
              'A few items',
              'Part of a van',
              'A full van',
              'More than one load',
              'Unsure',
            ],
            tags: <String>['removals', 'man-with-a-van', 'load-size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_man_with_van_access',
            text:
                'Are there any access or parking restrictions at either address?',
            helperText:
                'Include stairs, lifts, permits, narrow roads or carrying distance. Answer None if there are no restrictions.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['removals', 'man-with-a-van', 'access', 'parking'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_man_with_van_loading_help',
            text: 'Will anyone be helping with loading or unloading?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.loading,
            choiceOptions: <String>[
              'Help at both addresses',
              'Help at collection only',
              'Help at delivery only',
              'No help available',
              'Unsure',
            ],
            tags: <String>['removals', 'man-with-a-van', 'loading', 'labour'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_man_with_van_special_items',
            text:
                'Are there any heavy, fragile, unusually shaped or dismantled items?',
            helperText:
                'Include approximate dimensions or weights where known.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['removals', 'man-with-a-van', 'special-handling'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_man_with_van_additional_helper',
            label: 'Additional helper',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_man_with_van_dismantling',
            label: 'Furniture dismantling',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_man_with_van_reassembly',
            label: 'Furniture reassembly',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_man_with_van_collection_stop',
            label: 'Extra collection stop',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_man_with_van_delivery_stop',
            label: 'Extra delivery stop',
          ),
        ],
        availability: _removalsMondayToSaturday,
        suggestedDurationMinutes: 120,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 4,
        requestPhotos: true,
        requireAddress: false,
        suggestedCustomerMessage:
            "Tell us what needs moving and any access or loading details. We'll review your request and confirm availability and price.",
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'removals_full_house_move',
        name: 'Full House Move',
        description:
            'Request a quote for moving the contents of a whole home between two addresses.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.loadingUnloadingHelp,
          VanServiceCapabilityIds.dismantlingReassembly,
          VanServiceCapabilityIds.packingService,
          VanServiceCapabilityIds.teamMembers,
          VanServiceCapabilityIds.multipleVehicles,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: _removalsPickupDeliveryFlow,
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos of rooms and larger items can help estimate the vehicle and labour needed.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_properties',
            text: 'Tell us about the collection and delivery properties.',
            helperText:
                'Include each property type, approximate bedroom count, floor levels, stairs and lifts. Do not repeat the addresses.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.property,
            tags: <String>['removals', 'full-house', 'property'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_volume',
            text:
                'Roughly how many boxes and large furniture items are being moved?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['removals', 'full-house', 'volume'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_access',
            text:
                'What access and parking should we know about at either property?',
            helperText:
                'Include loading distance, stairs, lifts, permits or restricted access. Answer None if there are no restrictions.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['removals', 'full-house', 'access', 'parking'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_help',
            text: 'What level of moving help do you need?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.loading,
            choiceOptions: <String>[
              'Transport only',
              'Loading and unloading',
              'Packing and moving',
              'Unsure',
            ],
            tags: <String>['removals', 'full-house', 'labour', 'packing'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_dismantling',
            text: 'Which items need dismantling or reassembly?',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.assembly,
            tags: <String>['removals', 'full-house', 'assembly'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_full_house_special_items',
            text:
                'Are there any especially heavy, fragile or unusually shaped items?',
            helperText:
                'Include approximate dimensions or weights where known.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['removals', 'full-house', 'special-handling'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_additional_helper',
            label: 'Additional helper',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_packing_service',
            label: 'Packing service',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_packing_materials',
            label: 'Packing materials',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_dismantling',
            label: 'Furniture dismantling',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_reassembly',
            label: 'Furniture reassembly',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_full_house_covers',
            label: 'Protective furniture covers',
          ),
        ],
        availability: _removalsMondayToSaturday,
        suggestedDurationMinutes: 480,
        suggestedNoticeHours: 72,
        maximumBookingsPerDay: 1,
        requestPhotos: true,
        requireAddress: false,
        suggestedCustomerMessage:
            "Tell us about both properties, the amount being moved and any help you need. We'll review the details before confirming availability and price.",
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'removals_furniture_single_item',
        name: 'Furniture / Single Item Collection and Delivery',
        description:
            'Collection and delivery of one item or a small group of furniture, subject to size, access and handling needs.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.localDelivery,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.loadingUnloadingHelp,
          VanServiceCapabilityIds.dismantlingReassembly,
          VanServiceCapabilityIds.teamMembers,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.pickupDeliveryRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessDelivers,
        requestFlowOptions: _removalsPickupDeliveryFlow,
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help check the item, access and protection needed.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_items',
            text: 'What item or items need collecting?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['removals', 'furniture', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_dimensions_weight',
            text: 'What are the approximate dimensions and weight?',
            helperText: 'Estimates are fine. Answer Unsure where necessary.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.sizeWeight,
            tags: <String>['removals', 'furniture', 'dimensions', 'weight'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_access',
            text:
                'What access and parking should we know about at either address?',
            helperText:
                'Include stairs, lifts, doorways, permits or carrying distance. Answer None if there are no restrictions.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['removals', 'furniture', 'access', 'parking'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_lifting_help',
            text: 'Will anyone be available to help with lifting?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.loading,
            choiceOptions: <String>[
              'Help at both addresses',
              'Help at collection only',
              'Help at delivery only',
              'No help available',
              'Unsure',
            ],
            tags: <String>['removals', 'furniture', 'lifting', 'labour'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_dismantling',
            text: 'Does anything need dismantling or reassembly?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.assembly,
            choiceOptions: <String>[
              'No',
              'Dismantling',
              'Reassembly',
              'Both',
              'Unsure',
            ],
            tags: <String>['removals', 'furniture', 'assembly'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_furniture_special_handling',
            text: 'Does the item need fragile or special handling?',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.fragileValuableItems,
            tags: <String>['removals', 'furniture', 'special-handling'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_furniture_additional_helper',
            label: 'Additional helper',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_furniture_dismantling',
            label: 'Furniture dismantling',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_furniture_reassembly',
            label: 'Furniture reassembly',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_furniture_covers',
            label: 'Protective furniture covers',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_furniture_waiting_time',
            label: 'Waiting time',
          ),
        ],
        availability: _removalsMondayToSaturday,
        suggestedDurationMinutes: 90,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 6,
        requestPhotos: true,
        requireAddress: false,
        suggestedCustomerMessage:
            'Add the item details, approximate measurements and access information so we can check the vehicle and labour required.',
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'removals_clearance',
        name: 'House, Garage or Storage Clearance',
        description:
            'Request removal of unwanted household, garage or storage items for the business to review and quote.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.appointmentRequired,
          VanServiceCapabilityIds.businessVisitsCustomer,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.loadingUnloadingHelp,
          VanServiceCapabilityIds.dismantlingReassembly,
          VanServiceCapabilityIds.teamMembers,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.quoteRequest,
        startHandover: null,
        endHandover: null,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: true,
          askPreferredTime: true,
          showPickupAddress: false,
          showDeliveryAddress: false,
          showDropOffDate: false,
          showDropOffTime: false,
          showPickUpDate: false,
          showPickUpTime: false,
          showNotes: true,
        ),
        builtInQuestionKeys: <String>{
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        },
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'address': <String, dynamic>{'required': true, 'helperText': ''},
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': '',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText': '',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help assess the volume and whether the items are suitable.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'removals_clearance_areas_items',
            text: 'Which areas are being cleared, and what needs removing?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['removals', 'clearance', 'areas', 'items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_clearance_volume',
            text: 'Roughly how much is there?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.sizeWeight,
            choiceOptions: <String>[
              'A few items',
              'A small van load',
              'A full van load',
              'Multiple loads',
              'Unsure',
            ],
            tags: <String>['removals', 'clearance', 'volume'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_clearance_restricted_items',
            text:
                'Are there any electricals, mattresses, paint, chemicals, gas bottles or other potentially restricted items?',
            helperText:
                'Listing an item does not mean the business can accept or remove it. Answer None if there are no such items.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['removals', 'clearance', 'restricted-items'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_clearance_access',
            text:
                'What access, stairs or parking restrictions should we know about?',
            helperText: 'Answer None if there are no restrictions.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['removals', 'clearance', 'access', 'parking'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'removals_clearance_reusable_items',
            text: 'Should reusable items be kept separate where possible?',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.yesNo,
            category: VanCustomQuestionCategory.items,
            tags: <String>['removals', 'clearance', 'reusable-items'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_clearance_additional_helper',
            label: 'Additional helper',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_clearance_dismantling',
            label: 'Dismantling for removal',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_removals_clearance_additional_load',
            label: 'Additional load',
          ),
        ],
        availability: _removalsMondayToSaturday,
        suggestedDurationMinutes: 180,
        suggestedNoticeHours: 48,
        maximumBookingsPerDay: 3,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Please describe everything to be removed and include photos where possible. The business will confirm which items it can legally and safely accept.',
      ),
    ],
  ),
  VanBusinessTemplateDefinition(
    categoryId: 'cleaning',
    categoryName: 'Cleaning',
    businessTypeId: 'cleaning',
    businessTypeName: 'Cleaning',
    description:
        'Domestic and commercial cleaning services for homes and small business premises.',
    iconKey: 'cleaning',
    colorValue: 0xFF2DB7A3,
    featured: true,
    searchKeywords: <String>[
      'cleaning',
      'cleaner',
      'domestic cleaning',
      'deep cleaning',
      'end of tenancy cleaning',
      'office cleaning',
      'commercial cleaning',
    ],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Domestic cleaner'),
      VanBusinessSearchAlias('House cleaning'),
      VanBusinessSearchAlias('Deep cleaning'),
      VanBusinessSearchAlias('End of tenancy cleaner'),
      VanBusinessSearchAlias('Office cleaning'),
      VanBusinessSearchAlias('Commercial cleaning'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'cleaning_regular_domestic',
        name: 'Domestic Cleaning',
        description:
            'Routine cleaning for occupied homes, tailored to the rooms and frequency requested.',
        featureIds: <String>[
          VanServiceCapabilityIds.appointmentRequired,
          VanServiceCapabilityIds.businessVisitsCustomer,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.recurring,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.quoteRequest,
        startHandover: null,
        endHandover: null,
        requestFlowOptions: _cleaningStandardQuoteFlow,
        builtInQuestionKeys: <String>{
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        },
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'address': <String, dynamic>{
            'required': true,
            'helperText':
                'Enter the address where the cleaning will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred cleaning date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can show the general condition or priority areas. Avoid including private documents, security devices or sensitive personal information.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_property_type',
            text: 'What type of property is being cleaned?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.property,
            choiceOptions: _cleaningPropertyTypeOptions,
            tags: <String>['cleaning', 'regular', 'property'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_bedrooms_bathrooms',
            text: 'How many bedrooms and bathrooms are included?',
            category: VanCustomQuestionCategory.property,
            tags: <String>['cleaning', 'regular', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_rooms_priorities',
            text: 'Which rooms are included, and are there any priority areas?',
            helperText:
                'Optional photos can help show the general condition or priority areas.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            tags: <String>['cleaning', 'regular', 'rooms', 'priorities'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_frequency',
            text: 'How often would you prefer the cleaning?',
            helperText:
                'This records your preference only and does not automatically create recurring bookings.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              'One-off',
              'Weekly',
              'Fortnightly',
              'Every four weeks',
              'Unsure',
            ],
            tags: <String>['cleaning', 'regular', 'frequency'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_pets',
            text: 'Are there any pets the cleaner should plan around?',
            requiredByDefault: false,
            category: VanCustomQuestionCategory.property,
            tags: <String>['cleaning', 'regular', 'pets'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_supplies',
            text: 'Who should provide the cleaning products and equipment?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.jobDetails,
            choiceOptions: _cleaningSupplyOptions,
            tags: <String>['cleaning', 'regular', 'products', 'equipment'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_regular_access_occupancy',
            text:
                'Describe parking, access and whether someone will be present during the clean.',
            helperText:
                'Do not include door, alarm or key-safe codes. Sensitive access details can be arranged privately after the job is accepted.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>[
              'cleaning',
              'regular',
              'access',
              'parking',
              'occupancy',
            ],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_regular_additional_bedroom',
            label: 'Additional bedroom',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_regular_additional_bathroom',
            label: 'Additional bathroom',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_regular_interior_windows',
            label: 'Interior windows',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_regular_bed_linen_change',
            label: 'Bed linen change',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_regular_ironing',
            label: 'Ironing',
          ),
        ],
        availability: _cleaningMondayToSaturday,
        suggestedDurationMinutes: 120,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 3,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            "Tell us about your home, the rooms to clean and your preferred frequency. We'll review the request and confirm the scope, availability and price.",
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'cleaning_one_off_deep',
        name: 'One-off Deep Clean',
        description:
            'A detailed one-off clean for homes needing extra attention, subject to condition and agreed scope.',
        featureIds: <String>[
          VanServiceCapabilityIds.appointmentRequired,
          VanServiceCapabilityIds.businessVisitsCustomer,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.photoUpload,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.quoteRequest,
        startHandover: null,
        endHandover: null,
        requestFlowOptions: _cleaningStandardQuoteFlow,
        builtInQuestionKeys: <String>{
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        },
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'address': <String, dynamic>{
            'required': true,
            'helperText':
                'Enter the address where the cleaning will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred cleaning date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Photos of buildup and priority rooms can help the business assess the work. Avoid including private documents, security equipment or sensitive information.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_property_type',
            text: 'What type of property is being cleaned?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.property,
            choiceOptions: _cleaningPropertyTypeOptions,
            tags: <String>['cleaning', 'deep', 'property'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_bedrooms_bathrooms',
            text: 'How many bedrooms and bathrooms are included?',
            category: VanCustomQuestionCategory.property,
            tags: <String>['cleaning', 'deep', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_condition',
            text: 'How would you describe the current condition?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.survey,
            choiceOptions: <String>[
              'Light buildup',
              'Moderate buildup',
              'Heavy buildup',
              'Recently vacated',
              'Unsure',
            ],
            tags: <String>['cleaning', 'deep', 'condition'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_priorities',
            text:
                'Which rooms or areas need the most attention, and what buildup is present?',
            helperText:
                'Include visible issues such as grease or limescale. Results depend on the condition and agreed scope.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            tags: <String>['cleaning', 'deep', 'priorities', 'buildup'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_occupancy',
            text: 'What will the occupancy arrangement be during the clean?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.access,
            choiceOptions: <String>[
              'Someone will be present',
              'Property will be empty and access arranged',
              'Property is vacant',
              'Unsure',
            ],
            tags: <String>['cleaning', 'deep', 'occupancy'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_supplies',
            text: 'Who should provide the cleaning products and equipment?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.jobDetails,
            choiceOptions: _cleaningSupplyOptions,
            tags: <String>['cleaning', 'deep', 'products', 'equipment'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_deep_access_furniture',
            text:
                'What access, parking, pet or furniture-movement issues should we plan for?',
            helperText:
                'Furniture movement is subject to agreement. Do not include door, alarm or key-safe codes.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>[
              'cleaning',
              'deep',
              'access',
              'parking',
              'pets',
              'furniture',
            ],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_deep_inside_oven',
            label: 'Inside oven',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_deep_inside_fridge_freezer',
            label: 'Inside fridge / freezer',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_deep_inside_cupboards',
            label: 'Inside cupboards',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_deep_interior_windows',
            label: 'Interior windows',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_deep_pet_hair_treatment',
            label: 'Additional pet-hair treatment',
          ),
        ],
        availability: _cleaningMondayToSaturday,
        suggestedDurationMinutes: 240,
        suggestedNoticeHours: 48,
        maximumBookingsPerDay: 2,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            "Tell us about the property's size, condition and priority areas. Photos can help us review the work before confirming availability and price.",
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'cleaning_end_of_tenancy',
        name: 'End of Tenancy Cleaning',
        description:
            'Cleaning for a rented property before handover, based on its condition and any agent or inventory requirements.',
        featureIds: <String>[
          VanServiceCapabilityIds.appointmentRequired,
          VanServiceCapabilityIds.businessVisitsCustomer,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.photoUpload,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.quoteRequest,
        startHandover: null,
        endHandover: null,
        requestFlowOptions: _cleaningStandardQuoteFlow,
        builtInQuestionKeys: <String>{
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        },
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'address': <String, dynamic>{
            'required': true,
            'helperText':
                'Enter the address where the cleaning will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred cleaning date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Photos of the current condition, empty rooms, appliances or inventory concerns can help the business review the work. Avoid showing private documents or security information.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_property_type',
            text: 'What type of property is being cleaned?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.property,
            choiceOptions: _cleaningPropertyTypeOptions,
            tags: <String>['cleaning', 'tenancy', 'property'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_bedrooms_bathrooms',
            text: 'How many bedrooms and bathrooms are included?',
            category: VanCustomQuestionCategory.property,
            tags: <String>['cleaning', 'tenancy', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_furnishing_occupancy',
            text:
                "What will the property's furnishing and occupancy status be?",
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.property,
            choiceOptions: <String>[
              'Furnished and occupied',
              'Furnished and empty',
              'Unfurnished and occupied',
              'Unfurnished and empty',
              'Unsure',
            ],
            tags: <String>['cleaning', 'tenancy', 'furnishing', 'occupancy'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_condition',
            text: 'How would you describe the current condition?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.survey,
            choiceOptions: <String>[
              'Light cleaning needed',
              'Moderate cleaning needed',
              'Heavy cleaning needed',
              'Unsure',
            ],
            tags: <String>['cleaning', 'tenancy', 'condition'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_handover_deadline',
            text:
                'If there is a separate checkout or handover deadline, what date is it?',
            helperText:
                'This is the checkout or handover deadline, not your requested cleaning date.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.date,
            category: VanCustomQuestionCategory.timing,
            tags: <String>['cleaning', 'tenancy', 'handover', 'deadline'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_agent_requirements',
            text:
                'Are there any agent, landlord or inventory requirements we should review?',
            helperText:
                'Requirements can be reviewed, but results depend on the property condition and agreed scope.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.survey,
            tags: <String>['cleaning', 'tenancy', 'agent', 'inventory'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_tenancy_access',
            text: 'Describe the key handover, access and parking arrangements.',
            helperText:
                'Do not include door, alarm, key-safe or other security codes. Sensitive access details can be arranged privately after acceptance.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>['cleaning', 'tenancy', 'access', 'parking', 'keys'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_tenancy_inside_oven',
            label: 'Inside oven',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_tenancy_inside_fridge_freezer',
            label: 'Inside fridge / freezer',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_tenancy_inside_cupboards',
            label: 'Inside cupboards',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_tenancy_interior_windows',
            label: 'Interior windows',
          ),
        ],
        availability: _cleaningMondayToSaturday,
        suggestedDurationMinutes: 360,
        suggestedNoticeHours: 72,
        maximumBookingsPerDay: 1,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            "Tell us about the property, its condition and any agent or inventory requirements. Cleaning does not guarantee a deposit return; results depend on the property's condition and the agreed scope.",
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'cleaning_office_commercial',
        name: 'Office / Commercial Cleaning',
        description:
            'One-off or regular cleaning for offices and small commercial premises, arranged around access and operating hours.',
        featureIds: <String>[
          VanServiceCapabilityIds.appointmentRequired,
          VanServiceCapabilityIds.businessVisitsCustomer,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
          VanServiceCapabilityIds.recurring,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.quoteRequest,
        startHandover: null,
        endHandover: null,
        requestFlowOptions: _cleaningStandardQuoteFlow,
        builtInQuestionKeys: <String>{
          'address',
          'phone',
          'email',
          'preferred_date',
          'preferred_time',
          'photos',
        },
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'address': <String, dynamic>{
            'required': true,
            'helperText':
                'Enter the address where the cleaning will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred cleaning date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Photos may show the general layout or condition. Do not photograph security systems, confidential documents, personal records or restricted areas.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_premises_type',
            text: 'What type of premises need cleaning?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.property,
            choiceOptions: <String>[
              'Office',
              'Retail premises',
              'Studio / workshop',
              'Community / communal space',
              'Other',
              'Unsure',
            ],
            tags: <String>['cleaning', 'office', 'premises'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_floor_area',
            text: 'What is the approximate floor area?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.sizeWeight,
            choiceOptions: <String>[
              'Under 100 m²',
              '100–250 m²',
              '251–500 m²',
              'Over 500 m²',
              'Unsure',
            ],
            tags: <String>['cleaning', 'office', 'floor-area', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_areas_facilities',
            text:
                'Describe the work areas, washrooms, kitchens and communal spaces included.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            tags: <String>['cleaning', 'office', 'areas', 'facilities'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_frequency',
            text: 'What cleaning pattern are you looking for?',
            helperText:
                'This records your preference only and does not automatically create repeat jobs.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              'One-off',
              'Daily on weekdays',
              'Weekly',
              'Fortnightly',
              'Other',
              'Unsure',
            ],
            tags: <String>['cleaning', 'office', 'frequency'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_hours',
            text: 'Which cleaning window usually works best?',
            helperText:
                "This is an operating preference, not a replacement for the current request's preferred appointment time.",
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              'During business hours',
              'Before opening',
              'After closing',
              'Weekend',
              'Flexible / unsure',
            ],
            tags: <String>['cleaning', 'office', 'hours'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_access',
            text:
                'Describe reception, key handover, parking and any restricted areas.',
            helperText:
                'Do not include alarm codes, door codes, passwords or sensitive security instructions.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            tags: <String>[
              'cleaning',
              'office',
              'access',
              'parking',
              'security',
            ],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_supplies',
            text: 'Who should provide the cleaning products and equipment?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.jobDetails,
            choiceOptions: _cleaningSupplyOptions,
            tags: <String>['cleaning', 'office', 'products', 'equipment'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'cleaning_office_bins',
            text: 'Are ordinary internal bin-emptying duties required?',
            helperText:
                'Hazardous, clinical and licensed waste is not included.',
            requiredByDefault: false,
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            tags: <String>['cleaning', 'office', 'bins', 'waste'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_office_additional_washroom',
            label: 'Additional washroom',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_office_communal_area_deep_clean',
            label: 'Kitchen / communal-area deep clean',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_office_interior_windows',
            label: 'Interior windows',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_office_products_supplied',
            label: 'Cleaning products supplied',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_cleaning_office_internal_bins',
            label: 'Internal bin emptying',
          ),
        ],
        availability: _cleaningMondayToFriday,
        suggestedDurationMinutes: 180,
        suggestedNoticeHours: 48,
        maximumBookingsPerDay: 2,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Tell us about the premises, areas, preferred frequency and access arrangements. Do not include alarm codes, door codes, passwords or other sensitive security details.',
      ),
    ],
  ),
];

class VanStarterCapabilityPack {
  const VanStarterCapabilityPack({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.colorValue,
    this.services = const <VanBusinessServiceRecommendation>[],
    this.featured = false,
    this.searchKeywords = const <String>[],
    this.searchAliases = const <VanBusinessSearchAlias>[],
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String iconKey;
  final int colorValue;
  final List<VanBusinessServiceRecommendation> services;
  final bool featured;
  final List<String> searchKeywords;
  final List<VanBusinessSearchAlias> searchAliases;

  List<VanBusinessServiceRecommendation> get serviceRecommendations => services;

  List<VanRecommendedServiceSetup> recommendationsFor(
    Iterable<String> selectedServiceIds, {
    Map<String, Set<String>> capabilityIdsByService =
        const <String, Set<String>>{},
  }) {
    final selectedIds = selectedServiceIds.toSet();
    return <VanRecommendedServiceSetup>[
      for (final service in services)
        if (selectedIds.contains(service.id))
          VanRecommendedServiceSetup.fromRecommendation(
            pack: this,
            recommendation: service,
            capabilityIds:
                capabilityIdsByService[service.id] ??
                service.recommendedCapabilityIds.toSet(),
          ),
    ];
  }
}

class VanBusinessSearchAlias {
  const VanBusinessSearchAlias(this.label, {this.keywords = const <String>[]});

  final String label;
  final List<String> keywords;
}

class VanBusinessSearchResult {
  const VanBusinessSearchResult({required this.pack, required this.label});

  final VanStarterCapabilityPack pack;
  final String label;
}

class VanBusinessServiceRecommendation {
  const VanBusinessServiceRecommendation({
    required this.id,
    required this.name,
    required this.description,
    required this.recommendedCapabilityIds,
    this.journeyType = VanCustomerJourneyType.quote,
    this.requestType = VanCustomerRequestType.quoteRequest,
    this.startHandover,
    this.endHandover,
    this.requestFlowOptions,
    this.builtInQuestionKeys = const <String>{},
    this.builtInQuestionSettings = const <String, Map<String, dynamic>>{},
    this.questions = const <VanServiceTemplateQuestion>[],
    this.extras = const <VanServiceTemplateExtra>[],
    this.availability = const <VanTemplateDayAvailability>[],
    this.suggestedDurationMinutes,
    this.suggestedNoticeHours = 24,
    this.maximumBookingsPerDay = 8,
    this.suggestedCustomerMessage = '',
    this.suggestedStatusNames = const <String, String>{},
    this.suggestedReminderMinutes = const <int>[],
    this.requestPhotos = false,
    this.requireAddress = false,
    this.pricingMode = VanServiceCapabilityIds.customQuote,
    this.iconKey,
    this.colorValue,
  });

  final String id;
  final String name;
  final String description;
  final List<String> recommendedCapabilityIds;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions? requestFlowOptions;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requestPhotos;
  final bool requireAddress;
  final String pricingMode;
  final String? iconKey;
  final int? colorValue;
}

class VanRecommendedServiceSetup {
  const VanRecommendedServiceSetup({
    required this.packId,
    required this.packName,
    required this.capabilityIds,
    required this.serviceKey,
    required this.name,
    required this.description,
    required this.category,
    required this.iconKey,
    required this.colorValue,
    required this.journeyType,
    required this.requestType,
    required this.startHandover,
    required this.endHandover,
    required this.requestFlowOptions,
    required this.questions,
    required this.extras,
    required this.availability,
    required this.suggestedDurationMinutes,
    required this.suggestedNoticeHours,
    required this.maximumBookingsPerDay,
    required this.suggestedCustomerMessage,
    required this.suggestedStatusNames,
    required this.suggestedReminderMinutes,
    required this.requireAddress,
    required this.requestPhotos,
    required this.builtInQuestionKeys,
    required this.builtInQuestionSettings,
    required this.pricingMode,
  });

  factory VanRecommendedServiceSetup.fromRecommendation({
    required VanStarterCapabilityPack pack,
    required VanBusinessServiceRecommendation recommendation,
    required Set<String> capabilityIds,
  }) {
    final explicitIds =
        capabilityIds
            .where((id) => findVanServiceCapability(id) != null)
            .toList(growable: false)
          ..sort();
    return VanRecommendedServiceSetup(
      packId: pack.id,
      packName: pack.name,
      capabilityIds: explicitIds,
      serviceKey: recommendation.id,
      name: recommendation.name,
      description: recommendation.description,
      category: pack.category,
      iconKey: recommendation.iconKey ?? pack.iconKey,
      colorValue: recommendation.colorValue ?? pack.colorValue,
      journeyType: recommendation.journeyType,
      requestType: recommendation.requestType,
      startHandover: recommendation.startHandover,
      endHandover: recommendation.endHandover,
      requestFlowOptions:
          recommendation.requestFlowOptions ??
          VanCustomerRequestFlowOptions.defaultsFor(recommendation.requestType),
      questions: List<VanServiceTemplateQuestion>.unmodifiable(
        recommendation.questions,
      ),
      extras: List<VanServiceTemplateExtra>.unmodifiable(recommendation.extras),
      availability: List<VanTemplateDayAvailability>.unmodifiable(
        recommendation.availability,
      ),
      suggestedDurationMinutes: recommendation.suggestedDurationMinutes,
      suggestedNoticeHours: recommendation.suggestedNoticeHours,
      maximumBookingsPerDay: recommendation.maximumBookingsPerDay,
      suggestedCustomerMessage: recommendation.suggestedCustomerMessage,
      suggestedStatusNames: Map<String, String>.unmodifiable(
        recommendation.suggestedStatusNames,
      ),
      suggestedReminderMinutes: List<int>.unmodifiable(
        recommendation.suggestedReminderMinutes,
      ),
      requireAddress: recommendation.requireAddress,
      requestPhotos: recommendation.requestPhotos,
      builtInQuestionKeys: Set<String>.unmodifiable(
        recommendation.builtInQuestionKeys,
      ),
      builtInQuestionSettings: Map<String, Map<String, dynamic>>.unmodifiable({
        for (final entry in recommendation.builtInQuestionSettings.entries)
          entry.key: Map<String, dynamic>.unmodifiable(entry.value),
      }),
      pricingMode: recommendation.pricingMode,
    );
  }

  final String packId;
  final String packName;
  final List<String> capabilityIds;
  final String serviceKey;
  final String name;
  final String description;
  final String category;
  final String iconKey;
  final int colorValue;
  final VanCustomerJourneyType journeyType;
  final VanCustomerRequestType requestType;
  final VanStartHandover? startHandover;
  final VanEndHandover? endHandover;
  final VanCustomerRequestFlowOptions requestFlowOptions;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final List<VanTemplateDayAvailability> availability;
  final int? suggestedDurationMinutes;
  final int suggestedNoticeHours;
  final int maximumBookingsPerDay;
  final String suggestedCustomerMessage;
  final Map<String, String> suggestedStatusNames;
  final List<int> suggestedReminderMinutes;
  final bool requireAddress;
  final bool requestPhotos;
  final Set<String> builtInQuestionKeys;
  final Map<String, Map<String, dynamic>> builtInQuestionSettings;
  final String pricingMode;

  bool get allowCustomerDropOff =>
      startHandover == VanStartHandover.customerDropsOff;
  bool get allowBusinessCollection =>
      startHandover == VanStartHandover.businessCollects;
  bool get allowCustomerCollection =>
      endHandover == VanEndHandover.customerCollects;
  bool get allowBusinessReturn => endHandover == VanEndHandover.businessReturns;
  bool get allowBusinessDelivery =>
      endHandover == VanEndHandover.businessDelivers;

  VanQuoteExtraDefaults quoteExtraDefaults() {
    var defaults = VanQuoteExtraDefaults.empty();
    for (final extra in extras.where(
      (item) => isVanQuoteBuiltInExtraKey(item.key),
    )) {
      defaults = defaults.copyWithExtra(
        VanQuoteExtraDefault.fallback(extra.key).copyWith(
          label: extra.label,
          defaultPrice: extra.defaultPrice,
          enabled: extra.enabledByDefault,
        ),
      );
    }
    return defaults.copyWithCustomExtras(<VanQuoteExtraDefault>[
      for (final extra in extras)
        if (!isVanQuoteBuiltInExtraKey(extra.key))
          VanQuoteExtraDefault.custom(
            key: extra.key,
            label: extra.label,
            defaultPrice: extra.defaultPrice,
            enabled: extra.enabledByDefault,
          ),
    ]);
  }
}

VanStarterCapabilityPack _packFromDefinition(
  VanBusinessTemplateDefinition definition,
) {
  return VanStarterCapabilityPack(
    id: definition.businessTypeId,
    name: definition.businessTypeName,
    description: definition.description,
    category: definition.categoryName,
    iconKey: definition.iconKey,
    colorValue: definition.colorValue,
    featured: definition.featured,
    searchKeywords: definition.searchKeywords,
    searchAliases: definition.searchAliases,
    services: <VanBusinessServiceRecommendation>[
      for (final service in definition.services)
        VanBusinessServiceRecommendation(
          id: service.serviceId,
          name: service.name,
          description: service.description,
          recommendedCapabilityIds: <String>{
            ...service.featureIds,
            ...service.bookingOptionIds,
          }.toList(growable: false),
          journeyType: service.customerJourney,
          requestType: service.requestType,
          startHandover: service.startHandover,
          endHandover: service.endHandover,
          requestFlowOptions: service.requestFlowOptions,
          builtInQuestionKeys: service.builtInQuestionKeys,
          builtInQuestionSettings: service.builtInQuestionSettings,
          questions: service.questions,
          extras: service.extras,
          availability: service.availability,
          suggestedDurationMinutes: service.suggestedDurationMinutes,
          suggestedNoticeHours: service.suggestedNoticeHours,
          maximumBookingsPerDay: service.maximumBookingsPerDay,
          suggestedCustomerMessage: service.suggestedCustomerMessage,
          suggestedStatusNames: service.suggestedStatusNames,
          suggestedReminderMinutes: service.suggestedReminderMinutes,
          requestPhotos: service.requestPhotos,
          requireAddress: service.requireAddress,
          pricingMode: service.pricingMode,
        ),
    ],
  );
}

final List<VanStarterCapabilityPack> kVanStarterCapabilityPacks =
    List<VanStarterCapabilityPack>.unmodifiable(
      kVanBusinessTemplateLibrary.map(_packFromDefinition),
    );

VanStarterCapabilityPack? findVanStarterCapabilityPackById(String id) {
  final normalized = id.trim();
  if (normalized.isEmpty) return null;
  for (final pack in kVanStarterCapabilityPacks) {
    if (pack.id == normalized) return pack;
  }
  return null;
}

List<VanBusinessSearchResult> searchVanStarterCapabilityPacks(String query) {
  final normalized = _normalizeSearch(query);
  if (normalized.isEmpty) return const <VanBusinessSearchResult>[];
  final results = <VanBusinessSearchResult>[];
  for (final pack in kVanStarterCapabilityPacks) {
    final terms = <String>[
      pack.name,
      pack.description,
      pack.category,
      ...pack.searchKeywords,
    ].map(_normalizeSearch);
    if (terms.any((term) => term.contains(normalized))) {
      results.add(VanBusinessSearchResult(pack: pack, label: pack.name));
      continue;
    }
    for (final alias in pack.searchAliases) {
      final aliasTerms = <String>[
        alias.label,
        ...alias.keywords,
      ].map(_normalizeSearch);
      if (aliasTerms.any((term) => term.contains(normalized))) {
        results.add(VanBusinessSearchResult(pack: pack, label: alias.label));
        break;
      }
    }
  }
  return List<VanBusinessSearchResult>.unmodifiable(results);
}

VanStarterCapabilityPack? findBestVanStarterCapabilityPack(String query) {
  final results = searchVanStarterCapabilityPacks(query);
  return results.isEmpty ? null : results.first.pack;
}

String _normalizeSearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
