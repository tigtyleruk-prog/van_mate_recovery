import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import 'van_business_profile.dart';

class VanInvoiceLineItem {
  const VanInvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.amount,
  });

  final String description;
  final int quantity;
  final double amount;

  double get total => quantity * amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'quantity': quantity,
      'amount': amount,
    };
  }

  factory VanInvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return VanInvoiceLineItem(
      description: _jsonString(json['description'], fallback: 'Line item'),
      quantity: _jsonInt(json['quantity'], fallback: 1),
      amount: _jsonDouble(json['amount']),
    );
  }
}

@immutable
class VanInvoiceDraft {
  const VanInvoiceDraft({
    this.jobKey,
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.businessAddress,
    required this.paymentInstructions,
    required this.customerName,
    required this.customerPhone,
    required this.billingAddress,
    required this.customerEmail,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.jobReference,
    required this.jobDescription,
    required this.lineItems,
    required this.estimatedMiles,
    required this.mileageCharge,
    required this.invoiceNotes,
    this.logoPath,
    this.paymentStatus = 'unpaid',
    this.paidAt,
  });

  factory VanInvoiceDraft.initial({
    String? jobKey,
    required VanBusinessProfile businessProfile,
    required String customerName,
    required String customerPhone,
    required String billingAddress,
    required String invoiceDate,
    required String jobReference,
    required String jobDescription,
    required String invoiceNumber,
  }) {
    return VanInvoiceDraft(
      jobKey: jobKey,
      businessName: businessProfile.businessName,
      contactName: businessProfile.contactName,
      phone: businessProfile.phone,
      email: businessProfile.email,
      businessAddress: businessProfile.businessAddress,
      paymentInstructions: businessProfile.paymentInstructions,
      logoPath: businessProfile.logoPath,
      customerName: customerName,
      customerPhone: customerPhone,
      billingAddress: billingAddress,
      customerEmail: '',
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: '',
      jobReference: jobReference,
      jobDescription: jobDescription,
      lineItems: const [
        VanInvoiceLineItem(description: 'Line item', quantity: 1, amount: 0.00),
      ],
      estimatedMiles: '18.4',
      mileageCharge: 0,
      invoiceNotes:
          'Thank you for your business. Please pay using the details above.',
      paymentStatus: 'unpaid',
    );
  }

  final String? jobKey;
  final String businessName;
  final String contactName;
  final String phone;
  final String email;
  final String businessAddress;
  final String paymentInstructions;
  final String? logoPath;
  final String customerName;
  final String customerPhone;
  final String billingAddress;
  final String customerEmail;
  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final String jobReference;
  final String jobDescription;
  final List<VanInvoiceLineItem> lineItems;
  final String estimatedMiles;
  final double mileageCharge;
  final String invoiceNotes;
  final String paymentStatus;
  final DateTime? paidAt;

  bool get hasLogo => logoPath?.trim().isNotEmpty == true;
  bool get isPaid => paymentStatus.trim().toLowerCase() == 'paid';
  bool get isUnpaid => !isPaid;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jobKey': jobKey,
      'businessName': businessName,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'businessAddress': businessAddress,
      'paymentInstructions': paymentInstructions,
      'logoPath': logoPath,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'billingAddress': billingAddress,
      'customerEmail': customerEmail,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate,
      'dueDate': dueDate,
      'jobReference': jobReference,
      'jobDescription': jobDescription,
      'lineItems': lineItems.map((item) => item.toJson()).toList(),
      'estimatedMiles': estimatedMiles,
      'mileageCharge': mileageCharge,
      'invoiceNotes': invoiceNotes,
      'paymentStatus': paymentStatus,
      'paidAt': paidAt?.toIso8601String(),
    };
  }

  factory VanInvoiceDraft.fromJson(Map<String, dynamic> json) {
    final lineItemsJson = json['lineItems'];
    final lineItems = lineItemsJson is List
        ? lineItemsJson
              .whereType<Map>()
              .map(
                (item) => VanInvoiceLineItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <VanInvoiceLineItem>[];

    return VanInvoiceDraft(
      jobKey: _jsonStringOrNull(json['jobKey']),
      businessName: _jsonString(
        json['businessName'],
        fallback: const VanBusinessProfile.defaults().businessName,
      ),
      contactName: _jsonString(
        json['contactName'],
        fallback: const VanBusinessProfile.defaults().contactName,
      ),
      phone: _jsonString(
        json['phone'],
        fallback: const VanBusinessProfile.defaults().phone,
      ),
      email: _jsonString(
        json['email'],
        fallback: const VanBusinessProfile.defaults().email,
      ),
      businessAddress: _jsonString(
        json['businessAddress'],
        fallback: const VanBusinessProfile.defaults().businessAddress,
      ),
      paymentInstructions: _jsonString(
        json['paymentInstructions'],
        fallback: const VanBusinessProfile.defaults().paymentInstructions,
      ),
      logoPath: _jsonStringOrNull(json['logoPath']),
      customerName: _jsonString(json['customerName'], fallback: ''),
      customerPhone: _jsonString(json['customerPhone'], fallback: ''),
      billingAddress: _jsonString(json['billingAddress'], fallback: ''),
      customerEmail: _jsonString(json['customerEmail'], fallback: ''),
      invoiceNumber: _jsonString(json['invoiceNumber'], fallback: ''),
      invoiceDate: _jsonString(json['invoiceDate'], fallback: ''),
      dueDate: _jsonString(json['dueDate'], fallback: ''),
      jobReference: _jsonString(json['jobReference'], fallback: ''),
      jobDescription: _jsonString(json['jobDescription'], fallback: ''),
      lineItems: lineItems,
      estimatedMiles: _jsonString(json['estimatedMiles'], fallback: '0'),
      mileageCharge: _jsonDouble(json['mileageCharge']),
      invoiceNotes: _jsonString(json['invoiceNotes'], fallback: ''),
      paymentStatus: _jsonString(json['paymentStatus'], fallback: 'unpaid'),
      paidAt: _jsonDateTimeOrNull(json['paidAt']),
    );
  }

  VanInvoiceDraft copyWith({
    String? businessName,
    String? contactName,
    String? phone,
    String? email,
    String? businessAddress,
    String? paymentInstructions,
    String? logoPath,
    String? customerName,
    String? customerPhone,
    String? billingAddress,
    String? customerEmail,
    String? invoiceNumber,
    String? invoiceDate,
    String? dueDate,
    String? jobReference,
    String? jobDescription,
    List<VanInvoiceLineItem>? lineItems,
    String? estimatedMiles,
    double? mileageCharge,
    String? invoiceNotes,
    String? jobKey,
    String? paymentStatus,
    DateTime? paidAt,
  }) {
    return VanInvoiceDraft(
      jobKey: jobKey ?? this.jobKey,
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessAddress: businessAddress ?? this.businessAddress,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      logoPath: logoPath ?? this.logoPath,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      billingAddress: billingAddress ?? this.billingAddress,
      customerEmail: customerEmail ?? this.customerEmail,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      jobReference: jobReference ?? this.jobReference,
      jobDescription: jobDescription ?? this.jobDescription,
      lineItems: lineItems ?? this.lineItems,
      estimatedMiles: estimatedMiles ?? this.estimatedMiles,
      mileageCharge: mileageCharge ?? this.mileageCharge,
      invoiceNotes: invoiceNotes ?? this.invoiceNotes,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  int get lineItemCount => lineItems.length;

  double get lineItemsTotal =>
      lineItems.fold<double>(0, (total, item) => total + item.total);

  double get totalDue => lineItemsTotal + mileageCharge;

  String get totalDueText => _moneyText(totalDue);

  String get invoiceText => buildInvoiceShareText();

  String buildInvoiceShareText() {
    final lines = <String>['Invoice ${sanitizeVanText(invoiceNumber).trim()}'];

    void addSection(String title, List<String> values) {
      final sectionLines = values
          .map(sanitizeVanText)
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (sectionLines.isEmpty) {
        return;
      }

      lines
        ..add('')
        ..add(title)
        ..addAll(sectionLines);
    }

    addSection('From:', <String>[
      businessName,
      contactName,
      phone,
      email,
      businessAddress,
    ]);

    addSection('Bill to:', <String>[
      customerName,
      billingAddress,
      customerPhone,
      customerEmail,
    ]);

    addSection('Job:', <String>[jobReference, jobDescription]);

    if (lineItems.isNotEmpty) {
      lines
        ..add('')
        ..add('Items:');
      for (final item in lineItems) {
        lines.add(
          '- ${sanitizeVanText(item.description).trim()}: ${_moneyText(item.total)}'
          ' (${item.quantity} x ${_moneyText(item.amount)})',
        );
      }
    }

    if (estimatedMiles.trim().isNotEmpty || mileageCharge > 0) {
      lines
        ..add('')
        ..add('Mileage:');
      if (estimatedMiles.trim().isNotEmpty) {
        lines.add('Estimated miles: $estimatedMiles');
      }
      if (mileageCharge > 0) {
        lines.add('Charge: ${_moneyText(mileageCharge)}');
      }
    }

    lines
      ..add('')
      ..add('Total due: ${_moneyText(totalDue)}');

    if (paymentInstructions.trim().isNotEmpty) {
      lines
        ..add('')
        ..add('Payment instructions:')
        ..add(sanitizeVanText(paymentInstructions).trim());
    }

    if (invoiceNotes.trim().isNotEmpty) {
      lines
        ..add('')
        ..add('Notes:')
        ..add(sanitizeVanText(invoiceNotes).trim());
    }

    return lines.join('\n');
  }

  String _moneyText(num amount) => formatCurrency(amount);
}

String _jsonString(Object? value, {required String fallback}) {
  final text = sanitizeVanText(value?.toString()).trim();
  return text.isEmpty ? fallback : text;
}

String? _jsonStringOrNull(Object? value) {
  final text = sanitizeVanText(value?.toString()).trim();
  return text.isEmpty ? null : text;
}

int _jsonInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  final parsed = int.tryParse(value?.toString().trim() ?? '');
  return parsed ?? fallback;
}

double _jsonDouble(Object? value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  final cleaned =
      value?.toString().replaceAll(RegExp(r'[^0-9.\-]'), '').trim() ?? '';
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
    return fallback;
  }
  return double.tryParse(cleaned) ?? fallback;
}

DateTime? _jsonDateTimeOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
