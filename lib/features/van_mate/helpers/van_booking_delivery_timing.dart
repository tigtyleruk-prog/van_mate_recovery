import 'package:flutter/material.dart';

String? validateVanBookingDeliveryTiming({
  required DateTime? collectionDate,
  required TimeOfDay? collectionTime,
  required DateTime? deliveryDate,
  required TimeOfDay? deliveryTime,
  required bool sameDayDelivery,
  bool requireCollectionDate = true,
  bool requireCollectionTime = true,
  bool requireDeliveryDate = true,
  bool requireDeliveryTime = true,
}) {
  if (requireCollectionDate && collectionDate == null) {
    return 'Choose a preferred collection date.';
  }
  if (requireCollectionTime && collectionTime == null) {
    return 'Choose a preferred collection time.';
  }
  if (requireDeliveryDate && deliveryDate == null) {
    return 'Choose a preferred delivery date.';
  }
  if (requireDeliveryTime && deliveryTime == null) {
    return 'Choose a preferred delivery time or delivery window.';
  }
  if (collectionDate != null && deliveryDate != null) {
    final normalizedCollection = DateUtils.dateOnly(collectionDate);
    final normalizedDelivery = DateUtils.dateOnly(deliveryDate);
    if (normalizedDelivery.isBefore(normalizedCollection)) {
      return 'Preferred delivery must not be earlier than collection.';
    }
    if (sameDayDelivery &&
        !DateUtils.isSameDay(normalizedCollection, normalizedDelivery)) {
      return 'Same-day delivery must use the collection date.';
    }
  }
  if (collectionDate != null &&
      collectionTime != null &&
      deliveryDate != null &&
      deliveryTime != null) {
    final collectionAt = DateTime(
      collectionDate.year,
      collectionDate.month,
      collectionDate.day,
      collectionTime.hour,
      collectionTime.minute,
    );
    final deliveryAt = DateTime(
      deliveryDate.year,
      deliveryDate.month,
      deliveryDate.day,
      deliveryTime.hour,
      deliveryTime.minute,
    );
    if (deliveryAt.isBefore(collectionAt)) {
      return 'Preferred delivery must not be earlier than collection.';
    }
    if (sameDayDelivery && !deliveryAt.isAfter(collectionAt)) {
      return 'Preferred delivery time must be later than collection time.';
    }
  }
  return null;
}
