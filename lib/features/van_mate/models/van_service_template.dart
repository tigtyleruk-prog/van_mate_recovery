import 'van_custom_job_question.dart';
import 'van_quote_extra_defaults.dart';

class VanServiceTemplateCategory {
  const VanServiceTemplateCategory({
    required this.id,
    required this.title,
    required this.services,
  });

  final String id;
  final String title;
  final List<VanServiceTemplate> services;
}

class VanServiceTemplate {
  const VanServiceTemplate({
    required this.id,
    required this.name,
    required this.questions,
    required this.extras,
    this.description = '',
    this.suggestedDurationMinutes,
    this.defaultQuoteDescription = '',
  });

  final String id;
  final String name;
  final String description;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int? suggestedDurationMinutes;
  final String defaultQuoteDescription;

  VanQuoteExtraDefaults quoteExtraDefaults() {
    var defaults = VanQuoteExtraDefaults.empty();
    for (final extra in extras.where(
      (extra) => isVanQuoteBuiltInExtraKey(extra.key),
    )) {
      defaults = defaults.copyWithExtra(
        VanQuoteExtraDefault.fallback(
          extra.key,
        ).copyWith(label: extra.label, defaultPrice: extra.defaultPrice),
      );
    }
    return defaults.copyWithCustomExtras(<VanQuoteExtraDefault>[
      for (final extra in extras)
        if (!isVanQuoteBuiltInExtraKey(extra.key))
          VanQuoteExtraDefault.custom(
            key: extra.key,
            label: extra.label,
            defaultPrice: extra.defaultPrice,
          ),
    ]);
  }
}

class VanServiceTemplateQuestion {
  const VanServiceTemplateQuestion({
    required this.text,
    this.answerType = VanCustomQuestionAnswerType.shortText,
    this.category = VanCustomQuestionCategory.jobDetails,
  });

  final String text;
  final VanCustomQuestionAnswerType answerType;
  final VanCustomQuestionCategory category;
}

class VanServiceTemplateExtra {
  const VanServiceTemplateExtra({
    required this.key,
    required this.label,
    this.defaultPrice = 0,
  });

  final String key;
  final String label;
  final double defaultPrice;
}

final List<VanServiceTemplateCategory> kVanServiceTemplateCategories =
    <VanServiceTemplateCategory>[
      VanServiceTemplateCategory(
        id: 'transport_delivery',
        title: 'Transport & Delivery',
        services: <VanServiceTemplate>[
          _manAndVanTemplate,
          _removalsTemplate,
          _courierTemplate,
          _multiDropDeliveryTemplate,
          _furnitureDeliveryTemplate,
          _simpleTransportTemplate('store_collections', 'Store Collections'),
          _simpleTransportTemplate('same_day_delivery', 'Same-day Delivery'),
          _simpleTransportTemplate('pet_transport', 'Pet Transport'),
          _simpleTransportTemplate(
            'bakery_cupcake_delivery',
            'Bakery / Cupcake Delivery',
          ),
          _simpleTransportTemplate('florist_delivery', 'Florist Delivery'),
        ],
      ),
      VanServiceTemplateCategory(
        id: 'property_services',
        title: 'Property Services',
        services: <VanServiceTemplate>[
          _gardeningTemplate,
          _cleaningTemplate,
          _propertyTemplate('window_cleaning', 'Window Cleaning'),
          _propertyTemplate('pressure_washing', 'Pressure Washing'),
          _propertyTemplate('house_clearance', 'House Clearance'),
          _propertyTemplate('carpet_cleaning', 'Carpet Cleaning'),
          _propertyTemplate('oven_cleaning', 'Oven Cleaning'),
          _propertyTemplate(
            'end_of_tenancy_cleaning',
            'End of Tenancy Cleaning',
          ),
          _propertyTemplate('gutter_cleaning', 'Gutter Cleaning'),
          _propertyTemplate('handyman', 'Handyman'),
        ],
      ),
      VanServiceTemplateCategory(
        id: 'trades',
        title: 'Trades',
        services: <VanServiceTemplate>[
          _tradeTemplate('electrician', 'Electrician'),
          _tradeTemplate('plumber', 'Plumber'),
          _tradeTemplate('painter_decorator', 'Painter & Decorator'),
          _tradeTemplate('carpenter', 'Carpenter'),
          _tradeTemplate('tiler', 'Tiler'),
          _tradeTemplate('plasterer', 'Plasterer'),
          _tradeTemplate('roofer', 'Roofer'),
          _tradeTemplate('mobile_mechanic', 'Mobile Mechanic'),
        ],
      ),
      VanServiceTemplateCategory(
        id: 'food_local',
        title: 'Food & Local Businesses',
        services: <VanServiceTemplate>[
          _foodTemplate('meal_prep', 'Meal Prep'),
          _cakeOrdersTemplate,
          _foodTemplate('bakery', 'Bakery'),
          _foodTemplate('farm_shop_delivery', 'Farm Shop Delivery'),
          _foodTemplate('catering', 'Catering'),
        ],
      ),
      VanServiceTemplateCategory(
        id: 'events_other',
        title: 'Events & Other',
        services: <VanServiceTemplate>[
          _eventTemplate('event_setup', 'Event Setup'),
          _eventTemplate('balloon_delivery', 'Balloon Delivery'),
          _eventTemplate('party_hire', 'Party Hire'),
          _eventTemplate('dj', 'DJ'),
          _eventTemplate('photographer', 'Photographer'),
          _eventTemplate('dog_walking', 'Dog Walking'),
          _eventTemplate('pet_sitting', 'Pet Sitting'),
          _eventTemplate('mobile_hairdresser', 'Mobile Hairdresser'),
          _eventTemplate('beautician', 'Beautician'),
        ],
      ),
    ];

VanServiceTemplate? findVanServiceTemplateById(String id) {
  final normalized = id.trim();
  if (normalized.isEmpty) {
    return null;
  }
  for (final category in kVanServiceTemplateCategories) {
    for (final service in category.services) {
      if (service.id == normalized) {
        return service;
      }
    }
  }
  return null;
}

VanServiceTemplate? findVanServiceTemplateForService({
  required String serviceId,
  required String serviceName,
}) {
  final normalizedId = serviceId.trim().toLowerCase();
  final normalizedName = serviceName.trim().toLowerCase();
  for (final category in kVanServiceTemplateCategories) {
    for (final template in category.services) {
      if (normalizedId == template.id ||
          normalizedId.startsWith('service_${template.id}_') ||
          (normalizedId.isEmpty &&
              normalizedName.isNotEmpty &&
              normalizedName == template.name.trim().toLowerCase())) {
        return template;
      }
    }
  }
  return null;
}

const VanServiceTemplate _gardeningTemplate = VanServiceTemplate(
  id: 'gardening',
  name: 'Gardening',
  description: 'Garden maintenance, tidy-ups and green waste.',
  suggestedDurationMinutes: 120,
  defaultQuoteDescription: 'Gardening work as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(
      text: 'What gardening work do you need?',
      answerType: VanCustomQuestionAnswerType.longText,
      category: VanCustomQuestionCategory.gardening,
    ),
    VanServiceTemplateQuestion(
      text: 'Grass cutting?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.gardening,
    ),
    VanServiceTemplateQuestion(
      text: 'Hedge trimming?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.gardening,
    ),
    VanServiceTemplateQuestion(
      text: 'Garden size?',
      category: VanCustomQuestionCategory.gardening,
    ),
    VanServiceTemplateQuestion(
      text: 'Green waste removal needed?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.gardening,
    ),
    VanServiceTemplateQuestion(
      text: 'Is there side access?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.access,
    ),
    VanServiceTemplateQuestion(
      text: 'Please upload photos if helpful.',
      answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      category: VanCustomQuestionCategory.photos,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: 'custom_extra_green_waste_removal',
      label: 'Green waste removal',
      defaultPrice: 20,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_extra_labour',
      label: 'Extra labour',
      defaultPrice: 30,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_materials',
      label: 'Materials',
      defaultPrice: 25,
    ),
  ],
);

const VanServiceTemplate _courierTemplate = VanServiceTemplate(
  id: 'courier',
  name: 'Courier',
  description: 'Collections, deliveries and urgent local drops.',
  suggestedDurationMinutes: 60,
  defaultQuoteDescription: 'Courier delivery as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(
      text: 'Collection address',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    VanServiceTemplateQuestion(
      text: 'Delivery address',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    VanServiceTemplateQuestion(text: 'Parcel size'),
    VanServiceTemplateQuestion(text: 'Approximate weight'),
    VanServiceTemplateQuestion(
      text: 'Fragile item?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
    VanServiceTemplateQuestion(
      text: 'Signature required?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
    VanServiceTemplateQuestion(
      text: 'Same-day delivery needed?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: kVanQuoteExtraWaitingTimeKey,
      label: 'Waiting time',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_urgent_delivery',
      label: 'Urgent delivery',
      defaultPrice: 15,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_signature_required',
      label: 'Signature required',
      defaultPrice: 5,
    ),
  ],
);

const VanServiceTemplate _manAndVanTemplate = VanServiceTemplate(
  id: 'man_van',
  name: 'Man & Van',
  description: 'Small moves, collections and deliveries.',
  suggestedDurationMinutes: 120,
  defaultQuoteDescription: 'Man & Van job as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(
      text: 'Pickup address',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    VanServiceTemplateQuestion(
      text: 'Delivery address',
      category: VanCustomQuestionCategory.collectionDelivery,
    ),
    VanServiceTemplateQuestion(
      text: 'What needs moving?',
      answerType: VanCustomQuestionAnswerType.longText,
    ),
    VanServiceTemplateQuestion(
      text: 'Are there stairs?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.access,
    ),
    VanServiceTemplateQuestion(
      text: 'Lift available?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.access,
    ),
    VanServiceTemplateQuestion(
      text: 'Heavy items?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.loading,
    ),
    VanServiceTemplateQuestion(
      text: 'Photos of items?',
      answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      category: VanCustomQuestionCategory.photos,
    ),
    VanServiceTemplateQuestion(
      text: 'Packing required?',
      answerType: VanCustomQuestionAnswerType.yesNo,
      category: VanCustomQuestionCategory.loading,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: kVanQuoteExtraHelperKey,
      label: 'Extra helper',
      defaultPrice: 20,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraStairsKey,
      label: 'Stair carry',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraWaitingTimeKey,
      label: 'Waiting time',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_packing_service',
      label: 'Packing service',
      defaultPrice: 25,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_dismantling_furniture',
      label: 'Dismantling furniture',
      defaultPrice: 20,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraMileageKey,
      label: 'Mileage',
      defaultPrice: 1,
    ),
  ],
);

final VanServiceTemplate _removalsTemplate = VanServiceTemplate(
  id: 'removals',
  name: 'Removals',
  description: 'Home and office removals.',
  suggestedDurationMinutes: 240,
  defaultQuoteDescription: 'Removal job as discussed.',
  questions: _manAndVanTemplate.questions,
  extras: _manAndVanTemplate.extras,
);

const VanServiceTemplate _cakeOrdersTemplate = VanServiceTemplate(
  id: 'cake_orders',
  name: 'Cake Orders',
  description: 'Custom cakes, celebration orders and delivery.',
  suggestedDurationMinutes: 60,
  defaultQuoteDescription: 'Cake order as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(text: 'Quantity'),
    VanServiceTemplateQuestion(text: 'Flavours'),
    VanServiceTemplateQuestion(text: 'Allergies'),
    VanServiceTemplateQuestion(text: 'Collection or delivery?'),
    VanServiceTemplateQuestion(
      text: 'Preferred date',
      answerType: VanCustomQuestionAnswerType.date,
    ),
    VanServiceTemplateQuestion(text: 'Celebration message'),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: 'custom_extra_delivery',
      label: 'Delivery',
      defaultPrice: 5,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_custom_topper',
      label: 'Custom topper',
      defaultPrice: 8,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_gift_box',
      label: 'Gift box',
      defaultPrice: 4,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_extra_decoration',
      label: 'Extra decoration',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_rush_order',
      label: 'Rush order',
      defaultPrice: 15,
    ),
  ],
);

const VanServiceTemplate _cleaningTemplate = VanServiceTemplate(
  id: 'cleaning',
  name: 'Cleaning',
  description: 'Domestic and commercial cleaning.',
  suggestedDurationMinutes: 120,
  defaultQuoteDescription: 'Cleaning service as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(text: 'What type of clean do you need?'),
    VanServiceTemplateQuestion(text: 'How many rooms?'),
    VanServiceTemplateQuestion(
      text: 'Deep clean required?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
    VanServiceTemplateQuestion(
      text: 'Oven clean required?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
    VanServiceTemplateQuestion(
      text: 'Please upload photos if helpful.',
      answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      category: VanCustomQuestionCategory.photos,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: 'custom_extra_oven_clean',
      label: 'Oven clean',
      defaultPrice: 40,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_deep_clean',
      label: 'Deep clean',
      defaultPrice: 50,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_extra_room',
      label: 'Extra room',
      defaultPrice: 15,
    ),
  ],
);

const VanServiceTemplate _multiDropDeliveryTemplate = VanServiceTemplate(
  id: 'multi_drop_delivery',
  name: 'Multi-drop Delivery',
  description: 'Multiple stops and delivery rounds.',
  suggestedDurationMinutes: 180,
  defaultQuoteDescription: 'Multi-drop delivery as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(text: 'How many stops?'),
    VanServiceTemplateQuestion(text: 'Collection address'),
    VanServiceTemplateQuestion(text: 'Delivery areas'),
    VanServiceTemplateQuestion(text: 'Parcel sizes'),
    VanServiceTemplateQuestion(
      text: 'Same-day delivery needed?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: 'custom_extra_extra_stop',
      label: 'Extra stop',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraWaitingTimeKey,
      label: 'Waiting time',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraMileageKey,
      label: 'Mileage',
      defaultPrice: 1,
    ),
  ],
);

const VanServiceTemplate _furnitureDeliveryTemplate = VanServiceTemplate(
  id: 'furniture_delivery',
  name: 'Furniture Delivery',
  description: 'Furniture collection, delivery and positioning.',
  suggestedDurationMinutes: 120,
  defaultQuoteDescription: 'Furniture delivery as discussed.',
  questions: <VanServiceTemplateQuestion>[
    VanServiceTemplateQuestion(text: 'Pickup address'),
    VanServiceTemplateQuestion(text: 'Delivery address'),
    VanServiceTemplateQuestion(text: 'What furniture needs moving?'),
    VanServiceTemplateQuestion(
      text: 'Are there stairs?',
      answerType: VanCustomQuestionAnswerType.yesNo,
    ),
    VanServiceTemplateQuestion(
      text: 'Photos of items?',
      answerType: VanCustomQuestionAnswerType.photoUploadRequest,
    ),
  ],
  extras: <VanServiceTemplateExtra>[
    VanServiceTemplateExtra(
      key: kVanQuoteExtraHelperKey,
      label: 'Extra helper',
      defaultPrice: 20,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraStairsKey,
      label: 'Stair carry',
      defaultPrice: 10,
    ),
    VanServiceTemplateExtra(
      key: 'custom_extra_dismantling_furniture',
      label: 'Dismantling furniture',
      defaultPrice: 20,
    ),
    VanServiceTemplateExtra(
      key: kVanQuoteExtraMileageKey,
      label: 'Mileage',
      defaultPrice: 1,
    ),
  ],
);

VanServiceTemplate _simpleTransportTemplate(String id, String name) {
  return VanServiceTemplate(
    id: id,
    name: name,
    description: 'Transport and delivery service.',
    suggestedDurationMinutes: 60,
    defaultQuoteDescription: 'Delivery as discussed.',
    questions: <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'Collection address'),
      VanServiceTemplateQuestion(text: 'Delivery address'),
      VanServiceTemplateQuestion(text: 'What needs transporting?'),
      VanServiceTemplateQuestion(text: 'Preferred date and time?'),
      VanServiceTemplateQuestion(
        text: 'Photos if helpful?',
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
    ],
    extras: <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: kVanQuoteExtraWaitingTimeKey,
        label: 'Waiting time',
        defaultPrice: 10,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_urgent_delivery',
        label: 'Urgent delivery',
        defaultPrice: 15,
      ),
      VanServiceTemplateExtra(
        key: kVanQuoteExtraMileageKey,
        label: 'Mileage',
        defaultPrice: 1,
      ),
    ],
  );
}

VanServiceTemplate _propertyTemplate(String id, String name) {
  return VanServiceTemplate(
    id: id,
    name: name,
    description: 'Property service.',
    suggestedDurationMinutes: 120,
    defaultQuoteDescription: '$name as discussed.',
    questions: <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'What work do you need?'),
      VanServiceTemplateQuestion(text: 'Property size or area?'),
      VanServiceTemplateQuestion(text: 'Preferred date and time?'),
      VanServiceTemplateQuestion(
        text: 'Is there easy access?',
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      VanServiceTemplateQuestion(
        text: 'Please upload photos if helpful.',
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
    ],
    extras: <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: 'custom_extra_extra_hour',
        label: 'Extra hour',
        defaultPrice: 30,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_materials',
        label: 'Materials',
        defaultPrice: 25,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_waste_removal',
        label: 'Waste removal',
        defaultPrice: 20,
      ),
    ],
  );
}

VanServiceTemplate _tradeTemplate(String id, String name) {
  return VanServiceTemplate(
    id: id,
    name: name,
    description: 'Trade service.',
    suggestedDurationMinutes: 120,
    defaultQuoteDescription: '$name work as discussed.',
    questions: <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(
        text: 'What issue or job do you need help with?',
      ),
      VanServiceTemplateQuestion(text: 'Property type?'),
      VanServiceTemplateQuestion(text: 'Preferred date and time?'),
      VanServiceTemplateQuestion(
        text: 'Materials supplied?',
        answerType: VanCustomQuestionAnswerType.yesNo,
      ),
      VanServiceTemplateQuestion(
        text: 'Please upload photos if helpful.',
        answerType: VanCustomQuestionAnswerType.photoUploadRequest,
      ),
    ],
    extras: <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: 'custom_extra_materials',
        label: 'Materials',
        defaultPrice: 25,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_extra_hour',
        label: 'Extra hour',
        defaultPrice: 35,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_callout',
        label: 'Callout',
        defaultPrice: 30,
      ),
    ],
  );
}

VanServiceTemplate _foodTemplate(String id, String name) {
  return VanServiceTemplate(
    id: id,
    name: name,
    description: 'Food order or local business service.',
    suggestedDurationMinutes: 60,
    defaultQuoteDescription: '$name order as discussed.',
    questions: <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'What would you like to order?'),
      VanServiceTemplateQuestion(text: 'Quantity'),
      VanServiceTemplateQuestion(text: 'Allergies or dietary notes?'),
      VanServiceTemplateQuestion(text: 'Collection or delivery?'),
      VanServiceTemplateQuestion(
        text: 'Preferred date',
        answerType: VanCustomQuestionAnswerType.date,
      ),
    ],
    extras: <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: 'custom_extra_delivery',
        label: 'Delivery',
        defaultPrice: 5,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_rush_order',
        label: 'Rush order',
        defaultPrice: 15,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_gift_box',
        label: 'Gift box',
        defaultPrice: 4,
      ),
    ],
  );
}

VanServiceTemplate _eventTemplate(String id, String name) {
  return VanServiceTemplate(
    id: id,
    name: name,
    description: 'Event or local service booking.',
    suggestedDurationMinutes: 120,
    defaultQuoteDescription: '$name service as discussed.',
    questions: <VanServiceTemplateQuestion>[
      VanServiceTemplateQuestion(text: 'What service do you need?'),
      VanServiceTemplateQuestion(
        text: 'Event date',
        answerType: VanCustomQuestionAnswerType.date,
      ),
      VanServiceTemplateQuestion(
        text: 'Event time',
        answerType: VanCustomQuestionAnswerType.time,
      ),
      VanServiceTemplateQuestion(text: 'Location'),
      VanServiceTemplateQuestion(text: 'Any special requirements?'),
    ],
    extras: <VanServiceTemplateExtra>[
      VanServiceTemplateExtra(
        key: 'custom_extra_extra_hour',
        label: 'Extra hour',
        defaultPrice: 30,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_setup',
        label: 'Setup',
        defaultPrice: 25,
      ),
      VanServiceTemplateExtra(
        key: 'custom_extra_travel',
        label: 'Travel',
        defaultPrice: 10,
      ),
    ],
  );
}
