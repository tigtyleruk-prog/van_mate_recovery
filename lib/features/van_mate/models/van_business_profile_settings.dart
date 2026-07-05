import '../helpers/van_business_logo_support.dart';
import '../helpers/van_text_formatters.dart';

class VanBusinessProfileSettings {
  const VanBusinessProfileSettings({
    required this.businessName,
    required this.ownerName,
    required this.businessType,
    required this.phoneNumber,
    required this.emailAddress,
    required this.websiteOrSocialLink,
    required this.addressLine1,
    required this.addressLine2,
    required this.townOrCity,
    required this.postcode,
    required this.bankName,
    required this.accountName,
    required this.sortCode,
    required this.accountNumber,
    required this.paymentNotes,
    required this.vatRegistered,
    required this.vatNumber,
    required this.defaultInvoiceNotes,
    required this.defaultPaymentTerms,
    required this.thankYouMessage,
    required this.defaultExtraHelperAmount,
    required this.defaultStairsAccessAmount,
    required this.defaultWaitingTimeAmount,
    required this.defaultCollectionDeliveryAmount,
    required this.defaultMileageRate,
    this.logoPath,
  });

  const VanBusinessProfileSettings.defaults()
    : businessName = '',
      ownerName = '',
      businessType = '',
      phoneNumber = '',
      emailAddress = '',
      websiteOrSocialLink = '',
      addressLine1 = '',
      addressLine2 = '',
      townOrCity = '',
      postcode = '',
      bankName = '',
      accountName = '',
      sortCode = '',
      accountNumber = '',
      paymentNotes = '',
      vatRegistered = false,
      vatNumber = '',
      defaultInvoiceNotes = '',
      defaultPaymentTerms = '',
      thankYouMessage = '',
      defaultExtraHelperAmount = 0,
      defaultStairsAccessAmount = 0,
      defaultWaitingTimeAmount = 0,
      defaultCollectionDeliveryAmount = 0,
      defaultMileageRate = 0,
      logoPath = null;

  final String businessName;
  final String ownerName;
  final String businessType;
  final String phoneNumber;
  final String emailAddress;
  final String websiteOrSocialLink;
  final String addressLine1;
  final String addressLine2;
  final String townOrCity;
  final String postcode;
  final String bankName;
  final String accountName;
  final String sortCode;
  final String accountNumber;
  final String paymentNotes;
  final bool vatRegistered;
  final String vatNumber;
  final String defaultInvoiceNotes;
  final String defaultPaymentTerms;
  final String thankYouMessage;
  final double defaultExtraHelperAmount;
  final double defaultStairsAccessAmount;
  final double defaultWaitingTimeAmount;
  final double defaultCollectionDeliveryAmount;
  final double defaultMileageRate;
  final String? logoPath;

  bool get hasLogo => logoPath?.trim().isNotEmpty == true;

  VanBusinessProfileSettings copyWith({
    String? businessName,
    String? ownerName,
    String? businessType,
    String? phoneNumber,
    String? emailAddress,
    String? websiteOrSocialLink,
    String? addressLine1,
    String? addressLine2,
    String? townOrCity,
    String? postcode,
    String? bankName,
    String? accountName,
    String? sortCode,
    String? accountNumber,
    String? paymentNotes,
    bool? vatRegistered,
    String? vatNumber,
    String? defaultInvoiceNotes,
    String? defaultPaymentTerms,
    String? thankYouMessage,
    double? defaultExtraHelperAmount,
    double? defaultStairsAccessAmount,
    double? defaultWaitingTimeAmount,
    double? defaultCollectionDeliveryAmount,
    double? defaultMileageRate,
    String? logoPath,
  }) {
    return VanBusinessProfileSettings(
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      businessType: businessType ?? this.businessType,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      websiteOrSocialLink: websiteOrSocialLink ?? this.websiteOrSocialLink,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      townOrCity: townOrCity ?? this.townOrCity,
      postcode: postcode ?? this.postcode,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      sortCode: sortCode ?? this.sortCode,
      accountNumber: accountNumber ?? this.accountNumber,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      vatRegistered: vatRegistered ?? this.vatRegistered,
      vatNumber: vatNumber ?? this.vatNumber,
      defaultInvoiceNotes: defaultInvoiceNotes ?? this.defaultInvoiceNotes,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      thankYouMessage: thankYouMessage ?? this.thankYouMessage,
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
      logoPath: logoPath ?? this.logoPath,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'businessName': businessName,
      'ownerName': ownerName,
      'businessType': businessType,
      'phoneNumber': phoneNumber,
      'emailAddress': emailAddress,
      'websiteOrSocialLink': websiteOrSocialLink,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'townOrCity': townOrCity,
      'postcode': postcode,
      'bankName': bankName,
      'accountName': accountName,
      'sortCode': sortCode,
      'accountNumber': accountNumber,
      'paymentNotes': paymentNotes,
      'vatRegistered': vatRegistered,
      'vatNumber': vatNumber,
      'defaultInvoiceNotes': defaultInvoiceNotes,
      'defaultPaymentTerms': defaultPaymentTerms,
      'thankYouMessage': thankYouMessage,
      'defaultExtraHelperAmount': defaultExtraHelperAmount,
      'defaultStairsAccessAmount': defaultStairsAccessAmount,
      'defaultWaitingTimeAmount': defaultWaitingTimeAmount,
      'defaultCollectionDeliveryAmount': defaultCollectionDeliveryAmount,
      'defaultMileageRate': defaultMileageRate,
      'logoPath': logoPath,
    };
  }

  factory VanBusinessProfileSettings.fromJson(Map<String, dynamic> json) {
    String readText(String key, {String fallback = ''}) {
      final value = sanitizeVanText(json[key]?.toString()).trim();
      return value.isEmpty ? fallback : value;
    }

    bool readBool(String key) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      final text = value?.toString().trim().toLowerCase() ?? '';
      return text == 'true' || text == '1' || text == 'yes';
    }

    String? readOptionalText(String key) {
      final value = sanitizeVanText(json[key]?.toString()).trim();
      return value.isEmpty ? null : value;
    }

    double readAmount(String key) {
      final raw = json[key];
      if (raw is num) {
        return raw.toDouble();
      }
      final value = sanitizeVanText(raw?.toString()).trim();
      return double.tryParse(value) ?? 0;
    }

    return VanBusinessProfileSettings(
      businessName: readText('businessName'),
      ownerName: readText('ownerName'),
      businessType: readText('businessType'),
      phoneNumber: readText('phoneNumber'),
      emailAddress: readText('emailAddress'),
      websiteOrSocialLink: readText('websiteOrSocialLink'),
      addressLine1: readText('addressLine1'),
      addressLine2: readText('addressLine2'),
      townOrCity: readText('townOrCity'),
      postcode: readText('postcode'),
      bankName: readText('bankName'),
      accountName: readText('accountName'),
      sortCode: readText('sortCode'),
      accountNumber: readText('accountNumber'),
      paymentNotes: readText('paymentNotes'),
      vatRegistered: readBool('vatRegistered'),
      vatNumber: readText('vatNumber'),
      defaultInvoiceNotes: readText('defaultInvoiceNotes'),
      defaultPaymentTerms: readText('defaultPaymentTerms'),
      thankYouMessage: readText('thankYouMessage'),
      defaultExtraHelperAmount: readAmount('defaultExtraHelperAmount'),
      defaultStairsAccessAmount: readAmount('defaultStairsAccessAmount'),
      defaultWaitingTimeAmount: readAmount('defaultWaitingTimeAmount'),
      defaultCollectionDeliveryAmount: readAmount(
        'defaultCollectionDeliveryAmount',
      ),
      defaultMileageRate: readAmount('defaultMileageRate'),
      logoPath: resolveSavedVanBusinessLogoPath(readOptionalText('logoPath')),
    );
  }
}
