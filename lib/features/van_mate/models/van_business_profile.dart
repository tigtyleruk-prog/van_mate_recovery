import '../helpers/van_text_formatters.dart';

class VanBusinessProfile {
  const VanBusinessProfile({
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.businessAddress,
    required this.paymentInstructions,
    required this.defaultExtraHelperAmount,
    required this.defaultStairsAccessAmount,
    required this.defaultWaitingTimeAmount,
    required this.defaultCollectionDeliveryAmount,
    required this.defaultMileageRate,
    this.logoPath,
    this.logoUrl,
  });

  const VanBusinessProfile.defaults()
    : businessName = '',
      contactName = '',
      phone = '',
      email = '',
      businessAddress = '',
      paymentInstructions = kVanMatePaymentInstructionsFallback,
      defaultExtraHelperAmount = 0,
      defaultStairsAccessAmount = 0,
      defaultWaitingTimeAmount = 0,
      defaultCollectionDeliveryAmount = 0,
      defaultMileageRate = 0,
      logoPath = null,
      logoUrl = null;

  final String businessName;
  final String contactName;
  final String phone;
  final String email;
  final String businessAddress;
  final String paymentInstructions;
  final double defaultExtraHelperAmount;
  final double defaultStairsAccessAmount;
  final double defaultWaitingTimeAmount;
  final double defaultCollectionDeliveryAmount;
  final double defaultMileageRate;
  final String? logoPath;
  final String? logoUrl;

  bool get hasLogo =>
      logoPath?.trim().isNotEmpty == true || logoUrl?.trim().isNotEmpty == true;

  VanBusinessProfile copyWith({
    String? businessName,
    String? contactName,
    String? phone,
    String? email,
    String? businessAddress,
    String? paymentInstructions,
    double? defaultExtraHelperAmount,
    double? defaultStairsAccessAmount,
    double? defaultWaitingTimeAmount,
    double? defaultCollectionDeliveryAmount,
    double? defaultMileageRate,
    Object? logoPath = _vanBusinessProfileNoChange,
    Object? logoUrl = _vanBusinessProfileNoChange,
  }) {
    return VanBusinessProfile(
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessAddress: businessAddress ?? this.businessAddress,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      defaultExtraHelperAmount:
          defaultExtraHelperAmount ?? this.defaultExtraHelperAmount,
      defaultStairsAccessAmount:
          defaultStairsAccessAmount ?? this.defaultStairsAccessAmount,
      defaultWaitingTimeAmount:
          defaultWaitingTimeAmount ?? this.defaultWaitingTimeAmount,
      defaultCollectionDeliveryAmount:
          defaultCollectionDeliveryAmount ??
          this.defaultCollectionDeliveryAmount,
      defaultMileageRate: defaultMileageRate ?? this.defaultMileageRate,
      logoPath: identical(logoPath, _vanBusinessProfileNoChange)
          ? this.logoPath
          : logoPath as String?,
      logoUrl: identical(logoUrl, _vanBusinessProfileNoChange)
          ? this.logoUrl
          : logoUrl as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'businessName': businessName,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'businessAddress': businessAddress,
      'paymentInstructions': paymentInstructions,
      'defaultExtraHelperAmount': defaultExtraHelperAmount,
      'defaultStairsAccessAmount': defaultStairsAccessAmount,
      'defaultWaitingTimeAmount': defaultWaitingTimeAmount,
      'defaultCollectionDeliveryAmount': defaultCollectionDeliveryAmount,
      'defaultMileageRate': defaultMileageRate,
      'logoPath': logoPath,
      'logoUrl': logoUrl,
    };
  }

  factory VanBusinessProfile.fromJson(Map<String, dynamic> json) {
    String readText(String key, String fallback) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    String? readOptionalText(String key) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    double readAmount(String key) {
      final raw = json[key];
      if (raw is num) {
        return raw.toDouble();
      }
      final value = raw?.toString().trim() ?? '';
      return double.tryParse(value) ?? 0;
    }

    return VanBusinessProfile(
      businessName: readText(
        'businessName',
        const VanBusinessProfile.defaults().businessName,
      ),
      contactName: readText(
        'contactName',
        const VanBusinessProfile.defaults().contactName,
      ),
      phone: readText('phone', const VanBusinessProfile.defaults().phone),
      email: readText('email', const VanBusinessProfile.defaults().email),
      businessAddress: readText(
        'businessAddress',
        const VanBusinessProfile.defaults().businessAddress,
      ),
      paymentInstructions: resolveVanMatePaymentInstructions(
        json['paymentInstructions']?.toString(),
      ),
      defaultExtraHelperAmount: readAmount('defaultExtraHelperAmount'),
      defaultStairsAccessAmount: readAmount('defaultStairsAccessAmount'),
      defaultWaitingTimeAmount: readAmount('defaultWaitingTimeAmount'),
      defaultCollectionDeliveryAmount: readAmount(
        'defaultCollectionDeliveryAmount',
      ),
      defaultMileageRate: readAmount('defaultMileageRate'),
      logoPath: readOptionalText('logoPath'),
      logoUrl: readOptionalText('logoUrl'),
    );
  }

  double defaultAmountForQuickExtra(String key) {
    switch (key.trim().toLowerCase()) {
      case 'helper':
        return defaultExtraHelperAmount;
      case 'stairs':
        return defaultStairsAccessAmount;
      case 'waiting_time':
        return defaultWaitingTimeAmount;
      case 'collection_delivery':
        return defaultCollectionDeliveryAmount;
      case 'mileage':
        return defaultMileageRate;
      default:
        return 0;
    }
  }
}

const Object _vanBusinessProfileNoChange = Object();
