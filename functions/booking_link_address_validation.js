'use strict';

const crypto = require('crypto');

function clean(value) {
  return String(value || '').trim();
}

function bookingLinkAddressValidationError({
  requireAddress,
  showAddress = true,
  standardAddressRequiredMessage,
  supportsStructuredRequestFlow,
  requestType,
  requestFlowOptions,
  usesAutomaticFulfilment = false,
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
    if (endHandover === 'businessDelivers' && !clean(deliveryAddress)) {
      return {
        code: 'missing_delivery_address',
        message: 'Delivery address is required.',
      };
    }
    return null;
  }

  const options = requestFlowOptions || {};
  const normalizedFulfilmentType = clean(fulfilmentType).toLowerCase();
  const usesMovementAddress =
    supportsStructuredRequestFlow &&
    usesAutomaticFulfilment &&
    ['delivery', 'localdelivery', 'nationwidedelivery', 'businessreturns'].includes(
      normalizedFulfilmentType,
    );
  const requiresStandardAddress =
    Boolean(requireAddress) &&
    showAddress !== false &&
    !usesMovementAddress &&
    (!supportsStructuredRequestFlow ||
      (requestType !== 'orderRequest' &&
        requestType !== 'pickupDeliveryRequest'));
  if (requiresStandardAddress && !clean(address) && !clean(postcode)) {
    return {
      code: 'missing_address_or_postcode',
      message:
        clean(standardAddressRequiredMessage) ||
        'Address or postcode is required for this service.',
    };
  }

  if (
    supportsStructuredRequestFlow &&
    (options.showFulfilmentChoice || usesAutomaticFulfilment) &&
    !clean(fulfilmentType)
  ) {
    return {
      code: 'missing_fulfilment_type',
      message: 'Please choose collection or delivery.',
    };
  }
  if (
    supportsStructuredRequestFlow &&
    (options.showFulfilmentChoice || usesAutomaticFulfilment) &&
    ['delivery', 'localdelivery', 'nationwidedelivery'].includes(
      normalizedFulfilmentType,
    ) &&
    !clean(deliveryAddress)
  ) {
    return {
      code: 'missing_delivery_address',
      message: 'Delivery address is required.',
    };
  }
  if (
    supportsStructuredRequestFlow &&
    (options.showFulfilmentChoice || usesAutomaticFulfilment) &&
    normalizedFulfilmentType === 'businessreturns' &&
    !clean(returnAddress)
  ) {
    return {
      code: 'missing_return_address',
      message: 'Return address is required.',
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
