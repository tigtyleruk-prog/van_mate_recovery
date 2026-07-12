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

test('drop-off/pick-up flows do not request a customer pin', () => {
  assert.equal(
    context.quoteNeedsExactPin({
      requestType: 'dropOffPickupRequest',
      requiresExactPinAfterQuoteAccepted: true,
    }),
    false,
  );
});
