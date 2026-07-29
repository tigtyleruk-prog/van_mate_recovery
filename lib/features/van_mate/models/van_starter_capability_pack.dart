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

const VanCustomerRequestFlowOptions _gardeningStandardQuoteFlow =
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

const List<VanTemplateDayAvailability> _gardeningMondayToSaturday =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
];

const List<VanTemplateDayAvailability> _petServicesMondayToSaturday =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 2, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 3, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 4, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 5, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 6, startMinutes: 420, endMinutes: 1140),
];

const List<VanTemplateDayAvailability> _petServicesMondayToSunday =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 2, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 3, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 4, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 5, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 6, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 7, startMinutes: 420, endMinutes: 1200),
];

const List<VanTemplateDayAvailability> _petServicesDayCareAvailability =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 420, endMinutes: 1080),
  VanTemplateDayAvailability(day: 2, startMinutes: 420, endMinutes: 1080),
  VanTemplateDayAvailability(day: 3, startMinutes: 420, endMinutes: 1080),
  VanTemplateDayAvailability(day: 4, startMinutes: 420, endMinutes: 1080),
  VanTemplateDayAvailability(day: 5, startMinutes: 420, endMinutes: 1080),
];

const List<VanTemplateDayAvailability> _petServicesBoardingAvailability =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 7, startMinutes: 480, endMinutes: 1080),
];

const VanCustomerRequestFlowOptions _petServicesStandardQuoteFlow =
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

const VanCustomerRequestFlowOptions _windowCleaningStandardQuoteFlow =
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

const VanCustomerRequestFlowOptions _handymanStandardQuoteFlow =
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

const List<VanTemplateDayAvailability> _windowCleaningMondayToSaturday =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
];

const List<VanTemplateDayAvailability> _windowCleaningCommercialAvailability =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 2, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 3, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 4, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 5, startMinutes: 420, endMinutes: 1140),
  VanTemplateDayAvailability(day: 6, startMinutes: 420, endMinutes: 1140),
];

const List<VanTemplateDayAvailability> _handymanMondayToSaturday =
     <VanTemplateDayAvailability>[
   VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
   VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
   VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
   VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
   VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
   VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
  ];

const VanCustomerRequestFlowOptions _photographyStandardQuoteFlow =
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

const List<VanTemplateDayAvailability> _photographyFamilyPortraitAvailability =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 2, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 3, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 4, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 5, startMinutes: 480, endMinutes: 1080),
  VanTemplateDayAvailability(day: 6, startMinutes: 480, endMinutes: 1080),
];

const List<VanTemplateDayAvailability> _photographyEventAvailability =
    <VanTemplateDayAvailability>[
  VanTemplateDayAvailability(day: 1, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 2, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 3, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 4, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 5, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 6, startMinutes: 420, endMinutes: 1200),
  VanTemplateDayAvailability(day: 7, startMinutes: 420, endMinutes: 1200),
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
  VanBusinessTemplateDefinition(
    categoryId: 'gardening',
    categoryName: 'Gardening',
    businessTypeId: 'gardening',
    businessTypeName: 'Gardening',
    description:
        'Domestic and commercial garden maintenance, lawn care and clearance services.',
    iconKey: 'local_florist',
    colorValue: 0xFF4CAF50,
    featured: true,
    searchKeywords: <String>[
      'gardening',
      'lawn mowing',
      'garden maintenance',
      'hedge trimming',
      'garden clearance',
    ],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Lawn care'),
      VanBusinessSearchAlias('Garden care'),
      VanBusinessSearchAlias('Hedge cutting'),
      VanBusinessSearchAlias('Garden tidy'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'gardening_lawn_mowing',
        name: 'Lawn Mowing',
        description:
            'Routine lawn mowing for domestic or small commercial properties.',
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
        requestFlowOptions: _gardeningStandardQuoteFlow,
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
                'Enter the address where the gardening service will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help assess the garden size, access and condition.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_area',
            text: 'What area needs mowing?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Front garden',
              'Back garden',
              'Front and back',
              'Other',
              'Unsure',
            ],
            tags: <String>['gardening', 'lawn', 'area'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_size',
            text: 'Approximately how large is the lawn?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.sizeWeight,
            choiceOptions: <String>[
              'Small',
              'Medium',
              'Large',
              'Very large',
              'Unsure',
            ],
            tags: <String>['gardening', 'lawn', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_condition',
            text: 'How would you describe the current grass?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Regularly maintained',
              'Slightly overgrown',
              'Heavily overgrown',
              'Wet or difficult ground',
              'Unsure',
            ],
            tags: <String>['gardening', 'lawn', 'condition'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_ground',
            text: 'Is the ground flat, sloped or uneven?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Mostly flat',
              'Sloped',
              'Uneven',
              'Mixed',
              'Unsure',
            ],
            tags: <String>['gardening', 'lawn', 'ground', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_access_width',
            text: 'Describe any narrow gates or restricted equipment access',
            helperText: 'Include the narrowest access width where known.',
            answerType: VanCustomQuestionAnswerType.shortText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'lawn', 'access', 'width'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_obstacles',
            text:
                'Are there obstacles, pets or pet waste the gardener should plan around?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.gardening,
            requiredByDefault: false,
            tags: <String>['gardening', 'lawn', 'obstacles', 'pets'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_clippings',
            text: 'What should happen to the grass clippings?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Leave on site',
              'Use the customer\'s garden-waste bin',
              'Business to remove them',
              'Please advise',
            ],
            tags: <String>['gardening', 'lawn', 'clippings', 'waste'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_lawn_parking_access',
            text: 'Parking and access details',
            helperText:
                'Do not provide door, alarm or key-safe codes.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'lawn', 'parking', 'access'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_lawn_mowing_edging',
            label: 'Lawn edging',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_lawn_mowing_strimming_borders',
            label: 'Strimming around borders',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_lawn_mowing_clippings_removal',
            label: 'Clippings removal',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_lawn_mowing_first_overgrown_cut',
            label: 'First cut of heavily overgrown grass',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_lawn_mowing_additional_area',
            label: 'Additional lawn area',
          ),
        ],
        availability: _gardeningMondayToSaturday,
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 6,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Tell us about the lawn area, grass condition and access details. We will review and confirm availability and price.',
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'gardening_maintenance',
        name: 'Garden Maintenance',
        description:
            'A flexible general-maintenance visit covering routine garden tasks.',
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
        requestFlowOptions: _gardeningStandardQuoteFlow,
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
                'Enter the address where the gardening service will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help assess the garden size, access and condition.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_size',
            text: 'Approximately how large is the garden?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.sizeWeight,
            choiceOptions: <String>[
              'Small',
              'Medium',
              'Large',
              'Very large',
              'Unsure',
            ],
            tags: <String>['gardening', 'maintenance', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_main_task',
            text: 'What is the main task for this visit?',
            helperText:
                'Choose the main task. Additional work can be described below or selected as extras.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Lawn mowing',
              'Weeding',
              'Light pruning',
              'Border tidying',
              'Leaf clearance',
              'General tidy',
              'Other',
            ],
            tags: <String>['gardening', 'maintenance', 'task'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_focus_areas',
            text: 'Which areas need the most attention?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.gardening,
            tags: <String>['gardening', 'maintenance', 'focus'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_condition',
            text: 'How would you describe the current condition?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Regularly maintained',
              'Some work needed',
              'Overgrown',
              'Heavily overgrown',
              'Unsure',
            ],
            tags: <String>['gardening', 'maintenance', 'condition'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_frequency',
            text: 'What visit frequency would you prefer?',
            helperText:
                'This records your preference only and does not automatically create recurring bookings.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              'One-off',
              'Weekly',
              'Fortnightly',
              'Every four weeks',
              'Seasonal',
              'Unsure',
            ],
            tags: <String>['gardening', 'maintenance', 'frequency'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_equipment',
            text: 'Who should provide tools and equipment?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Business supplies equipment',
              'Customer has suitable equipment',
              'Please advise',
            ],
            tags: <String>['gardening', 'maintenance', 'equipment'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_green_waste',
            text: 'What should happen to green waste?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Leave on site',
              'Use the customer\'s garden-waste bin',
              'Business to remove it',
              'Please advise',
            ],
            tags: <String>['gardening', 'maintenance', 'waste'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_maintenance_access_issues',
            text: 'Are there access, parking, pet or obstacle issues?',
            helperText:
                'Do not provide door, alarm or key-safe codes.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'maintenance', 'access'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_additional_labour_hour',
            label: 'Additional labour hour',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_lawn_mowing',
            label: 'Lawn mowing',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_weeding',
            label: 'Weeding',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_light_pruning',
            label: 'Light pruning',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_leaf_clearance',
            label: 'Leaf clearance',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_maintenance_green_waste_removal',
            label: 'Green-waste removal',
          ),
        ],
        availability: _gardeningMondayToSaturday,
        suggestedDurationMinutes: 120,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 4,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Tell us about the garden size, condition, preferred tasks and access. We will review and confirm availability and price.',
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'gardening_hedge_trimming',
        name: 'Hedge Trimming',
        description:
            'Hedge trimming and shaping, with access and waste requirements confirmed before work is agreed.',
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
        requestFlowOptions: _gardeningStandardQuoteFlow,
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
                'Enter the address where the gardening service will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help assess hedge size, access and condition.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_count',
            text: 'How many hedges need trimming?',
            helperText: 'Enter the number of separate hedges where possible.',
            answerType: VanCustomQuestionAnswerType.shortText,
            category: VanCustomQuestionCategory.gardening,
            tags: <String>['gardening', 'hedge', 'count'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_combined_length',
            text: 'Approximately what is the combined hedge length?',
            helperText: 'Estimate in metres where possible, or enter Unsure.',
            answerType: VanCustomQuestionAnswerType.shortText,
            category: VanCustomQuestionCategory.gardening,
            tags: <String>['gardening', 'hedge', 'length'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_height',
            text: 'Approximately how high are the hedges?',
            helperText:
                'Taller hedges may require specialist equipment. The business will confirm whether the work can be completed safely.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Under 1.5 metres',
              '1.5–2 metres',
              '2–3 metres',
              'Over 3 metres',
              'Unsure',
            ],
            tags: <String>['gardening', 'hedge', 'height'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_work',
            text: 'What work is required?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Light maintenance trim',
              'Shape and tidy',
              'Significant height or width reduction',
              'Unsure',
            ],
            tags: <String>['gardening', 'hedge', 'work'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_sides_accessible',
            text: 'Which sides are accessible?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Front only',
              'Front and one side',
              'Both sides',
              'Access is restricted',
              'Unsure',
            ],
            tags: <String>['gardening', 'hedge', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_obstacles',
            text:
                'Are there fences, sheds, conservatories, cables, slopes or other obstacles nearby?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.gardening,
            requiredByDefault: false,
            tags: <String>['gardening', 'hedge', 'obstacles'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_nesting',
            text: 'Is there any visible active bird nesting or wildlife?',
            helperText:
                'If active nests or protected wildlife are present, the work may need to be postponed or restricted.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Yes',
              'No',
              'Unsure',
            ],
            tags: <String>['gardening', 'hedge', 'wildlife'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_cuttings',
            text: 'What should happen to the hedge cuttings?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Leave on site',
              'Use the customer\'s garden-waste bin',
              'Business to remove them',
              'Please advise',
            ],
            tags: <String>['gardening', 'hedge', 'waste'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_hedge_parking_access',
            text: 'Parking and access details',
            helperText:
                'Do not provide door, alarm or key-safe codes.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'hedge', 'parking', 'access'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_hedge_trimming_additional_length',
            label: 'Additional hedge length',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_hedge_trimming_height_reduction',
            label: 'Significant height reduction',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_hedge_trimming_top_and_both_sides',
            label: 'Trim top and both sides',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_hedge_trimming_green_waste_removal',
            label: 'Green-waste removal',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_hedge_trimming_difficult_access',
            label: 'Difficult-access supplement',
          ),
        ],
        availability: _gardeningMondayToSaturday,
        suggestedDurationMinutes: 120,
        suggestedNoticeHours: 48,
        maximumBookingsPerDay: 3,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Tell us about the hedges, size, access and waste requirements. We will confirm whether we can complete the work safely.',
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'gardening_clearance',
        name: 'Garden Clearance',
        description:
            'A larger one-off garden tidy and clearance service, subject to access, waste type and disposal confirmation.',
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
        requestFlowOptions: _gardeningStandardQuoteFlow,
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
                'Enter the address where the gardening service will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred start time or time window. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help assess the area size, waste type and access.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_area_size',
            text: 'Approximately how large is the area?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Small',
              'Medium',
              'Large',
              'Very large',
              'Unsure',
            ],
            tags: <String>['gardening', 'clearance', 'size'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_main_type',
            text: 'What is the main type of clearance needed?',
            helperText:
                'Choose the main type. Describe any additional materials in the later questions.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Weeds and general growth',
              'Brambles',
              'Fallen leaves or branches',
              'Cuttings and green waste',
              'Old pots or lightweight garden items',
              'Mixed garden waste',
              'Other',
            ],
            tags: <String>['gardening', 'clearance', 'type'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_overgrown',
            text: 'How overgrown is the area?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Light',
              'Moderate',
              'Heavy',
              'Dense or difficult',
              'Unsure',
            ],
            tags: <String>['gardening', 'clearance', 'overgrown'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_waste_amount',
            text: 'Approximately how much waste is expected?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'A few bags',
              'Several bags',
              'Around one small van load',
              'More than one load',
              'Unsure',
            ],
            tags: <String>['gardening', 'clearance', 'waste'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_heavy_lifting',
            text: 'Is heavy lifting likely to be required?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.loading,
            choiceOptions: <String>[
              'Yes',
              'No',
              'Unsure',
            ],
            tags: <String>['gardening', 'clearance', 'lifting'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_heavy_lifting_details',
            text: 'Describe any heavy or awkward items',
            helperText:
                'Include approximate size or weight where known. The business will confirm what it can handle safely.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.loading,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'lifting', 'details'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_access_distance',
            text:
                'What is the access width and distance to the nearest suitable vehicle position?',
            answerType: VanCustomQuestionAnswerType.shortText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_steps_slopes',
            text: 'Are there steps, slopes or restricted-access areas?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'access'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_protected_areas',
            text: 'Are there plants, items or areas that must remain untouched?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.gardening,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'protected'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_restricted_materials',
            text: 'Are any restricted or specialist materials present?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.gardening,
            choiceOptions: <String>[
              'Yes',
              'No',
              'Unsure',
            ],
            tags: <String>['gardening', 'clearance', 'restricted'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_restricted_materials_details',
            text: 'Describe any restricted or specialist materials',
            helperText:
                'Examples include chemicals, paint, fuel, gas cylinders, asbestos or suspected asbestos, clinical or hazardous waste, or significant quantities of soil or rubble. The business must confirm accepted waste and any disposal cost before the job is agreed.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.gardening,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'restricted', 'details'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'gardening_clearance_parking_access',
            text: 'Parking and access details',
            helperText:
                'Do not provide door, alarm or key-safe codes.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['gardening', 'clearance', 'parking', 'access'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_clearance_additional_labour_hour',
            label: 'Additional labour hour',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_clearance_green_waste_removal',
            label: 'Green-waste removal',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_clearance_dense_bramble_clearance',
            label: 'Dense bramble clearance',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_clearance_heavy_item_handling',
            label: 'Heavy-item handling',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_gardening_clearance_additional_waste_load',
            label: 'Additional waste load',
          ),
        ],
        availability: _gardeningMondayToSaturday,
        suggestedDurationMinutes: 240,
        suggestedNoticeHours: 72,
        maximumBookingsPerDay: 2,
        requestPhotos: true,
        requireAddress: true,
        suggestedCustomerMessage:
            'Tell us about the area to clear, waste types and access. The business will confirm accepted waste and disposal costs before accepting.',
      ),
    ],
  ),
  VanBusinessTemplateDefinition(
    categoryId: 'pet_services',
    categoryName: 'Pet Services',
    businessTypeId: 'pet_services',
    businessTypeName: 'Pet Services',
    description:
        'Pet care services including dog walking and drop-in visits.',
    iconKey: 'pets',
    colorValue: 0xFF7E57C2,
    featured: true,
    searchKeywords: <String>[
      'pet services',
      'dog walking',
      'pet sitting',
      'drop-in visits',
      'dog day care',
      'dog boarding',
    ],
    searchAliases: <VanBusinessSearchAlias>[
      VanBusinessSearchAlias('Dog walking'),
      VanBusinessSearchAlias('Pet sitting'),
      VanBusinessSearchAlias('Drop-in visit'),
    ],
    services: <VanBusinessServiceTemplateDefinition>[
      VanBusinessServiceTemplateDefinition(
        serviceId: 'pet_services_dog_walking',
        name: 'Dog Walking',
        description:
            'Dog walking with flexible collection, return, drop-off or collection arrangements, subject to business confirmation.',
        featureIds: <String>[
          VanServiceCapabilityIds.oneOff,
          VanServiceCapabilityIds.businessCollects,
          VanServiceCapabilityIds.businessReturns,
          VanServiceCapabilityIds.customQuote,
          VanServiceCapabilityIds.estimatedDuration,
          VanServiceCapabilityIds.leadTime,
          VanServiceCapabilityIds.photoUpload,
        ],
        bookingOptionIds: <String>[
          VanServiceCapabilityIds.booking,
          VanServiceCapabilityIds.requestQuote,
        ],
        customerJourney: VanCustomerJourneyType.quote,
        requestType: VanCustomerRequestType.dropOffPickupRequest,
        startHandover: VanStartHandover.businessCollects,
        endHandover: VanEndHandover.businessReturns,
        requestFlowOptions: VanCustomerRequestFlowOptions(
          showFulfilmentChoice: false,
          askPreferredDate: false,
          askPreferredTime: false,
          showPickupAddress: false,
          showDeliveryAddress: false,
          showDropOffDate: true,
          showDropOffTime: true,
          showPickUpDate: true,
          showPickUpTime: true,
          showNotes: false,
        ),
        builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
        builtInQuestionSettings: <String, Map<String, dynamic>>{
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help the walker plan the route and identify the dog.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_dog_count',
            text: 'How many dogs need walking?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.items,
            choiceOptions: <String>[
              'One',
              'Two',
              'Three or more',
              'Unsure',
            ],
            tags: <String>['pet services', 'dog walking', 'dog count'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_dog_details',
            text: 'Tell us about the dogs',
            helperText:
                'Include each dog\'s name, breed or type, age and approximate size.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['pet services', 'dog walking', 'dog details'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_walk_duration',
            text: 'What walk duration would you prefer?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              '30 minutes',
              '45 minutes',
              '60 minutes',
              'Another duration',
              'Unsure',
            ],
            tags: <String>['pet services', 'dog walking', 'duration'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_walk_group',
            text: 'What type of walk would you prefer?',
            helperText:
                'The business will confirm what is safe and suitable.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.other,
            choiceOptions: <String>[
              'Solo walk',
              'Group walk is suitable',
              'No preference',
              'Unsure',
            ],
            tags: <String>['pet services', 'dog walking', 'walk group'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_lead_restrictions',
            text: 'What lead arrangement is required?',
            helperText:
                'An off-lead request is subject to the business confirming it is safe and appropriate.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.collection,
            choiceOptions: <String>[
              'Keep on lead',
              'Off lead only in an enclosed area',
              'Owner would like to discuss off-lead walking',
              'Unsure',
            ],
            tags: <String>['pet services', 'dog walking', 'lead'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_behaviour',
            text:
                'Are there any behaviour, handling or escape-risk concerns?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.generalNotes,
            requiredByDefault: false,
            tags: <String>['pet services', 'dog walking', 'behaviour'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_health',
            text:
                'Are there any health, mobility, allergy or medication needs?',
            helperText:
                'The business must confirm whether it can safely meet these needs.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.medicalHandling,
            requiredByDefault: false,
            tags: <String>['pet services', 'dog walking', 'health'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_frequency',
            text: 'How often would you ideally like walks?',
            helperText:
                'This records your preference only and does not automatically create recurring bookings.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            requiredByDefault: false,
            choiceOptions: <String>[
              'One-off',
              'Weekly',
              'Several times a week',
              'Weekdays',
              'Ad hoc',
              'Unsure',
            ],
            tags: <String>['pet services', 'dog walking', 'frequency'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_dog_walking_parking_access',
            text: 'Parking and access information',
            helperText:
                'Do not provide alarm, door or key-safe codes publicly.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>['pet services', 'dog walking', 'parking', 'access'],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_dog_walking_additional_dog',
            label: 'Additional dog from the same household',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_dog_walking_additional_30_minutes',
            label: 'Additional 30 minutes',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_dog_walking_solo_walk',
            label: 'Solo walk',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_dog_walking_weekend_holiday',
            label: 'Weekend or bank-holiday walk',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_dog_walking_towel_dry',
            label: 'Towel dry',
          ),
        ],
        availability: _petServicesMondayToSaturday,
        suggestedDurationMinutes: 60,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 6,
        requestPhotos: true,
        requireAddress: false,
        pricingMode: VanServiceCapabilityIds.customQuote,
        suggestedCustomerMessage:
            'We will confirm the walk arrangements, collection and return details before accepting.',
      ),
      VanBusinessServiceTemplateDefinition(
        serviceId: 'pet_services_drop_in_visit',
        name: 'Pet Drop-in Visit',
        description:
            'Visiting care for pets at the customer\'s home, including agreed feeding, toileting, companionship and basic care.',
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
        requestFlowOptions: _petServicesStandardQuoteFlow,
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
                'Enter the address where the visit will take place.',
          },
          'phone': <String, dynamic>{'required': true, 'helperText': ''},
          'email': <String, dynamic>{'required': false, 'helperText': ''},
          'preferred_date': <String, dynamic>{
            'required': true,
            'helperText': 'Choose your preferred date.',
          },
          'preferred_time': <String, dynamic>{
            'required': true,
            'helperText':
                'Choose a preferred time. The business will confirm availability.',
          },
          'photos': <String, dynamic>{
            'required': false,
            'helperText':
                'Optional photos can help the visitor plan care.',
          },
        },
        questions: <VanServiceTemplateQuestion>[
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_pet_types',
            text: 'What types and how many pets need care?',
            helperText: 'Include the species and number of each pet.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['pet services', 'drop-in', 'pet types'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_pet_details',
            text: 'Tell us their names, ages and care details',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.items,
            tags: <String>['pet services', 'drop-in', 'pet details'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_duration',
            text: 'What visit duration would you prefer?',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            choiceOptions: <String>[
              '15 minutes',
              '30 minutes',
              '45 minutes',
              '60 minutes',
              'Another duration',
              'Unsure',
            ],
            tags: <String>['pet services', 'drop-in', 'duration'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_tasks',
            text: 'What should be done during the visit?',
            helperText:
                'Mention feeding, water, toilet needs, companionship, basic play and comfort checks.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            tags: <String>['pet services', 'drop-in', 'tasks'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_feeding',
            text: 'What are the feeding requirements?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            requiredByDefault: false,
            tags: <String>['pet services', 'drop-in', 'feeding'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_toilet_routine',
            text: 'What is the toilet or litter routine?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.jobDetails,
            requiredByDefault: false,
            tags: <String>['pet services', 'drop-in', 'toilet'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_medication_requested',
            text: 'Will any medication or treatment support be requested?',
            helperText:
                'Listing medication does not mean the business can administer it.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.medicalHandling,
            choiceOptions: <String>[
              'Yes',
              'No',
              'Unsure',
            ],
            tags: <String>['pet services', 'drop-in', 'medication'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_medication_details',
            text: 'Describe the medication or support requested',
            helperText:
                'The business must confirm whether it can safely provide the requested support.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.medicalHandling,
            requiredByDefault: false,
            tags: <String>['pet services', 'drop-in', 'medication details'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_behaviour',
            text: 'Are there any behaviour, handling or escape-risk concerns?',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.generalNotes,
            requiredByDefault: false,
            tags: <String>['pet services', 'drop-in', 'behaviour'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_frequency',
            text: 'What visit frequency would you prefer?',
            helperText:
                'This records your preference only. One submission creates one request and does not create recurring bookings.',
            answerType: VanCustomQuestionAnswerType.multipleChoice,
            category: VanCustomQuestionCategory.timing,
            requiredByDefault: false,
            choiceOptions: <String>[
              'One-off',
              'Daily',
              'Several times a week',
              'Weekly',
              'Holiday cover',
              'Ad hoc',
              'Unsure',
            ],
            tags: <String>['pet services', 'drop-in', 'frequency'],
          ),
          VanServiceTemplateQuestion(
            libraryId: 'pet_services_drop_in_visit_parking_access',
            text: 'Parking and property access information',
            helperText:
                'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
            answerType: VanCustomQuestionAnswerType.longText,
            category: VanCustomQuestionCategory.access,
            requiredByDefault: false,
            tags: <String>[
              'pet services',
              'drop-in',
              'parking',
              'access',
            ],
          ),
        ],
        extras: <VanServiceTemplateExtra>[
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_drop_in_visit_additional_pet',
            label: 'Additional pet',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_drop_in_visit_additional_15_minutes',
            label: 'Additional 15 minutes',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_drop_in_visit_short_dog_walk',
            label: 'Short dog walk',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_drop_in_visit_litter_tray_cleaning',
            label: 'Litter-tray cleaning',
          ),
          VanServiceTemplateExtra(
            key: 'custom_extra_pet_services_drop_in_visit_weekend_holiday',
            label: 'Weekend or bank-holiday visit',
          ),
        ],
        availability: _petServicesMondayToSunday,
        suggestedDurationMinutes: 30,
        suggestedNoticeHours: 24,
        maximumBookingsPerDay: 8,
        requestPhotos: true,
        requireAddress: true,
        pricingMode: VanServiceCapabilityIds.customQuote,
         suggestedCustomerMessage:
             'We will confirm the visit details, feeding and care requirements before accepting.',
       ),
       VanBusinessServiceTemplateDefinition(
         serviceId: 'pet_services_dog_day_care',
         name: 'Dog Day Care',
         description:
             'Same-day care for dogs, including agreed supervision, exercise, rest and feeding.',
         featureIds: <String>[
           VanServiceCapabilityIds.oneOff,
           VanServiceCapabilityIds.customerDropsOff,
           VanServiceCapabilityIds.customerCollects,
           VanServiceCapabilityIds.customQuote,
           VanServiceCapabilityIds.estimatedDuration,
           VanServiceCapabilityIds.leadTime,
           VanServiceCapabilityIds.photoUpload,
         ],
         bookingOptionIds: <String>[
           VanServiceCapabilityIds.booking,
           VanServiceCapabilityIds.requestQuote,
         ],
         customerJourney: VanCustomerJourneyType.quote,
         requestType: VanCustomerRequestType.dropOffPickupRequest,
         startHandover: VanStartHandover.customerDropsOff,
         endHandover: VanEndHandover.customerCollects,
         requestFlowOptions: VanCustomerRequestFlowOptions(
           showFulfilmentChoice: false,
           askPreferredDate: false,
           askPreferredTime: false,
           showPickupAddress: false,
           showDeliveryAddress: false,
           showDropOffDate: true,
           showDropOffTime: true,
           showPickUpDate: true,
           showPickUpTime: true,
           showNotes: false,
         ),
         builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
         builtInQuestionSettings: <String, Map<String, dynamic>>{
           'phone': <String, dynamic>{'required': true, 'helperText': ''},
           'email': <String, dynamic>{'required': false, 'helperText': ''},
           'photos': <String, dynamic>{
             'required': false,
             'helperText':
                 'Optional photos can help the carer plan the day.',
           },
         },
         questions: <VanServiceTemplateQuestion>[
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_dog_details',
             text: 'Tell us about the dog',
             helperText:
                 'Include name, breed/type, age and approximate size.',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             tags: <String>['pet services', 'day care', 'dog details'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_previous_attendance',
             text: 'Has the dog attended day care before?',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.items,
             choiceOptions: <String>[
               'Regularly attends day care',
               'Has attended before',
               'First time',
               'Unsure',
             ],
             tags: <String>['pet services', 'day care', 'attendance'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_vaccination_records',
             text: 'Can vaccination records be provided if required?',
             helperText:
                 'The business will confirm its own requirements. This does not guarantee acceptance.',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.medicalHandling,
             choiceOptions: <String>[
               'Yes',
               'No',
               'Unsure',
             ],
             tags: <String>['pet services', 'day care', 'vaccination'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_social_behaviour',
             text:
                 'How does the dog behave around other dogs and people?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.generalNotes,
             tags: <String>['pet services', 'day care', 'behaviour'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_behaviour_concerns',
             text:
                 'Are there any behaviour, separation, resource-guarding or escape-risk concerns?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.generalNotes,
             requiredByDefault: false,
             tags: <String>['pet services', 'day care', 'behaviour concerns'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_feeding',
             text: 'Are there any feeding requirements?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             requiredByDefault: false,
             tags: <String>['pet services', 'day care', 'feeding'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_health',
             text: 'Are there any health, allergy or medication needs?',
             helperText:
                 'The business must confirm whether it can safely meet these needs.',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.medicalHandling,
             choiceOptions: <String>[
               'Yes',
               'No',
               'Unsure',
             ],
             tags: <String>['pet services', 'day care', 'health'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_health_details',
             text: 'Describe any health or medication needs',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.medicalHandling,
             requiredByDefault: false,
             tags: <String>['pet services', 'day care', 'health details'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_rest_routine',
             text: 'Does the dog need a rest, crate or settling routine?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             requiredByDefault: false,
             tags: <String>['pet services', 'day care', 'rest routine'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_day_care_items',
             text:
                 'What items are being brought, and is there any essential safe-care information?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             requiredByDefault: false,
             tags: <String>['pet services', 'day care', 'items'],
           ),
         ],
         extras: <VanServiceTemplateExtra>[
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_day_care_additional_dog',
             label: 'Additional dog from the same household',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_day_care_extended_care_hour',
             label: 'Extended-care hour',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_day_care_meal_preparation',
             label: 'Meal preparation',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_day_care_medication_support',
             label: 'Medication support, subject to agreement',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_day_care_weekend_holiday',
             label: 'Weekend or bank-holiday care',
           ),
         ],
         availability: _petServicesDayCareAvailability,
         suggestedDurationMinutes: 480,
         suggestedNoticeHours: 48,
         maximumBookingsPerDay: 4,
         requestPhotos: true,
         requireAddress: false,
         pricingMode: VanServiceCapabilityIds.customQuote,
         suggestedCustomerMessage:
             'We will confirm the day care arrangements and suitability before accepting.',
       ),
       VanBusinessServiceTemplateDefinition(
         serviceId: 'pet_services_dog_boarding',
         name: 'Dog Boarding',
         description:
             'Overnight or multi-day care for dogs, with routines, suitability and care requirements reviewed before confirmation.',
         featureIds: <String>[
           VanServiceCapabilityIds.oneOff,
           VanServiceCapabilityIds.customerDropsOff,
           VanServiceCapabilityIds.customerCollects,
           VanServiceCapabilityIds.customQuote,
           VanServiceCapabilityIds.leadTime,
           VanServiceCapabilityIds.photoUpload,
         ],
         bookingOptionIds: <String>[
           VanServiceCapabilityIds.booking,
           VanServiceCapabilityIds.requestQuote,
         ],
         customerJourney: VanCustomerJourneyType.quote,
         requestType: VanCustomerRequestType.dropOffPickupRequest,
         startHandover: VanStartHandover.customerDropsOff,
         endHandover: VanEndHandover.customerCollects,
         requestFlowOptions: VanCustomerRequestFlowOptions(
           showFulfilmentChoice: false,
           askPreferredDate: false,
           askPreferredTime: false,
           showPickupAddress: false,
           showDeliveryAddress: false,
           showDropOffDate: true,
           showDropOffTime: true,
           showPickUpDate: true,
           showPickUpTime: true,
           showNotes: false,
         ),
         builtInQuestionKeys: <String>{'phone', 'email', 'photos'},
         builtInQuestionSettings: <String, Map<String, dynamic>>{
           'phone': <String, dynamic>{'required': true, 'helperText': ''},
           'email': <String, dynamic>{'required': false, 'helperText': ''},
           'photos': <String, dynamic>{
             'required': false,
             'helperText':
                 'Optional photos can help the boarder plan care.',
           },
         },
         questions: <VanServiceTemplateQuestion>[
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_dog_count',
             text: 'How many dogs need boarding?',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.items,
             choiceOptions: <String>[
               'One',
               'Two',
               'Three or more',
               'Unsure',
             ],
             tags: <String>['pet services', 'boarding', 'dog count'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_dog_details',
             text: 'Tell us about the dogs',
             helperText:
                 'Include names, breeds/types, ages, sizes and temperament.',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             tags: <String>['pet services', 'boarding', 'dog details'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_previous_stay',
             text: 'Has the dog stayed in boarding before?',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.items,
             choiceOptions: <String>[
               'Boards regularly',
               'Has boarded before',
               'First time',
               'Unsure',
             ],
             tags: <String>['pet services', 'boarding', 'previous stay'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_vaccination_records',
             text: 'Can vaccination or health records be provided if required?',
             helperText:
                 'The business will confirm its own requirements. This does not guarantee acceptance.',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.medicalHandling,
             choiceOptions: <String>[
               'Yes',
               'No',
               'Unsure',
             ],
             tags: <String>['pet services', 'boarding', 'vaccination'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_social_behaviour',
             text:
                 'How is the dog around dogs, cats, children and unfamiliar people?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.generalNotes,
             tags: <String>['pet services', 'boarding', 'social behaviour'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_feeding_routine',
             text: 'What is the dog\'s feeding routine?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             tags: <String>['pet services', 'boarding', 'feeding routine'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_sleeping_routine',
             text: 'Does the dog need a sleeping or crate routine?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             requiredByDefault: false,
             tags: <String>['pet services', 'boarding', 'sleeping routine'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_exercise_toilet',
             text: 'What is the dog\'s exercise and toilet routine?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             tags: <String>['pet services', 'boarding', 'exercise toilet'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_behaviour_concerns',
             text: 'Are there any behaviour or escape-risk concerns?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.generalNotes,
             requiredByDefault: false,
             tags: <String>['pet services', 'boarding', 'behaviour concerns'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_health',
             text: 'Are there any health, allergy or medication needs?',
             helperText:
                 'The business must confirm whether it can safely meet these needs.',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.medicalHandling,
             choiceOptions: <String>[
               'Yes',
               'No',
               'Unsure',
             ],
             tags: <String>['pet services', 'boarding', 'health'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_health_details',
             text: 'Describe any health or medication needs',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.medicalHandling,
             requiredByDefault: false,
             tags: <String>['pet services', 'boarding', 'health details'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_items',
             text: 'What items are being brought?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.items,
             requiredByDefault: false,
             tags: <String>['pet services', 'boarding', 'items'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_emergency_contact',
             text:
                 'Can emergency-contact and veterinary details be supplied if the booking proceeds?',
             helperText:
                 'These details can be arranged privately after the booking is accepted.',
             answerType: VanCustomQuestionAnswerType.multipleChoice,
             category: VanCustomQuestionCategory.medicalHandling,
             choiceOptions: <String>[
               'Yes',
               'No',
               'Unsure',
             ],
             tags: <String>['pet services', 'boarding', 'emergency contact'],
           ),
           VanServiceTemplateQuestion(
             libraryId: 'pet_services_dog_boarding_safe_care_info',
             text: 'Is there any essential safe-care information?',
             answerType: VanCustomQuestionAnswerType.longText,
             category: VanCustomQuestionCategory.generalNotes,
             requiredByDefault: false,
             tags: <String>['pet services', 'boarding', 'safe care info'],
           ),
         ],
         extras: <VanServiceTemplateExtra>[
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_boarding_additional_dog',
             label: 'Additional dog from the same household',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_boarding_additional_night',
             label: 'Additional night',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_boarding_special_feeding',
             label: 'Special feeding preparation',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_boarding_medication_support',
             label: 'Medication support, subject to agreement',
           ),
           VanServiceTemplateExtra(
             key: 'custom_extra_pet_services_dog_boarding_weekend_holiday',
             label: 'Weekend or bank-holiday boarding',
           ),
         ],
         availability: _petServicesBoardingAvailability,
         suggestedNoticeHours: 72,
         maximumBookingsPerDay: 3,
         requestPhotos: true,
         requireAddress: false,
         pricingMode: VanServiceCapabilityIds.customQuote,
         suggestedCustomerMessage:
              'We will confirm the boarding suitability and routines before accepting.',
        ),
      ],
    ),
    VanBusinessTemplateDefinition(
      categoryId: 'window_cleaning',
      categoryName: 'Window Cleaning',
      businessTypeId: 'window_cleaning',
      businessTypeName: 'Window Cleaning',
      description:
          'Domestic and commercial window and conservatory cleaning services.',
      iconKey: 'home',
      colorValue: 0xFF29B6F4,
      featured: true,
      searchKeywords: <String>[
        'window cleaning',
        'domestic window cleaning',
        'commercial window cleaning',
        'shopfront cleaning',
        'conservatory cleaning',
        'one-off window cleaning',
      ],
      searchAliases: <VanBusinessSearchAlias>[
        VanBusinessSearchAlias('Window cleaner'),
        VanBusinessSearchAlias('Domestic window cleaner'),
        VanBusinessSearchAlias('Shopfront cleaner'),
        VanBusinessSearchAlias('Commercial window cleaner'),
        VanBusinessSearchAlias('Conservatory cleaning'),
        VanBusinessSearchAlias('One-off window cleaning'),
      ],
      services: <VanBusinessServiceTemplateDefinition>[
        VanBusinessServiceTemplateDefinition(
          serviceId: 'window_cleaning_domestic',
          name: 'Domestic Window Cleaning',
          description:
              'Routine window cleaning for houses, flats and other domestic properties, subject to safe access and scope confirmation.',
          featureIds: <String>[
            VanServiceCapabilityIds.appointmentRequired,
            VanServiceCapabilityIds.businessVisitsCustomer,
            VanServiceCapabilityIds.customQuote,
            VanServiceCapabilityIds.estimatedDuration,
            VanServiceCapabilityIds.leadTime,
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
          requestFlowOptions: _windowCleaningStandardQuoteFlow,
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
                  'Optional photos can show the window condition, access issues or priority areas. Avoid including private documents or sensitive information.',
            },
          },
          questions: <VanServiceTemplateQuestion>[
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_property_type',
              text: 'What type of property is it?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.property,
              choiceOptions: <String>[
                'House',
                'Bungalow',
                'Flat or maisonette',
                'Other',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'domestic', 'property'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_storeys',
              text: 'How many storeys need window cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.access,
              choiceOptions: <String>[
                'Ground floor only',
                'Two storeys',
                'Three storeys or more',
                'Unsure',
              ],
              helperText:
                  'Higher or difficult-to-reach windows are subject to the business confirming safe access.',
              tags: <String>['window cleaning', 'domestic', 'storeys', 'access'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_window_count',
              text: 'Approximately how many windows need cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.sizeWeight,
              choiceOptions: <String>[
                'Up to 10',
                '11–20',
                '21–30',
                'More than 30',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'domestic', 'window count'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_inside_outside',
              text: 'Which areas need cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Outside only',
                'Inside only',
                'Inside and outside',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'domestic', 'inside', 'outside'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_frames_sills',
              text: 'Should frames and sills be included?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Yes',
                'No',
                'Please advise',
              ],
              tags: <String>['window cleaning', 'domestic', 'frames', 'sills'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_condition',
              text: 'How would you describe the current condition?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'Regularly maintained',
                'Moderate dirt or marks',
                'Heavy buildup',
                'Specialist residue may be present',
                'Unsure',
              ],
              helperText:
                  'Paint, cement, adhesive, mineral deposits or other specialist residue may require separate assessment and may not be removable.',
              tags: <String>['window cleaning', 'domestic', 'condition'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_access_issues',
              text: 'Are there any access or safety issues around the windows?',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Examples may include locked gates, narrow side access, extensions or conservatories below windows, sloping or uneven ground, overhead cables, or windows above fragile surfaces. Do not include door, alarm or key-safe codes.',
              tags: <String>['window cleaning', 'domestic', 'access', 'safety'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_frequency',
              text: 'How often would you ideally like the windows cleaned?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.timing,
              choiceOptions: <String>[
                'One-off',
                'Every four weeks',
                'Every six to eight weeks',
                'Quarterly',
                'Ad hoc',
                'Unsure',
              ],
              helperText:
                  'This records your preference only and does not automatically create recurring bookings.',
              tags: <String>['window cleaning', 'domestic', 'frequency'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_domestic_parking_access',
              text: 'Parking and access information',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
              tags: <String>['window cleaning', 'domestic', 'parking', 'access'],
            ),
          ],
          extras: <VanServiceTemplateExtra>[
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_domestic_interior_windows',
              label: 'Interior windows',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_domestic_frames_sills',
              label: 'Frames and sills',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_domestic_patio_doors',
              label: 'Patio or French doors',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_domestic_skylights',
              label: 'Skylights, subject to safe access',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_domestic_first_clean',
              label: 'First clean or heavy buildup',
            ),
          ],
          availability: _windowCleaningMondayToSaturday,
          suggestedDurationMinutes: 90,
          suggestedNoticeHours: 24,
          maximumBookingsPerDay: 6,
          requestPhotos: true,
          requireAddress: true,
          pricingMode: VanServiceCapabilityIds.customQuote,
          suggestedCustomerMessage:
              'Tell us about the property, window type and access. We will confirm the scope and price before accepting.',
        ),
        VanBusinessServiceTemplateDefinition(
          serviceId: 'window_cleaning_commercial',
          name: 'Commercial / Shopfront Window Cleaning',
          description:
              'Window and shopfront cleaning for commercial premises, with access, timing and surface condition confirmed before work is agreed.',
          featureIds: <String>[
            VanServiceCapabilityIds.appointmentRequired,
            VanServiceCapabilityIds.businessVisitsCustomer,
            VanServiceCapabilityIds.customQuote,
            VanServiceCapabilityIds.estimatedDuration,
            VanServiceCapabilityIds.leadTime,
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
          requestFlowOptions: _windowCleaningStandardQuoteFlow,
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
                  'Optional photos can show the window condition, access issues or priority areas. Avoid including private documents or sensitive information.',
            },
          },
          questions: <VanServiceTemplateQuestion>[
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_premises_type',
              text: 'What type of premises needs cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.property,
              choiceOptions: <String>[
                'Shopfront',
                'Office',
                'Salon, café or restaurant',
                'Small commercial property',
                'Other',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'commercial', 'premises'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_areas',
              text: 'Which glass areas need cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Outside only',
                'Inside only',
                'Inside and outside',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'commercial', 'areas'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_frontage_size',
              text: 'Approximately how much window frontage is there?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.sizeWeight,
              choiceOptions: <String>[
                'Small frontage',
                'Medium frontage',
                'Large frontage',
                'Multiple frontage sections',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'commercial', 'frontage'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_height',
              text: 'At what level are the windows?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.access,
              choiceOptions: <String>[
                'Ground floor only',
                'Ground and first floor',
                'Higher-level windows',
                'Mixed levels',
                'Unsure',
              ],
              helperText:
                  'Higher-level or difficult-access work is subject to the business confirming suitable equipment and safe access.',
              tags: <String>['window cleaning', 'commercial', 'height', 'access'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_condition',
              text: 'How would you describe the current condition?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'Regularly maintained',
                'Fingerprints and general marks',
                'Grease or heavier buildup',
                'Stickers, adhesive or specialist residue',
                'Unsure',
              ],
              helperText:
                  'Specialist residue removal is not guaranteed and may require separate assessment.',
              tags: <String>['window cleaning', 'commercial', 'condition'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_frequency',
              text: 'How often would you ideally like the windows cleaned?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.timing,
              choiceOptions: <String>[
                'One-off',
                'Weekly',
                'Fortnightly',
                'Every four weeks',
                'Ad hoc',
                'Unsure',
              ],
              helperText:
                  'This records your preference only and does not automatically create recurring bookings.',
              tags: <String>['window cleaning', 'commercial', 'frequency'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_service_timing',
              text: 'When would you prefer the work to take place?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.timing,
              choiceOptions: <String>[
                'Before opening',
                'During business hours',
                'After closing',
                'Flexible',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'commercial', 'timing'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_public_access',
              text:
                  'Are there public-access, loading or trading restrictions to consider?',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Examples may include busy pedestrian areas, market days, loading restrictions, customer entrances, outdoor seating, or displays close to the glass.',
              tags: <String>['window cleaning', 'commercial', 'public access'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_signage',
              text: 'Are there signs, displays or equipment close to the windows?',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.jobDetails,
              requiredByDefault: false,
              tags: <String>['window cleaning', 'commercial', 'signage'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_commercial_parking_access',
              text: 'Parking and access information',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
              tags: <String>['window cleaning', 'commercial', 'parking', 'access'],
            ),
          ],
          extras: <VanServiceTemplateExtra>[
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_commercial_interior_glass',
              label: 'Interior glass',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_commercial_frames_sills',
              label: 'Frames and sills',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_commercial_glass_doors',
              label: 'Glass doors',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_commercial_additional_frontage',
              label: 'Additional frontage section',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_commercial_out_of_hours',
              label: 'Out-of-hours visit',
            ),
          ],
          availability: _windowCleaningCommercialAvailability,
          suggestedDurationMinutes: 180,
          suggestedNoticeHours: 24,
          maximumBookingsPerDay: 3,
          requestPhotos: true,
          requireAddress: true,
          pricingMode: VanServiceCapabilityIds.customQuote,
          suggestedCustomerMessage:
              'Tell us about the premises, glass areas and access requirements. We will confirm the scope, timing and price before accepting.',
        ),
        VanBusinessServiceTemplateDefinition(
          serviceId: 'window_cleaning_conservatory',
          name: 'Conservatory Cleaning',
          description:
              'Conservatory glass and panel cleaning, with condition and safe access confirmed before work is agreed.',
          featureIds: <String>[
            VanServiceCapabilityIds.appointmentRequired,
            VanServiceCapabilityIds.businessVisitsCustomer,
            VanServiceCapabilityIds.customQuote,
            VanServiceCapabilityIds.estimatedDuration,
            VanServiceCapabilityIds.leadTime,
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
          requestFlowOptions: _windowCleaningStandardQuoteFlow,
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
                  'Optional photos can show the conservatory size, condition or access issues. Avoid including private documents or sensitive information.',
            },
          },
          questions: <VanServiceTemplateQuestion>[
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_size',
              text: 'Approximately how large is the conservatory?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.sizeWeight,
              choiceOptions: <String>[
                'Small',
                'Medium',
                'Large',
                'Very large',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'conservatory', 'size'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_priority',
              text: 'Which area is the main priority?',
              helperText:
                  'Additional areas can be selected as extras or discussed before the work is agreed.',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Whole exterior',
                'Roof panels',
                'Side glass and doors',
                'Interior glass',
                'Inside and outside',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'conservatory', 'priority'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_roof_material',
              text: 'What is the conservatory roof made from?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Glass',
                'Polycarbonate panels',
                'Mixed materials',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'conservatory', 'roof'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_access',
              text: 'How would you describe access around the conservatory?',
              helperText:
                  'Roof panels and difficult areas are subject to the business confirming safe access and suitable equipment.',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.access,
              choiceOptions: <String>[
                'Clear ground-level access',
                'Restricted side access',
                'Obstacles or extensions affect access',
                'Sloping or uneven ground',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'conservatory', 'access'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_condition',
              text: 'How would you describe the current condition?',
              helperText:
                  'Paint, cement, adhesive, mineral deposits or other specialist residue may require separate assessment and may not be removable.',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'Regularly maintained',
                'General dirt or marks',
                'Algae or heavier buildup',
                'Specialist residue may be present',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'conservatory', 'condition'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_damage',
              text: 'Are there any damaged, loose, leaking or fragile areas?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'Yes',
                'No',
                'Unsure',
              ],
              helperText:
                  'The business must confirm whether the area can be cleaned safely.',
              tags: <String>['window cleaning', 'conservatory', 'damage'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_frequency',
              text: 'How often would you ideally like the conservatory cleaned?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.timing,
              requiredByDefault: false,
              choiceOptions: <String>[
                'One-off',
                'Twice a year',
                'Annually',
                'Ad hoc',
                'Unsure',
              ],
              helperText:
                  'This records your preference only and does not automatically create recurring bookings.',
              tags: <String>['window cleaning', 'conservatory', 'frequency'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_interior_preparation',
              text: 'Are there blinds, furniture or other items close to the interior glass?',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              tags: <String>['window cleaning', 'conservatory', 'interior', 'preparation'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_conservatory_parking_access',
              text: 'Parking and access information',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
              tags: <String>['window cleaning', 'conservatory', 'parking', 'access'],
            ),
          ],
          extras: <VanServiceTemplateExtra>[
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_conservatory_interior_glass',
              label: 'Interior conservatory glass',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_conservatory_frames_sills',
              label: 'Frames and sills',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_conservatory_doors',
              label: 'Conservatory doors',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_conservatory_roof_panels',
              label: 'Roof panels, subject to safe access',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_conservatory_first_clean',
              label: 'First clean or heavy buildup',
            ),
          ],
          availability: _windowCleaningMondayToSaturday,
          suggestedDurationMinutes: 180,
          suggestedNoticeHours: 48,
          maximumBookingsPerDay: 2,
          requestPhotos: true,
          requireAddress: true,
          pricingMode: VanServiceCapabilityIds.customQuote,
          suggestedCustomerMessage:
              'Tell us about the conservatory size, areas, condition and access. We will confirm safe access and scope before accepting.',
        ),
        VanBusinessServiceTemplateDefinition(
          serviceId: 'window_cleaning_one_off',
          name: 'One-off Window Cleaning',
          description:
              'A one-time window clean for moving, property preparation, first cleans or other occasional requirements.',
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
          requestFlowOptions: _windowCleaningStandardQuoteFlow,
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
                  'Optional photos can show the window type, condition and access. Avoid including private documents or sensitive information.',
            },
          },
          questions: <VanServiceTemplateQuestion>[
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_reason',
              text: 'What is the main reason for the clean?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Moving in or out',
                'After building or decorating work',
                'Preparing for a sale or inspection',
                'First clean after a long gap',
                'Other',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'one-off', 'reason'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_property_type',
              text: 'What type of property is it?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.property,
              choiceOptions: <String>[
                'House',
                'Bungalow',
                'Flat or maisonette',
                'Commercial property',
                'Other',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'one-off', 'property'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_storeys',
              text: 'How many storeys need window cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.access,
              choiceOptions: <String>[
                'Ground floor only',
                'Two storeys',
                'Three storeys or more',
                'Unsure',
              ],
              helperText:
                  'Higher or difficult-to-reach windows are subject to the business confirming safe access.',
              tags: <String>['window cleaning', 'one-off', 'storeys', 'access'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_window_count',
              text: 'Approximately how many windows need cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.sizeWeight,
              choiceOptions: <String>[
                'Up to 10',
                '11–20',
                '21–30',
                'More than 30',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'one-off', 'window count'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_areas',
              text: 'Which areas need cleaning?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Outside only',
                'Inside only',
                'Inside and outside',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'one-off', 'areas'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_frames_sills',
              text: 'Should frames and sills be included?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.jobDetails,
              choiceOptions: <String>[
                'Yes',
                'No',
                'Please advise',
              ],
              tags: <String>['window cleaning', 'one-off', 'frames', 'sills'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_condition',
              text: 'How would you describe the current condition?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'General dirt or marks',
                'Heavy buildup',
                'Post-building dust or residue',
                'Paint, adhesive or specialist residue may be present',
                'Unsure',
              ],
              helperText:
                  'Specialist residue removal is not guaranteed and may require separate assessment.',
              tags: <String>['window cleaning', 'one-off', 'condition'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_specialist_residue',
              text: 'Is any paint, cement, adhesive or other specialist residue present?',
              answerType: VanCustomQuestionAnswerType.multipleChoice,
              category: VanCustomQuestionCategory.survey,
              choiceOptions: <String>[
                'Yes',
                'No',
                'Unsure',
              ],
              tags: <String>['window cleaning', 'one-off', 'specialist residue'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_access_safety',
              text: 'Describe any residue, access or safety concerns',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Examples may include restricted gates, extensions below windows, fragile surfaces, sloping ground, overhead cables, or known residue or damaged glass. Do not request security codes.',
              tags: <String>['window cleaning', 'one-off', 'access', 'safety'],
            ),
            VanServiceTemplateQuestion(
              libraryId: 'window_cleaning_one_off_parking_access',
              text: 'Parking and access information',
              answerType: VanCustomQuestionAnswerType.longText,
              category: VanCustomQuestionCategory.access,
              requiredByDefault: false,
              helperText:
                  'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
              tags: <String>['window cleaning', 'one-off', 'parking', 'access'],
            ),
          ],
          extras: <VanServiceTemplateExtra>[
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_one_off_interior_windows',
              label: 'Interior windows',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_one_off_frames_sills',
              label: 'Frames and sills',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_one_off_patio_doors',
              label: 'Patio or French doors',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_one_off_additional_area',
              label: 'Additional window area',
            ),
            VanServiceTemplateExtra(
              key: 'custom_extra_window_cleaning_one_off_first_clean',
              label: 'First clean or heavy buildup',
            ),
          ],
          availability: _windowCleaningMondayToSaturday,
          suggestedDurationMinutes: 90,
          suggestedNoticeHours: 24,
          maximumBookingsPerDay: 6,
          requestPhotos: true,
          requireAddress: true,
          pricingMode: VanServiceCapabilityIds.customQuote,
         suggestedCustomerMessage:
               'Tell us about the property, window type, condition and access. We will confirm the scope and price before accepting.',
         ),
       ],
     ),
     VanBusinessTemplateDefinition(
       categoryId: 'handyman',
       categoryName: 'Handyman & General Services',
       businessTypeId: 'handyman',
       businessTypeName: 'Handyman & General Services',
       description:
           'Small household jobs, furniture assembly, mounting and non-specialist repairs.',
       iconKey: 'home',
       colorValue: 0xFFFFC107,
       featured: true,
       searchKeywords: <String>[
         'handyman',
         'general handyman',
         'odd jobs',
         'household jobs',
         'small repairs',
         'furniture assembly',
         'flat-pack assembly',
         'wall mounting',
         'shelf fitting',
       ],
       searchAliases: <VanBusinessSearchAlias>[
         VanBusinessSearchAlias('Handyman'),
         VanBusinessSearchAlias('General Handyman'),
         VanBusinessSearchAlias('Odd Jobs'),
         VanBusinessSearchAlias('Small Repairs'),
         VanBusinessSearchAlias('Household Fixes'),
         VanBusinessSearchAlias('Flat-Pack Assembly'),
       ],
       services: <VanBusinessServiceTemplateDefinition>[
         VanBusinessServiceTemplateDefinition(
           serviceId: 'handyman_general_visit',
           name: 'General Handyman Visit',
           description:
               'A flexible visit for several small household jobs. The business will confirm what can safely be completed within the agreed visit.',
           featureIds: <String>[
             VanServiceCapabilityIds.appointmentRequired,
             VanServiceCapabilityIds.businessVisitsCustomer,
             VanServiceCapabilityIds.customQuote,
             VanServiceCapabilityIds.estimatedDuration,
             VanServiceCapabilityIds.leadTime,
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
           requestFlowOptions: _handymanStandardQuoteFlow,
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
                   'Enter the address where the work will take place.',
             },
             'phone': <String, dynamic>{'required': true, 'helperText': ''},
             'email': <String, dynamic>{'required': false, 'helperText': ''},
             'preferred_date': <String, dynamic>{
               'required': true,
               'helperText': 'Choose your preferred date.',
             },
             'preferred_time': <String, dynamic>{
               'required': true,
               'helperText':
                   'Choose a preferred start time or time window. The business will confirm availability.',
             },
             'photos': <String, dynamic>{
               'required': false,
               'helperText':
                   'Optional photos can show the work required, available space, fittings and access issues. Avoid including private documents or sensitive information.',
             },
           },
           questions: <VanServiceTemplateQuestion>[
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_task_list',
               text: 'What jobs need doing?',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               helperText:
                   'List each job separately. Electrical, gas, structural, roofing and major plumbing work are not included.',
               tags: <String>['handyman', 'general', 'tasks'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_task_count',
               text: 'Approximately how many separate jobs are there?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'One',
                 'Two or three',
                 'Four or five',
                 'Six or more',
                 'Unsure',
               ],
               tags: <String>['handyman', 'general', 'task count'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_priorities',
               text: 'Which jobs are the highest priority?',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: false,
               helperText:
                   'The business may not be able to complete every requested job in one visit.',
               tags: <String>['handyman', 'general', 'priorities'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_duration_preference',
               text: 'How much time do you think may be needed?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.timing,
               requiredByDefault: false,
               choiceOptions: <String>[
                 'Less than two hours',
                 'Two to four hours',
                 'Half day',
                 'Full day',
                 'Unsure',
               ],
               helperText:
                   'This is a guide only. The business will confirm the expected time after reviewing the work.',
               tags: <String>['handyman', 'general', 'duration'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_materials_responsibility',
               text: 'Who should provide materials and fixings?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Business to supply',
                 'Customer will supply',
                 'Some items are already supplied',
                 'Please advise',
               ],
               tags: <String>['handyman', 'general', 'materials'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_materials_details',
               text: 'Describe any materials, parts or fixings already available',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: false,
               tags: <String>['handyman', 'general', 'materials details'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_workspace',
               text: 'Is the working area ready and accessible?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Clear and ready',
                 'Some items need moving',
                 'Access is restricted',
                 'Unsure',
               ],
               tags: <String>['handyman', 'general', 'workspace'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_specialist_work',
               text: 'Could any requested job involve specialist or regulated work?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Yes',
                 'No',
                 'Unsure',
               ],
               helperText:
                   'This includes electrical, gas, structural, roofing, asbestos-related or major plumbing work. Listing it does not mean the business can undertake it.',
               tags: <String>['handyman', 'general', 'specialist'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_safety_details',
               text: 'Describe any access, height or safety concerns',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: false,
               helperText:
                   'Examples may include: fragile surfaces, restricted working space, heavy items, damaged walls, suspected pipes or cables, work above normal standing height.',
               tags: <String>['handyman', 'general', 'safety'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_general_visit_parking_access',
               text: 'Parking and property access information',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: false,
               helperText:
                   'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
               tags: <String>['handyman', 'general', 'parking', 'access'],
             ),
           ],
           extras: <VanServiceTemplateExtra>[
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_general_visit_additional_hour',
               label: 'Additional labour hour',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_general_visit_half_day',
               label: 'Half-day visit',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_general_visit_materials_fixings',
               label: 'Materials and fixings',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_general_visit_second_person',
               label: 'Second-person assistance, subject to agreement',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_general_visit_small_waste_removal',
               label: 'Small non-hazardous waste removal, subject to agreement',
             ),
           ],
           availability: _handymanMondayToSaturday,
           suggestedDurationMinutes: 120,
           suggestedNoticeHours: 24,
           maximumBookingsPerDay: 4,
           requestPhotos: true,
           requireAddress: true,
           pricingMode: VanServiceCapabilityIds.customQuote,
           suggestedCustomerMessage:
               'Describe the jobs you need done. The business will confirm what can safely be completed within the agreed visit.',
         ),
         VanBusinessServiceTemplateDefinition(
           serviceId: 'handyman_flat_pack_assembly',
           name: 'Flat-Pack Furniture Assembly',
           description:
               'Flat-pack furniture assembly, with item size, parts, working space and any wall-fixing requirements confirmed before work is agreed.',
           featureIds: <String>[
             VanServiceCapabilityIds.appointmentRequired,
             VanServiceCapabilityIds.businessVisitsCustomer,
             VanServiceCapabilityIds.customQuote,
             VanServiceCapabilityIds.estimatedDuration,
             VanServiceCapabilityIds.leadTime,
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
           requestFlowOptions: _handymanStandardQuoteFlow,
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
                   'Enter the address where the assembly will take place.',
             },
             'phone': <String, dynamic>{'required': true, 'helperText': ''},
             'email': <String, dynamic>{'required': false, 'helperText': ''},
             'preferred_date': <String, dynamic>{
               'required': true,
               'helperText': 'Choose your preferred date.',
             },
             'preferred_time': <String, dynamic>{
               'required': true,
               'helperText':
                   'Choose a preferred start time or time window. The business will confirm availability.',
             },
             'photos': <String, dynamic>{
               'required': false,
               'helperText':
                   'Optional photos can show the work required, available space, fittings and access issues. Avoid including private documents or sensitive information.',
             },
           },
           questions: <VanServiceTemplateQuestion>[
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_furniture_type',
               text: 'What is the main item being assembled?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Wardrobe',
                 'Chest of drawers',
                 'Bed frame',
                 'Table or desk',
                 'Shelving or storage unit',
                 'Other',
                 'Unsure',
               ],
               tags: <String>['handyman', 'flat-pack', 'furniture type'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_item_count',
               text: 'How many items need assembling?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'One',
                 'Two',
                 'Three or four',
                 'Five or more',
                 'Unsure',
               ],
               tags: <String>['handyman', 'flat-pack', 'item count'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_product_details',
               text: 'Provide the brand, model or product details where known',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: false,
               helperText:
                   'Product names, model numbers or links can help the business estimate the assembly time.',
               tags: <String>['handyman', 'flat-pack', 'product details'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_current_condition',
               text: 'What condition are the items currently in?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Unopened boxes',
                 'Boxes opened but not assembled',
                 'Partially assembled',
                 'Previously assembled and dismantled',
                 'Mixed',
                 'Unsure',
               ],
               tags: <String>['handyman', 'flat-pack', 'condition'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_parts_available',
               text: 'Are all parts, fittings and instructions available?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Yes',
                 'No',
                 'Unsure',
               ],
               helperText:
                   'Missing or damaged parts may prevent completion.',
               tags: <String>['handyman', 'flat-pack', 'parts'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_workspace',
               text: 'Is there enough clear space for assembly?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Clear working space',
                 'Some furniture needs moving',
                 'Limited working space',
                 'Unsure',
               ],
               tags: <String>['handyman', 'flat-pack', 'workspace'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_wall_fixing',
               text: 'Does any item require fixing to a wall?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Yes',
                 'No',
                 'Unsure',
               ],
               helperText:
                   'Wall fixing is subject to the business confirming the wall condition, item weight and safe drilling location.',
               tags: <String>['handyman', 'flat-pack', 'wall fixing'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_access',
               text: 'Are there stairs, narrow access or large-item restrictions?',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: false,
               tags: <String>['handyman', 'flat-pack', 'access'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_packaging',
               text: 'What should happen to the packaging?',
               answerType: VanCustomQuestionAnswerType.multipleChoice,
               category: VanCustomQuestionCategory.jobDetails,
               requiredByDefault: true,
               choiceOptions: <String>[
                 'Leave it on site',
                 'Use the customer\'s recycling or waste bins',
                 'Business to remove it, subject to agreement',
                 'Please advise',
               ],
               tags: <String>['handyman', 'flat-pack', 'packaging'],
             ),
             VanServiceTemplateQuestion(
               libraryId: 'handyman_flat_pack_parking_access',
               text: 'Parking and property access information',
               answerType: VanCustomQuestionAnswerType.longText,
               category: VanCustomQuestionCategory.access,
               requiredByDefault: false,
               helperText:
                   'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
               tags: <String>['handyman', 'flat-pack', 'parking', 'access'],
             ),
           ],
           extras: <VanServiceTemplateExtra>[
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_flat_pack_additional_item',
               label: 'Additional furniture item',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_flat_pack_additional_hour',
               label: 'Additional assembly hour',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_flat_pack_large_unit',
               label: 'Large wardrobe or storage unit',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_flat_pack_wall_fixing',
               label: 'Wall fixing, subject to safe assessment',
             ),
             VanServiceTemplateExtra(
               key: 'custom_extra_handyman_flat_pack_packaging_removal',
               label: 'Packaging removal',
             ),
           ],
           availability: _handymanMondayToSaturday,
           suggestedDurationMinutes: 90,
           suggestedNoticeHours: 24,
           maximumBookingsPerDay: 4,
           requestPhotos: true,
           requireAddress: true,
           pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Tell us about the furniture to assemble, its condition and any wall-fixing requirements. We will confirm the scope and price before accepting.',
          ),
          VanBusinessServiceTemplateDefinition(
            serviceId: 'handyman_wall_mounting',
            name: 'Shelves, Curtain Poles & Wall Mounting',
            description:
                'Mounting shelves, curtain poles, mirrors, pictures and similar household items, subject to the wall condition, item weight and a safe fixing location being confirmed.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _handymanStandardQuoteFlow,
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
                    'Enter the address where the work will take place.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The business will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional photos can show the work required, available space, fittings and access issues. Avoid including private documents or sensitive information.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_item_type',
                text: 'What is the main item being fitted or mounted?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Shelves',
                  'Curtain pole or blind',
                  'Mirror',
                  'Picture or wall decoration',
                  'Television bracket',
                  'Storage or wall unit',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['handyman', 'wall mounting', 'item type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_item_count',
                text: 'How many items need fitting or mounting?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'One',
                  'Two',
                  'Three or four',
                  'Five or more',
                  'Unsure',
                ],
                tags: <String>['handyman', 'wall mounting', 'item count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_item_details',
                text: 'Describe the items, including approximate size and weight',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                helperText:
                    'Product details, dimensions and approximate weight can help the business assess the work.',
                tags: <String>['handyman', 'wall mounting', 'item details'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_wall_type',
                text: 'What type of wall or surface will the items be fixed to?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Brick or block',
                  'Plasterboard',
                  'Solid plaster',
                  'Tile',
                  'Mixed surfaces',
                  'Unsure',
                ],
                helperText:
                    'The business must confirm the wall condition and suitable fixing method before drilling.',
                tags: <String>['handyman', 'wall mounting', 'wall type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_height',
                text: 'Approximately how high will the items be mounted?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Normal standing height',
                  'Above head height',
                  'Near ceiling height',
                  'Multiple heights',
                  'Unsure',
                ],
                helperText:
                    'Higher work is subject to safe access and suitable equipment.',
                tags: <String>['handyman', 'wall mounting', 'height'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_fixings',
                text: 'Who should provide the brackets, fittings and fixings?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Customer has all fittings and fixings',
                  'Customer has the item but needs fixings',
                  'Business to supply suitable fixings',
                  'Some items are already supplied',
                  'Please advise',
                ],
                tags: <String>['handyman', 'wall mounting', 'fixings'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_hidden_services',
                text: 'Are there any known or suspected pipes, cables or other services behind the wall?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                helperText:
                    'Work may not proceed if a safe drilling location cannot be confirmed.',
                tags: <String>['handyman', 'wall mounting', 'hidden services'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_wall_condition',
                text: 'Are there any cracks, loose plaster, damp, tiles or other wall-condition concerns?',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: false,
                tags: <String>['handyman', 'wall mounting', 'wall condition'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_workspace',
                text: 'Is the working area clear and safely accessible?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Clear and ready',
                  'Some furniture needs moving',
                  'Access is restricted',
                  'Unsure',
                ],
                tags: <String>['handyman', 'wall mounting', 'workspace'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_wall_mounting_parking_access',
                text: 'Parking and property access information',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                helperText:
                    'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
                tags: <String>['handyman', 'wall mounting', 'parking', 'access'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_wall_mounting_additional_item',
                label: 'Additional mounted item',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_wall_mounting_fixings',
                label: 'Suitable fixings, subject to assessment',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_wall_mounting_heavy_item',
                label: 'Heavy or oversized item, subject to assessment',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_wall_mounting_furniture_moving',
                label: 'Furniture moving',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_wall_mounting_additional_hour',
                label: 'Additional labour hour',
              ),
            ],
            availability: _handymanMondayToSaturday,
            suggestedDurationMinutes: 90,
            suggestedNoticeHours: 24,
            maximumBookingsPerDay: 4,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Tell us about the items to mount, their size, weight and the wall type. We will confirm the scope and price before accepting.',
          ),
          VanBusinessServiceTemplateDefinition(
            serviceId: 'handyman_minor_home_repairs',
            name: 'Minor Home Repairs',
            description:
                'Small non-specialist household repairs and adjustments. Electrical, gas, structural, roofing and major plumbing work are not included.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _handymanStandardQuoteFlow,
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
                    'Enter the address where the repair will take place.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The business will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional photos can show the work required, available space, fittings and access issues. Avoid including private documents or sensitive information.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_main_type',
                text: 'What is the main repair needed?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Door, hinge or handle adjustment',
                  'Cupboard or drawer repair',
                  'Loose fitting or fixture',
                  'Sealant or caulking',
                  'Minor cosmetic repair',
                  'Small household adjustment',
                  'Other non-specialist repair',
                  'Unsure',
                ],
                tags: <String>['handyman', 'minor repairs', 'repair type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_description',
                text: 'Describe the problem and what needs repairing',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                helperText:
                    'Include what is damaged, loose, sticking, leaking or no longer working as expected.',
                tags: <String>['handyman', 'minor repairs', 'description'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_item_count',
                text: 'How many separate repairs are required?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'One',
                  'Two',
                  'Three or four',
                  'Five or more',
                  'Unsure',
                ],
                tags: <String>['handyman', 'minor repairs', 'item count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_condition',
                text: 'How would you describe the current condition?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Minor adjustment needed',
                  'Loose or worn',
                  'Damaged but still usable',
                  'Broken or unusable',
                  'Unsure',
                ],
                tags: <String>['handyman', 'minor repairs', 'condition'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_parts_available',
                text: 'Are replacement parts or materials already available?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes, all parts are available',
                  'Some parts are available',
                  'No parts are available',
                  'Unsure',
                  'Please advise',
                ],
                tags: <String>['handyman', 'minor repairs', 'parts available'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_parts_details',
                text: 'Describe any replacement parts or materials already available',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: false,
                tags: <String>['handyman', 'minor repairs', 'parts details'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_specialist_risk',
                text: 'Could the repair involve electrical, gas, structural or major plumbing work?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                helperText:
                    'These jobs require an appropriately qualified specialist and are not included in this service.',
                tags: <String>['handyman', 'minor repairs', 'specialist risk'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_damage_risk',
                text: 'Are there any signs of damp, asbestos, major cracking or hidden damage?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                helperText:
                    'Listing a concern does not mean the business can inspect, disturb or repair hazardous or structural materials.',
                tags: <String>['handyman', 'minor repairs', 'damage risk'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_workspace',
                text: 'Is the repair area clear and safely accessible?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Clear and ready',
                  'Some items need moving',
                  'Access is restricted',
                  'Unsure',
                ],
                tags: <String>['handyman', 'minor repairs', 'workspace'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'handyman_minor_repairs_parking_access',
                text: 'Parking and property access information',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                helperText:
                    'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
                tags: <String>['handyman', 'minor repairs', 'parking', 'access'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_minor_repairs_additional_repair',
                label: 'Additional minor repair',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_minor_repairs_additional_hour',
                label: 'Additional labour hour',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_minor_repairs_parts_materials',
                label: 'Parts and materials',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_minor_repairs_sealant',
                label: 'Sealant or caulking',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_handyman_minor_repairs_small_waste_removal',
                label: 'Small non-hazardous waste removal, subject to agreement',
              ),
            ],
            availability: _handymanMondayToSaturday,
            suggestedDurationMinutes: 60,
            suggestedNoticeHours: 24,
            maximumBookingsPerDay: 6,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Describe the repair needed. The business will confirm what can safely be completed.',
          ),
        ],
      ),
      VanBusinessTemplateDefinition(
        categoryId: 'photography',
        categoryName: 'Photography',
        businessTypeId: 'photography',
        businessTypeName: 'Photography',
        description:
            'Photography services for people, events, properties and products, quoted for each job.',
        iconKey: 'sparkle',
        colorValue: 0xFFFF6E40,
        featured: true,
        searchKeywords: <String>[
          'photography',
          'photographer',
          'portrait photography',
          'family photographer',
          'event photographer',
          'property photographer',
          'product photographer',
          'headshots',
        ],
        searchAliases: <VanBusinessSearchAlias>[
          VanBusinessSearchAlias('Photographer'),
          VanBusinessSearchAlias('Portrait Photography'),
          VanBusinessSearchAlias('Family Photography'),
          VanBusinessSearchAlias('Event Photographer'),
          VanBusinessSearchAlias('Property Photographer'),
          VanBusinessSearchAlias('Product Photographer'),
          VanBusinessSearchAlias('Headshots'),
        ],
        services: <VanBusinessServiceTemplateDefinition>[
          VanBusinessServiceTemplateDefinition(
            serviceId: 'photography_family_portrait',
            name: 'Family & Portrait Photography',
            description:
                'Family, couple, individual and portrait photography at an agreed location, with the session style and requirements confirmed before booking.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _photographyStandardQuoteFlow,
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
                    'Enter the address where the photography session will take place.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The photographer will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional reference images can help show the preferred style, venue, location or important details. Only upload images you are permitted to share.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_shoot_type',
                text: 'What type of photography session would you like?',
                helperText:
                    'Specialist newborn sessions are not automatically included and must be confirmed with the photographer.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Individual portrait',
                  'Couple',
                  'Family',
                  'Children',
                  'Maternity',
                  'Professional headshots',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'shoot type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_people_count',
                text: 'How many people will take part?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'One',
                  'Two',
                  'Three to five',
                  'Six to ten',
                  'More than ten',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'people count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_children',
                text: 'Will anyone under 18 take part?',
                helperText:
                    'A parent or responsible adult must arrange and supervise participation. This does not grant permission for marketing or public use.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'children'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_age_details',
                text: 'Provide approximate age ranges where this may affect the session',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: false,
                helperText:
                    'Do not include children\'s full names, schools or other unnecessary personal information.',
                tags: <String>['photography', 'family portrait', 'age details'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_location_style',
                text: 'What type of location would you prefer?',
                helperText:
                    'Location availability and any required permission must be confirmed before booking.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  "Customer's home",
                  'Outdoor location',
                  "Photographer's studio",
                  'Workplace or business',
                  'Multiple locations',
                  'Please advise',
                ],
                tags: <String>['photography', 'family portrait', 'location'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_visual_style',
                text: 'What style of photographs do you prefer?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Natural and candid',
                  'Posed portraits',
                  'Lifestyle',
                  'Formal',
                  'Professional headshots',
                  'A mixture',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'visual style'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_session_length',
                text: 'What session length would you prefer?',
                helperText:
                    'This is a preference only. The photographer will confirm the recommended session length.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.timing,
                requiredByDefault: false,
                choiceOptions: <String>[
                  'Up to 30 minutes',
                  'Around one hour',
                  'Around 90 minutes',
                  'Two hours or more',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'session length'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_outfit_changes',
                text: 'Are outfit changes planned?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'No',
                  'One change',
                  'Two or more changes',
                  'Unsure',
                ],
                tags: <String>['photography', 'family portrait', 'outfit changes'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_image_requirements',
                text: 'What finished images or formats are you hoping to receive?',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.photos,
                requiredByDefault: false,
                helperText:
                    'Examples: Approximate number of edited images, Digital gallery, High-resolution files, Prints, Social-media images. Do not imply copyright transfer or unrestricted commercial use.',
                tags: <String>['photography', 'family portrait', 'image requirements'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_accessibility',
                text: 'Are there any accessibility, mobility or location requirements?',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                tags: <String>['photography', 'family portrait', 'accessibility'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_family_portrait_parking_access',
                text: 'Parking and location access information',
                helperText:
                    'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                tags: <String>['photography', 'family portrait', 'parking', 'access'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_family_portrait_additional_time',
                label: 'Additional session time',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_family_portrait_additional_images',
                label: 'Additional edited images',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_family_portrait_outfit_change',
                label: 'Additional outfit change',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_family_portrait_additional_location',
                label: 'Additional location',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_family_portrait_express_editing',
                label: 'Express editing, subject to availability',
              ),
            ],
            availability: _photographyFamilyPortraitAvailability,
            suggestedDurationMinutes: 90,
            suggestedNoticeHours: 48,
            maximumBookingsPerDay: 3,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Describe the session style and requirements. The photographer will confirm availability and pricing.',
          ),
          VanBusinessServiceTemplateDefinition(
            serviceId: 'photography_event',
            name: 'Event Photography',
            description:
                'Photography coverage for private, community and business events, with timings, venue restrictions and required coverage agreed beforehand.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _photographyStandardQuoteFlow,
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
                    'Enter the venue address where the event will take place.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The photographer will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional reference images can help show the venue layout, important areas or access points. Only upload images you are permitted to share.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_type',
                text: 'What type of event is it?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Birthday or celebration',
                  'Wedding reception or party',
                  'Community event',
                  'Corporate or business event',
                  'Performance or presentation',
                  'Charity event',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_venue',
                text: 'Describe the venue and event areas',
                helperText:
                    'Include whether the event uses indoor areas, outdoor areas or more than one room.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                tags: <String>['photography', 'event', 'venue'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_coverage_duration',
                text: 'How much photography coverage is required?',
                helperText:
                    'The selected duration is a request only. The photographer will confirm coverage and pricing.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.timing,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Up to one hour',
                  'Two to three hours',
                  'Four to six hours',
                  'More than six hours',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'coverage duration'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_guest_count',
                text: 'Approximately how many guests are expected?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Fewer than 25',
                  '25 to 50',
                  '51 to 100',
                  '101 to 200',
                  'More than 200',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'guest count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_key_moments',
                text: 'Which moments or activities are most important to capture?',
                helperText:
                    'Examples: Guest arrivals, Speeches, Awards, Performances, Cake cutting, Group photographs',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                tags: <String>['photography', 'event', 'key moments'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_indoor_outdoor',
                text: 'Where will photography take place?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Indoors',
                  'Outdoors',
                  'Both indoors and outdoors',
                  'Multiple venue areas',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'indoor outdoor'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_lighting',
                text: 'What are the expected lighting conditions?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Normal indoor lighting',
                  'Low light',
                  'Stage or coloured lighting',
                  'Daylight outdoors',
                  'Evening or night outdoors',
                  'Mixed',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'lighting'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_venue_restrictions',
                text: 'Are there any photography or access restrictions at the venue?',
                helperText:
                    'The customer or organiser should confirm venue permission and relevant restrictions. The photographer is not automatically responsible for arranging them.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'venue restrictions'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_restriction_details',
                text: 'Describe any venue rules, restricted areas or limitations',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                tags: <String>['photography', 'event', 'restriction details'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_delivery_preference',
                text: 'How would you prefer the finished photographs to be delivered?',
                helperText:
                    'Availability, delivery times and privacy settings will be confirmed by the photographer.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.photos,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Private online gallery',
                  'Digital download',
                  'Shared business gallery',
                  'Physical media or prints',
                  'Please advise',
                ],
                tags: <String>['photography', 'event', 'delivery preference'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_image_use',
                text: 'How will the photographs mainly be used?',
                helperText:
                    'Commercial, press or publication use may require a separate agreement. This question does not transfer copyright or provide legal advice.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.photos,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Personal use',
                  'Private organisation use',
                  'Business marketing',
                  'Press or publication',
                  'Social media',
                  'Mixed use',
                  'Unsure',
                ],
                tags: <String>['photography', 'event', 'image use'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_event_parking_access',
                text: 'Parking, loading and venue access information',
                helperText:
                    'Do not provide alarm, door or restricted-access codes publicly. Sensitive arrangements can be agreed privately after acceptance.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                tags: <String>['photography', 'event', 'parking', 'access'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_event_additional_hour',
                label: 'Additional coverage hour',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_event_second_photographer',
                label: 'Second photographer, subject to availability',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_event_express_gallery',
                label: 'Express gallery, subject to availability',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_event_additional_venue_area',
                label: 'Additional venue or coverage area',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_event_print_package',
                label: 'Printed image package',
              ),
            ],
            availability: _photographyEventAvailability,
            suggestedDurationMinutes: 180,
            suggestedNoticeHours: 72,
            maximumBookingsPerDay: 2,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Describe the event type, timings and coverage needed. The photographer will confirm availability and pricing.',
          ),
          VanBusinessServiceTemplateDefinition(
            serviceId: 'photography_property',
            name: 'Property Photography',
            description:
                'Interior and exterior property photography for sales, lettings and business promotion, with the required areas and property readiness agreed beforehand.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _photographyStandardQuoteFlow,
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
                    'Enter the property address where photography will take place.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The photographer will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional reference images can help show the property style, condition or important details. Only upload images you are permitted to share.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_type',
                text: 'What type of property needs photographing?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'House',
                  'Bungalow',
                  'Flat or apartment',
                  'Commercial premises',
                  'Holiday accommodation',
                  'Land or development',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_intended_use',
                text: 'What will the photographs mainly be used for?',
                helperText:
                    'Commercial, press or publication use may require a separate agreement. This question does not transfer copyright or provide legal advice.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Property sale',
                  'Property letting',
                  'Holiday-let listing',
                  'Business website or marketing',
                  'Portfolio or records',
                  'Press or publication',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'intended use'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_occupancy',
                text: 'What will the property\'s condition be during the photography visit?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Empty',
                  'Occupied',
                  'Furnished but unoccupied',
                  'Professionally staged',
                  'Under renovation',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'occupancy'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_size',
                text: 'Approximately how many rooms or main areas need photographing?',
                helperText:
                    'Include main living areas, bedrooms, bathrooms and business rooms where relevant.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Up to five',
                  'Six to ten',
                  'Eleven to fifteen',
                  'More than fifteen',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'size'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_required_areas',
                text: 'Which areas need to be photographed?',
                helperText:
                    'Examples: Main rooms, Kitchen and bathrooms, Exterior, Garden, Outbuildings, Communal spaces, Commercial work areas.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                tags: <String>['photography', 'property', 'required areas'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_exterior_requirements',
                text: 'Is exterior, garden or outbuilding photography required?',
                helperText:
                    'Exterior photography is subject to safe access, suitable conditions and available daylight.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Exterior only',
                  'Garden only',
                  'Exterior and garden',
                  'Outbuildings or additional areas',
                  'No exterior photography',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'exterior'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_readiness',
                text: 'Will the property be ready for photography?',
                helperText:
                    'The photographer is not automatically responsible for cleaning, staging, moving furniture or storing belongings.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Fully prepared',
                  'Minor tidying remains',
                  'Furniture or belongings need moving',
                  'Renovation work is ongoing',
                  'Please advise',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'readiness'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_key_features',
                text: 'Which features are most important to capture?',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: false,
                helperText:
                    'Examples: Views, Kitchen details, Period features, Garden, Workspace, Accessibility features, Recent improvements.',
                tags: <String>['photography', 'property', 'key features'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_people_pets',
                text: 'Will people or pets be present during the visit?',
                helperText:
                    'The customer remains responsible for supervising children, pets and access to occupied areas.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'No',
                  'People will be present',
                  'Pets will be present',
                  'Both people and pets',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'people pets'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_access_restrictions',
                text: 'Are there any restricted, unsafe or unavailable areas?',
                helperText:
                    'The photographer may decline areas that cannot be accessed safely or legally.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Yes',
                  'No',
                  'Unsure',
                ],
                tags: <String>['photography', 'property', 'access restrictions'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_property_parking_access',
                text: 'Parking and property access information',
                helperText:
                    'Do not provide alarm, door or key-safe codes publicly. Sensitive access arrangements can be agreed privately after acceptance.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.access,
                requiredByDefault: false,
                tags: <String>['photography', 'property', 'parking', 'access'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_property_additional_rooms',
                label: 'Additional rooms or areas',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_property_exterior_garden',
                label: 'Exterior and garden coverage',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_property_twilight_session',
                label: 'Twilight session, subject to conditions',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_property_additional_property',
                label: 'Additional property',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_property_express_editing',
                label: 'Express editing, subject to availability',
              ),
            ],
            availability: _photographyFamilyPortraitAvailability,
            suggestedDurationMinutes: 90,
            suggestedNoticeHours: 24,
            maximumBookingsPerDay: 4,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Describe the property type, required areas and readiness. The photographer will confirm availability and pricing.',
          ),
          VanBusinessServiceTemplateDefinition(
            serviceId: 'photography_product',
            name: 'Product Photography',
            description:
                'Product photography for websites, catalogues, marketplaces and marketing, with the products, shoot location and required image style agreed beforehand.',
            featureIds: <String>[
              VanServiceCapabilityIds.appointmentRequired,
              VanServiceCapabilityIds.businessVisitsCustomer,
              VanServiceCapabilityIds.customQuote,
              VanServiceCapabilityIds.estimatedDuration,
              VanServiceCapabilityIds.leadTime,
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
            requestFlowOptions: _photographyStandardQuoteFlow,
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
                    'Enter the proposed shoot location if known. For studio-based work, enter your business or contact address and select the studio option below. The photographer will confirm the final location privately.',
              },
              'phone': <String, dynamic>{'required': true, 'helperText': ''},
              'email': <String, dynamic>{'required': false, 'helperText': ''},
              'preferred_date': <String, dynamic>{
                'required': true,
                'helperText': 'Choose your preferred date.',
              },
              'preferred_time': <String, dynamic>{
                'required': true,
                'helperText':
                    'Choose a preferred start time or time window. The photographer will confirm availability.',
              },
              'photos': <String, dynamic>{
                'required': false,
                'helperText':
                    'Optional reference images can help show the preferred style, venue, location or important details. Only upload images you are permitted to share.',
              },
            },
            questions: <VanServiceTemplateQuestion>[
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_type',
                text: 'What type of products need photographing?',
                helperText:
                    'Restricted, dangerous or specialist products must be discussed and may not be accepted.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Clothing or accessories',
                  'Food or drink',
                  'Jewellery or small valuables',
                  'Furniture or homeware',
                  'Electronics',
                  'Beauty or personal-care products',
                  'Artwork or handmade products',
                  'Other',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'type'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_count',
                text: 'How many different products need photographing?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.customerDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'One',
                  'Two to five',
                  'Six to ten',
                  'Eleven to twenty',
                  'More than twenty',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_image_count',
                text: 'Approximately how many finished images or angles are required per product?',
                helperText:
                    'The photographer will confirm the final image count and editing scope.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'One',
                  'Two or three',
                  'Four to six',
                  'More than six',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'image count'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_size_weight',
                text: 'Describe the approximate size and weight of the products',
                helperText:
                    'Include dimensions or weight where items are large, heavy or difficult to move.',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                tags: <String>['photography', 'product', 'size weight'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_condition',
                text: 'What condition will the products be in?',
                helperText:
                    'Cleaning, repair, assembly and preparation are not automatically included.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'New and presentation-ready',
                  'Packaged',
                  'Used but clean',
                  'Requires unpacking or assembly',
                  'Mixed condition',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'condition'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_location_preference',
                text: 'Where would you prefer the photography to take place?',
                helperText:
                    'The final location and any access requirements must be agreed before booking.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  "Customer's premises",
                  "Photographer's studio",
                  'Business or retail premises',
                  'Outdoor location',
                  'Please advise',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'location'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_background_style',
                text: 'What type of image style or background is required?',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Plain white background',
                  'Plain coloured background',
                  'Transparent or cut-out result',
                  'Lifestyle setting',
                  'Natural environment',
                  'A mixture',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'background style'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_styling_props',
                text: 'Are styling, props or arranged scenes required?',
                helperText:
                    'Styling, specialist props and set construction must be agreed separately.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'No',
                  'Customer will supply everything',
                  'Photographer to supply basic styling',
                  'Detailed lifestyle setup required',
                  'Please advise',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'styling props'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_fragile_value',
                text: 'Do any products require special handling?',
                helperText:
                    'Listing an item does not confirm that the photographer can accept, store, insure or handle it.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.jobDetails,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'No',
                  'Fragile items',
                  'High-value items',
                  'Heavy or oversized items',
                  'Food, liquid or perishable items',
                  'Restricted or potentially hazardous items',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'fragile value'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_intended_use',
                text: 'How will the finished images mainly be used?',
                helperText:
                    'Commercial, advertising or publication use may require a separate agreement. This question does not transfer copyright or provide legal advice.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.photos,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Online shop or marketplace',
                  'Business website',
                  'Social media',
                  'Catalogue or brochure',
                  'Advertising campaign',
                  'Press or publication',
                  'Internal business use',
                  'Mixed use',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'intended use'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_editing_requirements',
                text: 'Describe any editing or image-format requirements',
                answerType: VanCustomQuestionAnswerType.longText,
                category: VanCustomQuestionCategory.photos,
                requiredByDefault: false,
                helperText:
                    'Examples: Background removal, Colour correction, Cropping, File dimensions, Transparent files, Marketplace specifications. Do not guarantee exact colour reproduction or platform approval.',
                tags: <String>['photography', 'product', 'editing requirements'],
              ),
              VanServiceTemplateQuestion(
                libraryId: 'photography_product_delivery_timeframe',
                text: 'When are the finished images required?',
                helperText:
                    'This is a requested timeframe only. Availability and delivery dates must be confirmed by the photographer.',
                answerType: VanCustomQuestionAnswerType.multipleChoice,
                category: VanCustomQuestionCategory.timing,
                requiredByDefault: true,
                choiceOptions: <String>[
                  'Within two working days',
                  'Within one week',
                  'Within two weeks',
                  'No fixed deadline',
                  'Please advise',
                  'Unsure',
                ],
                tags: <String>['photography', 'product', 'delivery timeframe'],
              ),
            ],
            extras: <VanServiceTemplateExtra>[
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_product_additional_product',
                label: 'Additional product',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_product_additional_image',
                label: 'Additional finished image',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_product_background_removal',
                label: 'Background removal',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_product_lifestyle_setup',
                label: 'Lifestyle setup or styling',
              ),
              VanServiceTemplateExtra(
                key: 'custom_extra_photography_product_express_editing',
                label: 'Express editing, subject to availability',
              ),
            ],
            availability: _photographyEventAvailability,
            suggestedDurationMinutes: 120,
            suggestedNoticeHours: 48,
            maximumBookingsPerDay: 3,
            requestPhotos: true,
            requireAddress: true,
            pricingMode: VanServiceCapabilityIds.customQuote,
            suggestedCustomerMessage:
                'Describe the products, shoot location and image style. The photographer will confirm availability and pricing.',
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
