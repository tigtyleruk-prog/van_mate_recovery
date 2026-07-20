const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const pageSource = fs.readFileSync(
  path.join(__dirname, '..', 'web', 'quote_response.html'),
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
  'customerJourneyType',
  'quoteResponseCopy',
  'quoteNeedsCustomerLocation',
  'quoteNeedsExactPin',
  'quoteContactNoun',
  'proposedTimeLabel',
  'exactPinPrompt',
];
const context = {};
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
  assert.match(pageSource, /"Business collection"\s*:\s*"Your drop-off"/);
  assert.match(pageSource, /"Business return"\s*:\s*"Your collection"/);
  assert.match(pageSource, /dropOffDate: asDate\(data\.dropOffDate\)/);
  assert.match(pageSource, /pickUpDate: asDate\(data\.pickUpDate\)/);
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
