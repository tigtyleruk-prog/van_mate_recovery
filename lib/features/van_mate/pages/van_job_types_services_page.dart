import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_prefilled_job_questions.dart';
import '../pages/van_custom_job_questions_page.dart';
import '../services/van_business_hub_onboarding_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_job_services_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

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
  static const List<String> _quickStartNames = <String>[
    'Man & Van',
    'Gardening',
    'Courier',
    'Fish Delivery',
    'Handyman',
    'Other',
  ];

  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;
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
            'Add your services, then link questions from your Question Library.',
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

  Widget _buildAddServiceCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Service',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your own service names. Suggestions are optional.',
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _quickStartNames)
                ActionChip(
                  onPressed: () => _openAddService(suggestedName: name),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  label: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: () => _openAddService(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Service'),
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
                      _buildAddServiceCard(),
                      const SizedBox(height: 12),
                      if (_services.isEmpty)
                        const _EmptyState(
                          title: 'No services yet.',
                          message:
                              'Add your first service, then link custom job questions.',
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
      for (final question in <VanCustomJobQuestion>[
        ...VanPrefilledJobQuestions.all,
        ...customQuestions,
      ])
        question.id: question,
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

  Future<void> _addQuestions() async {
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
    final selectedIds = await pickVanCustomJobQuestionIds(
      context,
      initialSelectedQuestionIds: service.linkedQuestionIds.toSet(),
    );
    if (selectedIds == null || !mounted) {
      return;
    }
    setState(() {
      _service = service.copyWith(
        linkedQuestionIds: List<String>.unmodifiable(selectedIds.toList()),
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
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
        .where(
          (id) =>
              !visibleSet.contains(id) &&
              !VanPrefilledJobQuestions.isDeprecatedDuplicatePresetId(id),
        )
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
        title: const Text('Remove question?'),
        content: const Text('Remove this question from this service?'),
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
            child: const Text('Remove'),
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
      updatedAt: DateTime.now(),
    );

    setState(() {
      _service = updatedService;
      _saving = true;
    });
    try {
      await _serviceStorage.upsert(updatedService);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _changed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question removed from service.'),
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

  String _linkedQuestionMetaLabel(VanCustomJobQuestion question) {
    final answerLabel = question.answerType.label.trim();
    final categoryLabel = question.category?.label.trim() ?? '';
    if (categoryLabel.isEmpty) {
      return answerLabel;
    }
    return '$answerLabel - $categoryLabel';
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
                              value: service.requestPhotos,
                              onChanged: (value) {
                                setState(() {
                                  _service = service.copyWith(
                                    requestPhotos: value,
                                    updatedAt: DateTime.now(),
                                  );
                                  _changed = true;
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
                              value: service.requireAddress,
                              onChanged: (value) {
                                setState(() {
                                  _service = service.copyWith(
                                    requireAddress: value,
                                    updatedAt: DateTime.now(),
                                  );
                                  _changed = true;
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
                                    'Linked questions',
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
                                'No linked questions yet.',
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
                                                    _linkedQuestionMetaLabel(
                                                      question,
                                                    ),
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
                                        ? _addQuestions
                                        : null,
                                    icon: const Icon(Icons.playlist_add_check),
                                    label: const Text('+ Add Questions'),
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
  bool _saving = false;

  bool get _isEditing => widget.initialService != null;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    final service = VanJobService(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      description: sanitizeVanText(_descriptionController.text).trim(),
      isActive: _isActive,
      requestPhotos: _requestPhotos,
      requireAddress: _requireAddress,
      requestExactPinAfterQuoteAccepted: _requestExactPinAfterQuoteAccepted,
      linkedQuestionIds: existing?.linkedQuestionIds ?? const <String>[],
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
              _InfoChip(
                label: '${service.linkedQuestionIds.length} linked questions',
              ),
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
