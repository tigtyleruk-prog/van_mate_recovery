import 'dart:async';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_customer_journey.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_handover.dart';
import '../pages/van_booking_link_page.dart';
import '../pages/van_service_question_editor_page.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_job_services_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_quote_extra_defaults_sheet.dart';

class VanServiceWizardPage extends StatefulWidget {
  const VanServiceWizardPage({
    super.key,
    this.initialService,
    this.duplicateFrom,
    this.suggestedName,
  });

  final VanJobService? initialService;
  final VanJobService? duplicateFrom;
  final String? suggestedName;

  @override
  State<VanServiceWizardPage> createState() => _VanServiceWizardPageState();
}

class _VanServiceWizardPageState extends State<VanServiceWizardPage> {
  static const _stepTitles = <String>[
    'Basic information',
    'Customer journey',
    'Service flow',
    'Customer questions',
    'Pricing',
    'Availability',
    'Review',
  ];
  static const _categories = <String>[
    'General',
    'Home & property',
    'Transport & delivery',
    'Pets',
    'Beauty & wellbeing',
    'Repairs & maintenance',
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
  late final String _serviceId;
  late String _category;
  late String _iconKey;
  late int _colourValue;
  late VanCustomerJourneyType _journey;
  late VanCustomerRequestType _requestType;
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
  final Map<String, VanCustomJobQuestion> _questions = {};
  final List<String> _linkedQuestionIds = [];
  final Set<String> _optionalQuestionIds = {};
  bool _isActive = true;
  bool _requestPhotos = false;
  bool _requireAddress = true;
  bool _requestExactPin = true;
  int _step = 0;
  bool _saving = false;
  bool _loadingQuestions = true;

  VanJobService? get _source => widget.initialService ?? widget.duplicateFrom;
  bool get _isEditing => widget.initialService != null;
  bool get _isDuplicating => widget.duplicateFrom != null;

  @override
  void initState() {
    super.initState();
    final source = _source;
    final now = DateTime.now();
    _serviceId = _isEditing
        ? source!.id
        : 'service_${now.microsecondsSinceEpoch}';
    _nameController = TextEditingController(
      text: _isDuplicating
          ? ''
          : (source?.isDraft == true && source?.name == 'Untitled service')
          ? ''
          : source?.name ?? widget.suggestedName ?? '',
    );
    _descriptionController = TextEditingController(
      text: source?.description ?? '',
    );
    _dropOffController = TextEditingController(
      text: source?.businessDropOffInstructions ?? '',
    );
    _collectionController = TextEditingController(
      text: source?.businessCollectionInstructions ?? '',
    );
    _category = source?.category ?? 'General';
    _iconKey = source?.iconKey ?? 'work';
    _colourValue = source?.colorValue ?? _colourOptions.first;
    _journey =
        source?.customerJourneyType ??
        defaultVanCustomerJourneyTypeForService(
          serviceId: '',
          serviceName: widget.suggestedName ?? '',
        );
    _requestType =
        source?.requestType ??
        defaultVanServiceFlowForService(
          serviceId: '',
          serviceName: widget.suggestedName ?? '',
        ).requestType;
    final handover =
        source?.effectiveHandover ??
        VanServiceHandoverConfig.resolve(requestType: _requestType);
    _startHandover = handover.start;
    _endHandover = handover.end;
    _allowedStarts = handover.allowedStarts;
    _allowedEnds = handover.allowedEnds;
    _extras =
        source?.quoteExtraDefaults ??
        VanQuoteExtraDefaults.starterForServiceName(widget.suggestedName ?? '');
    _workingDays = {...?source?.workingDays};
    if (_workingDays.isEmpty) _workingDays.addAll(const [1, 2, 3, 4, 5]);
    _startMinutes = source?.businessStartMinutes ?? 9 * 60;
    _endMinutes = source?.businessEndMinutes ?? 17 * 60;
    _noticeHours = source?.noticeHours ?? 24;
    _maxBookings = source?.maxBookingsPerDay ?? 8;
    _isActive = source?.isActive ?? true;
    _requestPhotos = source?.requestPhotos ?? false;
    _requireAddress = source?.requireAddress ?? true;
    _requestExactPin = source?.requestExactPinAfterQuoteAccepted ?? true;
    _optionalQuestionIds.addAll(source?.optionalQuestionIds ?? const []);
    _nameController.addListener(_refreshPreview);
    _descriptionController.addListener(_refreshPreview);
    unawaited(_loadQuestions());
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
        _linkedQuestionIds.add(id);
        if (_source!.optionalQuestionIds.contains(original.id)) {
          _optionalQuestionIds.add(id);
        }
      }
    } else {
      _questions.addAll(lookup);
      _linkedQuestionIds.addAll(sourceIds.where(lookup.containsKey));
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
    super.dispose();
  }

  VanJobService _buildService({required bool isDraft}) {
    final source = _source;
    final now = DateTime.now();
    final cleanName = sanitizeVanText(_nameController.text).trim();
    final flowOptions =
        source != null && source.serviceFlow == _requestType.serviceFlow
        ? source.requestFlowOptions
        : VanCustomerRequestFlowOptions.defaultsFor(_requestType);
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

  Future<void> _publish() async {
    if (_saving || !_validateStep(0) || !_validateStep(5)) return;
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
    if (step == 0 && sanitizeVanText(_nameController.text).trim().isEmpty) {
      message = 'Add a service name before continuing.';
    } else if (step == 5 && _workingDays.isEmpty) {
      message = 'Choose at least one working day.';
    } else if (step == 5 && _endMinutes <= _startMinutes) {
      message = 'Closing time must be later than opening time.';
    }
    if (message == null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step < _stepTitles.length - 1) setState(() => _step++);
  }

  void _previous() {
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

  Future<void> _showQuestionTemplates() async {
    final templates = _questionTemplates();
    final selected = await showModalBottomSheet<_QuestionTemplate>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Text(
              'Question templates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('Choose a useful starting question. You can edit it.'),
            const SizedBox(height: 10),
            for (final template in templates)
              ListTile(
                leading: Icon(template.icon),
                title: Text(template.text),
                subtitle: Text(template.answerType.label),
                onTap: () => Navigator.of(sheetContext).pop(template),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final now = DateTime.now();
    final id = 'service_question_${_serviceId}_${now.microsecondsSinceEpoch}';
    setState(() {
      _questions[id] = VanCustomJobQuestion(
        id: id,
        questionText: selected.text,
        helperText: '',
        answerType: selected.answerType,
        category: selected.category,
        isActive: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      _linkedQuestionIds.add(id);
    });
  }

  List<_QuestionTemplate> _questionTemplates() {
    final name = _nameController.text.toLowerCase();
    if (name.contains('dog') || name.contains('pet') || _category == 'Pets') {
      return const [
        _QuestionTemplate('Pet name', Icons.pets_outlined),
        _QuestionTemplate('Breed', Icons.badge_outlined),
        _QuestionTemplate(
          'Behaviour or handling notes',
          Icons.notes_outlined,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
        _QuestionTemplate(
          'Medical notes',
          Icons.medical_information_outlined,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ];
    }
    if (_requestType.serviceFlow == VanServiceFlow.pickupDelivery ||
        name.contains('courier')) {
      return const [
        _QuestionTemplate('Parcel size', Icons.inventory_2_outlined),
        _QuestionTemplate('Approximate weight', Icons.scale_outlined),
        _QuestionTemplate(
          'Delivery instructions',
          Icons.notes_outlined,
          answerType: VanCustomQuestionAnswerType.longText,
        ),
      ];
    }
    return const [
      _QuestionTemplate('Property type', Icons.home_outlined),
      _QuestionTemplate(
        'Is there easy access?',
        Icons.door_front_door_outlined,
        answerType: VanCustomQuestionAnswerType.yesNo,
        category: VanCustomQuestionCategory.access,
      ),
      _QuestionTemplate(
        'Parking details',
        Icons.local_parking_outlined,
        answerType: VanCustomQuestionAnswerType.longText,
        category: VanCustomQuestionCategory.parking,
      ),
      _QuestionTemplate(
        'Anything else we should know?',
        Icons.notes_outlined,
        answerType: VanCustomQuestionAnswerType.longText,
      ),
    ];
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

  void _selectFlow(VanServiceFlow flow) {
    final defaults = VanServiceHandoverConfig.resolve(
      requestType: flow.requestType,
    );
    setState(() {
      _requestType = flow.requestType;
      _requireAddress = flow == VanServiceFlow.standard;
      _startHandover = defaults.start;
      _endHandover = defaults.end;
      _allowedStarts = defaults.allowedStarts;
      _allowedEnds = defaults.allowedEnds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
          title: Text(_isEditing ? 'Edit Service' : 'Create Service'),
          leadingWidth: 96,
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: VanBackBusinessHubButtons(onBack: _cancel),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _saveDraft,
              child: const Text('Save Draft'),
            ),
            const SizedBox(width: 8),
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
                  _WizardProgress(step: _step, titles: _stepTitles),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final editor = _WizardPanel(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: _buildStep(),
                            ),
                          ),
                        );
                        final preview = _LiveJourneyPreview(
                          journey: _journey,
                          flow: _requestType.serviceFlow,
                          colour: Color(_colourValue),
                        );
                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            bottomInset + 110,
                          ),
                          children: wide
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
                              : [editor, const SizedBox(height: 12), preview],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _WizardNavigation(
                step: _step,
                saving: _saving,
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
    3 => _buildQuestions(),
    4 => _buildPricing(),
    5 => _buildAvailability(),
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
          initialValue: _category,
          dropdownColor: const Color(0xFF17253A),
          decoration: vanMateFieldDecoration(
            label: 'Category',
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          items: [
            for (final value in _categories)
              DropdownMenuItem(value: value, child: Text(value)),
          ],
          onChanged: (value) => setState(() => _category = value ?? _category),
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
          title: 'Order',
          description:
              'Customer places an order. You prepare it for collection or delivery.',
          selected: _journey == VanCustomerJourneyType.order,
          onTap: () => setState(() => _journey = VanCustomerJourneyType.order),
        ),
      ],
    );
  }

  Widget _buildFlow() {
    final flow = _requestType.serviceFlow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How is this service carried out?',
          'This automatically adjusts wording, addresses and handovers.',
        ),
        _SelectionCard(
          icon: Icons.handyman_outlined,
          title: 'Standard',
          description: 'The business performs the service at one location.',
          selected: flow == VanServiceFlow.standard,
          onTap: () => _selectFlow(VanServiceFlow.standard),
        ),
        const SizedBox(height: 10),
        _SelectionCard(
          icon: Icons.local_shipping_outlined,
          title: 'Pickup & Delivery',
          description: 'Collect the item, complete the work, then return it.',
          selected: flow == VanServiceFlow.pickupDelivery,
          onTap: () => _selectFlow(VanServiceFlow.pickupDelivery),
        ),
        const SizedBox(height: 10),
        _SelectionCard(
          icon: Icons.store_mall_directory_outlined,
          title: 'Drop-off & Collection',
          description:
              'The customer drops off, then collects when work is done.',
          selected: flow == VanServiceFlow.dropOffPickup,
          onTap: () => _selectFlow(VanServiceFlow.dropOffPickup),
        ),
        if (vanRequestTypeSupportsHandover(_requestType)) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<VanStartHandover>(
                  initialValue: _startHandover,
                  dropdownColor: const Color(0xFF17253A),
                  decoration: vanMateFieldDecoration(label: 'Service starts'),
                  items: [
                    for (final value in VanStartHandover.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) => setState(() {
                    _startHandover = value ?? _startHandover;
                    if (!_allowedStarts.contains(_startHandover)) {
                      _allowedStarts = [..._allowedStarts, _startHandover];
                    }
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<VanEndHandover>(
                  initialValue: _endHandover,
                  dropdownColor: const Color(0xFF17253A),
                  decoration: vanMateFieldDecoration(label: 'Service ends'),
                  items: [
                    for (final value in VanEndHandover.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) => setState(() {
                    _endHandover = value ?? _endHandover;
                    if (!_allowedEnds.contains(_endHandover)) {
                      _allowedEnds = [..._allowedEnds, _endHandover];
                    }
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dropOffController,
            maxLines: 2,
            decoration: vanMateFieldDecoration(
              label: 'Drop-off instructions',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _collectionController,
            maxLines: 2,
            decoration: vanMateFieldDecoration(
              label: 'Collection instructions',
              hintText: 'Optional',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'What do you need from the customer?',
          'Only ask what helps you understand and complete this service.',
        ),
        _CompactToggle(
          icon: Icons.location_on_outlined,
          title: 'Address',
          subtitle: 'Ask where the service takes place.',
          value: _requireAddress,
          onChanged: (value) => setState(() => _requireAddress = value),
        ),
        _CompactToggle(
          icon: Icons.add_a_photo_outlined,
          title: 'Photos',
          subtitle: 'Let customers add useful images.',
          value: _requestPhotos,
          onChanged: (value) => setState(() => _requestPhotos = value),
        ),
        _CompactToggle(
          icon: Icons.pin_drop_outlined,
          title: 'Exact pin after acceptance',
          subtitle: 'Request a precise location once the work is agreed.',
          value: _requestExactPin,
          onChanged: (value) => setState(() => _requestExactPin = value),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: _FieldLabel('Your questions')),
            TextButton.icon(
              onPressed: _showQuestionTemplates,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Templates'),
            ),
            TextButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (_loadingQuestions)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_linkedQuestionIds.isEmpty)
          const _EmptyWizardCard(
            icon: Icons.question_answer_outlined,
            text: 'No extra questions yet. Use a template or add your own.',
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _linkedQuestionIds.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final id = _linkedQuestionIds.removeAt(oldIndex);
                _linkedQuestionIds.insert(newIndex, id);
              });
            },
            itemBuilder: (context, index) {
              final id = _linkedQuestionIds[index];
              final question = _questions[id]!;
              final optional = _optionalQuestionIds.contains(id);
              return _QuestionCard(
                key: ValueKey(id),
                question: question,
                optional: optional,
                onOptionalChanged: (value) => setState(() {
                  value
                      ? _optionalQuestionIds.add(id)
                      : _optionalQuestionIds.remove(id);
                }),
                onEdit: () => _editQuestion(id),
                onRemove: () => setState(() {
                  _linkedQuestionIds.remove(id);
                  _optionalQuestionIds.remove(id);
                }),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPricing() {
    final extras = _extras.orderedExtras;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'How will you price extras?',
          'Keep this simple. Enable only the charges you use regularly.',
        ),
        if (extras.isEmpty)
          const _EmptyWizardCard(
            icon: Icons.payments_outlined,
            text:
                'No pricing extras yet. Add one only if this service needs it.',
          )
        else
          for (final extra in extras) ...[
            _PricingCard(
              extra: extra,
              onChanged: (value) => setState(() {
                _extras = _extras.copyWithExtra(extra.copyWith(enabled: value));
              }),
              onEdit: _editExtras,
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _editExtras,
          icon: const Icon(Icons.tune_rounded),
          label: Text(
            extras.isEmpty ? 'Add pricing extras' : 'Manage pricing extras',
          ),
        ),
      ],
    );
  }

  Widget _buildAvailability() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'When is this service available?',
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
          initialValue: _noticeHours,
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
          label: 'Flow',
          value: _requestType.serviceFlow.label,
          onEdit: () => setState(() => _step = 2),
        ),
        _ReviewRow(
          icon: Icons.question_answer_outlined,
          label: 'Questions',
          value: '${_linkedQuestionIds.length} custom questions',
          onEdit: () => setState(() => _step = 3),
        ),
        _ReviewRow(
          icon: Icons.payments_outlined,
          label: 'Pricing extras',
          value: '${_extras.enabledExtras.length} enabled',
          onEdit: () => setState(() => _step = 4),
        ),
        _ReviewRow(
          icon: Icons.schedule_outlined,
          label: 'Availability',
          value:
              '${_workingDaysLabel()} · ${_formatMinutes(_startMinutes)}–${_formatMinutes(_endMinutes)}',
          onEdit: () => setState(() => _step = 5),
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
          title: const Text(
            'Publish as active',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Customers can choose this service immediately.',
            style: TextStyle(color: Colors.white.withValues(alpha: .62)),
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
            Text(
              'Step ${step + 1} of ${titles.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              titles[step],
              style: TextStyle(color: Colors.white.withValues(alpha: .68)),
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
    required this.saving,
    required this.onPrevious,
    required this.onNext,
    required this.onPublish,
    required this.onSaveDraft,
    required this.onCancel,
  });
  final int step;
  final bool saving;
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
      child: Row(
        children: [
          IconButton(
            onPressed: saving ? null : onCancel,
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
          ),
          if (step > 0)
            OutlinedButton.icon(
              onPressed: saving ? null : onPrevious,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
          const Spacer(),
          if (step < 6)
            FilledButton.icon(
              onPressed: saving ? null : onNext,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            )
          else
            FilledButton.icon(
              onPressed: saving ? null : onPublish,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch_outlined),
              label: const Text('Publish'),
            ),
        ],
      ),
    ),
  );
}

class _LiveJourneyPreview extends StatelessWidget {
  const _LiveJourneyPreview({
    required this.journey,
    required this.flow,
    required this.colour,
  });
  final VanCustomerJourneyType journey;
  final VanServiceFlow flow;
  final Color colour;
  List<String> get _steps {
    final start = switch (journey) {
      VanCustomerJourneyType.quote => [
        'Customer',
        'Quote request',
        'Business review',
        'Quote sent',
        'Accepted',
      ],
      VanCustomerJourneyType.booking => [
        'Customer',
        'Booking request',
        'Business confirms',
      ],
      VanCustomerJourneyType.order => [
        'Customer',
        'Order placed',
        'Business prepares',
      ],
    };
    final fulfilment = switch (flow) {
      VanServiceFlow.standard => ['Service', 'Calendar', 'Invoice'],
      VanServiceFlow.pickupDelivery => [
        'Collect',
        'Complete work',
        'Return',
        'Invoice',
      ],
      VanServiceFlow.dropOffPickup => [
        'Drop-off',
        'Complete work',
        'Collection',
        'Invoice',
      ],
    };
    return [...start, ...fulfilment];
  }

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
            Text(
              'Live journey preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < _steps.length; index++) ...[
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  index == 0 ? Icons.person_outline : Icons.check_rounded,
                  size: 14,
                  color: colour,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _steps[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (index < _steps.length - 1)
            Container(
              margin: const EdgeInsets.only(left: 11),
              width: 2,
              height: 12,
              color: colour.withValues(alpha: .35),
            ),
        ],
      ],
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
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

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback onEdit;
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
    trailing: TextButton(onPressed: onEdit, child: const Text('Edit')),
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

class _QuestionTemplate {
  const _QuestionTemplate(
    this.text,
    this.icon, {
    this.answerType = VanCustomQuestionAnswerType.shortText,
    this.category,
  });
  final String text;
  final IconData icon;
  final VanCustomQuestionAnswerType answerType;
  final VanCustomQuestionCategory? category;
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
