const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const pageSource = fs.readFileSync(
  path.join(__dirname, '..', 'web', 'quote_response.html'),
  'utf8',
);
const firebaseConfig = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', 'firebase.json'),
  'utf8',
));
const quotePublisherSource = fs.readFileSync(
  path.join(
    __dirname,
    '..',
    'lib',
    'features',
    'van_mate',
    'services',
    'van_public_quote_cloud_service.dart',
  ),
  'utf8',
);

function readFunction(name) {
  const start = pageSource.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `Missing ${name}() in quote_response.html`);
  const bodyStart = pageSource.indexOf('{', start);
  let depth = 0;
  for (let index = bodyStart; index < pageSource.length; index += 1) {
    if (pageSource[index] === '{') depth += 1;
    if (pageSource[index] === '}') depth -= 1;
    if (depth === 0) return pageSource.slice(start, index + 1);
  }
  throw new Error(`Could not read ${name}()`);
}

const helperNames = [
  'quoteHasExactPin',
  'normaliseRequestFlowValue',
  'isOrderRequest',
  'isCollectionOrder',
  'isDeliveryOrder',
  'isPickupDeliveryRequest',
  'isDropOffPickupRequest',
  'handoverForQuote',
  'customerHandoverSummary',
  'customerHandoverView',
  'quoteDisplayFingerprint',
  'customerJourneyType',
  'quoteResponseCopy',
  'quoteNeedsCustomerLocation',
  'quoteNeedsExactPin',
  'quoteContactNoun',
  'proposedTimeLabel',
  'exactPinPrompt',
  'normaliseQuoteToken',
  'quoteTokenFromPath',
  'quoteReferenceFromLocation',
];
const context = { URLSearchParams };
vm.createContext(context);
vm.runInContext(helperNames.map(readFunction).join('\n'), context);

test('collection Order Requests skip the exact-pin final step', () => {
  const quote = {
    requestType: 'orderRequest',
    fulfilmentType: 'collection',
    requiresExactPinAfterQuoteAccepted: true,
  };

  assert.equal(context.quoteNeedsCustomerLocation(quote), false);
  assert.equal(context.quoteNeedsExactPin(quote), false);
  assert.equal(context.quoteContactNoun(quote), 'business');
  assert.equal(context.proposedTimeLabel(quote), 'Proposed collection time');
});

test('delivery Order Requests keep configured exact-pin behavior and wording', () => {
  const quote = {
    requestType: 'orderRequest',
    fulfilmentType: 'delivery',
    requiresExactPinAfterQuoteAccepted: true,
  };

  assert.equal(context.quoteNeedsCustomerLocation(quote), true);
  assert.equal(context.quoteNeedsExactPin(quote), true);
  assert.equal(context.exactPinPrompt(quote), 'Please confirm the exact delivery point.');
  assert.equal(context.proposedTimeLabel(quote), 'Proposed delivery time');
  assert.equal(
    context.quoteNeedsExactPin({
      ...quote,
      requiresExactPinAfterQuoteAccepted: false,
    }),
    false,
  );
});

test('pickup/delivery and legacy quotes retain safe location fallback', () => {
  const courierQuote = {
    requestType: 'pickupDeliveryRequest',
    requiresExactPinAfterQuoteAccepted: true,
  };
  const legacyQuote = { requiresExactPinAfterQuoteAccepted: true };

  assert.equal(context.quoteNeedsExactPin(courierQuote), true);
  assert.match(context.exactPinPrompt(courierQuote), /driver/);
  assert.equal(context.quoteNeedsExactPin(legacyQuote), true);
  assert.equal(
    context.quoteNeedsExactPin({
      ...legacyQuote,
      exactPinLatitude: 51.5,
      exactPinLongitude: -0.12,
    }),
    false,
  );
});

test('drop-off/pick-up flows request a pin only when configured', () => {
  const quote = { requestType: 'dropOffPickupRequest' };
  assert.deepEqual(
    JSON.parse(JSON.stringify(context.quoteResponseCopy(quote))),
    {
      helper: 'Use the buttons below to confirm your choice.',
      accept: 'Accept & book',
      arrange: 'Accept quote – rearrange appointment',
      decline: 'Decline quote',
    },
  );
  assert.equal(
    context.quoteNeedsExactPin({
      requestType: 'dropOffPickupRequest',
      requiresExactPinAfterQuoteAccepted: true,
    }),
    true,
  );
  assert.equal(
    context.quoteNeedsExactPin({
      requestType: 'dropOffPickupRequest',
      requiresExactPinAfterQuoteAccepted: false,
    }),
    false,
  );
  assert.equal(
    context.exactPinPrompt({
      requestType: 'dropOffPickupRequest',
      requiresExactPinAfterQuoteAccepted: true,
    }),
    'Please confirm the exact drop-off location.',
  );
  assert.deepEqual(
    JSON.parse(JSON.stringify(context.handoverForQuote(quote))),
    { start: 'customerdropsoff', end: 'customercollects' },
  );
  assert.equal(
    context.customerHandoverSummary(quote),
    'You will drop off and collect.',
  );
  assert.match(pageSource, /dropOffDate: asDate\(data\.dropOffDate\)/);
  assert.match(pageSource, /pickUpDate: asDate\(data\.pickUpDate\)/);
});

test('Courier delivery quotes use collect-and-deliver labels and addresses', () => {
  const quote = {
    requestType: 'pickupDeliveryRequest',
    startHandover: 'businessCollects',
    endHandover: 'businessDelivers',
    collectionAddress: '1 Collection Road',
    deliveryAddress: '2 Delivery Avenue',
    returnAddress: 'legacy destination fallback',
    collectionDate: '2026-07-27',
    collectionTime: '09:00',
    deliveryDate: '2026-07-27',
    deliveryTime: '14:00',
  };

  assert.deepEqual(
    JSON.parse(JSON.stringify(context.handoverForQuote(quote))),
    { start: 'businesscollects', end: 'businessdelivers' },
  );
  assert.equal(context.customerHandoverSummary(quote), 'We will collect and deliver.');
  const view = JSON.parse(JSON.stringify(context.customerHandoverView(quote)));
  assert.equal(view.startLabel, 'Business collection');
  assert.equal(view.label, 'Business delivery');
  assert.equal(view.collectionAddress, '1 Collection Road');
  assert.equal(view.addressLabel, 'Delivery address');
  assert.equal(view.address, '2 Delivery Avenue');
  assert.notEqual(view.label, 'Business return');
  assert.notEqual(view.addressLabel, 'Return address');
});

test('genuine businessReturns quotes retain return wording', () => {
  const quote = {
    requestType: 'pickupDeliveryRequest',
    startHandover: 'businessCollects',
    endHandover: 'businessReturns',
    collectionAddress: '1 Collection Road',
    returnAddress: '1 Collection Road',
  };

  assert.equal(context.customerHandoverSummary(quote), 'We will collect and return.');
  const view = JSON.parse(JSON.stringify(context.customerHandoverView(quote)));
  assert.equal(view.label, 'Business return');
  assert.equal(view.addressLabel, 'Return address');
  assert.equal(view.address, '1 Collection Road');
});

test('the proposed quote appointment is rendered separately from requested journey times', () => {
  const renderSource = readFunction('renderQuote');
  const proposedIndex = renderSource.indexOf('if (proposedAppointment)');
  const handoverIndex = renderSource.indexOf('if (handoverView)');

  assert.notEqual(proposedIndex, -1);
  assert.ok(proposedIndex < handoverIndex);
  assert.match(
    renderSource,
    /renderRow\(proposedTimeLabel\(quote\), proposedAppointment\)/,
  );
  assert.match(renderSource, /`Requested: \$\{/);
  assert.doesNotMatch(
    renderSource,
    /proposedAppointment \|\| formatDate\(quote\.scheduledAt/,
  );
});

test('public quote publishing and hosted rendering use explicit delivery fields', () => {
  assert.match(
    quotePublisherSource,
    /effectiveHandover\.end == VanEndHandover\.businessDelivers/,
  );
  assert.match(
    quotePublisherSource,
    /'deliveryAddress': isBusinessDelivery \? destinationAddress : ''/,
  );
  assert.match(
    pageSource,
    /normaliseRequestFlowValue\(data\.endHandover\) === "businessdelivers"/,
  );
  assert.match(pageSource, /addressLabel: "Delivery address"/);
});

test('quote page is versioned and served with no-store cache headers', () => {
  assert.match(
    pageSource,
    /QUOTE_RESPONSE_PAGE_VERSION = "2026-07-22-quote-link-v1"/,
  );
  const quoteHeaders = firebaseConfig.hosting.headers.filter((entry) =>
    entry.source === '/quote/**' ||
      entry.source === '/quote' ||
      entry.source === '/quote_response.html'
  );
  assert.equal(quoteHeaders.length, 3);
  for (const entry of quoteHeaders) {
    assert.ok(entry.headers.some((header) =>
      header.key === 'Cache-Control' && header.value.includes('no-store')
    ));
  }
});

test('hosted quote parser accepts current and legacy URL formats', () => {
  const pathLink = context.quoteReferenceFromLocation('', '/quote/token-123');
  const queryLink = context.quoteReferenceFromLocation('?token=token-456', '/quote');
  const htmlTokenLink = context.quoteReferenceFromLocation(
    '?token=token-789',
    '/quote_response.html',
  );
  const legacyIdLink = context.quoteReferenceFromLocation(
    '?id=legacy-quote',
    '/quote_response.html',
  );
  const legacyResponseIdLink = context.quoteReferenceFromLocation(
    '?quoteResponseId=legacy-response-quote',
    '/quote_response.html',
  );

  assert.deepEqual(JSON.parse(JSON.stringify(pathLink)), {
    quoteId: '',
    quoteToken: 'token-123',
  });
  assert.equal(queryLink.quoteToken, 'token-456');
  assert.equal(htmlTokenLink.quoteToken, 'token-789');
  assert.equal(legacyIdLink.quoteId, 'legacy-quote');
  assert.equal(legacyResponseIdLink.quoteId, 'legacy-response-quote');
});

test('absent quote identifiers keep the missing-link safety state', () => {
  const missing = context.quoteReferenceFromLocation('', '/quote');
  const loadSource = readFunction('loadQuote');

  assert.deepEqual(JSON.parse(JSON.stringify(missing)), {
    quoteId: '',
    quoteToken: '',
  });
  assert.match(
    loadSource,
    /Missing quote link\. Please reopen the quote from the original message\./,
  );
});

test('legacy path identifiers and superseded tokens resolve explicitly', () => {
  const resolveSource = readFunction('resolveQuoteReference');
  const exactQuoteRewrite = firebaseConfig.hosting.rewrites.find(
    (entry) => entry.source === '/quote',
  );

  assert.match(resolveSource, /quoteId = quoteToken/);
  assert.match(resolveSource, /tokenData\.currentQuoteId/);
  assert.deepEqual(exactQuoteRewrite, {
    source: '/quote',
    destination: '/quote_response.html',
  });
});

test('token resolution opens the authoritative current quote at runtime', async () => {
  const runtime = {
    quoteRef: null,
    quoteToken: 'superseded-token',
    quoteId: '',
    quoteTokenCollectionName: 'public_quote_response_tokens',
    quoteCollectionName: 'public_quote_responses',
    db: {
      collection(name) {
        return {
          doc(id) {
            if (name === 'public_quote_response_tokens') {
              return {
                async get() {
                  return {
                    exists: true,
                    data: () => ({ currentQuoteId: 'quote-current' }),
                  };
                },
              };
            }
            return { collection: name, id };
          },
        };
      },
    },
  };
  vm.createContext(runtime);
  const resolveQuoteReferenceSource = readFunction(
    'resolveQuoteReference',
  ).replace(/^function /, 'async function ');
  vm.runInContext(
    [readFunction('text'), resolveQuoteReferenceSource].join('\n'),
    runtime,
  );

  const resolved = await runtime.resolveQuoteReference();
  assert.equal(runtime.quoteId, 'quote-current');
  assert.deepEqual(JSON.parse(JSON.stringify(resolved)), {
    collection: 'public_quote_responses',
    id: 'quote-current',
  });
});

test('hosted quote page listens to exactly one current quote without reloading', () => {
  const loadSource = readFunction('loadQuote');
  const subscribeSource = readFunction('subscribeToCurrentQuote');
  const resolveSource = readFunction('resolveQuoteReference');

  assert.match(loadSource, /subscribeToCurrentQuote\(resolvedQuoteRef\)/);
  assert.match(subscribeSource, /resolvedQuoteRef\.onSnapshot/);
  assert.match(subscribeSource, /nextCurrentQuoteId !== snapshot\.id/);
  assert.match(resolveSource, /tokenData\.currentQuoteId/);
  assert.doesNotMatch(subscribeSource, /location\.reload|window\.location\s*=/);
  assert.doesNotMatch(pageSource, /location\.reload\(/);
});

test('unrelated snapshot writes do not rerender displayed quote content', () => {
  const baseQuote = {
    quoteResponseId: 'quote-2',
    currentQuoteId: 'quote-2',
    quoteVersion: 2,
    isCurrent: true,
    quoteAmount: 175,
    proposedDate: '2026-07-27',
    proposedStartTime: '10:00',
    quoteExtras: ['Stairs'],
    quoteStatus: 'sent',
  };
  const first = context.quoteDisplayFingerprint(baseQuote);
  const unrelatedFunctionWrite = context.quoteDisplayFingerprint({
    ...baseQuote,
    updatedAt: '2026-07-21T12:00:00.000Z',
    quoteNotificationSentAt: '2026-07-21T12:00:00.000Z',
  });
  const revisedAmount = context.quoteDisplayFingerprint({
    ...baseQuote,
    quoteAmount: 200,
  });
  const revisedAppointment = context.quoteDisplayFingerprint({
    ...baseQuote,
    proposedStartTime: '11:30',
  });

  assert.equal(unrelatedFunctionWrite, first);
  assert.notEqual(revisedAmount, first);
  assert.notEqual(revisedAppointment, first);
});

test('meaningful quote updates preserve scroll position and render in place', () => {
  const subscribeSource = readFunction('subscribeToCurrentQuote');
  const preservingRenderSource = readFunction('renderQuotePreservingScroll');

  assert.match(subscribeSource, /nextFingerprint === lastDisplayedQuoteFingerprint/);
  assert.match(subscribeSource, /renderQuotePreservingScroll\(\)/);
  assert.match(preservingRenderSource, /window\.scrollX/);
  assert.match(preservingRenderSource, /window\.scrollY/);
  assert.match(preservingRenderSource, /window\.scrollTo/);
});

test('legacy booking journeys keep booking decline wording', () => {
  assert.deepEqual(
    JSON.parse(JSON.stringify(context.quoteResponseCopy({ requestType: 'bookingRequest' }))),
    {
      helper: 'Use the buttons below to confirm your choice.',
      accept: 'Accept & book',
      arrange: 'Accept quote – rearrange appointment',
      decline: 'Decline booking',
    },
  );
});
