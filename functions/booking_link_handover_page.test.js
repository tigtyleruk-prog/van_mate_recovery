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
  const bodyStart = pageSource.indexOf('{', start);
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
};
vm.createContext(context);
vm.runInContext(
  [
    'readText',
    'inferredRequestType',
    'handoverChoiceValue',
    'handoverForService',
    'customerHandoverSummary',
  ].map(readFunction).join('\n'),
  context,
);

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
    /Boolean\(service\.requireAddress\)\s*&&\s*!handover/,
  );
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*collectionAddress/s);
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*returnAddress/s);
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
