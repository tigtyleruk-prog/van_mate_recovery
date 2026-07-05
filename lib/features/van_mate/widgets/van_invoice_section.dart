import 'package:flutter/material.dart';

import '../models/van_invoice_draft.dart';

class TradeInvoiceSection extends StatelessWidget {
  const TradeInvoiceSection({super.key, this.invoice});

  final VanInvoiceDraft? invoice;

  String get _invoiceNumber {
    final value = invoice?.invoiceNumber.trim() ?? '';
    if (value.isNotEmpty) return value;
    return 'INV-1023'; // TODO: Replace with real invoice number when available
  }

  String get _invoiceStatus {
    final status = invoice?.paymentStatus.trim().toLowerCase() ?? '';
    return switch (status) {
      'paid' => 'Paid',
      'sent' => 'Sent',
      'overdue' => 'Overdue',
      'draft' => 'Draft',
      _ => 'Sent', // TODO: Map all invoice statuses when model is fully connected
    };
  }

  String get _issueDate {
    final value = invoice?.invoiceDate.trim() ?? '';
    if (value.isNotEmpty) return value;
    return '01 Jan 2024'; // TODO: Replace with real issue date when available
  }

  String get _dueDate {
    final value = invoice?.dueDateLabel.trim() ?? '';
    if (value.isNotEmpty) return value;
    return 'Due on receipt'; // TODO: Replace with real due date when available
  }

  String get _lineItemSummary {
    final count = invoice?.lineItemCount ?? 0;
    if (count > 0) return '$count line items';
    return '5 line items'; // TODO: Replace with real line item count when available
  }

  String get _labour {
    // TODO: Labour breakdown not yet separated in VanInvoiceDraft model
    return '£500.00';
  }

  String get _materials {
    // TODO: Materials breakdown not yet separated in VanInvoiceDraft model
    return '£550.00';
  }

  String get _wasteRemoval {
    // TODO: Waste removal not yet separated in VanInvoiceDraft model
    return '£50.00';
  }

  String get _vat {
    // TODO: VAT not yet in VanInvoiceDraft model
    return '£220.00';
  }

  String get _total {
    final value = invoice?.totalDueText.trim() ?? '';
    if (value.isNotEmpty) return value;
    return '£1,320.00'; // TODO: Replace with real total when available
  }

  String get _paid {
    if (invoice != null && invoice!.isPaid) {
      return invoice!.totalDueText;
    }
    return '£0.00'; // TODO: Replace with real paid amount when payment tracking is available
  }

  String get _balanceDue {
    if (invoice != null && invoice!.isPaid) {
      return '£0.00';
    }
    return invoice?.totalDueText ?? '£1,320.00'; // TODO: Replace with real balance when payment tracking is available
  }

  String get _paymentMethod {
    // TODO: Payment method not yet in VanInvoiceDraft model
    return 'Bank transfer';
  }

  String get _note1 {
    final notes = invoice?.visibleInvoiceNotes.trim() ?? '';
    if (notes.isNotEmpty) {
      final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isNotEmpty) return lines.first;
    }
    return 'Sent to customer'; // TODO: Replace with real invoice notes when available
  }

  String get _note2 {
    final notes = invoice?.visibleInvoiceNotes.trim() ?? '';
    if (notes.isNotEmpty) {
      final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length > 1) return lines[1];
    }
    return 'Due on receipt'; // TODO: Replace with real invoice notes when available
  }

  String get _note3 {
    final notes = invoice?.visibleInvoiceNotes.trim() ?? '';
    if (notes.isNotEmpty) {
      final lines = notes.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length > 2) return lines[2];
    }
    return 'Payment instructions included'; // TODO: Replace with real invoice notes when available
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF142031) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InvoiceCard(
          title: 'Invoice Summary',
          icon: Icons.receipt_long_outlined,
          summary: '$_invoiceNumber • $_invoiceStatus',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice number: $_invoiceNumber',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Status: $_invoiceStatus',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Issue date: $_issueDate',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Due date: $_dueDate',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Balance due: $_balanceDue',
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _InvoiceCard(
          title: 'Invoice Breakdown',
          icon: Icons.list_alt_outlined,
          summary: '$_lineItemSummary • $_total',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Labour: $_labour',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Materials: $_materials',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Waste removal: $_wasteRemoval',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'VAT: $_vat',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: $_total',
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _InvoiceCard(
          title: 'Payment Status',
          icon: Icons.payments_outlined,
          summary: '$_paid paid • $_balanceDue due',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid: $_paid',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Balance due: $_balanceDue',
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Payment method: $_paymentMethod',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _InvoiceCard(
          title: 'Invoice Notes',
          icon: Icons.sticky_note_2_outlined,
          summary: '3 notes',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _note1,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                _note2,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                _note3,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.title,
    required this.icon,
    required this.summary,
    required this.cardColor,
    required this.borderColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String summary;
  final Widget child;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.dark(
            surface: cardColor,
            onSurface: Colors.white,
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(icon, color: Colors.white, size: 20),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [child],
        ),
      ),
    );
  }
}