'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  bookingLinkAddressValidationError,
  bookingLinkRequestDocumentId,
  withTimeout,
} = require('./booking_link_address_validation');

const functionSource = fs.readFileSync(
  path.join(__dirname, 'index.js'),
  'utf8',
);

function validate(overrides = {}) {
  return bookingLinkAddressValidationError({
    requireAddress: true,
    supportsStructuredRequestFlow: true,
    requestType: 'quoteRequest',
    requestFlowOptions: {},
    supportsHandover: true,
    startHandover: 'businessCollects',
    endHandover: 'businessReturns',
    address: '',
    postcode: '',
    fulfilmentType: '',
    pickupAddress: '',
    deliveryAddress: '',
    collectionAddress: '',
    returnAddress: '',
    ...overrides,
  });
}

test('business collects and returns accepts collection for both addresses', () => {
  assert.equal(
    validate({
      collectionAddress: ' 10 Collection Road, London, SW1A 1AA ',
      returnAddress: '10 Collection Road, London, SW1A 1AA',
    }),
    null,
  );
  assert.match(
    functionSource,
    /returnAddressSameAsCollection &&[\s\S]*startHandover === 'businessCollects' &&[\s\S]*endHandover === 'businessReturns'[\s\S]*returnAddress = collectionAddress;/,
  );
});

test('business collects and delivers uses collection and delivery addresses', () => {
  assert.equal(
    validate({
      endHandover: 'businessDelivers',
      collectionAddress: '10 Collection Road, SW1A 1AA',
      deliveryAddress: '20 Delivery Street, E1 1AA',
      returnAddress: '',
    }),
    null,
  );
  assert.deepEqual(
    validate({
      endHandover: 'businessDelivers',
      collectionAddress: '10 Collection Road, SW1A 1AA',
      deliveryAddress: '',
    }),
    {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    },
  );
});

test('business return requires a separate resolved return address', () => {
  assert.deepEqual(
    validate({ collectionAddress: '10 Collection Road, SW1A 1AA' }),
    {
      code: 'missing_return_address',
      message: 'Return address is required.',
    },
  );
});

test('handover does not incorrectly require the generic address field', () => {
  assert.equal(
    validate({
      address: '',
      postcode: '',
      collectionAddress: '10 Collection Road, SW1A 1AA',
      returnAddress: '20 Return Road, E1 6AN',
    }),
    null,
  );
});

test('missing collection address returns the journey-specific error', () => {
  assert.deepEqual(validate({ returnAddress: '20 Return Road, E1 6AN' }), {
    code: 'missing_collection_address',
    message: 'Collection address is required.',
  });
});

test('customer drop-off and collection does not require customer addresses', () => {
  assert.equal(
    validate({
      startHandover: 'customerDropsOff',
      endHandover: 'customerCollects',
    }),
    null,
  );
});

test('standard customer visit still requires address or postcode', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
    }),
    {
      code: 'missing_address_or_postcode',
      message: 'Address or postcode is required for this service.',
    },
  );
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      postcode: ' sw1a 1aa ',
    }),
    null,
  );
});

test('automatic local delivery requires delivery address instead of hidden generic address', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'localdelivery',
    }),
    {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    },
  );
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'localdelivery',
      deliveryAddress: '20 Delivery Street, E1 1AA',
    }),
    null,
  );
});

test('automatic nationwide delivery requires canonical delivery address', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'nationwidedelivery',
    }),
    {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    },
  );
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'nationwidedelivery',
      deliveryAddress: '20 Delivery Street, E1 1AA',
    }),
    null,
  );
});

test('automatic customer visits business collection does not require hidden addresses', () => {
  assert.equal(
    validate({
      requireAddress: false,
      supportsHandover: false,
      requestType: 'orderRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'collection',
      address: '',
      postcode: '',
      deliveryAddress: '',
    }),
    null,
  );
});

test('automatic business visit requires a service address, not a delivery address', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'businessvisit',
      standardAddressRequiredMessage: 'Please add the service address.',
    }),
    {
      code: 'missing_address_or_postcode',
      message: 'Please add the service address.',
    },
  );
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'businessvisit',
      address: '1 Customer Street',
      deliveryAddress: '',
      standardAddressRequiredMessage: 'Please add the service address.',
    }),
    null,
  );
});

test('automatic customer drop-off does not require hidden address fields', () => {
  assert.equal(
    validate({
      requireAddress: false,
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'customerdropsoff',
      address: '',
      postcode: '',
      deliveryAddress: '',
    }),
    null,
  );
});

test('automatic customer collection does not require hidden address fields', () => {
  assert.equal(
    validate({
      requireAddress: false,
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'customercollects',
      address: '',
      postcode: '',
      deliveryAddress: '',
      collectionAddress: '',
      returnAddress: '',
    }),
    null,
  );
});

test('automatic business return requires canonical return address', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'businessreturns',
      address: '',
      postcode: '',
      deliveryAddress: '',
      returnAddress: '',
    }),
    {
      code: 'missing_return_address',
      message: 'Return address is required.',
    },
  );
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      usesAutomaticFulfilment: true,
      fulfilmentType: 'businessreturns',
      address: '',
      postcode: '',
      deliveryAddress: '',
      returnAddress: '20 Return Road, E1 1AA',
    }),
    null,
  );
});

test('automatic business collection preserves the visible address canonically', () => {
  assert.match(functionSource, /function isCollectionFulfilmentType\(value\)/);
  assert.match(
    functionSource,
    /isCollectionFulfilmentType\(fulfilmentType\)[\s\S]*collectionAddress = \[address, postcode\]\.filter\(Boolean\)\.join\(', '\);/,
  );
});

test('automatic business return preserves the visible address canonically', () => {
  assert.match(functionSource, /function isReturnFulfilmentType\(value\)/);
  assert.match(
    functionSource,
    /isReturnFulfilmentType\(fulfilmentType\)[\s\S]*returnAddress = \[address, postcode\]\.filter\(Boolean\)\.join\(', '\);/,
  );
});

test('automatic movement choices are inferred and checked from the capability contract', () => {
  assert.match(
    functionSource,
    /function automaticFulfilmentOptionsForService\(service\)/,
  );
  assert.match(
    functionSource,
    /if \(!fulfilmentType && automaticFulfilmentOptions\.length === 1\)/,
  );
  assert.match(
    functionSource,
    /Selected fulfilment option is not available for this service\./,
  );
  assert.match(
    functionSource,
    /deliveryAddress = \[address, postcode\]\.filter\(Boolean\)\.join\(', '\);/,
  );
});

test('hosted submission resolves fulfilment options in its own scope', () => {
  const bookingLinkSource = fs.readFileSync(
    path.join(__dirname, '..', 'web', 'booking_link.html'),
    'utf8',
  );
  assert.match(
    bookingLinkSource,
    /const flowOptions = flowOptionsForService\(service, flow\.requestType\);\s+const handover = handoverForService\(service\);\s+const fulfilmentOptions = fulfilmentOptionsForService\(service, flowOptions\);\s+const selectedFulfilmentType = fulfilmentOptions\.length > 0/s,
  );
  assert.match(bookingLinkSource, /Powered by Business Mate/);
});

test('hidden built-in address question suppresses generic address validation', () => {
  assert.equal(
    validate({
      supportsHandover: false,
      requestType: 'quoteRequest',
      showAddress: false,
    }),
    null,
  );
});

test('pickup and delivery retains its journey-specific address checks', () => {
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'pickupDeliveryRequest',
      requestFlowOptions: {
        showPickupAddress: true,
        showDeliveryAddress: true,
      },
    }),
    {
      code: 'missing_pickup_address',
      message: 'Pickup address is required.',
    },
  );
  assert.deepEqual(
    validate({
      supportsHandover: false,
      requestType: 'pickupDeliveryRequest',
      requestFlowOptions: {
        showPickupAddress: true,
        showDeliveryAddress: true,
      },
      pickupAddress: 'Collection depot, M1 1AE',
    }),
    {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    },
  );
});

test('one client submission id always maps to exactly one request document', () => {
  const first = bookingLinkRequestDocumentId('owner-1', 'attempt-123');
  const retry = bookingLinkRequestDocumentId('owner-1', 'attempt-123');
  const other = bookingLinkRequestDocumentId('owner-1', 'attempt-124');

  assert.match(first, /^booking_[a-f0-9]{32}$/);
  assert.equal(retry, first);
  assert.notEqual(other, first);
});

test('photo upload timeout becomes a handled failure path', async () => {
  await assert.rejects(
    withTimeout(new Promise(() => {}), 5, 'photo upload timed out'),
    /photo upload timed out/,
  );
  assert.match(
    functionSource,
    /withTimeout\(\s*file\.save[\s\S]*BOOKING_LINK_PHOTO_UPLOAD_TIMEOUT_MS/,
  );
  assert.match(
    functionSource,
    /catch \(error\) {[\s\S]*photoUploadFailed = true;[\s\S]*uploadedPhotos = \[\];/,
  );
});
