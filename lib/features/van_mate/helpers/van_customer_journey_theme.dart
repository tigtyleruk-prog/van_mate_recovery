import 'package:flutter/material.dart';

import '../models/van_customer_journey.dart';

class VanCustomerJourneyTheme {
  const VanCustomerJourneyTheme({required this.accent, required this.icon});

  static const quote = VanCustomerJourneyTheme(
    accent: Color(0xFF4A7DFF),
    icon: Icons.request_quote_outlined,
  );
  static const booking = VanCustomerJourneyTheme(
    accent: Color(0xFF9B7CFF),
    icon: Icons.calendar_month_outlined,
  );
  static const order = VanCustomerJourneyTheme(
    accent: Color(0xFFFFA24C),
    icon: Icons.inventory_2_outlined,
  );

  final Color accent;
  final IconData icon;

  Color surface({required Brightness brightness}) =>
      accent.withValues(alpha: brightness == Brightness.dark ? 0.20 : 0.12);
}

extension VanCustomerJourneyThemeX on VanCustomerJourneyType {
  VanCustomerJourneyTheme get journeyTheme => switch (this) {
    VanCustomerJourneyType.quote => VanCustomerJourneyTheme.quote,
    VanCustomerJourneyType.booking => VanCustomerJourneyTheme.booking,
    VanCustomerJourneyType.order => VanCustomerJourneyTheme.order,
  };
}
