import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import 'van_business_profile.dart';

enum VanJobReportRange { today, thisWeek }

extension VanJobReportRangeLabel on VanJobReportRange {
  String get label => switch (this) {
    VanJobReportRange.today => 'Today',
    VanJobReportRange.thisWeek => 'This week',
  };
}

@immutable
class VanJobReportEntry {
  const VanJobReportEntry({
    required this.customerName,
    required this.jobTitle,
    required this.jobDateLabel,
    required this.completedAt,
    required this.address,
    required this.exactPinSaved,
    this.scheduledAt,
    this.phone,
    this.quoteAmount,
    this.invoiceNumber,
    this.invoiceTotal,
    this.estimatedMiles,
    this.mileageCharge,
    this.paymentStatus = 'unpaid',
    this.notes,
  });

  final String customerName;
  final String jobTitle;
  final String jobDateLabel;
  final DateTime completedAt;
  final DateTime? scheduledAt;
  final String address;
  final bool exactPinSaved;
  final String? phone;
  final double? quoteAmount;
  final String? invoiceNumber;
  final double? invoiceTotal;
  final double? estimatedMiles;
  final double? mileageCharge;
  final String paymentStatus;
  final String? notes;

  bool get hasInvoice => invoiceNumber?.trim().isNotEmpty == true;
  bool get hasQuote => quoteAmount != null;
  bool get hasMileageCharge => (mileageCharge ?? 0) > 0;
  bool get isPaid => paymentStatus.trim().toLowerCase() == 'paid';
  bool get isUnpaid => !isPaid;
  String get paymentStatusLabel => isPaid ? 'Paid' : 'Unpaid';

  bool get hasSeparateScheduledDate =>
      scheduledAt != null && !_isSameDay(scheduledAt!, completedAt);

  String get completedDateText => formatVanDate(completedAt);

  String? get scheduledDateText =>
      scheduledAt == null ? null : formatVanDate(scheduledAt!);

  String get completionLabel => 'Completed: $completedDateText';

  String? get scheduledLabel =>
      scheduledAt == null ? null : 'Scheduled: $scheduledDateText';

  String get quoteLabel => hasQuote
      ? 'Quote: ${formatVanCurrency(quoteAmount ?? 0)}'
      : 'Quote: none';

  String get invoiceLabel {
    if (!hasInvoice) {
      return 'Invoice: none';
    }

    final cleanedInvoiceNumber = sanitizeVanText(invoiceNumber).trim();
    return 'Invoice: ${cleanedInvoiceNumber.isEmpty ? '-' : cleanedInvoiceNumber} - ${formatVanCurrency(invoiceTotal ?? 0)} - $paymentStatusLabel';
  }

  String get reportDateSummary => hasSeparateScheduledDate
      ? '$completionLabel\n$scheduledLabel'
      : completionLabel;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

@immutable
class VanJobReportData {
  const VanJobReportData({
    required this.businessProfile,
    required this.range,
    required this.generatedAt,
    required this.rangeStart,
    required this.rangeEndExclusive,
    required this.entries,
  });

  final VanBusinessProfile businessProfile;
  final VanJobReportRange range;
  final DateTime generatedAt;
  final DateTime rangeStart;
  final DateTime rangeEndExclusive;
  final List<VanJobReportEntry> entries;

  bool get hasEntries => entries.isNotEmpty;

  String get rangeLabel => range.label;

  String get previewTitle => range == VanJobReportRange.today
      ? 'Today completed jobs report'
      : 'This week completed jobs report';

  String get previewSubtitle => range == VanJobReportRange.today
      ? 'Completed on ${formatVanDate(rangeStart)}'
      : 'Completed this week';

  String get dateRangeLabel {
    if (range == VanJobReportRange.today) {
      return formatVanDate(rangeStart);
    }

    final rangeEnd = rangeEndExclusive.subtract(const Duration(days: 1));
    return '${formatVanDate(rangeStart)} to ${formatVanDate(rangeEnd)}';
  }

  int get completedJobsCount => entries.length;

  int get quotesSentCount => entries.where((entry) => entry.hasQuote).length;

  int get invoicesCreatedCount =>
      entries.where((entry) => entry.hasInvoice).length;

  double get totalQuoted => entries.fold<double>(
    0,
    (total, entry) => total + (entry.quoteAmount ?? 0),
  );

  double get totalInvoiced => entries.fold<double>(
    0,
    (total, entry) => total + (entry.invoiceTotal ?? 0),
  );

  double get totalPaid => entries.fold<double>(
    0,
    (total, entry) => total + (entry.isPaid ? (entry.invoiceTotal ?? 0) : 0),
  );

  double get totalOutstanding => entries.fold<double>(
    0,
    (total, entry) => total + (entry.isUnpaid ? (entry.invoiceTotal ?? 0) : 0),
  );

  double get totalCompletedJobValue => entries.fold<double>(
    0,
    (total, entry) => total + (entry.invoiceTotal ?? entry.quoteAmount ?? 0),
  );

  double get totalMiles => entries.fold<double>(
    0,
    (total, entry) => total + (entry.estimatedMiles ?? 0),
  );

  double get totalMileageCharges => entries.fold<double>(
    0,
    (total, entry) => total + (entry.mileageCharge ?? 0),
  );

  double get mileageTotal => totalMiles;

  String get totalQuotedText => formatVanCurrency(totalQuoted);
  String get totalInvoicedText => formatVanCurrency(totalInvoiced);
  String get totalPaidText => formatVanCurrency(totalPaid);
  String get totalOutstandingText => formatVanCurrency(totalOutstanding);
  String get totalCompletedJobValueText =>
      formatVanCurrency(totalCompletedJobValue);
  String get totalMilesText => formatVanMileageTotal(totalMiles);
  String get totalMileageChargesText => formatVanCurrency(totalMileageCharges);
  String get mileageTotalText => totalMilesText;

  String buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln(previewTitle);
    buffer.writeln(previewSubtitle);
    buffer.writeln('');
    buffer.writeln('Completed jobs: $completedJobsCount');
    buffer.writeln('Quotes sent: $quotesSentCount');
    buffer.writeln('Invoices created: $invoicesCreatedCount');
    buffer.writeln('Total quoted: $totalQuotedText');
    buffer.writeln('Total invoiced: $totalInvoicedText');
    buffer.writeln('Paid: $totalPaidText');
    buffer.writeln('Outstanding: $totalOutstandingText');
    buffer.writeln('Total miles: $totalMilesText');
    buffer.writeln('Mileage charges included: $totalMileageChargesText');
    buffer.writeln('Completed job value: $totalCompletedJobValueText');

    if (entries.isEmpty) {
      return buffer.toString().trimRight();
    }

    buffer.writeln('');
    buffer.writeln('Jobs:');
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.writeln(
        '${i + 1}. ${sanitizeVanText(entry.customerName).trim()} - ${sanitizeVanText(entry.jobTitle).trim()}',
      );
      buffer.writeln('   ${entry.completionLabel}');
      if (entry.scheduledLabel != null) {
        buffer.writeln('   ${entry.scheduledLabel}');
      }
      buffer.writeln('   ${entry.quoteLabel}');
      buffer.writeln('   ${entry.invoiceLabel}');
      buffer.writeln(
        '   Exact pin: ${entry.exactPinSaved ? 'saved' : 'not saved'}',
      );
      if (entry.estimatedMiles != null) {
        buffer.writeln(
          '   Mileage: ${formatVanMileage(entry.estimatedMiles ?? 0)}',
        );
      }
      if (entry.hasMileageCharge) {
        buffer.writeln(
          '   Mileage charge included: ${formatVanCurrency(entry.mileageCharge ?? 0)}',
        );
      }
      if (entry.notes != null && entry.notes!.trim().isNotEmpty) {
        buffer.writeln('   Notes: ${sanitizeVanText(entry.notes).trim()}');
      }
    }

    return buffer.toString().trimRight();
  }
}

String formatVanCurrency(num amount) => formatCurrency(amount);

String formatVanMileage(num amount) {
  if (amount <= 0) {
    return '-';
  }
  return formatMileage(amount);
}

String formatVanMileageTotal(num amount) {
  return formatMileageTotal(amount);
}

String formatVanDate(DateTime date) => formatDate(date);

String formatVanDateForFile(DateTime date) => formatDateForFile(date);

String summarizeVanNotes(String? note) {
  final cleaned = note?.trim() ?? '';
  if (cleaned.isEmpty) {
    return '';
  }

  if (cleaned.length <= 96) {
    return cleaned;
  }

  return '${cleaned.substring(0, 93).trimRight()}...';
}
