import 'van_custom_job_question.dart';
import 'van_quote_extra_defaults.dart';

/// Legacy-compatible template category shape.
///
/// The catalogue is intentionally empty after the controlled seed reset. Keep
/// this type so existing editors and future template imports have a stable API.
class VanServiceTemplateCategory {
  const VanServiceTemplateCategory({
    required this.id,
    required this.title,
    required this.services,
  });

  final String id;
  final String title;
  final List<VanServiceTemplate> services;
}

class VanServiceTemplate {
  const VanServiceTemplate({
    required this.id,
    required this.name,
    required this.questions,
    required this.extras,
    this.description = '',
    this.suggestedDurationMinutes,
    this.defaultQuoteDescription = '',
  });

  final String id;
  final String name;
  final String description;
  final List<VanServiceTemplateQuestion> questions;
  final List<VanServiceTemplateExtra> extras;
  final int? suggestedDurationMinutes;
  final String defaultQuoteDescription;

  VanQuoteExtraDefaults quoteExtraDefaults() {
    var defaults = VanQuoteExtraDefaults.empty();
    for (final extra in extras.where(
      (item) => isVanQuoteBuiltInExtraKey(item.key),
    )) {
      defaults = defaults.copyWithExtra(
        VanQuoteExtraDefault.fallback(extra.key).copyWith(
          label: extra.label,
          defaultPrice: extra.defaultPrice,
          enabled: extra.enabledByDefault,
        ),
      );
    }
    return defaults.copyWithCustomExtras(<VanQuoteExtraDefault>[
      for (final extra in extras)
        if (!isVanQuoteBuiltInExtraKey(extra.key))
          VanQuoteExtraDefault.custom(
            key: extra.key,
            label: extra.label,
            defaultPrice: extra.defaultPrice,
            enabled: extra.enabledByDefault,
          ),
    ]);
  }
}

class VanServiceTemplateQuestion {
  const VanServiceTemplateQuestion({
    required this.text,
    this.libraryId = '',
    this.answerType = VanCustomQuestionAnswerType.shortText,
    this.category = VanCustomQuestionCategory.jobDetails,
    this.choiceOptions = const <String>[],
    this.tags = const <String>[],
  });

  final String text;
  final String libraryId;
  final VanCustomQuestionAnswerType answerType;
  final VanCustomQuestionCategory category;
  final List<String> choiceOptions;
  final List<String> tags;
}

class VanServiceTemplateExtra {
  const VanServiceTemplateExtra({
    required this.key,
    required this.label,
    this.defaultPrice = 0,
    this.enabledByDefault = true,
    this.defaultChargeUnit = 'Fixed',
    this.tags = const <String>[],
  });

  final String key;
  final String label;
  final double defaultPrice;
  final bool enabledByDefault;
  final String defaultChargeUnit;
  final List<String> tags;
}

/// Intentionally empty. Business templates will be reintroduced only through
/// the central business-template library, one verified pack at a time.
const List<VanServiceTemplateCategory> kVanServiceTemplateCategories =
    <VanServiceTemplateCategory>[];

VanServiceTemplate? findVanServiceTemplateById(String id) => null;

VanServiceTemplate? findVanServiceTemplateForService({
  required String serviceId,
  required String serviceName,
}) => null;
