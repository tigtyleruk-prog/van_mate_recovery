import 'dart:async';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_customer_journey.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_capability.dart';
import '../models/van_service_handover.dart';
import '../models/van_starter_capability_pack.dart';
import '../models/van_service_template.dart';
import '../pages/van_booking_link_page.dart';
import '../pages/van_service_question_editor_page.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_job_services_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_quote_extra_defaults_sheet.dart';

class VanServiceCreationEntryResult {
  const VanServiceCreationEntryResult({
    required this.createdServiceIds,
    this.existingServiceIds = const <String>[],
    this.pendingServices = const <VanJobService>[],
    this.pendingQuestions = const <VanCustomJobQuestion>[],
  });

  final List<String> createdServiceIds;
  final List<String> existingServiceIds;
  final List<VanJobService> pendingServices;
  final List<VanCustomJobQuestion> pendingQuestions;

  List<String> get serviceIds => <String>[
    ...createdServiceIds,
    ...existingServiceIds,
  ];
}

enum _BusinessSetupStage {
  services,
  capabilities,
  extras,
  availability,
  review,
}

class VanServiceCreationEntryPage extends StatefulWidget {
  const VanServiceCreationEntryPage({super.key});

  @override
  State<VanServiceCreationEntryPage> createState() =>
      _VanServiceCreationEntryPageState();
}

class _VanServiceCreationEntryPageState
    extends State<VanServiceCreationEntryPage> {
  static const _stepTitles = <String>[
    'Basic information',
    'Customer journey',
    'Service flow',
    'Choose questions',
    'Configure questions',
    'Pricing',
    'Availability',
    'Review',
  ];
  static const _categoryOptions = <({String id, String label})>[
    (id: 'general', label: 'General'),
    (id: 'home_property', label: 'Home & property'),
    (id: 'transport_delivery', label: 'Transport & Delivery'),
    (id: 'trades', label: 'Trades'),
    (id: 'food_local_business', label: 'Food & local business'),
    (id: 'events_other', label: 'Events & other'),
    (id: 'pets', label: 'Pets'),
    (id: 'beauty_wellbeing', label: 'Beauty & wellbeing'),
    (id: 'repairs_maintenance', label: 'Repairs & maintenance'),
  ];
  static const _iconOptions = <String, IconData>{
    'work': Icons.work_outline_rounded,
    'cleaning': Icons.cleaning_services_outlined,
    'van': Icons.local_shipping_outlined,
    'pet': Icons.pets_outlined,
    'home': Icons.home_repair_service_outlined,
    'sparkle': Icons.auto_awesome_outlined,
  };
  static const _colourOptions = <int>[
    0xFF4F8CFF,
    0xFF7B61FF,
    0xFF13B98C,
    0xFFFF8A4C,
    0xFFE45775,
    0xFF25A7B8,
  ];
  static const _dayLabels = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  final _servicesStorage = VanJobServicesStorage.instance;
  final _questionsStorage = VanCustomJobQuestionsStorage.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dropOffController;
  late final TextEditingController _collectionController;
  late final TextEditingController _customerMessageController;
  late final TextEditingController _fixedPriceController;
  late final TextEditingController _fromPriceController;
  late final TextEditingController _businessSearchController;
  late final String _serviceId;
  late String _category;
  late String _iconKey;
  late int _colourValue;
  late VanCustomerJourneyType _journey;
  late VanCustomerRequestType _requestType;
  late VanCustomerRequestFlowOptions _flowOptions;
  late VanStartHandover _startHandover;
  late VanEndHandover _endHandover;
  late List<VanStartHandover> _allowedStarts;
  late List<VanEndHandover> _allowedEnds;
  late VanQuoteExtraDefaults _extras;
  late Set<int> _workingDays;
  late int _startMinutes;
  late int _endMinutes;
  late int _noticeHours;
  late int _maxBookings;
  late int _appointmentDurationMinutes;
  final Map<String, VanCustomJobQuestion> _questions = {};
  final List<String> _linkedQuestionIds = [];
  final Set<String> _availableQuestionIds = {};
  final Set<String> _optionalQuestionIds = {};
  final Set<String> _selectedBuiltInQuestions = {};
  final Map<String, Map<String, dynamic>> _builtInQuestionSettings = {};
  final Map<String, String> _libraryQuestionIds = {};
  final Map<String, String> _extraChargeUnits = {};
  final Set<String> _templateQuestionIds = {};
  late int _maxCustomerPhotos;
  VanServiceTemplate? _selectedStarterTemplate;
  VanStarterCapabilityPack? _selectedCapabilityPack;
  final Set<String> _selectedRecommendedServiceIds = <String>{};
  final Map<String, Set<String>> _capabilityIdsByService =
      <String, Set<String>>{};
  final Set<String> _manualCapabilityIds = <String>{};
  final Set<String> _capabilityGeneratedQuestionIds = <String>{};
  final Map<String, String> _capabilityGeneratedQuestionKeys =
      <String, String>{};
  final Set<String> _capabilityGeneratedExtraKeys = <String>{};
  final Set<String> _capabilityGeneratedBuiltInQuestionKeys = <String>{};
  String _creationSource = '';
  String? _expandedTemplateCategoryId;
  String _businessSearchQuery = '';
  List<_BusinessChoice> _recentBusinessChoices = const <_BusinessChoice>[];
  bool _showStarterBrowser = false;
  bool _showBasicFields = false;
  _BusinessSetupStage _businessSetupStage = _BusinessSetupStage.services;
  bool _businessSetupExtrasPrepared = false;
  bool _isActive = true;
  bool _requestPhotos = false;
  bool _requireAddress = true;
  bool _requestExactPin = true;
  int _step = 0;
  bool _saving = false;
  bool _loadingQuestions = true;
  bool _configuringExtras = false;
  bool _handoverTouched = false;

  VanJobService? get _source => null;
  bool get _isEditing => false;
  bool get _isDuplicating => false;
  bool get _showWizardChrome => _source != null || _showBasicFields;
  bool get _isManualIdentityPreflight =>
      _source == null &&
      _creationSource == 'blank' &&
      _showBasicFields &&
      _step == 0;
  bool get _usesUniversalCapabilityEditor =>
      (_source?.isCapabilityDriven ?? false) ||
      (_source == null && _creationSource == 'blank');
  String get _resolvedPricingMode {
    if (_usesUniversalCapabilityEditor) {
      return resolveVanCapabilityContract(_manualCapabilityIds).pricingMode;
    }
    return _source?.pricingMode ?? '';
  }

  bool get _usesFixedPrice =>
      _resolvedPricingMode == VanServiceCapabilityIds.fixedPrice;
  bool get _usesFromPrice =>
      _resolvedPricingMode == VanServiceCapabilityIds.fromPrice;

  num get _fixedPriceAmount =>
      _usesFixedPrice ? parseCurrencyValue(_fixedPriceController.text) : 0;
  num get _fromPriceAmount =>
      _usesFromPrice ? parseCurrencyValue(_fromPriceController.text) : 0;
  bool get _isUnchangedStandardWithoutFullHandover =>
      _source != null &&
      (_source!.serviceFlow == VanServiceFlow.standard ||
          _source!.serviceFlow == VanServiceFlow.order) &&
      !_source!.hasHandoverConfiguration &&
      !_handoverTouched &&
      !(_allowedStarts.isNotEmpty && _allowedEnds.isNotEmpty);

  static String _normalizedCategoryLabel(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static List<({String id, String label})> _categoryDropdownOptions(
    String selectedLabel,
  ) {
    final byId = <String, ({String id, String label})>{};
    final seenLabels = <String>{};
    for (final option in _categoryOptions) {
      final normalizedLabel = _normalizedCategoryLabel(option.label);
      if (byId.containsKey(option.id) || !seenLabels.add(normalizedLabel)) {
        continue;
      }
      byId[option.id] = option;
    }
    final normalizedSelected = _normalizedCategoryLabel(selectedLabel);
    if (!seenLabels.contains(normalizedSelected)) {
      final legacyId = normalizedSelected.isEmpty
          ? 'legacy_category'
          : 'legacy_${normalizedSelected.replaceAll(' ', '_')}';
      byId.putIfAbsent(
        legacyId,
        () => (id: legacyId, label: selectedLabel.trim()),
      );
    }
    return byId.values.toList(growable: false);
  }

  static ({String id, String label}) _selectedCategoryOption(
    String selectedLabel,
  ) {
    final normalizedSelected = _normalizedCategoryLabel(selectedLabel);
    return _categoryDropdownOptions(selectedLabel).firstWhere(
      (option) => _normalizedCategoryLabel(option.label) == normalizedSelected,
    );
  }

  @override
  void initState() {
    super.initState();
    final source = _source;
    final now = DateTime.now();
    _selectedStarterTemplate = null;
    if (_selectedStarterTemplate == null &&
        source?.starterTemplateId.isNotEmpty == true) {
      _selectedStarterTemplate = findVanServiceTemplateById(
        source!.starterTemplateId,
      );
    }
    _creationSource = _isDuplicating
        ? 'duplicate'
        : source?.creationSource.isNotEmpty == true
        ? source!.creationSource
        : source != null && !source.isDraft
        ? 'existing'
        : (_selectedStarterTemplate == null ? '' : 'starterPack');
    _showBasicFields = source != null;
    _showStarterBrowser =
        _creationSource == 'starterPack' && _selectedStarterTemplate == null;
    _expandedTemplateCategoryId = null;
    _serviceId = _isEditing
        ? source!.id
        : 'service_${now.microsecondsSinceEpoch}';
    _nameController = TextEditingController(
      text: _isDuplicating
          ? '${source!.name} Copy'
          : (source?.isDraft == true && source?.name == 'Untitled service')
          ? ''
          : source?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: source?.description ?? _selectedStarterTemplate?.description ?? '',
    );
    _dropOffController = TextEditingController(
      text: source?.businessDropOffInstructions ?? '',
    );
    _collectionController = TextEditingController(
      text: source?.businessCollectionInstructions ?? '',
    );
    _customerMessageController = TextEditingController(
      text: source?.customerMessage ?? '',
    );
    _fixedPriceController = TextEditingController(
      text: source == null || source.fixedPriceAmount <= 0
          ? ''
          : formatCurrencyInputValue(source.fixedPriceAmount),
    );
    _fromPriceController = TextEditingController(
      text: source == null || source.fromPriceAmount <= 0
          ? ''
          : formatCurrencyInputValue(source.fromPriceAmount),
    );
    _businessSearchController = TextEditingController();
    _category = source?.category ?? 'General';
    _iconKey = source?.iconKey ?? 'work';
    _colourValue = source?.colorValue ?? _colourOptions.first;
    _journey =
        source?.customerJourneyType ??
        defaultVanCustomerJourneyTypeForService(
          serviceId: '',
          serviceName: _selectedStarterTemplate?.name ?? '',
        );
    _requestType =
        source?.requestType ??
        defaultVanServiceFlowForService(
          serviceId: '',
          serviceName: _selectedStarterTemplate?.name ?? '',
        ).requestType;
    _flowOptions =
        source?.effectiveRequestFlowOptions ??
        VanCustomerRequestFlowOptions.defaultsFor(
          _requestType,
        ).copyWith(askPreferredDate: false, askPreferredTime: false);
    final handover =
        source?.effectiveHandover ??
        VanServiceHandoverConfig.resolve(requestType: _requestType);
    _startHandover = handover.start;
    _endHandover = handover.end;
    _allowedStarts = handover.allowedStarts;
    _allowedEnds = handover.allowedEnds;
    _extras =
        source?.quoteExtraDefaults ??
        _selectedStarterTemplate?.quoteExtraDefaults() ??
        VanQuoteExtraDefaults.empty();
    _workingDays = {...?source?.workingDays};
    if (_workingDays.isEmpty) _workingDays.addAll(const [1, 2, 3, 4, 5]);
    _startMinutes = source?.businessStartMinutes ?? 9 * 60;
    _endMinutes = source?.businessEndMinutes ?? 17 * 60;
    _noticeHours = source?.noticeHours.round() ?? 24;
    _maxBookings = source?.maxBookingsPerDay ?? 8;
    _appointmentDurationMinutes = source?.appointmentDurationMinutes ?? 60;
    _isActive = source?.isActive ?? true;
    _requestPhotos = source?.requestPhotos ?? false;
    _requireAddress = source?.requireAddress ?? false;
    _requestExactPin = source?.requestExactPinAfterQuoteAccepted ?? false;
    _optionalQuestionIds.addAll(source?.optionalQuestionIds ?? const []);
    _selectedBuiltInQuestions.addAll(
      source?.effectiveSelectedBuiltInQuestionKeys ?? const <String>{},
    );
    if (_requestExactPin) _selectedBuiltInQuestions.add('exact_pin');
    for (final entry
        in source?.builtInQuestionSettings.entries ??
            const <MapEntry<String, Map<String, dynamic>>>[]) {
      _builtInQuestionSettings[entry.key] = {...entry.value};
    }
    _maxCustomerPhotos = source?.maxCustomerPhotos ?? 5;
    _extraChargeUnits.addAll(source?.extraChargeUnits ?? const {});
    _manualCapabilityIds.addAll(
      source?.serviceCapabilityIds ?? const <String>[],
    );
    _capabilityGeneratedQuestionIds.addAll(
      source?.capabilityGeneratedQuestionIds ?? const <String>[],
    );
    _capabilityGeneratedQuestionKeys.addAll(
      source?.capabilityGeneratedQuestionKeys ?? const <String, String>{},
    );
    _capabilityGeneratedExtraKeys.addAll(
      source?.capabilityGeneratedExtraKeys ?? const <String>[],
    );
    _capabilityGeneratedBuiltInQuestionKeys.addAll(
      source?.capabilityGeneratedBuiltInQuestionKeys ?? const <String>[],
    );
    final selectedStarterTemplate = _selectedStarterTemplate;
    if (source == null && selectedStarterTemplate != null) {
      _applyTemplateBuiltInRecommendations(selectedStarterTemplate);
      _applyTemplatePresentationDefaults(selectedStarterTemplate);
    }
    if (source?.isDraft == true) {
      _step = source!.wizardStep.clamp(0, _stepTitles.length - 1);
      if (_step > 0) _showBasicFields = true;
    }
    _nameController.addListener(_refreshPreview);
    _descriptionController.addListener(_refreshPreview);
    unawaited(_loadQuestions());
    if (source == null) unawaited(_loadRecentBusinesses());
  }

  Future<void> _loadRecentBusinesses() async {
    try {
      final services = await _servicesStorage.loadAll();
      final choices = <_BusinessChoice>[];
      final seenLabels = <String>{};
      for (final service in services) {
        if (service.isArchived || service.isDraft) continue;
        VanStarterCapabilityPack? pack;
        if (service.starterPackId.isNotEmpty) {
          pack = findVanStarterCapabilityPackById(service.starterPackId);
        }
        if (pack == null && service.starterTemplateId.isNotEmpty) {
          pack = findVanStarterCapabilityPackById(
            '${service.starterTemplateId}_business',
          );
        }
        pack ??= findBestVanStarterCapabilityPack(service.name);
        if (pack == null) {
          final nameTerms = service.name
              .split(RegExp(r'[^a-zA-Z0-9]+'))
              .where((term) => term.length >= 4);
          for (final term in nameTerms) {
            pack = findBestVanStarterCapabilityPack(term);
            if (pack != null) break;
          }
        }
        if (pack == null) continue;
        final label = service.name.trim().isEmpty ? pack.name : service.name;
        if (!seenLabels.add(label.toLowerCase())) continue;
        choices.add(_BusinessChoice(label: label, pack: pack));
        if (choices.length == 4) break;
      }
      if (mounted) {
        setState(() => _recentBusinessChoices = choices);
      }
    } catch (_) {
      // Recent shortcuts are optional; the full finder remains available.
    }
  }

  void _applyTemplateBuiltInRecommendations(VanServiceTemplate template) {
    for (final question in template.questions) {
      final key = _builtInQuestionKeyForText(question.text);
      if (key == null) continue;
      _selectedBuiltInQuestions.add(key);
      _builtInQuestionSettings[key] = <String, dynamic>{
        'required': true,
        'helperText': '',
      };
      if (key == 'photos') _requestPhotos = true;
    }
    _flowOptions = _flowOptions.copyWith(
      askPreferredDate: _selectedBuiltInQuestions.contains('preferred_date'),
      askPreferredTime: _selectedBuiltInQuestions.contains('preferred_time'),
    );
  }

  VanServiceTemplateCategory? _templateCategoryFor(
    VanServiceTemplate template,
  ) {
    for (final category in kVanServiceTemplateCategories) {
      if (category.services.any((item) => item.id == template.id)) {
        return category;
      }
    }
    return null;
  }

  void _applyTemplatePresentationDefaults(VanServiceTemplate template) {
    final templateCategory = _templateCategoryFor(template);
    _category = switch (templateCategory?.id) {
      'transport_delivery' => 'Transport & delivery',
      'property_services' => 'Home & property',
      'trades' => 'Trades',
      'food_local' => 'Food & local business',
      'events_other' when template.id.contains('dog') => 'Pets',
      'events_other' => 'Events & other',
      _ => 'General',
    };
    _iconKey = switch (templateCategory?.id) {
      'transport_delivery' => 'van',
      'property_services' => 'home',
      'trades' => 'work',
      'food_local' => 'sparkle',
      'events_other' when template.id.contains('dog') => 'pet',
      'events_other' => 'sparkle',
      _ => 'work',
    };
    _colourValue = switch (templateCategory?.id) {
      'transport_delivery' => _colourOptions[0],
      'property_services' => _colourOptions[2],
      'trades' => _colourOptions[3],
      'food_local' => _colourOptions[4],
      'events_other' => _colourOptions[1],
      _ => _colourOptions.first,
    };
    _journey = defaultVanCustomerJourneyTypeForService(
      serviceId: template.id,
      serviceName: template.name,
    );
    _requestType = defaultVanServiceFlowForService(
      serviceId: template.id,
      serviceName: template.name,
    ).requestType;
    _flowOptions = VanCustomerRequestFlowOptions.defaultsFor(_requestType)
        .copyWith(
          askPreferredDate: _selectedBuiltInQuestions.contains(
            'preferred_date',
          ),
          askPreferredTime: _selectedBuiltInQuestions.contains(
            'preferred_time',
          ),
        );
    final handover = VanServiceHandoverConfig.resolve(
      requestType: _requestType,
    );
    _startHandover = handover.start;
    _endHandover = handover.end;
    _allowedStarts = handover.allowedStarts;
    _allowedEnds = handover.allowedEnds;
  }

  void _clearNewServiceQuestionSelections() {
    for (final id in _availableQuestionIds) {
      _questions.remove(id);
    }
    _linkedQuestionIds.clear();
    _availableQuestionIds.clear();
    _optionalQuestionIds.clear();
    _selectedBuiltInQuestions.clear();
    _builtInQuestionSettings.clear();
    _libraryQuestionIds.clear();
    _templateQuestionIds.clear();
  }

  void _resetNewServiceState() {
    _clearNewServiceQuestionSelections();
    _nameController.clear();
    _descriptionController.clear();
    _dropOffController.clear();
    _collectionController.clear();
    _customerMessageController.clear();
    _category = 'General';
    _iconKey = 'work';
    _colourValue = _colourOptions.first;
    _journey = defaultVanCustomerJourneyTypeForService(
      serviceId: '',
      serviceName: '',
    );
    _requestType = defaultVanServiceFlowForService(
      serviceId: '',
      serviceName: '',
    ).requestType;
    _flowOptions = VanCustomerRequestFlowOptions.defaultsFor(
      _requestType,
    ).copyWith(askPreferredDate: false, askPreferredTime: false);
    final handover = VanServiceHandoverConfig.resolve(
      requestType: _requestType,
    );
    _startHandover = handover.start;
    _endHandover = handover.end;
    _allowedStarts = handover.allowedStarts;
    _allowedEnds = handover.allowedEnds;
    _extras = VanQuoteExtraDefaults.empty();
    _extraChargeUnits.clear();
    _manualCapabilityIds.clear();
    _capabilityGeneratedQuestionIds.clear();
    _capabilityGeneratedQuestionKeys.clear();
    _capabilityGeneratedExtraKeys.clear();
    _capabilityGeneratedBuiltInQuestionKeys.clear();
    _workingDays = <int>{1, 2, 3, 4, 5};
    _startMinutes = 9 * 60;
    _endMinutes = 17 * 60;
    _noticeHours = 24;
    _maxBookings = 8;
    _appointmentDurationMinutes = 60;
    _isActive = true;
    _requestPhotos = false;
    _requireAddress = false;
    _requestExactPin = false;
    _maxCustomerPhotos = 5;
    _configuringExtras = false;
    _handoverTouched = false;
  }

  void _applyTemplateCustomQuestions(VanServiceTemplate template) {
    final now = DateTime.now().microsecondsSinceEpoch;
    var index = 0;
    for (final templateQuestion in template.questions) {
      if (_builtInQuestionKeyForText(templateQuestion.text) != null) continue;
      final id = 'service_question_${_serviceId}_${now + index++}';
      final question = VanCustomJobQuestion(
        id: id,
        questionText: templateQuestion.text,
        helperText: '',
        libraryQuestionId: templateQuestion.libraryId,
        tags: templateQuestion.tags,
        answerType: templateQuestion.answerType,
        category: templateQuestion.category,
        choiceOptions: templateQuestion.choiceOptions,
        isActive: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _questions[id] = question;
      _linkedQuestionIds.add(id);
      _availableQuestionIds.add(id);
      _templateQuestionIds.add(id);
      final libraryKey = _libraryKeyForQuestion(question);
      if (libraryKey != null) _libraryQuestionIds[libraryKey] = id;
    }
  }

  void _selectCapabilityPack(VanStarterCapabilityPack pack) {
    setState(() {
      _resetNewServiceState();
      _selectedStarterTemplate = null;
      _selectedCapabilityPack = pack;
      _selectedRecommendedServiceIds.clear();
      _capabilityIdsByService.clear();
      _businessSetupStage = _BusinessSetupStage.services;
      _businessSetupExtrasPrepared = false;
      _creationSource = 'capabilityBuilder';
      _showStarterBrowser = false;
      _showBasicFields = false;
    });
  }

  void _updateBusinessSearch(String value) {
    setState(() => _businessSearchQuery = value.trim());
  }

  void _clearBusinessSearch() {
    _businessSearchController.clear();
    setState(() => _businessSearchQuery = '');
  }

  void _toggleRecommendedService(String serviceId, bool selected) {
    setState(() {
      if (selected) {
        _selectedRecommendedServiceIds.add(serviceId);
      } else {
        _selectedRecommendedServiceIds.remove(serviceId);
        _capabilityIdsByService.remove(serviceId);
      }
      _businessSetupExtrasPrepared = false;
    });
  }

  void _continueToServiceCapabilities() {
    final pack = _selectedCapabilityPack;
    if (pack == null || _selectedRecommendedServiceIds.isEmpty) return;
    for (final service in pack.serviceRecommendations) {
      if (!_selectedRecommendedServiceIds.contains(service.id)) continue;
      _capabilityIdsByService.putIfAbsent(
        service.id,
        () => service.recommendedCapabilityIds.toSet(),
      );
    }
    setState(() => _businessSetupStage = _BusinessSetupStage.review);
  }

  void _toggleUniversalCapability(
    String serviceId,
    String capabilityId,
    bool selected,
  ) {
    setState(() {
      final current = _capabilityIdsByService[serviceId] ?? <String>{};
      _capabilityIdsByService[serviceId] = toggleVanServiceCapability(
        current,
        capabilityId,
        selected,
      );
      _businessSetupExtrasPrepared = false;
    });
  }

  void _continueToBusinessSetupExtras() {
    final pack = _selectedCapabilityPack;
    if (pack == null) return;
    final setups = pack.recommendationsFor(
      _selectedRecommendedServiceIds,
      capabilityIdsByService: _capabilityIdsByService,
    );
    if (!_validateBusinessServiceSetups(setups)) return;
    if (!_businessSetupExtrasPrepared) {
      var generatedExtras = VanQuoteExtraDefaults.empty();
      for (final setup in setups) {
        for (final extra in setup.extras) {
          _extraChargeUnits.putIfAbsent(
            extra.key,
            () => extra.defaultChargeUnit,
          );
        }
        for (final extra in setup.quoteExtraDefaults().orderedExtras) {
          generatedExtras = generatedExtras.copyWithExtra(extra);
        }
      }
      _extras = generatedExtras;
      if (setups.isNotEmpty) {
        _noticeHours = setups.first.suggestedNoticeHours;
        _appointmentDurationMinutes =
            setups.first.suggestedDurationMinutes ?? 60;
      }
      _businessSetupExtrasPrepared = true;
    }
    setState(() => _businessSetupStage = _BusinessSetupStage.extras);
  }

  bool _validateBusinessServiceSetups(List<VanRecommendedServiceSetup> setups) {
    if (setups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one service you offer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    for (final setup in setups) {
      final hasJourney = setup.capabilityIds.any(
        const <String>{
          VanServiceCapabilityIds.placeOrder,
          VanServiceCapabilityIds.preOrder,
          VanServiceCapabilityIds.requestQuote,
          VanServiceCapabilityIds.bookAppointment,
        }.contains,
      );
      if (!hasJourney) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Choose a customer journey for ${setup.name}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _toggleManualCapability(String capabilityId, bool selected) {
    setState(() {
      final updated = toggleVanServiceCapability(
        _manualCapabilityIds,
        capabilityId,
        selected,
      );
      _manualCapabilityIds
        ..clear()
        ..addAll(updated);
    });
  }

  void _applyManualCapabilityDefaults() {
    final resolved = resolveVanServiceCapabilities(
      _manualCapabilityIds,
      recommendedDurationMinutes: _appointmentDurationMinutes,
      recommendedNoticeHours: _noticeHours,
    );
    final targetQuestionTexts = resolved.questions
        .map((question) => question.text.trim().toLowerCase())
        .toSet();
    final retainedGeneratedQuestionIds = <String>{};
    final retainedGeneratedQuestionKeys = <String, String>{};
    final customisedGeneratedQuestionKeys = <String>{};
    for (final id in _capabilityGeneratedQuestionIds.toList()) {
      final normalized = _questions[id]?.questionText.trim().toLowerCase();
      final generatedKey = _capabilityGeneratedQuestionKeys[id] ?? normalized;
      if (normalized != null &&
          generatedKey != null &&
          normalized != generatedKey) {
        customisedGeneratedQuestionKeys.add(generatedKey);
        continue;
      }
      if (generatedKey != null && targetQuestionTexts.contains(generatedKey)) {
        retainedGeneratedQuestionIds.add(id);
        retainedGeneratedQuestionKeys[id] = generatedKey;
        continue;
      }
      _linkedQuestionIds.remove(id);
      _availableQuestionIds.remove(id);
      _optionalQuestionIds.remove(id);
      _questions.remove(id);
    }

    final targetBuiltInKeys = resolved.builtInQuestionKeys
        .where((key) => key != 'phone' && key != 'email')
        .toSet();
    for (final key in _capabilityGeneratedBuiltInQuestionKeys.difference(
      targetBuiltInKeys,
    )) {
      _selectedBuiltInQuestions.remove(key);
      _builtInQuestionSettings.remove(key);
    }

    final targetExtraKeys = resolved.extras.map((extra) => extra.key).toSet();
    final removedExtraKeys = _capabilityGeneratedExtraKeys.difference(
      targetExtraKeys,
    );
    var refreshedExtras = _extras;
    for (final key in removedExtraKeys.where(isVanQuoteBuiltInExtraKey)) {
      refreshedExtras = refreshedExtras.copyWithExtra(
        refreshedExtras.extraForKey(key).copyWith(enabled: false),
      );
    }
    refreshedExtras = refreshedExtras.copyWithCustomExtras(
      refreshedExtras.customExtras
          .where((extra) => !removedExtraKeys.contains(extra.key))
          .toList(growable: false),
    );
    _extras = refreshedExtras;
    final newExtras = resolved.extras.where(
      (extra) => !_capabilityGeneratedExtraKeys.contains(extra.key),
    );

    _capabilityGeneratedQuestionIds
      ..clear()
      ..addAll(retainedGeneratedQuestionIds);
    _capabilityGeneratedQuestionKeys
      ..clear()
      ..addAll(retainedGeneratedQuestionKeys);
    _capabilityGeneratedExtraKeys
      ..clear()
      ..addAll(targetExtraKeys);
    _capabilityGeneratedBuiltInQuestionKeys
      ..clear()
      ..addAll(targetBuiltInKeys);

    _journey = resolved.journeyType;
    _requestType = resolved.requestType;
    _allowedStarts = <VanStartHandover>[
      if (resolved.allowCustomerDropOff) VanStartHandover.customerDropsOff,
      if (resolved.allowBusinessCollection) VanStartHandover.businessCollects,
    ];
    _allowedEnds = <VanEndHandover>[
      if (resolved.allowCustomerCollection) VanEndHandover.customerCollects,
      if (resolved.allowBusinessReturn) VanEndHandover.businessReturns,
      if (resolved.allowBusinessDelivery) VanEndHandover.businessDelivers,
    ];
    if (_allowedStarts.isNotEmpty) _startHandover = _allowedStarts.first;
    if (_allowedEnds.isNotEmpty) _endHandover = _allowedEnds.first;
    _requireAddress = resolved.requireAddress;
    _appointmentDurationMinutes = resolved.suggestedDurationMinutes;
    _noticeHours = resolved.suggestedNoticeHours;
    _selectedBuiltInQuestions.addAll(resolved.builtInQuestionKeys);
    _requestExactPin = resolved.builtInQuestionKeys.contains('exact_pin');
    for (final key in resolved.builtInQuestionKeys) {
      _builtInQuestionSettings.putIfAbsent(
        key,
        () => <String, dynamic>{
          'required':
              key == 'address' ||
              key == 'preferred_date' ||
              key == 'preferred_time',
          'helperText': '',
        },
      );
    }
    _flowOptions = VanCustomerRequestFlowOptions.defaultsFor(_requestType)
        .copyWith(
          askPreferredDate: resolved.builtInQuestionKeys.contains(
            'preferred_date',
          ),
          askPreferredTime: resolved.builtInQuestionKeys.contains(
            'preferred_time',
          ),
        );
    _mergeRecommendedExtras(newExtras);
    for (final question in resolved.questions) {
      final generatedKey = question.text.trim().toLowerCase();
      if (customisedGeneratedQuestionKeys.contains(generatedKey)) continue;
      final id = _ensureRecommendedQuestion(question);
      if (id != null) {
        _capabilityGeneratedQuestionIds.add(id);
        _capabilityGeneratedQuestionKeys[id] = generatedKey;
      }
    }
  }

  void _mergeRecommendedExtras(Iterable<VanServiceTemplateExtra> extras) {
    var updated = _extras;
    final custom = <String, VanQuoteExtraDefault>{
      for (final extra in updated.customExtras) extra.key: extra,
    };
    for (final extra in extras) {
      if (isVanQuoteBuiltInExtraKey(extra.key)) {
        updated = updated.copyWithExtra(
          VanQuoteExtraDefault.fallback(extra.key).copyWith(
            label: extra.label,
            defaultPrice: extra.defaultPrice,
            enabled: true,
          ),
        );
      } else {
        custom.putIfAbsent(
          extra.key,
          () => VanQuoteExtraDefault.custom(
            key: extra.key,
            label: extra.label,
            defaultPrice: extra.defaultPrice,
          ),
        );
      }
    }
    _extras = updated.copyWithCustomExtras(custom.values.toList());
  }

  String? _ensureRecommendedQuestion(
    VanServiceTemplateQuestion recommendation,
  ) {
    if (_builtInQuestionKeyForText(recommendation.text) != null) return null;
    final normalized = recommendation.text.trim().toLowerCase();
    for (final id in _linkedQuestionIds) {
      if (_questions[id]?.questionText.trim().toLowerCase() == normalized) {
        return _capabilityGeneratedQuestionIds.contains(id) ? id : null;
      }
    }
    final now = DateTime.now();
    final id =
        'service_capability_${_serviceId}_${now.microsecondsSinceEpoch}_${_linkedQuestionIds.length}';
    _questions[id] = VanCustomJobQuestion(
      id: id,
      questionText: recommendation.text,
      helperText: '',
      answerType: recommendation.answerType,
      category: recommendation.category,
      choiceOptions: recommendation.choiceOptions,
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    _linkedQuestionIds.add(id);
    _availableQuestionIds.add(id);
    return id;
  }

  VanQuoteExtraDefaults _businessSetupExtrasFor(
    VanQuoteExtraDefaults generated,
  ) {
    var merged = generated;
    for (final extra in _extras.orderedExtras) {
      merged = merged.copyWithExtra(extra);
    }
    return merged;
  }

  Future<void> _createRecommendedServices() async {
    final pack = _selectedCapabilityPack;
    if (_saving || pack == null) return;
    final recommendations = pack.recommendationsFor(
      _selectedRecommendedServiceIds,
      capabilityIdsByService: _capabilityIdsByService,
    );
    if (!_validateBusinessServiceSetups(recommendations)) return;

    setState(() => _saving = true);
    try {
      final existingServices = await _servicesStorage.loadAll();
      final now = DateTime.now();
      final stamp = now.microsecondsSinceEpoch;
      final createdServices = <VanJobService>[];
      final existingMatches = <VanJobService>[];
      final createdQuestions = <VanCustomJobQuestion>[];
      for (
        var serviceIndex = 0;
        serviceIndex < recommendations.length;
        serviceIndex++
      ) {
        final setup = recommendations[serviceIndex];
        final existingMatch = existingServices
            .where(
              (service) =>
                  !service.isArchived &&
                  (service.creationSource == 'capabilityPack' ||
                      service.creationSource == 'capabilityBuilder') &&
                  service.starterPackId == setup.packId &&
                  (service.id.startsWith(
                        'service_${setup.packId}_${setup.serviceKey}_',
                      ) ||
                      service.starterTemplateId == setup.serviceKey ||
                      _sameStringSet(
                        service.starterCapabilityIds,
                        setup.capabilityIds,
                      )),
            )
            .firstOrNull;
        if (existingMatch != null) {
          existingMatches.add(existingMatch);
          continue;
        }
        final serviceId =
            'service_${setup.packId}_${setup.serviceKey}_${stamp + serviceIndex}';
        final linkedQuestionIds = <String>[];
        final optionalQuestionIds = <String>[];
        final capabilityGeneratedQuestionIds = <String>[];
        final capabilityGeneratedQuestionKeys = <String, String>{};
        final resolvedCapabilityDefaults = resolveVanServiceCapabilities(
          setup.capabilityIds,
          recommendedDurationMinutes: setup.suggestedDurationMinutes,
          recommendedNoticeHours: setup.suggestedNoticeHours,
        );
        final generatedQuestionTexts = resolvedCapabilityDefaults.questions
            .map((question) => question.text.trim().toLowerCase())
            .toSet();
        final selectedBuiltIns = <String>{...setup.builtInQuestionKeys};
        final builtInSettings = <String, Map<String, dynamic>>{
          for (final entry in setup.builtInQuestionSettings.entries)
            entry.key: <String, dynamic>{...entry.value},
        };
        for (final key in setup.builtInQuestionKeys) {
          builtInSettings.putIfAbsent(
            key,
            () => <String, dynamic>{
              'required':
                  key == 'address' ||
                  key == 'preferred_date' ||
                  key == 'preferred_time',
              'helperText': '',
            },
          );
        }
        var customIndex = 0;
        for (final recommendation in setup.questions) {
          final builtInKey =
              recommendation.answerType ==
                  VanCustomQuestionAnswerType.photoUploadRequest
              ? 'photos'
              : _builtInQuestionKeyForText(recommendation.text);
          if (builtInKey != null) {
            selectedBuiltIns.add(builtInKey);
            builtInSettings[builtInKey] = <String, dynamic>{
              'required': builtInKey != 'photos',
              'helperText': builtInKey == 'photos' ? recommendation.text : '',
            };
            continue;
          }
          final questionId = 'service_capability_${serviceId}_${customIndex++}';
          createdQuestions.add(
            VanCustomJobQuestion(
              id: questionId,
              questionText: recommendation.text,
              helperText: recommendation.helperText,
              libraryQuestionId: recommendation.libraryId,
              tags: recommendation.tags,
              answerType: recommendation.answerType,
              category: recommendation.category,
              choiceOptions: recommendation.choiceOptions,
              isActive: true,
              isArchived: false,
              createdAt: now,
              updatedAt: now,
            ),
          );
          linkedQuestionIds.add(questionId);
          if (!recommendation.requiredByDefault) {
            optionalQuestionIds.add(questionId);
          }
          final normalizedQuestionText = recommendation.text
              .trim()
              .toLowerCase();
          if (generatedQuestionTexts.contains(normalizedQuestionText)) {
            capabilityGeneratedQuestionIds.add(questionId);
            capabilityGeneratedQuestionKeys[questionId] =
                normalizedQuestionText;
          }
        }
        if (setup.requestPhotos) {
          selectedBuiltIns.add('photos');
          builtInSettings.putIfAbsent(
            'photos',
            () => <String, dynamic>{'required': false, 'helperText': ''},
          );
        }
        if (setup.requireAddress) {
          selectedBuiltIns.add('address');
          builtInSettings['address'] = <String, dynamic>{
            'required': true,
            'helperText': '',
          };
        }
        final allowedStarts = <VanStartHandover>[
          if (setup.allowCustomerDropOff) VanStartHandover.customerDropsOff,
          if (setup.allowBusinessCollection) VanStartHandover.businessCollects,
        ];
        final allowedEnds = <VanEndHandover>[
          if (setup.allowCustomerCollection) VanEndHandover.customerCollects,
          if (setup.allowBusinessReturn) VanEndHandover.businessReturns,
          if (setup.allowBusinessDelivery) VanEndHandover.businessDelivers,
        ];
        final flowOptions = setup.requestFlowOptions.copyWith(
          askPreferredDate: selectedBuiltIns.contains('preferred_date'),
          askPreferredTime: selectedBuiltIns.contains('preferred_time'),
        );
        final availabilityByDay = <int, VanServiceDaySchedule>{
          for (final day in setup.availability)
            day.day: VanServiceDaySchedule(
              startMinutes: day.startMinutes,
              endMinutes: day.endMinutes,
            ),
        };
        final availabilityDays = availabilityByDay.keys.toList()..sort();
        final firstAvailability = availabilityDays.isEmpty
            ? null
            : availabilityByDay[availabilityDays.first];
        createdServices.add(
          VanJobService(
            id: serviceId,
            name: setup.name,
            description: setup.description,
            isActive: true,
            requestPhotos:
                setup.requestPhotos || selectedBuiltIns.contains('photos'),
            requireAddress: setup.requireAddress,
            requestExactPinAfterQuoteAccepted: false,
            requestType: setup.requestType,
            customerJourneyType: setup.journeyType,
            startHandover: allowedStarts.isEmpty ? null : allowedStarts.first,
            endHandover: allowedEnds.isEmpty ? null : allowedEnds.first,
            allowedStartHandoverOptions: allowedStarts,
            allowedEndHandoverOptions: allowedEnds,
            allowCustomerDropOff: setup.allowCustomerDropOff,
            allowBusinessCollection: setup.allowBusinessCollection,
            allowCustomerCollection: setup.allowCustomerCollection,
            allowBusinessReturn: setup.allowBusinessReturn,
            allowBusinessDelivery: setup.allowBusinessDelivery,
            requestFlowOptions: flowOptions,
            linkedQuestionIds: linkedQuestionIds,
            optionalQuestionIds: optionalQuestionIds,
            quoteExtraDefaults: setup.quoteExtraDefaults(),
            extraChargeUnits: Map.unmodifiable(<String, String>{
              for (final extra in setup.extras)
                extra.key: extra.defaultChargeUnit,
            }),
            createdAt: now,
            updatedAt: now,
            category: setup.category,
            iconKey: setup.iconKey,
            colorValue: setup.colorValue,
            workingDays: availabilityDays,
            businessStartMinutes:
                firstAvailability?.startMinutes ?? _startMinutes,
            businessEndMinutes: firstAvailability?.endMinutes ?? _endMinutes,
            availabilityByDay: availabilityByDay.isEmpty
                ? null
                : availabilityByDay,
            noticeHours: setup.suggestedNoticeHours,
            maxBookingsPerDay: setup.maximumBookingsPerDay,
            selectedBuiltInQuestionKeys: selectedBuiltIns.toList(
              growable: false,
            ),
            builtInQuestionSettings: builtInSettings,
            creationSource: 'capabilityBuilder',
            starterTemplateId: setup.serviceKey,
            starterPackId: setup.packId,
            starterCapabilityIds: const <String>[],
            serviceCapabilityIds: setup.capabilityIds,
            capabilitySchemaVersion: 1,
            capabilityGeneratedQuestionIds: capabilityGeneratedQuestionIds,
            capabilityGeneratedQuestionKeys: capabilityGeneratedQuestionKeys,
            capabilityGeneratedExtraKeys: resolvedCapabilityDefaults.extras
                .map((extra) => extra.key)
                .toList(growable: false),
            capabilityGeneratedBuiltInQuestionKeys: resolvedCapabilityDefaults
                .builtInQuestionKeys
                .where((key) => key != 'phone' && key != 'email')
                .toList(growable: false),
            pricingMode: setup.pricingMode,
            suggestedReminderMinutes: setup.suggestedReminderMinutes,
            suggestedStatusNames: setup.suggestedStatusNames,
            appointmentDurationMinutes: setup.suggestedDurationMinutes ?? 60,
            customerMessage: setup.suggestedCustomerMessage,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      if (mounted) {
        Navigator.of(context).pop(
          VanServiceCreationEntryResult(
            createdServiceIds: createdServices
                .map((service) => service.id)
                .toList(growable: false),
            existingServiceIds: existingMatches
                .map((service) => service.id)
                .toList(growable: false),
            pendingServices: createdServices,
            pendingQuestions: createdQuestions,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the recommended services.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
    final leftSet = left
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final rightSet = right
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return leftSet.isNotEmpty &&
        leftSet.length == rightSet.length &&
        leftSet.containsAll(rightSet);
  }

  void _chooseStarterPack() {
    setState(() {
      _creationSource = 'capabilityBuilder';
      _showStarterBrowser = true;
      _showBasicFields = false;
      _selectedStarterTemplate = null;
      _selectedCapabilityPack = null;
      _selectedRecommendedServiceIds.clear();
      _capabilityIdsByService.clear();
      _businessSetupStage = _BusinessSetupStage.services;
      _businessSetupExtrasPrepared = false;
      _businessSearchController.clear();
      _businessSearchQuery = '';
      _expandedTemplateCategoryId = null;
    });
  }

  void _chooseDifferentStarterPack() {
    setState(() {
      _resetNewServiceState();
      _selectedStarterTemplate = null;
      _selectedCapabilityPack = null;
      _selectedRecommendedServiceIds.clear();
      _capabilityIdsByService.clear();
      _businessSetupStage = _BusinessSetupStage.services;
      _businessSetupExtrasPrepared = false;
      _creationSource = 'capabilityBuilder';
      _showStarterBrowser = true;
      _showBasicFields = false;
      _businessSearchController.clear();
      _businessSearchQuery = '';
      _expandedTemplateCategoryId = null;
    });
  }

  void _startBlankService() {
    setState(() {
      _resetNewServiceState();
      _selectedStarterTemplate = null;
      _selectedCapabilityPack = null;
      _selectedRecommendedServiceIds.clear();
      _capabilityIdsByService.clear();
      _creationSource = 'blank';
      _showStarterBrowser = false;
      _showBasicFields = true;
    });
  }

  String? _builtInQuestionKeyForText(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    return switch (normalized) {
      'address' => 'address',
      'collection address' || 'pickup address' => 'collection_address',
      'delivery address' || 'return address' => 'delivery_address',
      'preferred date' => 'preferred_date',
      'preferred time' => 'preferred_time',
      'phone number' => 'phone',
      'email address' || 'email' => 'email',
      _
          when normalized.contains('upload photos') ||
              normalized.contains('upload a photo') ||
              normalized.contains('upload photo') ||
              normalized == 'photos' =>
        'photos',
      _ => null,
    };
  }

  String? _libraryKeyForQuestion(VanCustomJobQuestion question) {
    final normalized = question.questionText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    for (final item in _customQuestionLibrary) {
      final candidate = item.label
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (normalized == candidate) return item.key;
    }
    return null;
  }

  Future<void> _loadQuestions() async {
    final all = await _questionsStorage.loadAll();
    final lookup = {for (final question in all) question.id: question};
    final sourceIds = _source?.linkedQuestionIds ?? const <String>[];
    if (_isDuplicating) {
      final now = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < sourceIds.length; index++) {
        final original = lookup[sourceIds[index]];
        if (original == null) continue;
        final id = 'service_question_${_serviceId}_${now + index}';
        _questions[id] = original.copyWith(
          id: id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _availableQuestionIds.add(id);
        if (!_source!.disabledLinkedQuestionIds.contains(original.id)) {
          _linkedQuestionIds.add(id);
        }
        final libraryKey = _libraryKeyForQuestion(original);
        if (libraryKey != null) _libraryQuestionIds[libraryKey] = id;
        if (_source!.optionalQuestionIds.contains(original.id)) {
          _optionalQuestionIds.add(id);
        }
      }
    } else {
      _questions.addAll(lookup);
      _linkedQuestionIds.addAll(
        sourceIds.where(
          (id) =>
              lookup.containsKey(id) &&
              !(_source?.disabledLinkedQuestionIds.contains(id) ?? false),
        ),
      );
      _availableQuestionIds.addAll(sourceIds.where(lookup.containsKey));
      for (final id in _availableQuestionIds) {
        final question = lookup[id];
        if (question == null) continue;
        final libraryKey = _libraryKeyForQuestion(question);
        if (libraryKey != null) _libraryQuestionIds[libraryKey] = id;
      }
    }
    final starterTemplate = _selectedStarterTemplate;
    if (_source == null &&
        starterTemplate != null &&
        _templateQuestionIds.isEmpty) {
      _applyTemplateCustomQuestions(starterTemplate);
    }
    if (mounted) setState(() => _loadingQuestions = false);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshPreview);
    _descriptionController.removeListener(_refreshPreview);
    _nameController.dispose();
    _descriptionController.dispose();
    _dropOffController.dispose();
    _collectionController.dispose();
    _customerMessageController.dispose();
    _fixedPriceController.dispose();
    _fromPriceController.dispose();
    _businessSearchController.dispose();
    super.dispose();
  }

  VanJobService _buildService({required bool isDraft}) {
    final source = _source;
    final now = DateTime.now();
    final resolvedCapabilities = _usesUniversalCapabilityEditor
        ? resolveVanServiceCapabilities(
            _manualCapabilityIds,
            recommendedDurationMinutes: _appointmentDurationMinutes,
            recommendedNoticeHours: _noticeHours,
          )
        : null;
    final pricingMode =
        resolvedCapabilities?.pricingMode ?? source?.pricingMode ?? '';
    final cleanName = sanitizeVanText(_nameController.text).trim();
    final flowOptions = _flowOptions.copyWith(
      askPreferredDate: _selectedBuiltInQuestions.contains('preferred_date'),
      askPreferredTime: _selectedBuiltInQuestions.contains('preferred_time'),
      showPickupAddress:
          _requestType.serviceFlow == VanServiceFlow.pickupDelivery,
      showDeliveryAddress:
          _requestType.serviceFlow == VanServiceFlow.pickupDelivery,
    );
    return VanJobService(
      id: _serviceId,
      name: cleanName.isEmpty ? 'Untitled service' : cleanName,
      description: sanitizeVanText(_descriptionController.text).trim(),
      isActive: isDraft ? false : _isActive,
      requestPhotos: _requestPhotos,
      requireAddress: _requireAddress,
      requestExactPinAfterQuoteAccepted: _requestExactPin,
      requestType: _requestType,
      customerJourneyType: _journey,
      startHandover: _startHandover,
      endHandover: _endHandover,
      allowedStartHandoverOptions: _allowedStarts,
      allowedEndHandoverOptions: _allowedEnds,
      allowCustomerDropOff: _allowedStarts.contains(
        VanStartHandover.customerDropsOff,
      ),
      allowBusinessCollection: _allowedStarts.contains(
        VanStartHandover.businessCollects,
      ),
      allowCustomerCollection: _allowedEnds.contains(
        VanEndHandover.customerCollects,
      ),
      allowBusinessReturn: _allowedEnds.contains(
        VanEndHandover.businessReturns,
      ),
      allowBusinessDelivery: _allowedEnds.contains(
        VanEndHandover.businessDelivers,
      ),
      businessDropOffInstructions: sanitizeVanText(
        _dropOffController.text,
      ).trim(),
      businessCollectionInstructions: sanitizeVanText(
        _collectionController.text,
      ).trim(),
      requestFlowOptions: flowOptions,
      linkedQuestionIds: List.unmodifiable(_linkedQuestionIds),
      disabledLinkedQuestionIds:
          source?.disabledLinkedQuestionIds
              .where(_linkedQuestionIds.contains)
              .toList(growable: false) ??
          const [],
      optionalQuestionIds: List.unmodifiable(
        _optionalQuestionIds.where(_linkedQuestionIds.contains),
      ),
      quoteExtraDefaults: _extras,
      createdAt: _isEditing ? source!.createdAt : now,
      updatedAt: now,
      isArchived: _isEditing ? source!.isArchived : false,
      category: _category,
      iconKey: _iconKey,
      colorValue: _colourValue,
      isDraft: isDraft,
      workingDays: _workingDays.toList(growable: false)..sort(),
      businessStartMinutes: _startMinutes,
      businessEndMinutes: _endMinutes,
      noticeHours: _noticeHours,
      maxBookingsPerDay: _maxBookings,
      appointmentDurationMinutes: _appointmentDurationMinutes,
      customerMessage: sanitizeVanText(_customerMessageController.text).trim(),
      selectedBuiltInQuestionKeys: _selectedBuiltInQuestions.toList(
        growable: false,
      ),
      builtInQuestionSettings: Map.unmodifiable({
        for (final entry in _builtInQuestionSettings.entries)
          entry.key: Map<String, dynamic>.unmodifiable(entry.value),
      }),
      maxCustomerPhotos: _maxCustomerPhotos,
      extraChargeUnits: Map.unmodifiable(_extraChargeUnits),
      creationSource: _creationSource,
      starterTemplateId: _selectedStarterTemplate?.id ?? '',
      starterPackId: source?.starterPackId ?? '',
      starterCapabilityIds: source?.starterCapabilityIds ?? const <String>[],
      serviceCapabilityIds:
          resolvedCapabilities?.capabilityIds ??
          source?.serviceCapabilityIds ??
          const <String>[],
      capabilitySchemaVersion: resolvedCapabilities == null
          ? source?.capabilitySchemaVersion ?? 0
          : 1,
      capabilityGeneratedQuestionIds: _capabilityGeneratedQuestionIds.toList(
        growable: false,
      ),
      capabilityGeneratedQuestionKeys: Map.unmodifiable(
        _capabilityGeneratedQuestionKeys,
      ),
      capabilityGeneratedExtraKeys: _capabilityGeneratedExtraKeys.toList(
        growable: false,
      ),
      capabilityGeneratedBuiltInQuestionKeys:
          _capabilityGeneratedBuiltInQuestionKeys.toList(growable: false),
      pricingMode: pricingMode,
      fixedPriceAmount: pricingMode == VanServiceCapabilityIds.fixedPrice
          ? _fixedPriceAmount
          : 0,
      fromPriceAmount: pricingMode == VanServiceCapabilityIds.fromPrice
          ? _fromPriceAmount
          : 0,
      suggestedReminderMinutes:
          resolvedCapabilities?.suggestedReminderMinutes ??
          source?.suggestedReminderMinutes ??
          const <int>[],
      suggestedStatusNames:
          source?.suggestedStatusNames ?? const <String, String>{},
      wizardStep: _step,
    );
  }

  Future<void> _persistQuestions() async {
    final existing = await _questionsStorage.loadAll();
    final merged = {for (final question in existing) question.id: question};
    for (final id in _linkedQuestionIds) {
      final question = _questions[id];
      if (question != null) merged[id] = question;
    }
    await _questionsStorage.saveAll(merged.values.toList(growable: false));
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _persistQuestions();
      final service = _buildService(isDraft: true);
      await _servicesStorage.upsert(service);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved. You can resume it at any time.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _popResult(service);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the draft. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continueManualServiceToReview() async {
    if (_saving || !_validateStep(0)) return;
    setState(() => _saving = true);
    final service = _buildService(isDraft: false).copyWith(
      isActive: true,
      isDraft: false,
      workingDays: const <int>[],
      wizardStep: 0,
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      VanServiceCreationEntryResult(
        createdServiceIds: <String>[service.id],
        pendingServices: <VanJobService>[service],
      ),
    );
  }

  Future<void> _publish() async {
    if (_saving ||
        !_validateStep(0) ||
        !_validateStep(2) ||
        !_validateStep(6)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await _persistQuestions();
      final service = _buildService(isDraft: false);
      await _servicesStorage.upsert(service);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _CompletionDialog(
          onComplete: () => Navigator.of(dialogContext).pop(),
        ),
      );
      if (!mounted) return;
      _popResult(service);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not publish the service. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _popResult(VanJobService service) {
    if (_isEditing) {
      Navigator.of(context).pop(service);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  bool _validateStep(int step) {
    String? message;
    if (step == 0 && _source == null && !_showBasicFields) {
      message = 'Choose your business type and the services you offer.';
    } else if (step == 0 &&
        sanitizeVanText(_nameController.text).trim().isEmpty) {
      message = 'Add a service name before continuing.';
    } else if (step == 1 &&
        _usesUniversalCapabilityEditor &&
        !_manualCapabilityIds.any(
          const <String>{
            VanServiceCapabilityIds.placeOrder,
            VanServiceCapabilityIds.requestQuote,
            VanServiceCapabilityIds.bookAppointment,
          }.contains,
        )) {
      message = 'Choose one customer journey before continuing.';
    } else if (step == 6 && _workingDays.isEmpty) {
      message = 'Choose at least one working day.';
    } else if (step == 6 && _endMinutes <= _startMinutes) {
      message = 'Closing time must be later than opening time.';
    } else if (step == 2 &&
        _allowedStarts.isEmpty &&
        !_isUnchangedStandardWithoutFullHandover) {
      message = 'Choose at least one way for the service to start.';
    } else if (step == 2 &&
        _allowedEnds.isEmpty &&
        !_isUnchangedStandardWithoutFullHandover) {
      message = 'Choose at least one way for the service to end.';
    } else if (step == 5 &&
        _usesFixedPrice &&
        validateVanMateQuoteAmountInput(_fixedPriceController.text) != null) {
      message = 'Enter the fixed price for this service.';
    } else if (step == 5 &&
        _usesFromPrice &&
        validateVanMateQuoteAmountInput(_fromPriceController.text) != null) {
      message = 'Enter the starting price for this service.';
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step == 0 &&
        _source == null &&
        _creationSource == 'blank' &&
        _showBasicFields) {
      unawaited(_continueManualServiceToReview());
      return;
    }
    if (_step == 1 && _usesUniversalCapabilityEditor) {
      setState(_applyManualCapabilityDefaults);
    }
    if (_step == 5 && !_configuringExtras) {
      setState(() => _configuringExtras = true);
      return;
    }
    if (_step < _stepTitles.length - 1) setState(() => _step++);
  }

  void _previous() {
    if (_step == 5 && _configuringExtras) {
      setState(() => _configuringExtras = false);
      return;
    }
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _cancel() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave service setup?'),
        content: const Text(
          'Save a draft if you want to continue from here later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _editExtras() async {
    final updated = await showModalBottomSheet<VanQuoteExtraDefaults>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VanQuoteExtraDefaultsSheet(
        initialDefaults: _extras,
        resetDefaults: VanQuoteExtraDefaults.starterForServiceName(
          _nameController.text,
        ),
        title: 'Pricing extras',
        description: 'Add only the charges that make sense for this service.',
      ),
    );
    if (updated != null && mounted) setState(() => _extras = updated);
  }

  Future<void> _addQuestion() async {
    final question = await editVanServiceQuestion(
      context,
      serviceId: _serviceId,
    );
    if (question == null || !mounted) return;
    setState(() {
      _questions[question.id] = question;
      _linkedQuestionIds.add(question.id);
      _availableQuestionIds.add(question.id);
    });
  }

  Future<void> _editQuestion(String id) async {
    final current = _questions[id];
    if (current == null) return;
    final question = await editVanServiceQuestion(
      context,
      serviceId: _serviceId,
      question: current,
    );
    if (question != null && mounted) {
      setState(() => _questions[id] = question);
    }
  }

  Future<void> _previewCustomerExperience() async {
    if (!_validateStep(0)) return;
    final profile = await VanBusinessProfileStorage.instance.load();
    if (!mounted) return;
    final service = _buildService(isDraft: false).copyWith(isActive: true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VanBookingLinkCustomerFormPage(
          profile: profile,
          activeServices: [service],
          questionLookup: Map.unmodifiable(_questions),
          bookingLinkActive: true,
          bookingLinkUrl: '',
          bookingLinkTitle: service.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final compactHeader = MediaQuery.sizeOf(context).width < 420;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            compactHeader
                ? (_isEditing ? 'Edit' : 'Create')
                : (_isEditing ? 'Edit Service' : 'Create Service'),
            overflow: TextOverflow.ellipsis,
          ),
          leadingWidth: compactHeader ? 52 : 96,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: compactHeader
                ? IconButton(
                    onPressed: _cancel,
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : VanBackBusinessHubButtons(onBack: _cancel),
          ),
          actions: [
            if (compactHeader && _showWizardChrome)
              IconButton(
                onPressed: _saving ? null : _saveDraft,
                tooltip: 'Save Draft',
                icon: const Icon(Icons.save_outlined),
              )
            else if (_showWizardChrome) ...[
              TextButton(
                onPressed: _saving ? null : _saveDraft,
                child: const Text('Save Draft'),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppTheme.backgroundImage(),
            Container(color: Colors.black.withValues(alpha: 0.42)),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_showWizardChrome && !_isManualIdentityPreflight)
                    _WizardProgress(step: _step, titles: _stepTitles),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final editor = _WizardPanel(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('$_step-$_configuringExtras'),
                              child: _buildStep(),
                            ),
                          ),
                        );
                        final preview = _LiveJourneyPreview(
                          journey: _journey,
                          allowedStarts: _allowedStarts,
                          allowedEnds: _allowedEnds,
                          colour: Color(_colourValue),
                        );
                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            bottomInset + 110,
                          ),
                          children: wide && _showWizardChrome
                              ? [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 7, child: editor),
                                      const SizedBox(width: 16),
                                      SizedBox(width: 300, child: preview),
                                    ],
                                  ),
                                ]
                              : [
                                  editor,
                                  if (_showWizardChrome) ...[
                                    const SizedBox(height: 12),
                                    preview,
                                  ],
                                ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_showWizardChrome)
              Align(
                alignment: Alignment.bottomCenter,
                child: _WizardNavigation(
                  step: _step,
                  lastStep: _stepTitles.length - 1,
                  saving: _saving,
                  nextLabel: _isManualIdentityPreflight
                      ? 'Continue to Service Features'
                      : _step == 3
                      ? 'Configure questions'
                      : _step == 5 && !_configuringExtras
                      ? 'Configure extras'
                      : 'Next',
                  onPrevious: _previous,
                  onNext: _next,
                  onPublish: _publish,
                  onSaveDraft: _saveDraft,
                  onCancel: _cancel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _buildBasics(),
    1 => _buildJourney(),
    2 => _buildFlow(),
    3 => _buildQuestionLibrary(),
    4 => _buildQuestionConfiguration(),
    5 => _buildPricing(),
    6 => _buildAvailability(),
    _ => _buildReview(),
  };

  Widget _stepHeader(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        description,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .7),
          height: 1.4,
        ),
      ),
      const SizedBox(height: 20),
    ],
  );

  Widget _buildBasics() {
    if (_source != null) return _buildBasicInformationFields();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_showBasicFields) _buildCreationStart(),
        if (_showBasicFields) ...[
          if (_selectedStarterTemplate != null) ...[
            _CreationSourceBanner(
              title: 'Starter Pack: ${_selectedStarterTemplate!.name}',
              subtitle:
                  'Recommended settings are loaded and everything remains editable.',
              onChange: _chooseDifferentStarterPack,
            ),
            const SizedBox(height: 18),
          ],
          _buildBasicInformationFields(),
        ],
      ],
    );
  }

  Widget _buildCreationStart() {
    final selectedPack = _selectedCapabilityPack;
    final searchResults = searchVanStarterCapabilityPacks(_businessSearchQuery);
    final popularChoices = _popularBusinessChoices();
    final browseCategories = _businessBrowseCategories();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_showStarterBrowser && selectedPack == null) ...[
          _stepHeader(
            'Set Up My Business',
            'Choose your business type and the services you offer. Business Mate will build everything for you automatically, and you can customise everything later.',
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _chooseStarterPack,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Choose Business Type'),
            ),
          ),
        ],
        if (_showStarterBrowser) ...[
          const _QuestionSectionHeading(
            title: 'What business do you run?',
            subtitle:
                'Search or browse to find the best starting point. You will choose the services you offer next.',
          ),
          TextField(
            key: const Key('business_search_field'),
            controller: _businessSearchController,
            onChanged: _updateBusinessSearch,
            textInputAction: TextInputAction.search,
            decoration:
                vanMateFieldDecoration(
                  label: 'Search businesses',
                  hintText: 'Search businesses...',
                  prefixIcon: const Icon(Icons.search_rounded),
                ).copyWith(
                  suffixIcon: _businessSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearBusinessSearch,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
          ),
          const SizedBox(height: 14),
          if (kVanStarterCapabilityPacks.isEmpty) ...[
            const _EmptyWizardCard(
              icon: Icons.inventory_2_outlined,
              text:
                  'No business templates are available yet. Create a service manually while the verified library is rebuilt.',
            ),
          ] else if (_businessSearchQuery.isNotEmpty) ...[
            if (searchResults.isNotEmpty)
              _BusinessResultList(
                results: searchResults,
                onSelected: _selectCapabilityPack,
              )
            else
              const _EmptyBusinessSearch(),
          ] else ...[
            if (_recentBusinessChoices.isNotEmpty) ...[
              _BusinessShortcutSection(
                title: 'Recent',
                icon: Icons.history_rounded,
                choices: _recentBusinessChoices,
                onSelected: _selectCapabilityPack,
              ),
              const SizedBox(height: 16),
            ],
            _BusinessShortcutSection(
              title: 'Popular businesses',
              icon: Icons.star_rounded,
              choices: popularChoices,
              onSelected: _selectCapabilityPack,
            ),
            const SizedBox(height: 18),
            const Text(
              'Browse businesses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            for (final category in browseCategories) ...[
              _BusinessCategoryCard(
                category: category,
                expanded: _expandedTemplateCategoryId == category.id,
                onToggle: () => setState(() {
                  _expandedTemplateCategoryId =
                      _expandedTemplateCategoryId == category.id
                      ? null
                      : category.id;
                }),
                onSelected: _selectCapabilityPack,
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('create_service_manually'),
              onPressed: _startBlankService,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Service Manually'),
            ),
          ),
        ],
        if (selectedPack != null && !_showStarterBrowser) ...[
          const SizedBox(height: 20),
          switch (_businessSetupStage) {
            _BusinessSetupStage.services => _RecommendedServiceSelectionCard(
              pack: selectedPack,
              selectedIds: _selectedRecommendedServiceIds,
              saving: _saving,
              onChanged: _toggleRecommendedService,
              onContinue: _continueToServiceCapabilities,
              onChooseDifferent: _chooseDifferentStarterPack,
            ),
            _BusinessSetupStage.capabilities => _ServiceCapabilitiesCard(
              pack: selectedPack,
              selectedServiceIds: _selectedRecommendedServiceIds,
              capabilityIdsByService: _capabilityIdsByService,
              saving: _saving,
              onChanged: _toggleUniversalCapability,
              onBack: () => setState(
                () => _businessSetupStage = _BusinessSetupStage.services,
              ),
              onContinue: _continueToBusinessSetupExtras,
              onChooseDifferent: _chooseDifferentStarterPack,
            ),
            _BusinessSetupStage.extras => _buildBusinessSetupExtras(),
            _BusinessSetupStage.availability =>
              _buildBusinessSetupAvailability(),
            _BusinessSetupStage.review => _buildBusinessSetupReview(),
          },
        ],
      ],
    );
  }

  Widget _businessSetupActions({
    required VoidCallback onBack,
    required VoidCallback onContinue,
    required String continueLabel,
    IconData continueIcon = Icons.arrow_forward_rounded,
  }) => Column(
    children: [
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _saving ? null : onContinue,
          icon: Icon(continueIcon),
          label: Text(continueLabel),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Previous'),
        ),
      ),
    ],
  );

  Future<void> _addBusinessSetupCustomExtra() async {
    var extraName = '';
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Custom Extra'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Extra name',
            hintText: 'e.g. Equipment hire',
          ),
          onChanged: (value) => extraName = value,
          onSubmitted: (value) {
            final cleaned = value.trim();
            if (cleaned.isNotEmpty) Navigator.of(dialogContext).pop(cleaned);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final cleaned = extraName.trim();
              if (cleaned.isNotEmpty) Navigator.of(dialogContext).pop(cleaned);
            },
            child: const Text('Add Extra'),
          ),
        ],
      ),
    );
    if (label == null || !mounted) return;
    final key =
        'custom_extra_setup_${DateTime.now().microsecondsSinceEpoch.toString()}';
    setState(() {
      _extras = _extras.copyWithExtra(
        VanQuoteExtraDefault.custom(key: key, label: label, defaultPrice: 0),
      );
      _extraChargeUnits[key] = 'Fixed';
    });
  }

  Widget _buildBusinessSetupExtras() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepHeader(
        'Pricing extras',
        'Tick the extras you use. Business Mate will add them to your services, and you can set or change prices later.',
      ),
      _LibraryGrid(
        children: [
          for (final item in _extrasLibrary)
            _LibraryChoiceCard(
              icon: item.icon,
              label: item.label,
              selected: _configuredExtra(item.key)?.enabled == true,
              onChanged: (selected) => _toggleExtraLibraryItem(item, selected),
            ),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addBusinessSetupCustomExtra,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Custom Extra'),
        ),
      ),
      _businessSetupActions(
        onBack: () => setState(
          () => _businessSetupStage = _BusinessSetupStage.capabilities,
        ),
        onContinue: () => setState(
          () => _businessSetupStage = _BusinessSetupStage.availability,
        ),
        continueLabel: 'Set Availability',
        continueIcon: Icons.schedule_outlined,
      ),
    ],
  );

  void _continueToBusinessSetupReview() {
    String? message;
    if (_workingDays.isEmpty) {
      message = 'Choose at least one working day.';
    } else if (_endMinutes <= _startMinutes) {
      message = 'Closing time must be later than opening time.';
    }
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _businessSetupStage = _BusinessSetupStage.review);
  }

  Widget _buildBusinessSetupAvailability() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildAvailability(businessSetup: true),
      _businessSetupActions(
        onBack: () =>
            setState(() => _businessSetupStage = _BusinessSetupStage.extras),
        onContinue: _continueToBusinessSetupReview,
        continueLabel: 'Review Services',
        continueIcon: Icons.fact_check_outlined,
      ),
    ],
  );

  Widget _buildBusinessSetupReview() {
    final pack = _selectedCapabilityPack!;
    final setups = pack.recommendationsFor(
      _selectedRecommendedServiceIds,
      capabilityIdsByService: _capabilityIdsByService,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Review business',
          'Business Mate will create each selected service with its own sensible defaults. You will review features, questions, extras and availability one service at a time next.',
        ),
        for (final setup in setups) ...[
          _BusinessServiceReviewCard(
            setup: setup,
            handover: _businessSetupHandoverSummary(setup),
            extrasCount: _businessSetupExtrasFor(
              setup.quoteExtraDefaults(),
            ).enabledExtras.length,
            availability:
                'Mon–Fri · 9:00 AM–5:00 PM · ${setup.suggestedDurationMinutes ?? 60} min',
          ),
          const SizedBox(height: 12),
        ],
        _businessSetupActions(
          onBack: () => setState(
            () => _businessSetupStage = _BusinessSetupStage.services,
          ),
          onContinue: _createRecommendedServices,
          continueLabel: setups.length == 1
              ? 'Create Service'
              : 'Create ${setups.length} Services',
          continueIcon: Icons.rocket_launch_outlined,
        ),
      ],
    );
  }

  String _businessSetupHandoverSummary(VanRecommendedServiceSetup setup) {
    final values = <String>[
      if (setup.allowCustomerDropOff) 'Customer drops off',
      if (setup.allowBusinessCollection) 'Business collects',
      if (setup.allowCustomerCollection) 'Customer collects',
      if (setup.allowBusinessReturn) 'Business returns',
      if (setup.allowBusinessDelivery) 'Business delivers',
      if (setup.requireAddress &&
          !setup.allowBusinessCollection &&
          !setup.allowBusinessReturn &&
          !setup.allowBusinessDelivery)
        'Customer address required',
    ];
    return values.isEmpty ? 'No handover required' : values.join(' · ');
  }

  Widget _buildBasicInformationFields() {
    final categoryOptions = _categoryDropdownOptions(_category);
    final selectedCategory = _selectedCategoryOption(_category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'What service do you offer?',
          'Start with the essentials. You can refine everything later.',
        ),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: vanMateFieldDecoration(
            label: 'Service name',
            hintText: 'Window cleaning',
            prefixIcon: const Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('service_category_${selectedCategory.id}'),
          initialValue: selectedCategory.id,
          isExpanded: true,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(
            label: 'Category',
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: [
            for (final option in categoryOptions)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            final selected = categoryOptions.singleWhere(
              (option) => option.id == value,
            );
            setState(() => _category = selected.label);
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Icon'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in _iconOptions.entries)
              _IconChoice(
                icon: entry.value,
                selected: _iconKey == entry.key,
                colour: Color(_colourValue),
                onTap: () => setState(() => _iconKey = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Colour'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final value in _colourOptions)
              _ColourChoice(
                colour: Color(value),
                selected: _colourValue == value,
                onTap: () => setState(() => _colourValue = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: vanMateFieldDecoration(
            label: 'Short description',
            hintText: 'A clear sentence explaining what is included',
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customerMessageController,
          maxLines: 3,
          decoration: vanMateFieldDecoration(
            label: 'Customer message (optional)',
            hintText: 'A helpful message customers see for this service',
            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ),
        const SizedBox(height: 18),
        _ServicePreviewCard(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _category,
          icon: _iconOptions[_iconKey]!,
          colour: Color(_colourValue),
        ),
      ],
    );
  }

  Widget _buildJourney() {
    if (_usesUniversalCapabilityEditor) {
      final serviceName = _nameController.text.trim().isEmpty
          ? 'This service'
          : _nameController.text.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'How should this service work?',
            'Choose any capabilities you need. These choices build the customer journey, booking settings, questions and extras.',
          ),
          _ServiceCapabilityEditor(
            service: VanBusinessServiceRecommendation(
              id: _serviceId,
              name: serviceName,
              description: '',
              recommendedCapabilityIds: const <String>[],
            ),
            selectedIds: _manualCapabilityIds,
            colour: Color(_colourValue),
            enabled: !_saving,
            onChanged: _toggleManualCapability,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How do customers begin this service?',
          'Choose the journey that best matches how you win the work.',
        ),
        _SelectionCard(
          icon: Icons.request_quote_outlined,
          title: 'Quote',
          description:
              'Customer requests a quote. You review, price and send it for acceptance.',
          selected: _journey == VanCustomerJourneyType.quote,
          onTap: () => setState(() => _journey = VanCustomerJourneyType.quote),
        ),
        const SizedBox(height: 10),
        _SelectionCard(
          icon: Icons.calendar_month_outlined,
          title: 'Booking',
          description:
              'Customer requests a time. You confirm it and the booking enters the calendar.',
          selected: _journey == VanCustomerJourneyType.booking,
          onTap: () =>
              setState(() => _journey = VanCustomerJourneyType.booking),
        ),
        const SizedBox(height: 10),
        _SelectionCard(
          icon: Icons.shopping_bag_outlined,
          title: 'Order Request',
          description:
              'Customer requests a custom-made or made-to-order product. You review and confirm the details.',
          selected: _journey == VanCustomerJourneyType.order,
          onTap: () => setState(() => _journey = VanCustomerJourneyType.order),
        ),
        const SizedBox(height: 10),
        _SelectionCard(
          icon: Icons.shopping_basket_outlined,
          title: 'Pre Order',
          description:
              'Customer orders an existing product ahead of collection or delivery. You review and confirm the timing.',
          selected: _journey == VanCustomerJourneyType.preOrder,
          onTap: () =>
              setState(() => _journey = VanCustomerJourneyType.preOrder),
        ),
      ],
    );
  }

  Widget _buildFlow() {
    if (_usesUniversalCapabilityEditor) {
      final resolved = resolveVanServiceCapabilities(
        _manualCapabilityIds,
        recommendedDurationMinutes: _appointmentDurationMinutes,
        recommendedNoticeHours: _noticeHours,
      );
      final fulfilmentLabels = kVanServiceCapabilities
          .where(
            (capability) =>
                capability.group == VanServiceCapabilityGroup.fulfilment &&
                _manualCapabilityIds.contains(capability.id),
          )
          .map((capability) => capability.label)
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Your generated customer flow',
            'Business Mate has translated the selected capabilities into the customer journey and service settings below.',
          ),
          _RecommendationBanner(
            text:
                '${resolved.journeyType.selectorLabel} · ${resolved.builtInQuestionKeys.length} customer details · ${resolved.extras.length} suggested extras',
          ),
          if (fulfilmentLabels.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in fulfilmentLabels)
                  Chip(
                    avatar: const Icon(Icons.check_rounded, size: 17),
                    label: Text(label),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Use Previous to change capabilities. You can still customise individual questions, extras and availability in the next steps.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              height: 1.4,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How is this service carried out?',
          'Choose which handover options your business offers. Customers will only see the options you enable.',
        ),
        const _QuestionSectionHeading(
          title: 'Service starts',
          subtitle: 'Enable one or both options.',
        ),
        _HandoverCapabilityTile(
          icon: Icons.storefront_outlined,
          title: 'Customer drops off item',
          subtitle: 'The customer brings the item to your business.',
          selected: _allowedStarts.contains(VanStartHandover.customerDropsOff),
          onChanged: (selected) => setState(() {
            _handoverTouched = true;
            if (selected) {
              if (!_allowedStarts.contains(VanStartHandover.customerDropsOff)) {
                _allowedStarts = [
                  ..._allowedStarts,
                  VanStartHandover.customerDropsOff,
                ];
              }
            } else {
              _allowedStarts = _allowedStarts
                  .where((value) => value != VanStartHandover.customerDropsOff)
                  .toList(growable: false);
            }
            if (_allowedStarts.isNotEmpty &&
                !_allowedStarts.contains(_startHandover)) {
              _startHandover = _allowedStarts.first;
            }
          }),
        ),
        const SizedBox(height: 10),
        _HandoverCapabilityTile(
          icon: Icons.local_shipping_outlined,
          title: 'Business collects item',
          subtitle: 'You collect the item from the customer.',
          selected: _allowedStarts.contains(VanStartHandover.businessCollects),
          onChanged: (selected) => setState(() {
            _handoverTouched = true;
            if (selected) {
              if (!_allowedStarts.contains(VanStartHandover.businessCollects)) {
                _allowedStarts = [
                  ..._allowedStarts,
                  VanStartHandover.businessCollects,
                ];
              }
            } else {
              _allowedStarts = _allowedStarts
                  .where((value) => value != VanStartHandover.businessCollects)
                  .toList(growable: false);
            }
            if (_allowedStarts.isNotEmpty &&
                !_allowedStarts.contains(_startHandover)) {
              _startHandover = _allowedStarts.first;
            }
          }),
        ),
        const SizedBox(height: 22),
        const _QuestionSectionHeading(
          title: 'Service ends',
          subtitle: 'Enable one or both options.',
        ),
        _HandoverCapabilityTile(
          icon: Icons.shopping_bag_outlined,
          title: 'Customer collects item',
          subtitle: 'The customer collects it from your business.',
          selected: _allowedEnds.contains(VanEndHandover.customerCollects),
          onChanged: (selected) => setState(() {
            _handoverTouched = true;
            if (selected) {
              if (!_allowedEnds.contains(VanEndHandover.customerCollects)) {
                _allowedEnds = [
                  ..._allowedEnds,
                  VanEndHandover.customerCollects,
                ];
              }
            } else {
              _allowedEnds = _allowedEnds
                  .where((value) => value != VanEndHandover.customerCollects)
                  .toList(growable: false);
            }
            if (_allowedEnds.isNotEmpty &&
                !_allowedEnds.contains(_endHandover)) {
              _endHandover = _allowedEnds.first;
            }
          }),
        ),
        const SizedBox(height: 10),
        _HandoverCapabilityTile(
          icon: Icons.route_outlined,
          title: 'Business returns item',
          subtitle: 'You return it to the customer when finished.',
          selected: _allowedEnds.contains(VanEndHandover.businessReturns),
          onChanged: (selected) => setState(() {
            _handoverTouched = true;
            if (selected) {
              if (!_allowedEnds.contains(VanEndHandover.businessReturns)) {
                _allowedEnds = [
                  ..._allowedEnds,
                  VanEndHandover.businessReturns,
                ];
              }
            } else {
              _allowedEnds = _allowedEnds
                  .where((value) => value != VanEndHandover.businessReturns)
                  .toList(growable: false);
            }
            if (_allowedEnds.isNotEmpty &&
                !_allowedEnds.contains(_endHandover)) {
              _endHandover = _allowedEnds.first;
            }
          }),
        ),
        const SizedBox(height: 10),
        _HandoverCapabilityTile(
          icon: Icons.local_shipping_outlined,
          title: 'Business delivers item',
          subtitle: 'You deliver it to a destination address.',
          selected: _allowedEnds.contains(VanEndHandover.businessDelivers),
          onChanged: (selected) => setState(() {
            _handoverTouched = true;
            if (selected) {
              if (!_allowedEnds.contains(VanEndHandover.businessDelivers)) {
                _allowedEnds = [
                  ..._allowedEnds,
                  VanEndHandover.businessDelivers,
                ];
              }
            } else {
              _allowedEnds = _allowedEnds
                  .where((value) => value != VanEndHandover.businessDelivers)
                  .toList(growable: false);
            }
            if (_allowedEnds.isNotEmpty &&
                !_allowedEnds.contains(_endHandover)) {
              _endHandover = _allowedEnds.first;
            }
          }),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _dropOffController,
          maxLines: 2,
          decoration: vanMateFieldDecoration(
            label: 'Business location / drop-off instructions',
            hintText: 'Optional',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _collectionController,
          maxLines: 2,
          decoration: vanMateFieldDecoration(
            label: 'Collection / return instructions',
            hintText: 'Optional',
          ),
        ),
      ],
    );
  }

  List<_QuestionLibraryItem> get _questionLibrary => <_QuestionLibraryItem>[
    const _QuestionLibraryItem.builtIn(
      key: 'address',
      label: 'Address',
      icon: Icons.location_on_outlined,
    ),
    if (_requestType.serviceFlow == VanServiceFlow.pickupDelivery) ...const [
      _QuestionLibraryItem.builtIn(
        key: 'collection_address',
        label: 'Collection Address',
        icon: Icons.trip_origin_rounded,
      ),
      _QuestionLibraryItem.builtIn(
        key: 'delivery_address',
        label: 'Delivery Address',
        icon: Icons.location_on_rounded,
      ),
    ],
    const _QuestionLibraryItem.builtIn(
      key: 'preferred_date',
      label: 'Preferred Date',
      icon: Icons.calendar_today_outlined,
    ),
    const _QuestionLibraryItem.builtIn(
      key: 'preferred_time',
      label: 'Preferred Time',
      icon: Icons.schedule_outlined,
    ),
    const _QuestionLibraryItem.builtIn(
      key: 'photos',
      label: 'Photos',
      icon: Icons.add_a_photo_outlined,
    ),
    const _QuestionLibraryItem.builtIn(
      key: 'phone',
      label: 'Phone Number',
      icon: Icons.phone_outlined,
    ),
    const _QuestionLibraryItem.builtIn(
      key: 'email',
      label: 'Email Address',
      icon: Icons.email_outlined,
    ),
    ..._customQuestionLibrary,
    const _QuestionLibraryItem.builtIn(
      key: 'exact_pin',
      label: 'Exact Location After Acceptance',
      icon: Icons.pin_drop_outlined,
    ),
  ];

  bool _isQuestionLibraryItemSelected(_QuestionLibraryItem item) {
    if (item.builtIn) return _selectedBuiltInQuestions.contains(item.key);
    final id = _libraryQuestionIds[item.key];
    return id != null && _linkedQuestionIds.contains(id);
  }

  void _toggleQuestionLibraryItem(_QuestionLibraryItem item, bool selected) {
    setState(() {
      if (item.builtIn) {
        if (selected) {
          _selectedBuiltInQuestions.add(item.key);
          _builtInQuestionSettings.putIfAbsent(
            item.key,
            () => <String, dynamic>{'required': false, 'helperText': ''},
          );
        } else {
          _selectedBuiltInQuestions.remove(item.key);
        }
        _requestPhotos = _selectedBuiltInQuestions.contains('photos');
        _requestExactPin = _selectedBuiltInQuestions.contains('exact_pin');
        _requireAddress =
            _selectedBuiltInQuestions.contains('address') &&
            (_builtInQuestionSettings['address']?['required'] == true);
        return;
      }
      var id = _libraryQuestionIds[item.key];
      if (selected) {
        if (id == null || !_questions.containsKey(id)) {
          final now = DateTime.now();
          id = 'service_question_${_serviceId}_${now.microsecondsSinceEpoch}';
          _questions[id] = VanCustomJobQuestion(
            id: id,
            questionText: item.label,
            helperText: '',
            answerType: item.answerType,
            category: item.category,
            isActive: true,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          );
          _availableQuestionIds.add(id);
          _libraryQuestionIds[item.key] = id;
        }
        if (!_linkedQuestionIds.contains(id)) _linkedQuestionIds.add(id);
      } else if (id != null) {
        _linkedQuestionIds.remove(id);
        _optionalQuestionIds.remove(id);
      }
    });
  }

  String _normaliseQuestionText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Set<String> get _starterQuestionTexts => {
    for (final question
        in _selectedStarterTemplate?.questions ??
            const <VanServiceTemplateQuestion>[])
      _normaliseQuestionText(question.text),
  };

  Set<String> get _starterBuiltInQuestionKeys {
    final keys = <String>{};
    for (final question
        in _selectedStarterTemplate?.questions ??
            const <VanServiceTemplateQuestion>[]) {
      final key = _builtInQuestionKeyForText(question.text);
      if (key != null) keys.add(key);
    }
    return keys;
  }

  bool _isStarterQuestionLibraryItem(_QuestionLibraryItem item) {
    if (_selectedStarterTemplate == null) return false;
    if (item.builtIn) return _starterBuiltInQuestionKeys.contains(item.key);
    return _starterQuestionTexts.contains(_normaliseQuestionText(item.label));
  }

  bool _isStarterStoredQuestion(String id) {
    final question = _questions[id];
    return question != null &&
        _starterQuestionTexts.contains(
          _normaliseQuestionText(question.questionText),
        );
  }

  Widget _questionLibraryChoice(_QuestionLibraryItem item) =>
      _LibraryChoiceCard(
        icon: item.icon,
        label: item.label,
        selected: _isQuestionLibraryItemSelected(item),
        onChanged: (selected) => _toggleQuestionLibraryItem(item, selected),
      );

  Widget _storedQuestionChoice(String id) => _LibraryChoiceCard(
    icon: Icons.question_answer_outlined,
    label: _questions[id]!.questionText,
    selected: _linkedQuestionIds.contains(id),
    onChanged: (selected) => setState(() {
      if (selected) {
        if (!_linkedQuestionIds.contains(id)) _linkedQuestionIds.add(id);
      } else {
        _linkedQuestionIds.remove(id);
        _optionalQuestionIds.remove(id);
      }
    }),
  );

  Widget _buildQuestionLibrary() {
    final hasStarter = _selectedStarterTemplate != null;
    final suggestedLibraryItems = _questionLibrary
        .where(_isStarterQuestionLibraryItem)
        .toList(growable: false);
    final browseLibraryItems = _questionLibrary
        .where((item) => !hasStarter || !_isStarterQuestionLibraryItem(item))
        .toList(growable: false);
    final standaloneQuestionIds = _availableQuestionIds
        .where(
          (id) =>
              !_libraryQuestionIds.values.contains(id) &&
              _questions[id] != null,
        )
        .toList(growable: false);
    final suggestedQuestionIds = standaloneQuestionIds
        .where(_isStarterStoredQuestion)
        .toList(growable: false);
    final browseQuestionIds = standaloneQuestionIds
        .where((id) => !hasStarter || !_isStarterStoredQuestion(id))
        .toList(growable: false);
    final selectedCount =
        _selectedBuiltInQuestions.length + _linkedQuestionIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'What would you like to ask your customers?',
          'Choose the information you normally need from customers. You\'ll customise your selections in the next step.',
        ),
        if (hasStarter) ...[
          _QuestionSectionHeading(
            title: 'Suggested for your business',
            subtitle:
                '${_selectedStarterTemplate!.name} recommendations are already selected. Untick anything you do not need.',
          ),
          _LibraryGrid(
            children: [
              for (final item in suggestedLibraryItems)
                _questionLibraryChoice(item),
              for (final id in suggestedQuestionIds) _storedQuestionChoice(id),
            ],
          ),
          const SizedBox(height: 22),
        ],
        const _QuestionSectionHeading(
          title: 'Browse more questions',
          subtitle: 'Add any other information that would help with this job.',
        ),
        _LibraryGrid(
          children: [
            for (final item in browseLibraryItems) _questionLibraryChoice(item),
            for (final id in browseQuestionIds) _storedQuestionChoice(id),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Create Custom Question'),
          ),
        ),
        if (_loadingQuestions)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          const SizedBox(height: 12),
          _SelectedQuestionsSummary(count: selectedCount),
        ],
      ],
    );
  }

  Widget _buildQuestionConfiguration() {
    final builtIns = _questionLibrary
        .where((item) => item.builtIn && _isQuestionLibraryItemSelected(item))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Customise your selected questions',
          'Now tell us how you would like to ask each one. Only your selections are shown here.',
        ),
        if (builtIns.isEmpty && _linkedQuestionIds.isEmpty)
          const _EmptyWizardCard(
            icon: Icons.check_circle_outline,
            text: 'No customer questions selected. You can continue.',
          ),
        for (final item in builtIns) ...[
          _BuiltInQuestionConfigCard(
            item: item,
            requiredValue:
                _builtInQuestionSettings[item.key]?['required'] == true,
            helperText:
                _builtInQuestionSettings[item.key]?['helperText']?.toString() ??
                '',
            maxPhotos: _maxCustomerPhotos,
            onRequiredChanged: (value) => setState(() {
              final settings = _builtInQuestionSettings.putIfAbsent(
                item.key,
                () => <String, dynamic>{},
              );
              settings['required'] = value;
              if (item.key == 'address') _requireAddress = value;
            }),
            onHelperChanged: (value) {
              _builtInQuestionSettings.putIfAbsent(
                item.key,
                () => <String, dynamic>{},
              )['helperText'] = value;
            },
            onMaxPhotosChanged: item.key == 'photos'
                ? (value) => setState(() => _maxCustomerPhotos = value)
                : null,
          ),
          const SizedBox(height: 10),
        ],
        for (final id in _linkedQuestionIds) ...[
          if (_questions[id] case final question?)
            _CustomQuestionConfigCard(
              question: question,
              requiredValue: !_optionalQuestionIds.contains(id),
              showUnit: _libraryQuestionIds['measurements'] == id,
              onRequiredChanged: (required) => setState(() {
                required
                    ? _optionalQuestionIds.remove(id)
                    : _optionalQuestionIds.add(id);
              }),
              onHelperChanged: (value) {
                _questions[id] = question.copyWith(
                  helperText: value,
                  updatedAt: DateTime.now(),
                );
              },
              onUnitChanged: (unit) {
                _questions[id] = question.copyWith(
                  helperText: unit.isEmpty
                      ? ''
                      : 'Please provide this in $unit.',
                  updatedAt: DateTime.now(),
                );
              },
              onEdit: () => _editQuestion(id),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildPricing() {
    return _configuringExtras
        ? _buildExtraConfiguration()
        : _buildExtrasLibrary();
  }

  List<_ExtraLibraryItem> get _extrasLibrary {
    final items = <_ExtraLibraryItem>[..._defaultExtrasLibrary];
    final known = items.map((item) => item.key).toSet();
    for (final extra in _extras.orderedExtras) {
      if (known.add(extra.key)) {
        items.add(
          _ExtraLibraryItem(
            key: extra.key,
            label: extra.resolvedLabel,
            icon: Icons.add_card_outlined,
            defaultPrice: extra.defaultPrice,
            units: const <String>['Fixed'],
            defaultUnit: 'Fixed',
          ),
        );
      }
    }
    return items;
  }

  VanQuoteExtraDefault? _configuredExtra(String key) {
    for (final extra in _extras.orderedExtras) {
      if (extra.key == key) return extra;
    }
    return null;
  }

  void _toggleExtraLibraryItem(_ExtraLibraryItem item, bool selected) {
    setState(() {
      final existing = _configuredExtra(item.key);
      final next =
          existing?.copyWith(enabled: selected) ??
          (isVanQuoteBuiltInExtraKey(item.key)
              ? VanQuoteExtraDefault.fallback(item.key).copyWith(
                  label: item.label,
                  defaultPrice: item.defaultPrice,
                  enabled: selected,
                )
              : VanQuoteExtraDefault.custom(
                  key: item.key,
                  label: item.label,
                  defaultPrice: item.defaultPrice,
                  enabled: selected,
                ));
      _extras = _extras.copyWithExtra(next);
      if (selected) {
        _extraChargeUnits.putIfAbsent(item.key, () => item.defaultUnit);
      }
    });
  }

  Widget _buildExtrasLibrary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How would you like to charge?',
          'Choose any extras you use. You will set prices only for those choices next.',
        ),
        if (_usesFixedPrice) ...[
          _FixedPriceAmountCard(controller: _fixedPriceController),
          const SizedBox(height: 12),
        ],
        if (_usesFromPrice) ...[
          _FromPriceAmountCard(controller: _fromPriceController),
          const SizedBox(height: 12),
        ],
        if (_selectedStarterTemplate != null)
          _RecommendationBanner(
            text:
                '${_selectedStarterTemplate!.name} recommendations are pre-selected. You remain in control.',
          ),
        const SizedBox(height: 12),
        _LibraryGrid(
          children: [
            for (final item in _extrasLibrary)
              _LibraryChoiceCard(
                icon: item.icon,
                label: item.label,
                selected: _configuredExtra(item.key)?.enabled == true,
                onChanged: (selected) =>
                    _toggleExtraLibraryItem(item, selected),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _editExtras,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Extra'),
          ),
        ),
      ],
    );
  }

  Widget _buildExtraConfiguration() {
    final selected = _extras.enabledExtras;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Configure your pricing extras',
          'Set a clear price and charging method for only the extras you selected.',
        ),
        if (selected.isEmpty)
          const _EmptyWizardCard(
            icon: Icons.check_circle_outline,
            text: 'No pricing extras selected. You can continue.',
          ),
        for (final extra in selected) ...[
          Builder(
            builder: (context) {
              final libraryExtra = _libraryExtraForKey(extra.key);
              final unit =
                  _extraChargeUnits[extra.key] ??
                  libraryExtra?.defaultUnit ??
                  'Fixed';
              final units = <String>{
                ...?libraryExtra?.units,
                unit,
                'Fixed',
                'Hour',
                '30 Minutes',
                'Mile',
                'Item',
                'Stop',
                'Floor',
                'Day',
                'Week',
                'Percentage',
              }.toList(growable: false);
              return _ExtraConfigurationCard(
                key: ValueKey(extra.key),
                extra: extra,
                unit: unit,
                units: units,
                onPriceChanged: (value) {
                  final price = double.tryParse(value);
                  if (price == null || price < 0) return;
                  _extras = _extras.copyWithExtra(
                    extra.copyWith(defaultPrice: price),
                  );
                },
                onUnitChanged: (value) => setState(() {
                  _extraChargeUnits[extra.key] = value;
                }),
                onEnabledChanged: (value) => setState(() {
                  _extras = _extras.copyWithExtra(
                    extra.copyWith(enabled: value),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  _ExtraLibraryItem? _libraryExtraForKey(String key) {
    for (final item in _extrasLibrary) {
      if (item.key == key) return item;
    }
    return null;
  }

  Widget _buildAvailability({bool businessSetup = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          businessSetup
              ? 'When are these services available?'
              : 'When is this service available?',
          'Set a sensible default schedule. Holiday settings can be added later.',
        ),
        const _FieldLabel('Working days'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _dayLabels.entries)
              FilterChip(
                selected: _workingDays.contains(entry.key),
                label: Text(entry.value),
                onSelected: (selected) => setState(() {
                  selected
                      ? _workingDays.add(entry.key)
                      : _workingDays.remove(entry.key);
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _TimePickerField(
                label: 'Opens',
                minutes: _startMinutes,
                onTap: () async {
                  final picked = await _pickTime(_startMinutes);
                  if (picked != null) setState(() => _startMinutes = picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimePickerField(
                label: 'Closes',
                minutes: _endMinutes,
                onTap: () async {
                  final picked = await _pickTime(_endMinutes);
                  if (picked != null) setState(() => _endMinutes = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: _appointmentDurationMinutes,
          isExpanded: true,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Typical duration'),
          items:
              (<int>{
                    10,
                    15,
                    30,
                    45,
                    60,
                    90,
                    120,
                    180,
                    240,
                    480,
                    _appointmentDurationMinutes,
                  }.toList()..sort())
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value < 60
                            ? '$value minutes'
                            : value % 60 == 0
                            ? '${value ~/ 60} hour${value == 60 ? '' : 's'}'
                            : '${value ~/ 60}h ${value % 60}m',
                      ),
                    ),
                  )
                  .toList(growable: false),
          onChanged: (value) =>
              setState(() => _appointmentDurationMinutes = value ?? 60),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _noticeHours,
          isExpanded: true,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Minimum notice'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('No minimum notice')),
            DropdownMenuItem(value: 2, child: Text('2 hours')),
            DropdownMenuItem(value: 24, child: Text('24 hours')),
            DropdownMenuItem(value: 48, child: Text('48 hours')),
            DropdownMenuItem(value: 168, child: Text('1 week')),
          ],
          onChanged: (value) => setState(() => _noticeHours = value ?? 24),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _maxBookings,
          isExpanded: true,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Maximum bookings per day'),
          items: [
            for (final value in const [1, 2, 3, 4, 5, 6, 8, 10, 12, 20])
              DropdownMenuItem(value: value, child: Text('$value bookings')),
          ],
          onChanged: (value) => setState(() => _maxBookings = value ?? 8),
        ),
        const SizedBox(height: 14),
        const _EmptyWizardCard(
          icon: Icons.beach_access_outlined,
          text: 'Holiday and exception dates are ready for a future update.',
        ),
      ],
    );
  }

  Future<int?> _pickTime(int minutes) async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    return value == null ? null : value.hour * 60 + value.minute;
  }

  Widget _buildReview() {
    final service = _buildService(isDraft: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Ready to publish?',
          'Check the complete service, preview it as a customer, then publish.',
        ),
        _ReviewHero(service: service, icon: _iconOptions[_iconKey]!),
        const SizedBox(height: 14),
        _ReviewRow(
          icon: Icons.signpost_outlined,
          label: 'Journey',
          value: _journey.selectorLabel,
          onEdit: () => setState(() => _step = 1),
        ),
        _ReviewRow(
          icon: Icons.alt_route_rounded,
          label: 'Handover',
          value: _handoverConfigurationSummary(),
          onEdit: () => setState(() => _step = 2),
        ),
        _ReviewRow(
          icon: Icons.question_answer_outlined,
          label: 'Questions',
          value:
              '${_selectedBuiltInQuestions.length + _linkedQuestionIds.length} selected',
          onEdit: () => setState(() => _step = 3),
        ),
        _ReviewRow(
          icon: Icons.payments_outlined,
          label: 'Pricing extras',
          value: _usesFixedPrice
              ? '${formatCurrency(_fixedPriceAmount)} fixed price, ${_extras.enabledExtras.length} extras'
              : _usesFromPrice
              ? 'From ${formatCurrency(_fromPriceAmount)}, ${_extras.enabledExtras.length} extras'
              : '${_extras.enabledExtras.length} enabled',
          onEdit: () => setState(() {
            _configuringExtras = false;
            _step = 5;
          }),
        ),
        _ReviewRow(
          icon: Icons.schedule_outlined,
          label: 'Availability',
          value:
              '${_workingDaysLabel()} · ${_formatMinutes(_startMinutes)}–${_formatMinutes(_endMinutes)} · $_appointmentDurationMinutes min',
          onEdit: () => setState(() => _step = 6),
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            title: const Text(
              'Publish as active',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              'Customers can choose this service immediately.',
              style: TextStyle(color: Colors.white.withValues(alpha: .62)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _previewCustomerExperience,
            icon: const Icon(Icons.phone_iphone_rounded),
            label: const Text('Preview Customer Experience'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _saving ? null : _publish,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(_isEditing ? 'Save & Publish' : 'Publish Service'),
          ),
        ),
      ],
    );
  }

  String _workingDaysLabel() {
    final sorted = _workingDays.toList()..sort();
    if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
      return 'Mon–Fri';
    }
    if (sorted.length == 7) return 'Every day';
    return sorted.map((day) => _dayLabels[day]).join(', ');
  }

  String _handoverConfigurationSummary() {
    if (_allowedStarts.isEmpty && _allowedEnds.isEmpty) {
      return 'No handover required';
    }
    return '${_allowedStarts.length} start option${_allowedStarts.length == 1 ? '' : 's'} · ${_allowedEnds.length} end option${_allowedEnds.length == 1 ? '' : 's'}';
  }
}

String _formatMinutes(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.titles});
  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    color: const Color(0xFF0B1525).withValues(alpha: .88),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step ${step + 1} of ${titles.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titles[step],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(color: Colors.white.withValues(alpha: .68)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            for (var index = 0; index < titles.length; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: index <= step
                        ? const Color(0xFF66D6B5)
                        : Colors.white.withValues(alpha: .15),
                  ),
                ),
              ),
              if (index < titles.length - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ],
    ),
  );
}

class _WizardPanel extends StatelessWidget {
  const _WizardPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF111E31).withValues(alpha: .94),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12)),
      ],
    ),
    child: child,
  );
}

class _WizardNavigation extends StatelessWidget {
  const _WizardNavigation({
    required this.step,
    required this.lastStep,
    required this.saving,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onPublish,
    required this.onSaveDraft,
    required this.onCancel,
  });
  final int step;
  final int lastStep;
  final bool saving;
  final String nextLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1525),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final forward = step < lastStep
              ? FilledButton.icon(
                  onPressed: saving ? null : onNext,
                  iconAlignment: IconAlignment.end,
                  icon: compact
                      ? const SizedBox.shrink()
                      : const Icon(Icons.arrow_forward),
                  label: Text(
                    nextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : FilledButton.icon(
                  onPressed: saving ? null : onPublish,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Publish'),
                );
          return Row(
            children: [
              IconButton(
                onPressed: saving ? null : onCancel,
                tooltip: 'Cancel',
                icon: const Icon(Icons.close),
              ),
              if (step > 0)
                if (compact)
                  IconButton(
                    onPressed: saving ? null : onPrevious,
                    tooltip: 'Previous',
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: saving ? null : onPrevious,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                  ),
              const Spacer(),
              Flexible(child: forward),
            ],
          );
        },
      ),
    ),
  );
}

class _LiveJourneyPreview extends StatelessWidget {
  const _LiveJourneyPreview({
    required this.journey,
    required this.allowedStarts,
    required this.allowedEnds,
    required this.colour,
  });
  final VanCustomerJourneyType journey;
  final List<VanStartHandover> allowedStarts;
  final List<VanEndHandover> allowedEnds;
  final Color colour;
  String get _workLabel => switch (journey) {
    VanCustomerJourneyType.quote => 'Business completes service',
    VanCustomerJourneyType.booking => 'Business completes appointment',
    VanCustomerJourneyType.order => 'Business prepares order',
    VanCustomerJourneyType.preOrder => 'Business prepares Pre Order',
  };

  List<String> get _routes => [
    for (final start in allowedStarts)
      for (final end in allowedEnds)
        '${start == VanStartHandover.customerDropsOff ? 'Customer drops off' : 'Business collects'} → $_workLabel → ${end == VanEndHandover.customerCollects ? 'Customer collects' : 'Business returns'}',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF111E31).withValues(alpha: .94),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: colour.withValues(alpha: .45)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_tree_outlined, color: Colors.white70),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live journey preview',
                softWrap: true,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_routes.isEmpty)
          Text(
            'Choose at least one start and end option to preview the customer journey.',
            style: TextStyle(color: Colors.white.withValues(alpha: .62)),
          )
        else
          for (var index = 0; index < _routes.length; index++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colour.withValues(alpha: .22)),
              ),
              child: Text(
                _routes[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (index < _routes.length - 1) const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

class _HandoverCapabilityTile extends StatelessWidget {
  const _HandoverCapabilityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? const Color(0xFF66D6B5).withValues(alpha: .1)
        : Colors.white.withValues(alpha: .04),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected
            ? const Color(0xFF66D6B5)
            : Colors.white.withValues(alpha: .11),
      ),
    ),
    child: CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value == true),
      secondary: Icon(
        icon,
        color: selected ? const Color(0xFF66D6B5) : Colors.white60,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: .58)),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    ),
  );
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? const Color(0xFF66D6B5).withValues(alpha: .13)
              : Colors.white.withValues(alpha: .045),
          border: Border.all(
            color: selected
                ? const Color(0xFF66D6B5)
                : Colors.white.withValues(alpha: .12),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? const Color(0xFF66D6B5) : Colors.white70,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF66D6B5)),
          ],
        ),
      ),
    ),
  );
}

class _ServicePreviewCard extends StatelessWidget {
  const _ServicePreviewCard({
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.colour,
  });
  final String name, description, category;
  final IconData icon;
  final Color colour;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [colour.withValues(alpha: .3), colour.withValues(alpha: .08)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colour.withValues(alpha: .55)),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.trim().isEmpty ? 'Your service' : name.trim(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                category,
                style: TextStyle(color: colour, fontWeight: FontWeight.w800),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: .68)),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.colour,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: selected ? colour : Colors.white.withValues(alpha: .06),
        border: Border.all(
          color: selected ? colour : Colors.white.withValues(alpha: .12),
        ),
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

class _ColourChoice extends StatelessWidget {
  const _ColourChoice({
    required this.colour,
    required this.selected,
    required this.onTap,
  });
  final Color colour;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colour,
        border: Border.all(color: Colors.white, width: selected ? 3 : 0),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : null,
    ),
  );
}

// ignore: unused_element
class _CompactToggle extends StatelessWidget {
  const _CompactToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    secondary: Icon(icon, color: Colors.white70),
    value: value,
    onChanged: onChanged,
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: Colors.white.withValues(alpha: .58)),
    ),
  );
}

// ignore: unused_element
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.optional,
    required this.onOptionalChanged,
    required this.onEdit,
    required this.onRemove,
  });
  final VanCustomJobQuestion question;
  final bool optional;
  final ValueChanged<bool> onOptionalChanged;
  final VoidCallback onEdit, onRemove;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white.withValues(alpha: .055),
    margin: const EdgeInsets.only(bottom: 9),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.drag_handle_rounded, color: Colors.white38),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${question.answerType.label} · ${optional ? 'Optional' : 'Required'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            iconColor: Colors.white70,
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'remove') {
                onRemove();
              } else {
                onOptionalChanged(value == 'optional');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: optional ? 'required' : 'optional',
                child: Text(optional ? 'Make required' : 'Make optional'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit question')),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.extra,
    required this.onChanged,
    required this.onEdit,
  });
  final VanQuoteExtraDefault extra;
  final ValueChanged<bool> onChanged;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF66D6B5).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.payments_outlined, color: Color(0xFF66D6B5)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                extra.resolvedLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '£${extra.defaultPrice.toStringAsFixed(extra.defaultPrice == extra.defaultPrice.roundToDouble() ? 0 : 2)}',
                style: TextStyle(color: Colors.white.withValues(alpha: .62)),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onEdit, child: const Text('Edit')),
        Switch.adaptive(value: extra.enabled, onChanged: onChanged),
      ],
    ),
  );
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.minutes,
    required this.onTap,
  });
  final String label;
  final int minutes;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: vanMateFieldDecoration(
        label: label,
        prefixIcon: const Icon(Icons.schedule_outlined),
      ),
      child: Text(
        _formatMinutes(minutes),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.service, required this.icon});
  final VanJobService service;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Color(service.colorValue).withValues(alpha: .15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Color(service.colorValue).withValues(alpha: .5),
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Color(service.colorValue),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${service.category} · Ready to publish',
                style: TextStyle(color: Colors.white.withValues(alpha: .65)),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle, color: Color(0xFF66D6B5)),
      ],
    ),
  );
}

class _BusinessServiceReviewCard extends StatelessWidget {
  const _BusinessServiceReviewCard({
    required this.setup,
    required this.handover,
    required this.extrasCount,
    required this.availability,
  });

  final VanRecommendedServiceSetup setup;
  final String handover;
  final int extrasCount;
  final String availability;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .11)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          setup.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          setup.description,
          style: TextStyle(color: Colors.white.withValues(alpha: .62)),
        ),
        const SizedBox(height: 8),
        _ReviewRow(
          icon: Icons.signpost_outlined,
          label: 'Journey',
          value: setup.journeyType.selectorLabel,
          onEdit: null,
        ),
        _ReviewRow(
          icon: Icons.alt_route_rounded,
          label: 'Handover',
          value: handover,
          onEdit: null,
        ),
        _ReviewRow(
          icon: Icons.payments_outlined,
          label: 'Pricing extras',
          value: '$extrasCount enabled',
          onEdit: null,
        ),
        _ReviewRow(
          icon: Icons.schedule_outlined,
          label: 'Availability',
          value: availability,
          onEdit: null,
        ),
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
    leading: Icon(icon, color: Colors.white70),
    title: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      value,
      style: TextStyle(color: Colors.white.withValues(alpha: .62)),
    ),
    trailing: onEdit == null
        ? null
        : TextButton(onPressed: onEdit, child: const Text('Edit')),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
  );
}

class _EmptyWizardCard extends StatelessWidget {
  const _EmptyWizardCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white54),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuestionLibraryItem {
  const _QuestionLibraryItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.answerType,
    required this.category,
  }) : builtIn = false;

  const _QuestionLibraryItem.builtIn({
    required this.key,
    required this.label,
    required this.icon,
  }) : builtIn = true,
       answerType = VanCustomQuestionAnswerType.shortText,
       category = VanCustomQuestionCategory.jobDetails;

  final String key;
  final String label;
  final IconData icon;
  final bool builtIn;
  final VanCustomQuestionAnswerType answerType;
  final VanCustomQuestionCategory category;
}

const List<_QuestionLibraryItem> _customQuestionLibrary =
    <_QuestionLibraryItem>[];

class _ExtraLibraryItem {
  const _ExtraLibraryItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.defaultPrice,
    required this.units,
    required this.defaultUnit,
  });

  final String key;
  final String label;
  final IconData icon;
  final double defaultPrice;
  final List<String> units;
  final String defaultUnit;
}

const List<_ExtraLibraryItem> _defaultExtrasLibrary = <_ExtraLibraryItem>[];

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF66D6B5).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF66D6B5).withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, color: Color(0xFF66D6B5)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _BusinessChoice {
  const _BusinessChoice({required this.label, required this.pack});

  final String label;
  final VanStarterCapabilityPack pack;
}

class _BusinessBrowseCategory {
  const _BusinessBrowseCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.packs,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<VanStarterCapabilityPack> packs;
}

List<_BusinessChoice> _popularBusinessChoices() {
  return const <_BusinessChoice>[];
}

List<_BusinessBrowseCategory> _businessBrowseCategories() {
  final grouped = <String, List<VanStarterCapabilityPack>>{};
  for (final pack in kVanStarterCapabilityPacks) {
    grouped.putIfAbsent(pack.category, () => []).add(pack);
  }
  return <_BusinessBrowseCategory>[
    for (final entry in grouped.entries)
      _BusinessBrowseCategory(
        id: entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        title: entry.key,
        icon: Icons.business_center_outlined,
        packs: entry.value
          ..sort((left, right) => left.name.compareTo(right.name)),
      ),
  ];
}

class _BusinessShortcutSection extends StatelessWidget {
  const _BusinessShortcutSection({
    required this.title,
    required this.icon,
    required this.choices,
    required this.onSelected,
  });

  final String title;
  final IconData icon;
  final List<_BusinessChoice> choices;
  final ValueChanged<VanStarterCapabilityPack> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFFC65C)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in choices)
            ActionChip(
              onPressed: () => onSelected(choice.pack),
              avatar: Icon(
                Icons.business_center_outlined,
                size: 17,
                color: Color(choice.pack.colorValue),
              ),
              label: Text(choice.label),
              backgroundColor: Colors.white.withValues(alpha: .07),
              side: BorderSide(color: Colors.white.withValues(alpha: .13)),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ],
  );
}

class _BusinessResultList extends StatelessWidget {
  const _BusinessResultList({required this.results, required this.onSelected});

  final List<VanBusinessSearchResult> results;
  final ValueChanged<VanStarterCapabilityPack> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Column(
      children: [
        for (var index = 0; index < results.length; index++) ...[
          if (index > 0)
            Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
          _BusinessResultTile(
            label: results[index].label,
            pack: results[index].pack,
            onSelected: onSelected,
          ),
        ],
      ],
    ),
  );
}

class _BusinessResultTile extends StatelessWidget {
  const _BusinessResultTile({
    required this.label,
    required this.pack,
    required this.onSelected,
  });

  final String label;
  final VanStarterCapabilityPack pack;
  final ValueChanged<VanStarterCapabilityPack> onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onSelected(pack),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: Color(pack.colorValue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (label != pack.name)
                  Text(
                    'Recommended starting point: ${pack.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .52),
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54),
        ],
      ),
    ),
  );
}

class _BusinessCategoryCard extends StatelessWidget {
  const _BusinessCategoryCard({
    required this.category,
    required this.expanded,
    required this.onToggle,
    required this.onSelected,
  });

  final _BusinessBrowseCategory category;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<VanStarterCapabilityPack> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .04),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .11)),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(category.icon, size: 20, color: const Color(0xFF91E8CE)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${category.packs.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .42),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: Colors.white.withValues(alpha: .09)),
          for (final pack in category.packs)
            _BusinessResultTile(
              label: pack.name,
              pack: pack,
              onSelected: onSelected,
            ),
        ],
      ],
    ),
  );
}

class _EmptyBusinessSearch extends StatelessWidget {
  const _EmptyBusinessSearch();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Column(
      children: [
        const Text(
          "Can't find your business?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Try a shorter search, a related business name, or clear the search to browse categories.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .6)),
        ),
      ],
    ),
  );
}

class _RecommendedServiceSelectionCard extends StatelessWidget {
  const _RecommendedServiceSelectionCard({
    required this.pack,
    required this.selectedIds,
    required this.saving,
    required this.onChanged,
    required this.onContinue,
    required this.onChooseDifferent,
  });

  final VanStarterCapabilityPack pack;
  final Set<String> selectedIds;
  final bool saving;
  final void Function(String serviceId, bool selected) onChanged;
  final VoidCallback onContinue;
  final VoidCallback onChooseDifferent;

  @override
  Widget build(BuildContext context) {
    final services = pack.serviceRecommendations;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(pack.colorValue).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(pack.colorValue).withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Which services do you offer?',
            style: TextStyle(
              color: Color(0xFF91E8CE),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose what you provide and Business Mate will build each service for you.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          for (final service in services) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.white.withValues(alpha: .045),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selectedIds.contains(service.id)
                        ? Color(pack.colorValue).withValues(alpha: .52)
                        : Colors.white.withValues(alpha: .09),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CheckboxListTile(
                  value: selectedIds.contains(service.id),
                  onChanged: saving
                      ? null
                      : (value) => onChanged(service.id, value == true),
                  activeColor: Color(pack.colorValue),
                  checkColor: const Color(0xFF0B1728),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  title: Text(
                    service.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(
                        service.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .58),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            '${selectedIds.length} service${selectedIds.length == 1 ? '' : 's'} selected',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving || selectedIds.isEmpty ? null : onContinue,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Review Business'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : onChooseDifferent,
              child: const Text('Choose a different business type'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCapabilitiesCard extends StatelessWidget {
  const _ServiceCapabilitiesCard({
    required this.pack,
    required this.selectedServiceIds,
    required this.capabilityIdsByService,
    required this.saving,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
    required this.onChooseDifferent,
  });

  final VanStarterCapabilityPack pack;
  final Set<String> selectedServiceIds;
  final Map<String, Set<String>> capabilityIdsByService;
  final bool saving;
  final void Function(String serviceId, String capabilityId, bool selected)
  onChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onChooseDifferent;

  @override
  Widget build(BuildContext context) {
    final services = pack.serviceRecommendations
        .where((service) => selectedServiceIds.contains(service.id))
        .toList(growable: false);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(pack.colorValue).withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(pack.colorValue).withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Capabilities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose how each service works. Business Mate will turn these choices into the customer journey, booking settings, questions and pricing behaviour.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          for (final service in services) ...[
            _ServiceCapabilityEditor(
              service: service,
              selectedIds:
                  capabilityIdsByService[service.id] ??
                  service.recommendedCapabilityIds.toSet(),
              colour: Color(pack.colorValue),
              enabled: !saving,
              onChanged: (capabilityId, selected) =>
                  onChanged(service.id, capabilityId, selected),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onContinue,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Choose Pricing Extras'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Change Selected Services'),
            ),
          ),
          TextButton(
            onPressed: saving ? null : onChooseDifferent,
            child: const Text('Choose a different business type'),
          ),
        ],
      ),
    );
  }
}

class _ServiceCapabilityEditor extends StatelessWidget {
  const _ServiceCapabilityEditor({
    required this.service,
    required this.selectedIds,
    required this.colour,
    required this.enabled,
    required this.onChanged,
  });

  final VanBusinessServiceRecommendation service;
  final Set<String> selectedIds;
  final Color colour;
  final bool enabled;
  final void Function(String capabilityId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .045),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: .11)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      initiallyExpanded: true,
      iconColor: colour,
      collapsedIconColor: Colors.white70,
      title: Text(
        service.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        '${selectedIds.length} capabilities enabled',
        style: TextStyle(color: Colors.white.withValues(alpha: .58)),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      children: [
        for (final group in VanServiceCapabilityGroup.values) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 7),
              child: Text(
                group.label,
                style: TextStyle(
                  color: colour,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final capability in kVanServiceCapabilities)
                if (capability.group == group)
                  FilterChip(
                    selected: selectedIds.contains(capability.id),
                    onSelected: enabled
                        ? (selected) => onChanged(capability.id, selected)
                        : null,
                    label: Text(capability.label),
                    tooltip: capability.description,
                    selectedColor: colour.withValues(alpha: .25),
                    backgroundColor: Colors.white.withValues(alpha: .05),
                    side: BorderSide(
                      color: selectedIds.contains(capability.id)
                          ? colour
                          : Colors.white.withValues(alpha: .12),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _CreationSourceBanner extends StatelessWidget {
  const _CreationSourceBanner({
    required this.title,
    required this.subtitle,
    required this.onChange,
  });

  final String title;
  final String subtitle;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.white.withValues(alpha: .11)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF66D6B5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: .6)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton(onPressed: onChange, child: const Text('Change')),
      ],
    ),
  );
}

class _QuestionSectionHeading extends StatelessWidget {
  const _QuestionSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: .58)),
        ),
      ],
    ),
  );
}

class _SelectedQuestionsSummary extends StatelessWidget {
  const _SelectedQuestionsSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF66D6B5).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF66D6B5).withValues(alpha: .28)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF66D6B5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected Questions',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$count ${count == 1 ? 'question' : 'questions'} selected',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _LibraryChoiceCard extends StatelessWidget {
  const _LibraryChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF66D6B5).withValues(alpha: .11)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? const Color(0xFF66D6B5)
                : Colors.white.withValues(alpha: .11),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF66D6B5) : Colors.white60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value == true),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BuiltInQuestionConfigCard extends StatelessWidget {
  const _BuiltInQuestionConfigCard({
    required this.item,
    required this.requiredValue,
    required this.helperText,
    required this.maxPhotos,
    required this.onRequiredChanged,
    required this.onHelperChanged,
    this.onMaxPhotosChanged,
  });
  final _QuestionLibraryItem item;
  final bool requiredValue;
  final String helperText;
  final int maxPhotos;
  final ValueChanged<bool> onRequiredChanged;
  final ValueChanged<String> onHelperChanged;
  final ValueChanged<int>? onMaxPhotosChanged;

  @override
  Widget build(BuildContext context) => _ConfigCard(
    icon: item.icon,
    title: item.label,
    children: [
      if (item.key != 'exact_pin')
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: requiredValue,
          onChanged: onRequiredChanged,
          title: Text(
            requiredValue ? 'Required' : 'Optional',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      if (onMaxPhotosChanged != null)
        DropdownButtonFormField<int>(
          initialValue: maxPhotos,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Maximum number of photos'),
          items: [
            for (final value in const [1, 2, 3, 4, 5])
              DropdownMenuItem(value: value, child: Text('$value photos')),
          ],
          onChanged: (value) {
            if (value != null) onMaxPhotosChanged!(value);
          },
        ),
      if (onMaxPhotosChanged != null) const SizedBox(height: 10),
      TextFormField(
        initialValue: helperText,
        maxLines: 2,
        onChanged: onHelperChanged,
        decoration: vanMateFieldDecoration(
          label: 'Helper text',
          hintText: 'Optional guidance for the customer',
        ),
      ),
    ],
  );
}

class _CustomQuestionConfigCard extends StatelessWidget {
  const _CustomQuestionConfigCard({
    required this.question,
    required this.requiredValue,
    required this.showUnit,
    required this.onRequiredChanged,
    required this.onHelperChanged,
    required this.onUnitChanged,
    required this.onEdit,
  });
  final VanCustomJobQuestion question;
  final bool requiredValue;
  final bool showUnit;
  final ValueChanged<bool> onRequiredChanged;
  final ValueChanged<String> onHelperChanged;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _ConfigCard(
    icon: Icons.question_answer_outlined,
    title: question.questionText,
    trailing: TextButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Question & type'),
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Answer type: ${question.answerType.label}',
          style: TextStyle(color: Colors.white.withValues(alpha: .62)),
        ),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: requiredValue,
        onChanged: onRequiredChanged,
        title: Text(
          requiredValue ? 'Required' : 'Optional',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      if (showUnit) ...[
        DropdownButtonFormField<String>(
          initialValue: null,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Unit'),
          items: const [
            DropdownMenuItem(value: 'cm', child: Text('Centimetres (cm)')),
            DropdownMenuItem(value: 'mm', child: Text('Millimetres (mm)')),
            DropdownMenuItem(value: 'inches', child: Text('Inches')),
          ],
          onChanged: (value) => onUnitChanged(value ?? ''),
        ),
        const SizedBox(height: 10),
      ],
      TextFormField(
        initialValue: question.helperText,
        maxLines: 2,
        onChanged: onHelperChanged,
        decoration: vanMateFieldDecoration(
          label: 'Helper text',
          hintText: 'Optional guidance for the customer',
        ),
      ),
    ],
  );
}

class _FixedPriceAmountCard extends StatelessWidget {
  const _FixedPriceAmountCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _ConfigCard(
      icon: Icons.price_check_outlined,
      title: 'Fixed service price',
      children: [
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: vanMateFieldDecoration(
            label: 'Fixed price',
            hintText: '50.00',
            prefixText: '\u00A3',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customers will see this as the set service price. Extras can still be added on top where you use them.',
          style: TextStyle(color: Colors.white.withValues(alpha: .62)),
        ),
      ],
    );
  }
}

class _FromPriceAmountCard extends StatelessWidget {
  const _FromPriceAmountCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _ConfigCard(
      icon: Icons.price_change_outlined,
      title: 'Starting price',
      children: [
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: vanMateFieldDecoration(
            label: 'From price',
            hintText: '50.00',
            prefixText: '\u00A3',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customers will see this as the starting price. The final quoted amount may vary once you review the details.',
          style: TextStyle(color: Colors.white.withValues(alpha: .62)),
        ),
      ],
    );
  }
}

class _ExtraConfigurationCard extends StatelessWidget {
  const _ExtraConfigurationCard({
    super.key,
    required this.extra,
    required this.unit,
    required this.units,
    required this.onPriceChanged,
    required this.onUnitChanged,
    required this.onEnabledChanged,
  });
  final VanQuoteExtraDefault extra;
  final String unit;
  final List<String> units;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final uniqueUnits = <String>{
      for (final value in units)
        if (value.trim().isNotEmpty) value.trim(),
    }.toList(growable: true);
    if (uniqueUnits.isEmpty) uniqueUnits.add('Fixed');
    final selectedUnit = uniqueUnits.contains(unit) ? unit : uniqueUnits.first;
    return _ConfigCard(
      icon: Icons.payments_outlined,
      title: extra.resolvedLabel,
      children: [
        TextFormField(
          initialValue: extra.defaultPrice.toStringAsFixed(
            extra.defaultPrice == extra.defaultPrice.roundToDouble() ? 0 : 2,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onPriceChanged,
          decoration: vanMateFieldDecoration(label: 'Price', prefixText: '£'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedUnit,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(label: 'Charge per'),
          items: [
            for (final value in uniqueUnits)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) {
            if (value != null) onUnitChanged(value);
          },
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: extra.enabled,
          onChanged: onEnabledChanged,
          title: const Text('Enabled', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Material(
      color: Colors.white.withValues(alpha: .045),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: .11)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF66D6B5)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.onComplete});
  final VoidCallback onComplete;
  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => ready = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: ready
                  ? const Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey('ready'),
                      size: 58,
                      color: Color(0xFF38C895),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      key: ValueKey('building'),
                      size: 58,
                      color: Color(0xFFFFC857),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              ready ? 'Service Ready' : 'Building your service…',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ),
  );
}
