'use strict';

const crypto = require('crypto');

function clean(value) {
  return String(value || '').trim();
}

function bookingLinkAddressValidationError({
  requireAddress,
  supportsStructuredRequestFlow,
  requestType,
  requestFlowOptions,
  supportsHandover,
  startHandover,
  endHandover,
  address,
  postcode,
  fulfilmentType,
  pickupAddress,
  deliveryAddress,
  collectionAddress,
  returnAddress,
}) {
  if (supportsHandover) {
    if (startHandover === 'businessCollects' && !clean(collectionAddress)) {
      return {
        code: 'missing_collection_address',
        message: 'Collection address is required.',
      };
    }
    if (endHandover === 'businessReturns' && !clean(returnAddress)) {
      return {
        code: 'missing_return_address',
        message: 'Return address is required.',
      };
    }
    return null;
  }

  const options = requestFlowOptions || {};
  const requiresStandardAddress =
    Boolean(requireAddress) &&
    (!supportsStructuredRequestFlow ||
      (requestType !== 'orderRequest' &&
        requestType !== 'pickupDeliveryRequest'));
  if (requiresStandardAddress && !clean(address) && !clean(postcode)) {
    return {
      code: 'missing_address_or_postcode',
      message: 'Address or postcode is required for this service.',
    };
  }

  if (
    supportsStructuredRequestFlow &&
    requestType === 'orderRequest' &&
    options.showFulfilmentChoice &&
    !clean(fulfilmentType)
  ) {
    return {
      code: 'missing_fulfilment_type',
      message: 'Please choose collection or delivery.',
    };
  }
  if (
    supportsStructuredRequestFlow &&
    requestType === 'orderRequest' &&
    options.showFulfilmentChoice &&
    clean(fulfilmentType) === 'delivery' &&
    !clean(deliveryAddress)
  ) {
    return {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    };
  }
  if (
    supportsStructuredRequestFlow &&
    requestType === 'pickupDeliveryRequest' &&
    options.showPickupAddress &&
    !clean(pickupAddress)
  ) {
    return {
      code: 'missing_pickup_address',
      message: 'Pickup address is required.',
    };
  }
  if (
    supportsStructuredRequestFlow &&
    requestType === 'pickupDeliveryRequest' &&
    options.showDeliveryAddress &&
    !clean(deliveryAddress)
  ) {
    return {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    };
  }
  return null;
}

function bookingLinkRequestDocumentId(ownerUid, clientSubmissionId) {
  const owner = clean(ownerUid);
  const submission = clean(clientSubmissionId)
    .replace(/[^a-zA-Z0-9_-]/g, '')
    .slice(0, 128);
  if (!owner || !submission) return '';
  return `booking_${crypto
    .createHash('sha256')
    .update(`${owner}:${submission}`)
    .digest('hex')
    .slice(0, 32)}`;
}

async function withTimeout(promise, timeoutMs, message) {
  let timeoutId;
  const timeout = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(message)), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeout]);
  } finally {
    clearTimeout(timeoutId);
  }
}

module.exports = {
  bookingLinkAddressValidationError,
  bookingLinkRequestDocumentId,
  withTimeout,
};
