class VanBusinessProfile {
  const VanBusinessProfile({
    required this.businessName,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.businessAddress,
    required this.paymentInstructions,
    this.logoPath,
  });

  const VanBusinessProfile.defaults()
    : businessName = 'Van Mate Driver',
      contactName = 'David Tyler',
      phone = '07123 456789',
      email = 'driver@example.com',
      businessAddress = 'Your business address',
      paymentInstructions =
          'Payment arranged directly with the driver/business.',
      logoPath = null;

  final String businessName;
  final String contactName;
  final String phone;
  final String email;
  final String businessAddress;
  final String paymentInstructions;
  final String? logoPath;

  bool get hasLogo => logoPath?.trim().isNotEmpty == true;

  VanBusinessProfile copyWith({
    String? businessName,
    String? contactName,
    String? phone,
    String? email,
    String? businessAddress,
    String? paymentInstructions,
    String? logoPath,
  }) {
    return VanBusinessProfile(
      businessName: businessName ?? this.businessName,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      businessAddress: businessAddress ?? this.businessAddress,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      logoPath: logoPath ?? this.logoPath,
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
      'logoPath': logoPath,
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
      paymentInstructions: readText(
        'paymentInstructions',
        const VanBusinessProfile.defaults().paymentInstructions,
      ),
      logoPath: readOptionalText('logoPath'),
    );
  }
}
