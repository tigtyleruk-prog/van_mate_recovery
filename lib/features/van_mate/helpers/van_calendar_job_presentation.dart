import 'package:flutter/material.dart';

import 'van_customer_journey_theme.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../models/van_service_handover.dart';

const Color vanCalendarDefaultAccent = Color(0xFF4A7DFF);
const Color vanCalendarCollectionAccent = Color(0xFFFFC38C);
const Color vanCalendarTransferAccent = Color(0xFFB48CFF);

enum VanCalendarActionKind { dropOff, pickUp }

class VanCalendarActionProjection {
  const VanCalendarActionProjection({
    required this.kind,
    required this.label,
    required this.start,
    this.visualOccupancyMinutes = 1,
    this.showBookingDuration = false,
    this.address = '',
    required this.icon,
  });

  final VanCalendarActionKind kind;
  final String label;
  final DateTime start;
  final int visualOccupancyMinutes;
  final bool showBookingDuration;
  final String address;
  final IconData icon;
}

List<VanCalendarActionProjection> vanCalendarActionProjections(
  DriverCustomerReplyMockData job,
) {
  final dropOff = job.dropOffDateTime;
  final pickUp = job.pickUpDateTime;
  final isHandoverJob =
      job.hasServiceHandover ||
      job.startHandover.trim().isNotEmpty ||
      job.endHandover.trim().isNotEmpty;
  if (!isHandoverJob || dropOff == null || pickUp == null) {
    return const <VanCalendarActionProjection>[];
  }
  final handover = job.effectiveHandover;
  final startAddress = handover.start.needsCustomerAddress
      ? (job.collectionAddress.trim().isNotEmpty
            ? job.collectionAddress.trim()
            : job.address.trim())
      : job.businessDropOffInstructions.trim();
  final endAddress = handover.end.needsCustomerAddress
      ? (job.returnAddress.trim().isNotEmpty
            ? job.returnAddress.trim()
            : job.collectionAddress.trim())
      : (job.businessCollectionInstructions.trim().isNotEmpty
            ? job.businessCollectionInstructions.trim()
            : job.businessDropOffInstructions.trim());
  return <VanCalendarActionProjection>[
    VanCalendarActionProjection(
      kind: VanCalendarActionKind.dropOff,
      label: handover.start.calendarLabel,
      start: dropOff,
      address: startAddress,
      icon: handover.start == VanStartHandover.customerDropsOff
          ? Icons.move_to_inbox_outlined
          : Icons.local_shipping_outlined,
    ),
    VanCalendarActionProjection(
      kind: VanCalendarActionKind.pickUp,
      label: handover.end.calendarLabel,
      start: pickUp,
      address: endAddress,
      icon: handover.end == VanEndHandover.customerCollects
          ? Icons.shopping_bag_outlined
          : Icons.keyboard_return_rounded,
    ),
  ];
}

String _vanCalendarDateTimeLabel(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${months[value.month - 1]} ${value.year} at $hour:$minute';
}

String vanCalendarDropOffPickupTimingText(DriverCustomerReplyMockData job) {
  final dropOff = job.dropOffDateTime;
  final pickUp = job.pickUpDateTime;
  if (dropOff == null || pickUp == null) {
    return '';
  }
  final handover = job.effectiveHandover;
  return '${handover.start.calendarLabel}: ${_vanCalendarDateTimeLabel(dropOff)}\n'
      '${handover.end.calendarLabel}: ${_vanCalendarDateTimeLabel(pickUp)}';
}

Color vanCalendarAccentForJob(DriverCustomerReplyMockData job) {
  return job.customerJourney.journeyTheme.accent;
}

IconData vanCalendarIconForJob(DriverCustomerReplyMockData job) {
  if (job.isCompletedJob) {
    return Icons.check_circle;
  }
  return job.customerJourney.journeyTheme.icon;
}

String vanCalendarDisplayJobTitle(DriverCustomerReplyMockData job) {
  final title = job.jobTitle.trim().isEmpty
      ? 'Booked job'
      : job.jobTitle.trim();
  final prefix = switch (job.calendarJobKind) {
    VanCalendarJobKind.collectionOrder => 'Collection',
    VanCalendarJobKind.deliveryOrder => 'Delivery',
    VanCalendarJobKind.dropOffPickup => 'Drop-off / Pick-up',
    VanCalendarJobKind.pickupDelivery => 'Pickup / Delivery',
    VanCalendarJobKind.standard => '',
  };
  return prefix.isEmpty ? title : '$prefix – $title';
}

String vanCalendarCompletionActionLabel(DriverCustomerReplyMockData job) {
  return switch (job.calendarJobKind) {
    VanCalendarJobKind.collectionOrder => 'Mark collected',
    VanCalendarJobKind.deliveryOrder => 'Mark delivered',
    VanCalendarJobKind.dropOffPickup => 'Mark drop-off / pick-up done',
    VanCalendarJobKind.pickupDelivery => 'Mark pickup / delivery done',
    VanCalendarJobKind.standard => 'Mark done',
  };
}

String vanCalendarCompletionPastTenseLabel(DriverCustomerReplyMockData job) {
  return switch (job.calendarJobKind) {
    VanCalendarJobKind.collectionOrder => 'Order marked collected.',
    VanCalendarJobKind.deliveryOrder => 'Order marked delivered.',
    VanCalendarJobKind.dropOffPickup => 'Drop-off / pick-up marked done.',
    VanCalendarJobKind.pickupDelivery => 'Pickup / delivery marked done.',
    VanCalendarJobKind.standard => 'Job marked done.',
  };
}
