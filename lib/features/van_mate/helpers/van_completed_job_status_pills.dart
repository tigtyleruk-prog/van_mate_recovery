import 'package:flutter/material.dart';

import 'van_status_tone.dart';
import '../pages/driver_customer_reply_mock_page.dart';

class VanCompletedJobStatusPillData {
  const VanCompletedJobStatusPillData({
    required this.label,
    required this.color,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool filled;
}

List<VanCompletedJobStatusPillData> buildVanCompletedJobStatusPills(
  DriverCustomerReplyMockData job,
) {
  if (!job.isCompleted) {
    return const <VanCompletedJobStatusPillData>[];
  }

  final invoice = DriverReplyMockState.instance.invoiceForJob(
    job.invoiceHistoryKey,
  );

  return <VanCompletedJobStatusPillData>[
    const VanCompletedJobStatusPillData(
      label: 'Completed',
      color: kVanStatusPositiveColor,
      icon: Icons.check_circle,
      filled: true,
    ),
    if (invoice != null)
      invoice.isPaid
          ? const VanCompletedJobStatusPillData(
              label: 'Paid',
              color: kVanStatusPositiveColor,
              icon: Icons.payments_outlined,
            )
          : const VanCompletedJobStatusPillData(
              label: 'Invoiced',
              color: kVanStatusPrimaryColor,
              icon: Icons.receipt_long_outlined,
            ),
  ];
}
