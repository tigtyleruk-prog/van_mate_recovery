import 'package:flutter/foundation.dart';

import '../helpers/van_text_formatters.dart';
import 'van_business_profile.dart';

@immutable
class VanReportSummaryLine {
  const VanReportSummaryLine({required this.label, required this.value});

  final String label;
  final String value;
}

@immutable
class VanReportTableSection {
  const VanReportTableSection({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
}

@immutable
class VanReportDocument {
  const VanReportDocument({
    required this.businessProfile,
    required this.reportTitle,
    required this.dateRangeLabel,
    required this.generatedAt,
    required this.summaryLines,
    required this.sections,
  });

  final VanBusinessProfile businessProfile;
  final String reportTitle;
  final String dateRangeLabel;
  final DateTime generatedAt;
  final List<VanReportSummaryLine> summaryLines;
  final List<VanReportTableSection> sections;

  String get generatedDateLabel => formatDate(generatedAt);
}
