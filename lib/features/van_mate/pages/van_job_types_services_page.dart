import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_template.dart';
import '../pages/van_service_question_editor_page.dart';
import '../services/van_business_hub_onboarding_storage.dart';
import '../services/van_business_profile_scope_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_job_services_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_quote_extra_defaults_sheet.dart';

Future<void> openVanJobTypesServicesPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanJobTypesServicesPage()),
  );
}

class VanJobTypesServicesPage extends StatefulWidget {
  const VanJobTypesServicesPage({super.key});

  @override
  State<VanJobTypesServicesPage> createState() =>
      _VanJobTypesServicesPageState();
}

class _VanJobTypesServicesPageState extends State<VanJobTypesServicesPage> {
  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;
  final VanCustomJobQuestionsStorage _questionsStorage =
      VanCustomJobQuestionsStorage.instance;
  final VanBusinessHubOnboardingStorage _onboardingStorage =
      VanBusinessHubOnboardingStorage.instance;
  List<VanJobService> _services = <VanJobService>[];
  bool _loading = true;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _storage.addListener(_handleStorageChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowOnboardingDialog());
    });
    unawaited(_loadServices());
  }

  @override
  void dispose() {
    _storage.removeListener(_handleStorageChange);
    super.dispose();
  }

  void _handleStorageChange() {
    unawaited(_loadServices(showLoader: false));
  }

  Future<void> _loadServices({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
      });
    }
    debugPrint('[JobTypesServicesPage] load start');
    var loaded = <VanJobService>[];
    try {
      loaded = await _storage.loadAll();
      debugPrint(
        '[JobTypesServicesPage] local services loaded count=${loaded.length}',
      );
      await _storage.loadFromCloud();
      loaded = await _storage.loadAll();
      debugPrint(
        '[JobTypesServicesPage] hydrated services loaded count=${loaded.length}',
      );
    } catch (error) {
      debugPrint('[JobTypesServicesPage] load error error=$error');
    } finally {
      if (mounted) {
        setState(() {
          _services = loaded
              .where((service) => !service.isArchived)
              .toList(growable: false);
          _loading = false;
        });
      }
    }
  }

  Future<void> _maybeShowOnboardingDialog() async {
    if (_checkedOnboarding) {
      return;
    }
    _checkedOnboarding = true;
    final shouldShow = await _onboardingStorage.shouldShowJobTypesOnboarding();
    if (!shouldShow || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How Job Types work'),
        content: const Text(
          'Add the services you offer, then choose which questions customers should answer for each service.\n\n'
          'Example:\n'
          'Gardening -> garden size, rear access, waste removal\n'
          'Man & Van -> stairs, lift, parking, item photos\n\n'
          'Set it up once, then your Booking Link can use it every time.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text("Don't show again"),
          ),
        ],
      ),
    );
    await _onboardingStorage.dismissJobTypesOnboarding();
  }

  Future<void> _openAddService({String? suggestedName}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VanJobServiceEditorPage(suggestedName: suggestedName),
      ),
    );
    if (changed == true) {
      await _loadServices(showLoader: false);
    }
  }

  Future<void> _addServiceFromTemplate(VanServiceTemplate template) async {
    final now = DateTime.now();
    final existingServices = await _storage.loadAll();
    final normalizedTemplateName = _normalizeServiceTemplateText(template.name);
    final duplicate = existingServices
        .where(
          (service) =>
              !service.isArchived &&
              _normalizeServiceTemplateText(service.name) ==
                  normalizedTemplateName,
        )
        .firstOrNull;
    if (duplicate != null) {
      await _openService(duplicate);
      return;
    }

    final existingQuestions = await _questionsStorage.loadAll();
    final nextQuestions = <VanCustomJobQuestion>[...existingQuestions];
    final linkedQuestionIds = <String>[];
    final requestType = defaultVanCustomerRequestTypeForService(
      serviceId: template.id,
      serviceName: template.name,
    );

    for (var index = 0; index < template.questions.length; index++) {
      final templateQuestion = template.questions[index];
      final questionText = sanitizeVanText(templateQuestion.text).trim();
      if (questionText.isEmpty ||
          templateQuestion.answerType ==
              VanCustomQuestionAnswerType.photoUploadRequest ||
          isVanCustomerRequestBuiltInQuestion(requestType, questionText)) {
        continue;
      }
      final question = VanCustomJobQuestion(
        id: 'service_template_${template.id}_${index}_${now.microsecondsSinceEpoch}',
        questionText: questionText,
        helperText: '',
        answerType: templateQuestion.answerType,
        category: templateQuestion.category,
        isActive: true,
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      nextQuestions.add(question);
      linkedQuestionIds.add(question.id);
    }

    await _questionsStorage.saveAll(nextQuestions);
    final service = VanJobService(
      id: 'service_${template.id}_${now.microsecondsSinceEpoch}',
      name: template.name,
      description: template.description,
      isActive: true,
      requestPhotos: template.questions.any(
        (question) =>
            question.answerType ==
            VanCustomQuestionAnswerType.photoUploadRequest,
      ),
      requireAddress: true,
      requestExactPinAfterQuoteAccepted: true,
      requestType: requestType,
      requestFlowOptions: VanCustomerRequestFlowOptions.defaultsFor(
        requestType,
      ),
      linkedQuestionIds: List<String>.unmodifiable(linkedQuestionIds),
      quoteExtraDefaults: template.quoteExtraDefaults(),
      createdAt: now,
      updatedAt: now,
    );
    await _storage.upsert(service);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${template.name} service added.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadServices(showLoader: false);
  }

  Future<void> _openService(VanJobService service) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VanJobServiceDetailPage(serviceId: service.id),
      ),
    );
    if (changed == true) {
      await _loadServices(showLoader: false);
    }
  }

  Future<void> _editService(VanJobService service) async {
    final edited = await Navigator.of(context).push<VanJobService>(
      MaterialPageRoute<VanJobService>(
        builder: (_) => VanJobServiceEditorPage(initialService: service),
      ),
    );
    if (edited != null) {
      await _loadServices(showLoader: false);
    }
  }

  Future<void> _deleteService(VanJobService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text(
          'Delete "${service.name}"? This removes it from your Booking Link and question setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _storage.delete(service.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${service.name} deleted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _loadServices(showLoader: false);
  }

  Widget _buildHeroCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Types / Services',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your services, then manage questions from each Service Detail page.',
            style: TextStyle(
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedServicesCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Services',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a starter template, then edit the service, questions and extras any time.',
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final category in kVanServiceTemplateCategories)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.05),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white,
                iconColor: Colors.white,
                title: Text(
                  category.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 10),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final template in category.services)
                          ActionChip(
                            onPressed: () => _addServiceFromTemplate(template),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            label: Text(
                              template.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: () => _openAddService(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create My Own Service'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Job Types / Services'),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 12),
                      _buildSuggestedServicesCard(),
                      const SizedBox(height: 12),
                      if (_services.isEmpty)
                        const _EmptyState(
                          title: 'No services yet.',
                          message:
                              'Add your first service, then manage its questions.',
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < _services.length; i++) ...[
                              _ServiceListCard(
                                service: _services[i],
                                onOpen: () => _openService(_services[i]),
                                onEdit: () => _editService(_services[i]),
                                onDelete: () => _deleteService(_services[i]),
                              ),
                              if (i < _services.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class VanJobServiceDetailPage extends StatefulWidget {
  const VanJobServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  State<VanJobServiceDetailPage> createState() =>
      _VanJobServiceDetailPageState();
}

class _VanJobServiceDetailPageState extends State<VanJobServiceDetailPage> {
  final VanJobServicesStorage _serviceStorage = VanJobServicesStorage.instance;
  final VanCustomJobQuestionsStorage _questionsStorage =
      VanCustomJobQuestionsStorage.instance;
  final VanBusinessHubOnboardingStorage _onboardingStorage =
      VanBusinessHubOnboardingStorage.instance;

  VanJobService? _service;
  Map<String, VanCustomJobQuestion> _questionLookup =
      <String, VanCustomJobQuestion>{};
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  bool _checkedSettingsHelp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowServiceSettingsHelpDialog());
    });
    unawaited(_load());
  }

  Future<void> _maybeShowServiceSettingsHelpDialog() async {
    if (_checkedSettingsHelp) {
      return;
    }
    _checkedSettingsHelp = true;
    final shouldShow = await _onboardingStorage
        .shouldShowServiceDetailSettingsHelp();
    if (!shouldShow || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Service settings'),
        content: const Text(
          'These settings control what customers see when they choose this service from your Booking Link.\n\n'
          'Request photos:\n'
          'Ask the customer to add photos with their request.\n\n'
          'Require address:\n'
          'Make the customer enter an address or postcode before submitting.\n\n'
          'Request exact pin after quote accepted:\n'
          'Only ask for the exact pin after the customer accepts your quote.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Don\u2019t show again'),
          ),
        ],
      ),
    );

    await _onboardingStorage.dismissServiceDetailSettingsHelp();
  }

  Future<void> _load() async {
    debugPrint('[ServiceDetailPage] load start serviceId=${widget.serviceId}');
    var services = <VanJobService>[];
    var customQuestions = <VanCustomJobQuestion>[];
    try {
      services = await _serviceStorage.loadAll();
      customQuestions = await _questionsStorage.loadAll();
      await Future.wait<dynamic>([
        _serviceStorage.loadFromCloud(),
        _questionsStorage.loadFromCloud(),
      ]);
      services = await _serviceStorage.loadAll();
      customQuestions = await _questionsStorage.loadAll();
      debugPrint(
        '[ServiceDetailPage] hydrated service count=${services.length} question count=${customQuestions.length}',
      );
    } catch (error) {
      debugPrint('[ServiceDetailPage] load error error=$error');
    }
    final lookup = <String, VanCustomJobQuestion>{
      for (final question in customQuestions) question.id: question,
    };
    final service = services
        .where((item) => item.id == widget.serviceId)
        .firstOrNull;
    if (!mounted) {
      return;
    }
    setState(() {
      _service = service;
      _questionLookup = lookup;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final service = _service;
    if (service == null || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });
    await _serviceStorage.upsert(service.copyWith(updatedAt: DateTime.now()));
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _changed = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editService() async {
    final service = _service;
    if (service == null) {
      return;
    }
    final edited = await Navigator.of(context).push<VanJobService>(
      MaterialPageRoute<VanJobService>(
        builder: (_) => VanJobServiceEditorPage(initialService: service),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() {
      _service = edited;
      _changed = true;
    });
  }

  Future<void> _addQuestion() async {
    final service = _service;
    final selectedServiceId = service?.id.trim() ?? '';
    if (selectedServiceId.isEmpty || service == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open a service before adding questions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final question = await editVanServiceQuestion(
      context,
      serviceId: selectedServiceId,
    );
    if (question == null || !mounted) {
      return;
    }
    final updatedService = service.copyWith(
      linkedQuestionIds: List<String>.unmodifiable(<String>[
        ...service.linkedQuestionIds,
        question.id,
      ]),
      updatedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      await _questionsStorage.upsert(question);
      await _serviceStorage.upsert(updatedService);
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _changed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add question. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editQuoteExtras() async {
    final service = _service;
    if (service == null) {
      return;
    }
    final businessProfileId = await VanBusinessProfileScopeStorage.instance
        .activeBusinessId();
    final serviceId = service.id;
    final updated = await showModalBottomSheet<VanQuoteExtraDefaults>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VanQuoteExtraDefaultsSheet(
        initialDefaults: service.quoteExtraDefaults,
        resetDefaults:
            findVanServiceTemplateForService(
              serviceId: service.id,
              serviceName: service.name,
            )?.quoteExtraDefaults() ??
            VanQuoteExtraDefaults.empty(),
        title: '${service.name} extras',
        description: 'Set the quote extras shown for this service.',
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    final activeBusinessProfileId = await VanBusinessProfileScopeStorage
        .instance
        .activeBusinessId();
    if (!mounted) {
      return;
    }
    if (activeBusinessProfileId != businessProfileId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The active business changed. Reopen the service before saving extras.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedService = service.copyWith(
      quoteExtraDefaults: updated,
      updatedAt: DateTime.now(),
    );
    setState(() {
      _saving = true;
    });
    try {
      await _serviceStorage.upsert(updatedService);
      await _load();
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _changed = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _service = updatedService;
        _saving = false;
        _changed = true;
      });
      debugPrint(
        '[ServiceDetailPage] extras save failed businessProfileId=$businessProfileId serviceId=$serviceId error=$error',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save service extras. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<_LinkedServiceQuestion> _linkedQuestionsForService(
    VanJobService service,
  ) {
    final linked = <_LinkedServiceQuestion>[];
    for (final id in service.linkedQuestionIds) {
      final question = _questionLookup[id];
      if (question == null) {
        continue;
      }
      final text = question.questionText.trim();
      if (text.isEmpty) {
        continue;
      }
      linked.add(_LinkedServiceQuestion(id: id, question: question));
    }
    return linked;
  }

  void _reorderLinkedQuestions(int oldIndex, int newIndex) {
    final service = _service;
    if (service == null) {
      return;
    }
    final linkedQuestions = _linkedQuestionsForService(service);
    if (linkedQuestions.length < 2) {
      return;
    }
    if (oldIndex < 0 ||
        oldIndex >= linkedQuestions.length ||
        newIndex < 0 ||
        newIndex > linkedQuestions.length) {
      return;
    }

    final reorderedVisibleIds = linkedQuestions
        .map((item) => item.id)
        .toList(growable: true);
    final movedId = reorderedVisibleIds.removeAt(oldIndex);
    reorderedVisibleIds.insert(newIndex, movedId);

    final visibleSet = reorderedVisibleIds.toSet();
    final missingIds = service.linkedQuestionIds
        .where((id) => !visibleSet.contains(id))
        .toList(growable: false);
    final reorderedAllIds = <String>[...reorderedVisibleIds, ...missingIds];

    setState(() {
      _service = service.copyWith(
        linkedQuestionIds: List<String>.unmodifiable(reorderedAllIds),
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
  }

  Future<void> _removeLinkedQuestion(String questionId) async {
    final service = _service;
    final normalizedId = questionId.trim();
    if (service == null || normalizedId.isEmpty || _saving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('Delete this question from this service?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final updatedIds = service.linkedQuestionIds
        .where((id) => id != normalizedId)
        .toList(growable: false);
    if (updatedIds.length == service.linkedQuestionIds.length) {
      return;
    }

    final updatedService = service.copyWith(
      linkedQuestionIds: List<String>.unmodifiable(updatedIds),
      disabledLinkedQuestionIds: service.disabledLinkedQuestionIds
          .where((id) => id != normalizedId)
          .toList(growable: false),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _service = updatedService;
      _saving = true;
    });
    try {
      await _serviceStorage.upsert(updatedService);
      await _deleteQuestionDefinitionIfUnused(normalizedId);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _changed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question deleted from service.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove question. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _setLinkedQuestionEnabled(
    String questionId,
    bool enabled,
  ) async {
    final service = _service;
    if (service == null || _saving) {
      return;
    }
    final disabledIds = <String>{...service.disabledLinkedQuestionIds};
    if (enabled) {
      disabledIds.remove(questionId);
    } else {
      disabledIds.add(questionId);
    }
    final updated = service.copyWith(
      disabledLinkedQuestionIds: disabledIds.toList(growable: false),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _service = updated;
      _saving = true;
    });
    await _serviceStorage.upsert(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _changed = false;
    });
  }

  Future<void> _editLinkedQuestion(
    String questionId,
    VanCustomJobQuestion question,
  ) async {
    final service = _service;
    if (service == null || _saving) {
      return;
    }
    final now = DateTime.now();
    final serviceQuestionId =
        'service_question_${service.id}_${now.microsecondsSinceEpoch}';
    final edited = await editVanServiceQuestion(
      context,
      serviceId: service.id,
      question: question.copyWith(
        id: serviceQuestionId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    await _questionsStorage.upsert(edited);
    final updatedIds = service.linkedQuestionIds
        .map((id) => id == questionId ? serviceQuestionId : id)
        .toList(growable: false);
    final disabledIds = service.disabledLinkedQuestionIds
        .map((id) => id == questionId ? serviceQuestionId : id)
        .toList(growable: false);
    final updated = service.copyWith(
      linkedQuestionIds: updatedIds,
      disabledLinkedQuestionIds: disabledIds,
      updatedAt: DateTime.now(),
    );
    await _serviceStorage.upsert(updated);
    await _deleteQuestionDefinitionIfUnused(questionId);
    await _load();
  }

  Future<void> _deleteQuestionDefinitionIfUnused(String questionId) async {
    final services = await _serviceStorage.loadAll();
    final stillUsed = services.any(
      (service) => service.linkedQuestionIds.contains(questionId),
    );
    if (!stillUsed) {
      await _questionsStorage.delete(questionId);
    }
  }

  String _linkedQuestionMetaLabel(VanCustomJobQuestion question) {
    final answerLabel = question.answerType.label.trim();
    final categoryLabel = question.category?.label.trim() ?? '';
    if (categoryLabel.isEmpty) {
      return answerLabel;
    }
    return '$answerLabel - $categoryLabel';
  }

  void _updateRequestFlowOptions(
    VanJobService service,
    VanCustomerRequestFlowOptions options,
  ) {
    setState(() {
      _service = service.copyWith(
        requestFlowOptions: options,
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
  }

  Widget _flowOptionSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _saving ? null : onChanged,
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  List<Widget> _requestFlowOptionTiles(VanJobService service) {
    final options = service.effectiveRequestFlowOptions;
    final tiles = <Widget>[];

    void addOption(
      String label,
      bool value,
      VanCustomerRequestFlowOptions Function(bool value) update,
    ) {
      tiles.add(
        _flowOptionSwitch(
          label: label,
          value: value,
          onChanged: (enabled) =>
              _updateRequestFlowOptions(service, update(enabled)),
        ),
      );
    }

    switch (service.requestType) {
      case VanCustomerRequestType.quoteRequest:
        tiles.add(
          _flowOptionSwitch(
            label: 'Customer address',
            value: service.requireAddress,
            onChanged: (enabled) {
              setState(() {
                _service = service.copyWith(
                  requireAddress: enabled,
                  updatedAt: DateTime.now(),
                );
                _changed = true;
              });
            },
          ),
        );
        break;
      case VanCustomerRequestType.bookingRequest:
        tiles.add(
          _flowOptionSwitch(
            label: 'Customer address',
            value: service.requireAddress,
            onChanged: (enabled) {
              setState(() {
                _service = service.copyWith(
                  requireAddress: enabled,
                  updatedAt: DateTime.now(),
                );
                _changed = true;
              });
            },
          ),
        );
        break;
      case VanCustomerRequestType.orderRequest:
        addOption(
          'Collection / delivery choice',
          options.showFulfilmentChoice,
          (enabled) => options.copyWith(showFulfilmentChoice: enabled),
        );
        break;
      case VanCustomerRequestType.pickupDeliveryRequest:
        addOption(
          'Pickup address',
          options.showPickupAddress,
          (enabled) => options.copyWith(showPickupAddress: enabled),
        );
        addOption(
          'Delivery address',
          options.showDeliveryAddress,
          (enabled) => options.copyWith(showDeliveryAddress: enabled),
        );
        break;
      case VanCustomerRequestType.dropOffPickupRequest:
        addOption(
          'Drop-off date',
          options.showDropOffDate,
          (enabled) => options.copyWith(showDropOffDate: enabled),
        );
        addOption(
          'Drop-off time',
          options.showDropOffTime,
          (enabled) => options.copyWith(showDropOffTime: enabled),
        );
        addOption(
          'Pick-up date',
          options.showPickUpDate,
          (enabled) => options.copyWith(showPickUpDate: enabled),
        );
        addOption(
          'Pick-up time',
          options.showPickUpTime,
          (enabled) => options.copyWith(showPickUpTime: enabled),
        );
        break;
    }

    if (service.requestType != VanCustomerRequestType.dropOffPickupRequest) {
      addOption(
        'Preferred date',
        options.askPreferredDate,
        (enabled) => options.copyWith(askPreferredDate: enabled),
      );
      addOption(
        'Preferred time',
        options.askPreferredTime,
        (enabled) => options.copyWith(askPreferredTime: enabled),
      );
    }
    addOption(
      'Notes',
      options.showNotes,
      (enabled) => options.copyWith(showNotes: enabled),
    );
    tiles.add(
      _flowOptionSwitch(
        label: 'Photos',
        value: service.requestPhotos,
        onChanged: (enabled) {
          setState(() {
            _service = service.copyWith(
              requestPhotos: enabled,
              updatedAt: DateTime.now(),
            );
            _changed = true;
          });
        },
      ),
    );
    return tiles;
  }

  Future<void> _deleteService() async {
    final service = _service;
    if (service == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete service?'),
        content: const Text('This removes the service from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD24C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _serviceStorage.delete(service.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final service = _service;
    final selectedServiceId = service?.id.trim() ?? '';
    final canAddQuestions = selectedServiceId.isNotEmpty;
    final linkedQuestions = service == null
        ? const <_LinkedServiceQuestion>[]
        : _linkedQuestionsForService(service);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Service Detail'),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(_changed),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : service == null
                ? const Center(
                    child: Text(
                      'Service not found.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            if (service.hasDescription) ...[
                              const SizedBox(height: 8),
                              Text(
                                service.description,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  height: 1.45,
                                  color: Colors.white.withValues(alpha: 0.74),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _StatusChip(
                              label: service.isActive ? 'Active' : 'Inactive',
                              color: service.isActive
                                  ? const Color(0xFF58D0A4)
                                  : const Color(0xFFFFB86C),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Quote extras',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                _InfoChip(
                                  label:
                                      '${service.enabledQuoteExtraCount} enabled',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _quoteExtraSummary(service.quoteExtraDefaults),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: _editQuoteExtras,
                                icon: const Icon(Icons.tune),
                                label: const Text('Edit Extras'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Customer request flow',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose how customers request this service.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<VanCustomerRequestType>(
                              key: ValueKey<VanCustomerRequestType>(
                                service.requestType,
                              ),
                              initialValue: service.requestType,
                              dropdownColor: const Color(0xFF17253A),
                              iconEnabledColor: Colors.white70,
                              decoration: vanMateFieldDecoration(
                                label: 'Request type',
                                prefixIcon: const Icon(Icons.alt_route_rounded),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              items: [
                                for (final type
                                    in VanCustomerRequestType.values)
                                  DropdownMenuItem<VanCustomerRequestType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _service = service.copyWith(
                                          requestType: value,
                                          requestFlowOptions:
                                              VanCustomerRequestFlowOptions.defaultsFor(
                                                value,
                                              ),
                                          requireAddress:
                                              value ==
                                              VanCustomerRequestType
                                                  .quoteRequest,
                                          updatedAt: DateTime.now(),
                                        );
                                        _changed = true;
                                      });
                                    },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              service.requestType.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.66),
                                height: 1.4,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Flow options',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            ..._requestFlowOptionTiles(service),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: service.requestExactPinAfterQuoteAccepted,
                              onChanged: (value) {
                                setState(() {
                                  _service = service.copyWith(
                                    requestExactPinAfterQuoteAccepted: value,
                                    updatedAt: DateTime.now(),
                                  );
                                  _changed = true;
                                });
                              },
                              title: const Text(
                                'Request exact pin after quote accepted',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Questions',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                _InfoChip(
                                  label: '${linkedQuestions.length} linked',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (linkedQuestions.isEmpty)
                              Text(
                                'No questions yet.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Drag to change the order customers see these questions.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                      fontSize: 12.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: linkedQuestions.length,
                                    onReorderItem: _reorderLinkedQuestions,
                                    itemBuilder: (context, index) {
                                      final linkedQuestion =
                                          linkedQuestions[index];
                                      final question = linkedQuestion.question;
                                      final questionEnabled = !service
                                          .disabledLinkedQuestionIds
                                          .contains(linkedQuestion.id);
                                      final displayOrder = index + 1;
                                      return Container(
                                        key: ValueKey<String>(
                                          linkedQuestion.id,
                                        ),
                                        margin: EdgeInsets.only(
                                          bottom:
                                              index < linkedQuestions.length - 1
                                              ? 8
                                              : 0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 28,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.10,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.16),
                                                ),
                                              ),
                                              child: Text(
                                                '$displayOrder',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.86),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11.8,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    question.questionText,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.82,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '${_linkedQuestionMetaLabel(question)}${questionEnabled ? '' : ' - Disabled'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.58,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              tooltip: questionEnabled
                                                  ? 'Disable for this service'
                                                  : 'Enable for this service',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () =>
                                                        _setLinkedQuestionEnabled(
                                                          linkedQuestion.id,
                                                          !questionEnabled,
                                                        ),
                                              icon: Icon(
                                                questionEnabled
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                                size: 18,
                                                color: Colors.white.withValues(
                                                  alpha: 0.72,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Edit for this service',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _editLinkedQuestion(
                                                      linkedQuestion.id,
                                                      question,
                                                    ),
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: Colors.white.withValues(
                                                  alpha: 0.72,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  'Remove from this service',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _removeLinkedQuestion(
                                                      linkedQuestion.id,
                                                    ),
                                              icon: Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                                color: Colors.white.withValues(
                                                  alpha: 0.72,
                                                ),
                                              ),
                                            ),
                                            ReorderableDelayedDragStartListener(
                                              index: index,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                      vertical: 4,
                                                    ),
                                                child: Icon(
                                                  Icons.drag_handle_rounded,
                                                  size: 20,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.68),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: FilledButton.icon(
                                    onPressed: canAddQuestions
                                        ? _addQuestion
                                        : null,
                                    icon: const Icon(Icons.add),
                                    label: const Text('+ Add Question'),
                                  ),
                                ),
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: _editService,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit Service'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            height: 42,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ),
                          SizedBox(
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _deleteService,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete Service'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF9B9B),
                                side: BorderSide(
                                  color: const Color(
                                    0xFFFF9B9B,
                                  ).withValues(alpha: 0.65),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class VanJobServiceEditorPage extends StatefulWidget {
  const VanJobServiceEditorPage({
    super.key,
    this.initialService,
    this.suggestedName,
  });

  final VanJobService? initialService;
  final String? suggestedName;

  @override
  State<VanJobServiceEditorPage> createState() =>
      _VanJobServiceEditorPageState();
}

class _VanJobServiceEditorPageState extends State<VanJobServiceEditorPage> {
  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isActive = true;
  bool _requestPhotos = false;
  bool _requireAddress = true;
  bool _requestExactPinAfterQuoteAccepted = true;
  late VanQuoteExtraDefaults _quoteExtraDefaults;
  bool _saving = false;

  bool get _isEditing => widget.initialService != null;

  VanQuoteExtraDefaults _serviceTemplateDefaults({
    required String serviceId,
    required String serviceName,
  }) {
    if (widget.initialService == null) {
      return VanQuoteExtraDefaults.empty();
    }
    return findVanServiceTemplateForService(
          serviceId: serviceId,
          serviceName: serviceName,
        )?.quoteExtraDefaults() ??
        VanQuoteExtraDefaults.empty();
  }

  @override
  void initState() {
    super.initState();
    final service = widget.initialService;
    _nameController = TextEditingController(
      text: service?.name ?? (widget.suggestedName ?? ''),
    );
    _descriptionController = TextEditingController(
      text: service?.description ?? '',
    );
    _isActive = service?.isActive ?? true;
    _requestPhotos = service?.requestPhotos ?? false;
    _requireAddress = service?.requireAddress ?? true;
    _requestExactPinAfterQuoteAccepted =
        service?.requestExactPinAfterQuoteAccepted ?? true;
    _quoteExtraDefaults =
        service?.quoteExtraDefaults ?? VanQuoteExtraDefaults.empty();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _editQuoteExtras() async {
    final initialDefaults = _quoteExtraDefaults;
    final updated = await showModalBottomSheet<VanQuoteExtraDefaults>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VanQuoteExtraDefaultsSheet(
        initialDefaults: initialDefaults,
        resetDefaults: _serviceTemplateDefaults(
          serviceId: widget.initialService?.id ?? '',
          serviceName: _nameController.text,
        ),
        title: 'Service extras',
        description: 'Set the quote extras shown for this service.',
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() {
      _quoteExtraDefaults = updated;
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final name = sanitizeVanText(_nameController.text).trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a service name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.initialService;
    final quoteExtraDefaults = _quoteExtraDefaults;
    final requestType =
        existing?.requestType ??
        defaultVanCustomerRequestTypeForService(
          serviceId: '',
          serviceName: name,
        );
    final service = VanJobService(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      description: sanitizeVanText(_descriptionController.text).trim(),
      isActive: _isActive,
      requestPhotos: _requestPhotos,
      requireAddress: _requireAddress,
      requestExactPinAfterQuoteAccepted: _requestExactPinAfterQuoteAccepted,
      requestType: requestType,
      requestFlowOptions:
          existing?.requestFlowOptions ??
          VanCustomerRequestFlowOptions.defaultsFor(requestType),
      linkedQuestionIds: existing?.linkedQuestionIds ?? const <String>[],
      quoteExtraDefaults: quoteExtraDefaults,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isArchived: existing?.isArchived ?? false,
    );

    setState(() {
      _saving = true;
    });
    await _storage.upsert(service);
    if (!mounted) {
      return;
    }
    if (_isEditing) {
      Navigator.of(context).pop(service);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = _isEditing ? 'Edit Service' : 'Add Service';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(false),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomInset + keyboardInset + 24,
              ),
              children: [
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a service your business offers.',
                        style: TextStyle(
                          fontSize: 13.2,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ServiceTextField(
                        controller: _nameController,
                        label: 'Service name',
                        hint: 'Gardening',
                      ),
                      const SizedBox(height: 12),
                      _ServiceTextField(
                        controller: _descriptionController,
                        label: 'Description (optional)',
                        hint: 'What this service covers',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        title: const Text(
                          'Active service',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _requestPhotos,
                        onChanged: (value) {
                          setState(() {
                            _requestPhotos = value;
                          });
                        },
                        title: const Text(
                          'Request photos',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _requireAddress,
                        onChanged: (value) {
                          setState(() {
                            _requireAddress = value;
                          });
                        },
                        title: const Text(
                          'Require address',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _requestExactPinAfterQuoteAccepted,
                        onChanged: (value) {
                          setState(() {
                            _requestExactPinAfterQuoteAccepted = value;
                          });
                        },
                        title: const Text(
                          'Request exact pin after quote accepted',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Quote extras',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                _InfoChip(
                                  label:
                                      '${_quoteExtraDefaults.enabledExtras.length} enabled',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _quoteExtraSummary(_quoteExtraDefaults),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: _editQuoteExtras,
                                icon: const Icon(Icons.tune),
                                label: const Text('Edit Extras'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedServiceQuestion {
  const _LinkedServiceQuestion({required this.id, required this.question});

  final String id;
  final VanCustomJobQuestion question;
}

String _quoteExtraSummary(VanQuoteExtraDefaults defaults) {
  final enabledExtras = defaults.enabledExtras;
  if (enabledExtras.isEmpty) {
    return 'No extras enabled for this service.';
  }
  final labels = enabledExtras
      .take(3)
      .map((extra) => extra.resolvedLabel)
      .toList(growable: false);
  final extraCount = enabledExtras.length - labels.length;
  if (extraCount <= 0) {
    return labels.join(', ');
  }
  return '${labels.join(', ')} + $extraCount more';
}

String _normalizeServiceTemplateText(String value) {
  return sanitizeVanText(
    value,
  ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _ServiceListCard extends StatelessWidget {
  const _ServiceListCard({
    required this.service,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final VanJobService service;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  List<String> get _settingsSummary {
    final items = <String>[];
    if (service.requireAddress) {
      items.add('Request address');
    }
    if (service.requestExactPinAfterQuoteAccepted) {
      items.add('Request exact pin after quote accepted');
    }
    if (service.requestPhotos) {
      items.add('Request photos');
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final settingsSummary = _settingsSummary;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 16.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (service.hasDescription) ...[
                      const SizedBox(height: 6),
                      Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 12.7,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                label: service.isActive ? 'Active' : 'Inactive',
                color: service.isActive
                    ? const Color(0xFF58D0A4)
                    : const Color(0xFFFFB86C),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(label: '${service.linkedQuestionIds.length} questions'),
              _InfoChip(label: '${service.enabledQuoteExtraCount} extras'),
              _InfoChip(label: service.requestType.label),
              for (final item in settingsSummary) _InfoChip(label: item),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open Service'),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF9B9B),
                    side: BorderSide(
                      color: const Color(0xFFFF9B9B).withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceTextField extends StatelessWidget {
  const _ServiceTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        labelOpacity: 0.68,
        hintOpacity: 0.48,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.2,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.80),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13.0,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: child,
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
