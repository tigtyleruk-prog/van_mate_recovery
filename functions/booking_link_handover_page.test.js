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
  startHandoverChoice: { value: '' },
  endHandoverChoice: { value: '' },
};
vm.createContext(context);
vm.runInContext(
  [
    'readText',
    'inferredRequestType',
    'handoverForService',
    'customerHandoverSummary',
  ].map(readFunction).join('\n'),
  context,
);

test('hosted booking page supports every independent handover combination', () => {
  const combinations = [
    ['customerDropsOff', 'customerCollects', 'You will drop off and collect.'],
    ['customerDropsOff', 'businessReturns', 'You will drop off; we will return it to you.'],
    ['businessCollects', 'customerCollects', 'We will collect; you will collect when ready.'],
    ['businessCollects', 'businessReturns', 'We will collect and return.'],
  ];

  for (const [startHandover, endHandover, summary] of combinations) {
    const handover = context.handoverForService({
      requestType: 'dropOffPickupRequest',
      startHandover,
      endHandover,
      allowedStartHandoverOptions: [startHandover],
      allowedEndHandoverOptions: [endHandover],
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
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*collectionAddress/s);
  assert.doesNotMatch(pageSource, /additionalNotes:[^}]*returnAddress/s);
});
