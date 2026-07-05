import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import 'van_business_profile.dart';

class VanInvoiceLineItem {
  const VanInvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.amount,
    this.extraKey,
  });

  final String description;
  final int quantity;
  final double amount;
  final String? extraKey;

  double get total => quantity * amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'description': description,
      'quantity': quantity,
      'amount': amount,
      'extraKey': extraKey,
    };
  }

  factory VanInvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return VanInvoiceLineItem(
      description: _jsonString(json['description'], fallback: 'Line item'),
      quantity: _jsonInt(json['quantity'], fallback: 1),
      amount: _jsonDouble(json['amount']),
      extraKey: _jsonStringOrNull(json['extraKey']),
    );
  }
}

@immutable
class VanInvoiceDraft {
  static const String dueOnReceiptLabel = 'Due on receipt';
  static const String paymentInstructionsFallback =
      'Payment will be arranged directly with the driver/business.';

  const VanInvoiceDraft({
    this.jobKey,
    this.linkedJobId,
    this.linkedQuoteId,
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.businessAddress,
    required this.paymentInstructions,
    required this.quoteExtras,
    required this.quoteNotes,
    required this.quotePaymentInstructions,
    required this.quoteMessage,
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
    this.logoUrl,
    this.paymentStatus = 'unpaid',
    this.paidAt,
    this.paymentReminder3dSentAt,
    this.paymentReminder7dSentAt,
    this.paymentReminder14dSentAt,
  });

  factory VanInvoiceDraft.initial({
    String? jobKey,
    String? linkedJobId,
    String? linkedQuoteId,
    required VanBusinessProfile businessProfile,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String billingAddress,
    required String invoiceDate,
    required String jobReference,
    required String jobDescription,
    required String invoiceNumber,
    List<String> quoteExtras = const <String>[],
    String quoteNotes = '',
    String quotePaymentInstructions = '',
    String quoteMessage = '',
    double quoteAmount = 0,
  }) {
    final normalizedExtras = quoteExtras
        .map((item) => sanitizeVanText(item).trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final lineItems = <VanInvoiceLineItem>[
      VanInvoiceLineItem(
        description: jobReference,
        quantity: 1,
        amount: quoteAmount,
      ),
      for (var index = 0; index < normalizedExtras.length; index++)
        VanInvoiceLineItem(
          description: normalizedExtras[index],
          quantity: 1,
          amount: 0,
          extraKey:
              _canonicalInvoiceExtraKey(normalizedExtras[index]) ??
              _quoteExtraKey(normalizedExtras[index], index),
        ),
    ];
    final quotePaymentText = sanitizeVanText(quotePaymentInstructions).trim();
    final quoteNotesText = sanitizeVanText(quoteNotes).trim();
    final quoteMessageText = sanitizeVanText(quoteMessage).trim();

    return VanInvoiceDraft(
      jobKey: jobKey,
      linkedJobId: linkedJobId ?? jobKey,
      linkedQuoteId: linkedQuoteId,
      businessName: businessProfile.businessName,
      contactName: businessProfile.contactName,
      phone: businessProfile.phone,
      email: businessProfile.email,
      businessAddress: businessProfile.businessAddress,
      paymentInstructions: _resolveInvoicePaymentInstructions(
        quotePaymentText.isEmpty
            ? resolveVanMatePaymentInstructions(
                businessProfile.paymentInstructions,
              )
            : quotePaymentText,
      ),
      quoteExtras: normalizedExtras,
      quoteNotes: quoteNotesText,
      quotePaymentInstructions: quotePaymentText,
      quoteMessage: quoteMessageText,
      logoPath: businessProfile.logoPath,
      logoUrl: businessProfile.logoUrl,
      customerName: customerName,
      customerPhone: customerPhone,
      billingAddress: billingAddress,
      customerEmail: customerEmail,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueOnReceiptLabel,
      jobReference: jobReference,
      jobDescription: _resolveInvoiceJobDescription(
        explicitDescription: jobDescription,
        jobReference: jobReference,
      ),
      lineItems: lineItems,
      estimatedMiles: '',
      mileageCharge: 0,
      invoiceNotes: '',
      paymentStatus: 'unpaid',
    );
  }

  VanInvoiceDraft seedQuoteExtrasIfNeeded({required bool quoteAccepted}) {
    if (!quoteAccepted || quoteExtras.isEmpty) {
      return this;
    }

    if (lineItems.isEmpty) {
      // Empty drafts can be safely seeded from the accepted quote.
    } else if (lineItems.length == 1) {
      final onlyItem = lineItems.first;
      final onlyDescription = sanitizeVanText(
        onlyItem.description,
      ).trim().toLowerCase();
      final jobReferenceText = sanitizeVanText(
        jobReference,
      ).trim().toLowerCase();
      final looksLikeBaseLine =
          onlyItem.extraKey == null &&
          (jobReferenceText.isEmpty || onlyDescription == jobReferenceText);
      if (!looksLikeBaseLine) {
        return this;
      }
    } else {
      return this;
    }

    final baseLineItems = lineItems.isEmpty
        ? <VanInvoiceLineItem>[
            VanInvoiceLineItem(
              description: jobReference.trim().isEmpty
                  ? 'Line item'
                  : jobReference.trim(),
              quantity: 1,
              amount: 0,
            ),
          ]
        : <VanInvoiceLineItem>[lineItems.first];

    final seededExtras = <VanInvoiceLineItem>[];
    final seenKeys = <String>{};
    for (final item in baseLineItems) {
      final descriptionKey = _canonicalInvoiceExtraKey(item.description);
      final extraKey = item.extraKey?.trim().toLowerCase();
      if (descriptionKey != null) {
        seenKeys.add(descriptionKey);
      }
      if (extraKey != null && extraKey.isNotEmpty) {
        seenKeys.add(extraKey);
      }
    }

    for (var index = 0; index < quoteExtras.length; index++) {
      final description = sanitizeVanText(quoteExtras[index]).trim();
      if (description.isEmpty) {
        continue;
      }

      final canonicalKey = _canonicalInvoiceExtraKey(description);
      final itemKey = canonicalKey ?? _quoteExtraKey(description, index);
      final dedupeKey = canonicalKey ?? description.toLowerCase();
      if (seenKeys.contains(dedupeKey)) {
        continue;
      }

      seededExtras.add(
        VanInvoiceLineItem(
          description: description,
          quantity: 1,
          amount: 0,
          extraKey: itemKey,
        ),
      );
      seenKeys.add(dedupeKey);
    }

    if (seededExtras.isEmpty) {
      return this;
    }

    return copyWith(lineItems: [...baseLineItems, ...seededExtras]);
  }

  final String? jobKey;
  final String? linkedJobId;
  final String? linkedQuoteId;
  final String businessName;
  final String contactName;
  final String phone;
  final String email;
  final String businessAddress;
  final String paymentInstructions;
  final List<String> quoteExtras;
  final String quoteNotes;
  final String quotePaymentInstructions;
  final String quoteMessage;
  final String? logoPath;
  final String? logoUrl;
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
  final DateTime? paymentReminder3dSentAt;
  final DateTime? paymentReminder7dSentAt;
  final DateTime? paymentReminder14dSentAt;

  bool get hasLogo =>
      logoPath?.trim().isNotEmpty == true || logoUrl?.trim().isNotEmpty == true;
  bool get isPaid => paymentStatus.trim().toLowerCase() == 'paid';
  bool get isUnpaid => !isPaid;
  String get dueDateLabel {
    final value = sanitizeVanText(dueDate).trim();
    return value.isEmpty ? dueOnReceiptLabel : value;
  }

  String get paymentInstructionsLabel =>
      _resolveInvoicePaymentInstructions(paymentInstructions);

  DateTime? reminderSentAtForStage(int stageDays) {
    return switch (stageDays) {
      3 => paymentReminder3dSentAt,
      7 => paymentReminder7dSentAt,
      14 => paymentReminder14dSentAt,
      _ => null,
    };
  }

  bool hasReminderBeenSentForStage(int stageDays) {
    return reminderSentAtForStage(stageDays) != null;
  }

  VanInvoiceDraft markReminderStagesSentUpTo({
    required int stageDays,
    required DateTime sentAt,
  }) {
    return copyWith(
      paymentReminder3dSentAt: stageDays >= 3
          ? (paymentReminder3dSentAt ?? sentAt)
          : paymentReminder3dSentAt,
      paymentReminder7dSentAt: stageDays >= 7
          ? (paymentReminder7dSentAt ?? sentAt)
          : paymentReminder7dSentAt,
      paymentReminder14dSentAt: stageDays >= 14
          ? (paymentReminder14dSentAt ?? sentAt)
          : paymentReminder14dSentAt,
    );
  }

  String get visibleJobDescription => _resolveInvoiceJobDescription(
    explicitDescription: jobDescription,
    jobReference: jobReference,
  );

  String get visibleInvoiceNotes => _resolveInvoiceNotes(
    invoiceNotes,
    paymentInstructions: paymentInstructionsLabel,
  );

  bool get hasVisibleInvoiceNotes => visibleInvoiceNotes.isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'jobKey': jobKey,
      'linkedJobId': linkedJobId,
      'linkedQuoteId': linkedQuoteId,
      'businessName': businessName,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'businessAddress': businessAddress,
      'paymentInstructions': paymentInstructions,
      'quoteExtras': quoteExtras,
      'quoteNotes': quoteNotes,
      'quotePaymentInstructions': quotePaymentInstructions,
      'quoteMessage': quoteMessage,
      'logoPath': logoPath,
      'logoUrl': logoUrl,
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
      'paymentReminder3dSentAt': paymentReminder3dSentAt?.toIso8601String(),
      'paymentReminder7dSentAt': paymentReminder7dSentAt?.toIso8601String(),
      'paymentReminder14dSentAt': paymentReminder14dSentAt?.toIso8601String(),
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
      linkedJobId: _jsonStringOrNull(json['linkedJobId']),
      linkedQuoteId: _jsonStringOrNull(json['linkedQuoteId']),
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
      quoteExtras:
          (json['quoteExtras'] as List?)
              ?.map((item) => sanitizeVanText(item?.toString()).trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
      quoteNotes: _jsonString(json['quoteNotes'], fallback: ''),
      quotePaymentInstructions: _jsonString(
        json['quotePaymentInstructions'],
        fallback: '',
      ),
      quoteMessage: _jsonString(json['quoteMessage'], fallback: ''),
      logoPath: _jsonStringOrNull(json['logoPath']),
      logoUrl: _jsonStringOrNull(json['logoUrl']),
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
      estimatedMiles: _jsonString(json['estimatedMiles'], fallback: ''),
      mileageCharge: _jsonDouble(json['mileageCharge']),
      invoiceNotes: _jsonString(json['invoiceNotes'], fallback: ''),
      paymentStatus: _jsonString(json['paymentStatus'], fallback: 'unpaid'),
      paidAt: _jsonDateTimeOrNull(json['paidAt']),
      paymentReminder3dSentAt: _jsonDateTimeOrNull(
        json['paymentReminder3dSentAt'],
      ),
      paymentReminder7dSentAt: _jsonDateTimeOrNull(
        json['paymentReminder7dSentAt'],
      ),
      paymentReminder14dSentAt: _jsonDateTimeOrNull(
        json['paymentReminder14dSentAt'],
      ),
    );
  }

  VanInvoiceDraft copyWith({
    String? businessName,
    String? contactName,
    String? phone,
    String? email,
    String? businessAddress,
    String? paymentInstructions,
    List<String>? quoteExtras,
    String? quoteNotes,
    String? quotePaymentInstructions,
    String? quoteMessage,
    Object? logoPath = _vanInvoiceDraftNoChange,
    Object? logoUrl = _vanInvoiceDraftNoChange,
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
    String? linkedJobId,
    String? linkedQuoteId,
    String? paymentStatus,
    Object? paidAt = _vanInvoiceDraftNoChange,
    Object? paymentReminder3dSentAt = _vanInvoiceDraftNoChange,
    Object? paymentReminder7dSentAt = _vanInvoiceDraftNoChange,
    Object? paymentReminder14dSentAt = _vanInvoiceDraftNoChange,
  }) {
    return VanInvoiceDraft(
      jobKey: jobKey ?? this.jobKey,
      linkedJobId: linkedJobId ?? this.linkedJobId,
      linkedQuoteId: linkedQuoteId ?? this.linkedQuoteId,
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessAddress: businessAddress ?? this.businessAddress,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      quoteExtras: quoteExtras ?? this.quoteExtras,
      quoteNotes: quoteNotes ?? this.quoteNotes,
      quotePaymentInstructions:
          quotePaymentInstructions ?? this.quotePaymentInstructions,
      quoteMessage: quoteMessage ?? this.quoteMessage,
      logoPath: identical(logoPath, _vanInvoiceDraftNoChange)
          ? this.logoPath
          : logoPath as String?,
      logoUrl: identical(logoUrl, _vanInvoiceDraftNoChange)
          ? this.logoUrl
          : logoUrl as String?,
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
      paidAt: identical(paidAt, _vanInvoiceDraftNoChange)
          ? this.paidAt
          : paidAt as DateTime?,
      paymentReminder3dSentAt:
          identical(paymentReminder3dSentAt, _vanInvoiceDraftNoChange)
          ? this.paymentReminder3dSentAt
          : paymentReminder3dSentAt as DateTime?,
      paymentReminder7dSentAt:
          identical(paymentReminder7dSentAt, _vanInvoiceDraftNoChange)
          ? this.paymentReminder7dSentAt
          : paymentReminder7dSentAt as DateTime?,
      paymentReminder14dSentAt:
          identical(paymentReminder14dSentAt, _vanInvoiceDraftNoChange)
          ? this.paymentReminder14dSentAt
          : paymentReminder14dSentAt as DateTime?,
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

    addSection('Job:', <String>[jobReference, visibleJobDescription]);

    lines
      ..add('')
      ..add('Invoice date: ${sanitizeVanText(invoiceDate).trim()}')
      ..add('Due: $dueDateLabel');

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

    if (paymentInstructionsLabel.trim().isNotEmpty) {
      lines
        ..add('')
        ..add('Payment instructions:')
        ..add(paymentInstructionsLabel);
    }

    if (hasVisibleInvoiceNotes) {
      lines
        ..add('')
        ..add('Notes:')
        ..add(visibleInvoiceNotes);
    }

    return lines.join('\n');
  }

  String _moneyText(num amount) => formatCurrency(amount);
}

const Object _vanInvoiceDraftNoChange = Object();

String _quoteExtraKey(String value, int index) {
  final normalized = sanitizeVanText(value)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (normalized.isEmpty) {
    return 'quote_extra_${index + 1}';
  }
  return 'quote_extra_${index + 1}_$normalized';
}

String? _canonicalInvoiceExtraKey(String value) {
  final normalized = sanitizeVanText(value)
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized == 'custom item') {
    return 'custom';
  }
  if (normalized.contains('collection') && normalized.contains('delivery')) {
    return 'collection_delivery';
  }
  if (normalized.contains('waiting time')) {
    return 'waiting_time';
  }
  if (normalized.contains('stairs') ||
      normalized.contains('stairs access') ||
      normalized.contains('access charge')) {
    return 'stairs';
  }
  if (normalized.contains('extra helper') ||
      normalized.contains('loading help') ||
      normalized.contains('help loading') ||
      normalized.contains('loading/unloading') ||
      normalized.contains('loading unloading') ||
      normalized.contains('loading and unloading') ||
      normalized.contains('loading helper') ||
      normalized == 'helper') {
    return 'helper';
  }
  if (normalized.contains('mileage')) {
    return 'mileage';
  }

  return null;
}

String _resolveInvoicePaymentInstructions(String value) {
  final cleaned = sanitizeVanText(value).trim();
  if (cleaned.isEmpty) {
    return VanInvoiceDraft.paymentInstructionsFallback;
  }
  return cleaned;
}

String _resolveInvoiceJobDescription({
  required String explicitDescription,
  required String jobReference,
}) {
  if (_looksLikeQuoteConversationText(explicitDescription)) {
    final cleanedReference = sanitizeVanText(jobReference).trim();
    if (cleanedReference.isEmpty) {
      return 'Invoice for completed work.';
    }
    return 'Invoice for completed $cleanedReference work.';
  }
  final cleanedDescription = _cleanInvoiceVisibleText(
    explicitDescription,
    removeUrls: true,
  );
  if (cleanedDescription.isNotEmpty) {
    return cleanedDescription;
  }
  final cleanedReference = sanitizeVanText(jobReference).trim();
  if (cleanedReference.isEmpty) {
    return 'Invoice for completed work.';
  }
  return 'Invoice for completed $cleanedReference work.';
}

String _resolveInvoiceNotes(
  String value, {
  required String paymentInstructions,
}) {
  if (_looksLikeQuoteConversationText(value)) {
    return '';
  }
  final cleaned = _cleanInvoiceVisibleText(value, removeUrls: true);
  if (cleaned.isEmpty) {
    return '';
  }
  final normalizedCleaned = _normalizeInvoiceComparableText(cleaned);
  final normalizedPayment = _normalizeInvoiceComparableText(
    paymentInstructions,
  );
  if (normalizedCleaned.isEmpty || normalizedCleaned == normalizedPayment) {
    return '';
  }
  return cleaned;
}

String _cleanInvoiceVisibleText(String value, {required bool removeUrls}) {
  final lines = sanitizeVanText(value)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) {
        final normalized = line.toLowerCase();
        if (normalized.contains('revised quote')) {
          return false;
        }
        if (normalized.contains('open quote')) {
          return false;
        }
        if (normalized.contains("here's your quote")) {
          return false;
        }
        if (normalized.contains("here's your revised quote")) {
          return false;
        }
        if (normalized.contains('review your quote')) {
          return false;
        }
        if (normalized.contains('quote response')) {
          return false;
        }
        if (normalized.startsWith('quote:')) {
          return false;
        }
        if (normalized.contains('quote accepted')) {
          return false;
        }
        if (normalized.contains('quote ready')) {
          return false;
        }
        if (normalized.contains('requested appointment')) {
          return false;
        }
        if (normalized.contains('proposed appointment')) {
          return false;
        }
        if (normalized.contains('estimated duration')) {
          return false;
        }
        if (normalized.contains('payment / confirmation')) {
          return false;
        }
        if (removeUrls &&
            (normalized.contains('http://') ||
                normalized.contains('https://') ||
                normalized.contains('www.'))) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
  return lines.join('\n').trim();
}

bool _looksLikeQuoteConversationText(String value) {
  final normalized = sanitizeVanText(
    value,
  ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains("here's your quote") ||
      normalized.contains("here's your revised quote") ||
      normalized.contains('review your quote') ||
      normalized.contains('open quote') ||
      normalized.contains('/quote/') ||
      normalized.contains('quote_response.html') ||
      normalized.contains('proposed appointment') ||
      normalized.contains('requested appointment') ||
      normalized.contains('estimated duration') ||
      normalized.contains('quote:');
}

String _normalizeInvoiceComparableText(String value) {
  return sanitizeVanText(
    value,
  ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
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
