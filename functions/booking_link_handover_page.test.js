const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const pageSource = fs.readFileSync(
  path.join(__dirname, '..', 'web', 'booking_link.html'),
  'utf8',
);

function readFunction(name) {
  const start = pageSource.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `Missing ${name}() in booking_link.html`);
  const bodyStart = pageSource.indexOf(') {', start) + 2;
  assert.notEqual(bodyStart, 1, `Missing function body for ${name}()`);
  let depth = 0;
  for (let index = bodyStart; index < pageSource.length; index += 1) {
    if (pageSource[index] === '{') depth += 1;
    if (pageSource[index] === '}') depth -= 1;
    if (depth === 0) return pageSource.slice(start, index + 1);
  }
  throw new Error(`Could not read ${name}()`);
}

const context = {
  REQUEST_TYPES: new Set([
    'quoteRequest',
    'bookingRequest',
    'orderRequest',
    'dropOffPickupRequest',
    'pickupDeliveryRequest',
  ]),
  startHandoverChoice: { querySelector: () => null },
  endHandoverChoice: { querySelector: () => null },
  fulfilmentType: { value: '' },
};
vm.createContext(context);
vm.runInContext(
  [
    'readText',
    'fixedPriceAmountForService',
    'fromPriceAmountForService',
    'pricingModeForService',
    'fixedPriceLabelForService',
    'priceLabelForService',
    'bookingPastDateMessage',
    'bookingLeadTimeMessage',
    'startOfLocalDay',
    'parseLocalDate',
    'noticeHoursForService',
    'validatePreferredBookingWindow',
    'inferredRequestType',
    'customerJourneyForService',
    'isPreOrderService',
    'journeyCopyForService',
    'requestFlowForService',
    'flowOptionsForService',
    'serviceCapabilityIdsForService',
    'capabilityContractForService',
    'automaticFulfilmentOptionsForService',
    'fulfilmentOptionsForService',
    'isDeliveryFulfilment',
    'isCollectionFulfilment',
    'isReturnFulfilment',
    'selectedFulfilmentOption',
    'addressContractText',
    'addressHeadingForService',
    'addressFieldLabelForService',
    'addressFieldHintForService',
    'addressRequiredMessageForService',
    'handoverChoiceValue',
    'handoverForService',
    'isDogService',
    'customerHandoverSummary',
    'builtInQuestionSetting',
    'showsConfiguredBuiltInQuestion',
    'showsPreferredDate',
    'showsPreferredTime',
    'showsFlexibleTiming',
    'customerAddressForFulfilment',
    'requiresBuiltInQuestion',
    'requiresPreferredTiming',
    'preferredTimingHeadingForService',
    'preferredDateLabelForService',
    'preferredTimeLabelForService',
  ].map(readFunction).join('\n'),
  context,
);

test('hosted fixed price services show an unambiguous amount', () => {
  assert.equal(
    context.fixedPriceLabelForService({
      pricingMode: 'fixed_price',
      fixedPriceAmount: 50,
    }),
    'Fixed price: £50.00',
  );
  assert.equal(
    context.fixedPriceLabelForService({
      capabilityContract: { pricingMode: 'fixed_price' },
      fixedPriceAmount: '12.5',
    }),
    'Fixed price: £12.50',
  );
  assert.equal(
    context.fixedPriceLabelForService({
      pricingMode: 'from_price',
      fixedPriceAmount: 50,
    }),
    '',
  );
});

test('hosted from price services show a starting amount without final-total wording', () => {
  assert.equal(
    context.priceLabelForService({
      pricingMode: 'from_price',
      fromPriceAmount: 50,
    }),
    'From £50.00. Final price may vary after we review your details.',
  );
  assert.equal(
    context.priceLabelForService({
      capabilityContract: { pricingMode: 'from_price' },
      fromPriceAmount: '12.5',
    }),
    'From £12.50. Final price may vary after we review your details.',
  );
  assert.equal(
    context.priceLabelForService({
      pricingMode: 'fixed_price',
      fixedPriceAmount: 50,
      fromPriceAmount: 10,
    }),
    'Fixed price: £50.00',
  );
});

test('hosted booking page supports every independent handover combination', () => {
  const combinations = [
    ['customerDropsOff', 'customerCollects', "You'll drop off your item and collect it when ready."],
    ['customerDropsOff', 'businessReturns', "You'll drop off your item. We'll return it when finished."],
    ['businessCollects', 'customerCollects', "We'll collect your item. You'll collect it when ready."],
    ['businessCollects', 'businessReturns', "We'll collect your item and return it when finished."],
    ['businessCollects', 'businessDelivers', "We'll collect from the collection address and deliver to the destination."],
  ];

  for (const [startHandover, endHandover, summary] of combinations) {
    const handover = context.handoverForService({
      requestType: 'dropOffPickupRequest',
      startHandover,
      endHandover,
      allowCustomerDropOff: startHandover === 'customerDropsOff',
      allowBusinessCollection: startHandover === 'businessCollects',
      allowCustomerCollection: endHandover === 'customerCollects',
      allowBusinessReturn: endHandover === 'businessReturns',
      allowBusinessDelivery: endHandover === 'businessDelivers',
    });
    assert.equal(handover.start, startHandover);
    assert.equal(handover.end, endHandover);
    assert.equal(context.customerHandoverSummary(handover), summary);
  }
});

test('hosted booking page preserves legacy fixed and customer-choice modes', () => {
  const customerMode = context.handoverForService({
    requestType: 'dropOffPickupRequest',
  });
  const businessMode = context.handoverForService({
    requestType: 'dropOffPickupRequest',
    handoverMode: 'businessCollectReturn',
  });
  const customerChoice = context.handoverForService({
    requestType: 'dropOffPickupRequest',
    handoverMode: 'customerChooses',
  });

  assert.equal(customerMode.start, 'customerDropsOff');
  assert.equal(customerMode.end, 'customerCollects');
  assert.equal(businessMode.start, 'businessCollects');
  assert.equal(businessMode.end, 'businessReturns');
  assert.deepEqual(
    JSON.parse(JSON.stringify(customerChoice.allowedStarts)),
    ['customerDropsOff', 'businessCollects'],
  );
  assert.deepEqual(
    JSON.parse(JSON.stringify(customerChoice.allowedEnds)),
    ['customerCollects', 'businessReturns'],
  );
});

test('hosted booking built-in timing fields are generically configurable', () => {
  const defaultService = {
    requestType: 'orderRequest',
    customerJourneyType: 'order',
    requestFlowOptions: {
      askPreferredDate: true,
      askPreferredTime: true,
    },
    builtInQuestionSettings: {
      preferred_date: { required: true },
      preferred_time: { required: true },
    },
  };
  const defaultFlow = context.requestFlowForService(defaultService);
  const defaultOptions = context.flowOptionsForService(
    defaultService,
    defaultFlow.requestType,
  );

  assert.equal(context.showsPreferredDate(defaultService, defaultOptions), true);
  assert.equal(context.showsPreferredTime(defaultService, defaultOptions), true);
  assert.equal(context.showsFlexibleTiming(defaultService, defaultOptions), true);
  assert.equal(context.requiresPreferredTiming(defaultService), true);
  assert.match(pageSource, /id="preferredFlexibleHelper"/);
  assert.match(
    pageSource,
    /builtInQuestionSetting\(service, "flexible_timing"\)\.helperText/,
  );
  assert.match(
    pageSource,
    /preferredFlexibleHelper\.classList\.toggle\(\s*"hidden",\s*!showsFlexibleTiming\(service, flowOptions\) \|\| !preferredFlexibleHelperValue/s,
  );

  const collectionOnlyService = {
    ...defaultService,
    builtInQuestionSettings: {
      preferred_date: { required: false, show: false, label: 'Collection Date' },
      preferred_time: { required: true, show: true, label: 'Collection Time' },
      flexible_timing: { show: false, label: 'Any time today' },
    },
  };
  const collectionFlow = context.requestFlowForService(collectionOnlyService);
  const collectionOptions = context.flowOptionsForService(
    collectionOnlyService,
    collectionFlow.requestType,
  );

  assert.equal(
    context.showsPreferredDate(collectionOnlyService, collectionOptions),
    false,
  );
  assert.equal(
    context.showsPreferredTime(collectionOnlyService, collectionOptions),
    true,
  );
  assert.equal(
    context.showsFlexibleTiming(collectionOnlyService, collectionOptions),
    false,
  );
  assert.equal(context.requiresPreferredTiming(collectionOnlyService), true);
  assert.equal(
    context.preferredTimingHeadingForService(
      collectionOnlyService,
      collectionFlow,
      collectionOptions,
    ),
    'Collection Time',
  );
});

test('hosted Pre Orders use collection time wording unless overridden', () => {
  const preOrderService = {
    customerJourneyType: 'preOrder',
    requestType: 'orderRequest',
    builtInQuestionSettings: {
      preferred_time: { required: true, show: true },
    },
  };

  assert.equal(context.preferredTimeLabelForService(preOrderService), 'Collection Time');
  assert.equal(
    context.preferredTimeLabelForService({
      ...preOrderService,
      builtInQuestionSettings: {
        preferred_time: {
          required: true,
          show: true,
          label: 'Delivery Time',
        },
      },
    }),
    'Delivery Time',
  );
});

test('hosted Pre Orders use collection date wording unless overridden', () => {
  const preOrderService = {
    customerJourneyType: 'preOrder',
    requestType: 'orderRequest',
    builtInQuestionSettings: {
      preferred_date: { required: true, show: true },
    },
  };

  assert.equal(context.preferredDateLabelForService(preOrderService), 'Collection Date');
  assert.equal(
    context.preferredDateLabelForService({
      ...preOrderService,
      builtInQuestionSettings: {
        preferred_date: {
          required: true,
          show: true,
          label: 'Delivery Date',
        },
      },
    }),
    'Delivery Date',
  );
});

test('hosted preferred timing honours service lead time', () => {
  const now = new Date(2026, 6, 25, 10, 0, 0, 0);

  assert.equal(
    context.validatePreferredBookingWindow({
      preferredDate: context.parseLocalDate('2026-07-25'),
      preferredTimeWindow: '15:00',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    context.bookingLeadTimeMessage(),
  );
  assert.equal(
    context.validatePreferredBookingWindow({
      preferredDate: context.parseLocalDate('2026-07-26'),
      preferredTimeWindow: 'morning',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    context.bookingLeadTimeMessage(),
  );
  assert.equal(
    context.validatePreferredBookingWindow({
      preferredDate: context.parseLocalDate('2026-07-26'),
      preferredTimeWindow: 'afternoon',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    null,
  );
  assert.equal(
    context.validatePreferredBookingWindow({
      preferredDate: context.parseLocalDate('2026-07-26'),
      preferredTimeWindow: '',
      preferredIsFlexible: true,
      noticeHours: 48,
      now,
    }),
    context.bookingLeadTimeMessage(),
  );
  assert.equal(context.noticeHoursForService({ noticeHours: '24' }), 24);
  assert.equal(
    context.parseLocalDate('2026-07-26').getTime(),
    new Date(2026, 6, 26).getTime(),
  );
});

test('hosted form keeps addresses separate from notes and requires them by stage', () => {
  assert.match(pageSource, /handover\.start === "businessCollects" && !readText\(collectionAddress\.value\)/);
  assert.match(pageSource, /handover\.end === "businessReturns"/);
  assert.match(pageSource, /returnAddressSameAsCollection:/);
  assert.match(
    pageSource,
    /sameReturnAddress\.checked\s*\? readText\(collectionAddress\.value\)\s*:\s*readText\(returnAddress\.value\)/,
  );
  assert.match(
    pageSource,
    /const showStandardAddress = customerAddressForFulfilment\(service\)/,
  );
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*collectionAddress/s);
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*returnAddress/s);
});

test('hosted generic address follows the configured built-in address field', () => {
  assert.equal(
    context.customerAddressForFulfilment({
      requireAddress: true,
      showAddress: false,
      requestType: 'quoteRequest',
    }),
    false,
  );
  assert.equal(
    context.customerAddressForFulfilment({
      requireAddress: true,
      requestType: 'quoteRequest',
      builtInQuestionSettings: { address: { show: false } },
    }),
    false,
  );
  assert.equal(
    context.customerAddressForFulfilment({
      requireAddress: true,
      requestType: 'quoteRequest',
    }),
    true,
  );
});

test('capabilities generate generic fulfilment choices without manual questions', () => {
  const deliveryOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_visits_business', 'local_delivery'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(deliveryOptions)),
    [
      { value: 'collection', label: 'Collect' },
      { value: 'localDelivery', label: 'Local delivery' },
    ],
  );
  const nationwideOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['nationwide_delivery'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(nationwideOnlyOptions)),
    [{ value: 'nationwideDelivery', label: 'Nationwide delivery' }],
  );
  const nationwideReceiveOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: [
      'customer_visits_business',
      'local_delivery',
      'nationwide_delivery',
    ],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(nationwideReceiveOptions)),
    [
      { value: 'collection', label: 'Collect' },
      { value: 'localDelivery', label: 'Local delivery' },
      { value: 'nationwideDelivery', label: 'Nationwide delivery' },
    ],
  );

  const handoverOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_drops_off', 'business_collects'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(handoverOptions)),
    [
      { value: 'customerDropsOff', label: "I'll drop it off" },
      { value: 'businessCollects', label: 'Please collect it' },
    ],
  );

  const dropOffOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_drops_off'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(dropOffOnlyOptions)),
    [{ value: 'customerDropsOff', label: "I'll drop it off" }],
  );

  const businessCollectsOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['business_collects'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(businessCollectsOnlyOptions)),
    [{ value: 'businessCollects', label: 'Please collect it' }],
  );
  assert.equal(context.isCollectionFulfilment('businessCollects'), true);
  assert.equal(context.isCollectionFulfilment('customerDropsOff'), false);

  const customerCollectsOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_collects'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(customerCollectsOnlyOptions)),
    [{ value: 'customerCollects', label: "I'll collect it" }],
  );

  const completionOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_collects', 'business_returns'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(completionOptions)),
    [
      { value: 'customerCollects', label: "I'll collect it" },
      { value: 'businessReturns', label: 'Please return it' },
    ],
  );
  const businessReturnsOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['business_returns'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(businessReturnsOnlyOptions)),
    [{ value: 'businessReturns', label: 'Please return it' }],
  );
  assert.equal(context.isReturnFulfilment('businessReturns'), true);
  assert.equal(context.isReturnFulfilment('customerCollects'), false);

  assert.equal(context.isDeliveryFulfilment('localDelivery'), true);
  assert.equal(context.isDeliveryFulfilment('nationwideDelivery'), true);
  assert.equal(context.isDeliveryFulfilment('businessVisit'), false);
  assert.equal(context.isDeliveryFulfilment('collection'), false);

  const collectionOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['customer_visits_business'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(collectionOnlyOptions)),
    [{ value: 'collection', label: 'Collect' }],
  );
  assert.equal(
    context.fulfilmentOptionsForService(
      { serviceCapabilityIds: ['customer_visits_business'] },
      { showFulfilmentChoice: false },
    ).length,
    1,
  );

  const businessVisitOnlyOptions = context.automaticFulfilmentOptionsForService({
    serviceCapabilityIds: ['business_visits_customer'],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(businessVisitOnlyOptions)),
    [{ value: 'businessVisit', label: 'Business visit' }],
  );
  assert.equal(
    context.customerAddressForFulfilment({
      requireAddress: true,
      serviceCapabilityIds: ['business_visits_customer'],
      capabilityContract: {
        addressHeading: 'Service address',
        addressFieldLabel: 'Service address',
        addressHint: 'Where will the work take place?',
        addressRequiredMessage: 'Please add the service address.',
        movementChoiceGroups: [
          {
            id: 'receive',
            options: [{ value: 'businessVisit', label: 'Business visit' }],
          },
        ],
      },
    }),
    true,
  );
  assert.equal(
    context.addressHeadingForService({
      requireAddress: true,
      capabilityContract: { addressHeading: 'Service address' },
    }),
    'Service address',
  );
  assert.equal(
    context.addressFieldHintForService({
      capabilityContract: { addressHint: 'Where will the work take place?' },
    }),
    'Where will the work take place?',
  );
  assert.equal(
    context.addressRequiredMessageForService({
      capabilityContract: { addressRequiredMessage: 'Please add the service address.' },
    }),
    'Please add the service address.',
  );

  const contractOptions = context.automaticFulfilmentOptionsForService({
    capabilityContract: {
      movementChoiceGroups: [
        {
          id: 'receive',
          options: [
            { value: 'collection', label: 'Collect' },
            { value: 'localDelivery', label: 'Local delivery' },
          ],
        },
      ],
    },
    serviceCapabilityIds: [],
  });
  assert.deepEqual(
    JSON.parse(JSON.stringify(contractOptions)),
    [
      { value: 'collection', label: 'Collect' },
      { value: 'localDelivery', label: 'Local delivery' },
    ],
  );
});

test('hosted submission validates before loading and always restores retry state', () => {
  const submitSource = readFunction('submitRequest');
  assert.ok(
    submitSource.indexOf('if (!validateSubmission())') <
      submitSource.indexOf('state.submitting = true'),
  );
  assert.match(submitSource, /if \(state\.submitting\)/);
  assert.match(submitSource, /withSubmissionTimeout\(submitBookingLinkRequest/);
  assert.match(submitSource, /finally\s*{[\s\S]*state\.submitting = false/);
  assert.match(
    submitSource,
    /if \(!state\.submitted\)[\s\S]*submitButton\.disabled = false/,
  );
  assert.doesNotMatch(submitSource, /state\.selectedPhotos\s*=\s*\[\]/);
});

test('hosted submission has a retryable timeout and stable request identity', () => {
  assert.match(pageSource, /const SUBMISSION_TIMEOUT_MS = 45 \* 1000/);
  assert.match(pageSource, /Request timed out\. Check your connection and try again\./);
  assert.match(pageSource, /clientSubmissionId: state\.clientSubmissionId/);
  assert.match(pageSource, /state\.clientSubmissionId = state\.clientSubmissionId \|\| createClientSubmissionId\(\)/);
});
