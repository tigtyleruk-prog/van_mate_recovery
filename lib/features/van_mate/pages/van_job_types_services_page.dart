import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_customer_journey.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_capability.dart';
import '../models/van_service_template.dart';
import '../models/van_service_handover.dart';
import '../models/van_starter_capability_pack.dart';
import '../pages/van_service_question_editor_page.dart';
import '../pages/van_service_wizard_page.dart';
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

Future<bool?> openVanExistingServiceEditor(
  BuildContext context, {
  required String serviceId,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => VanJobServiceDetailPage(
        serviceId: serviceId,
        reviewServiceIds: <String>[serviceId],
        existingServiceConfiguration: true,
      ),
    ),
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
        title: const Text('How services work'),
        content: const Text(
          'Add the services you offer, then choose which questions customers should answer for each service.\n\n'
          'Example:\n'
          'Gardening → garden size, rear access, waste removal\n'
          'Man & Van → stairs, lift, parking, item photos\n\n'
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

  Future<void> _openAddService() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => const VanJobServiceEditorPage(),
      ),
    );
    if (result == true || result is VanServiceWizardBuildResult) {
      await _loadServices(showLoader: false);
    }
    if (!mounted || result is! VanServiceWizardBuildResult) return;
    if (result.createdServiceIds.isNotEmpty) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => VanJobServiceDetailPage(
            serviceId: result.createdServiceIds.first,
            reviewServiceIds: result.createdServiceIds,
          ),
        ),
      );
      if (!mounted) return;
      await _loadServices(showLoader: false);
      if (!mounted) return;
    }
    final createdCount = result.createdServiceIds.length;
    final existingCount = result.existingServiceIds.length;
    final existingIds = result.existingServiceIds.toSet();
    final firstExisting = _services
        .where((service) => existingIds.contains(service.id))
        .firstOrNull;
    final message = switch ((createdCount, existingCount)) {
      (0, _) =>
        'No duplicates added. ${existingCount == 1 ? 'That service is' : 'Those services are'} already in your list.',
      (_, 0) =>
        '$createdCount service${createdCount == 1 ? '' : 's'} created and ready to edit.',
      _ =>
        '$createdCount service${createdCount == 1 ? '' : 's'} created. $existingCount existing ${existingCount == 1 ? 'service was' : 'services were'} kept.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: firstExisting == null
            ? null
            : SnackBarAction(
                label: 'Edit existing',
                onPressed: () => unawaited(_editService(firstExisting)),
              ),
      ),
    );
  }

  Future<void> _openService(VanJobService service) async {
    if (service.isDraft) {
      await _resumeDraftService(service);
      return;
    }
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
    final changed = await openVanExistingServiceEditor(
      context,
      serviceId: service.id,
    );
    if (changed == true) {
      await _loadServices(showLoader: false);
    }
  }

  Future<void> _resumeDraftService(VanJobService service) async {
    final edited = await Navigator.of(context).push<VanJobService>(
      MaterialPageRoute<VanJobService>(
        builder: (_) => VanJobServiceEditorPage(initialService: service),
      ),
    );
    if (edited != null) await _loadServices(showLoader: false);
  }

  Future<void> _duplicateService(VanJobService service) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VanJobServiceEditorPage(duplicateFrom: service),
      ),
    );
    if (changed == true) {
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
            'Services',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAddService,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Service'),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Tell Business Mate what you offer, or create one service from scratch.',
            style: TextStyle(
              fontSize: 12.4,
              color: Colors.white.withValues(alpha: .62),
              fontWeight: FontWeight.w600,
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
        title: const Text('Services'),
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
                      if (_services.isEmpty)
                        _EmptyState(
                          title: 'No services created yet.',
                          message:
                              'Create your first service and Business Mate will suggest a useful starting setup.',
                          actionLabel: 'Create a service',
                          onAction: _openAddService,
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < _services.length; i++) ...[
                              _ServiceListCard(
                                service: _services[i],
                                onOpen: () => _openService(_services[i]),
                                onEdit: () => _services[i].isDraft
                                    ? _resumeDraftService(_services[i])
                                    : _editService(_services[i]),
                                onDuplicate: () =>
                                    _duplicateService(_services[i]),
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
  const VanJobServiceDetailPage({
    super.key,
    required this.serviceId,
    this.reviewServiceIds = const <String>[],
    this.existingServiceConfiguration = false,
  });

  final String serviceId;
  final List<String> reviewServiceIds;
  final bool existingServiceConfiguration;

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
  int _reviewServiceIndex = 0;
  int _reviewSectionIndex = 0;
  Set<String> _configurationOriginalQuestionIds = const <String>{};
  bool _capturedConfigurationOriginals = false;
  int _guidedExtrasResetRevision = 0;
  String _guidedExtraDraftServiceId = '';
  String? _guidedNewExtraKey;
  String? _guidedHighlightedExtraKey;
  GlobalKey<_GuidedPricingExtraRowState>? _guidedNewExtraRowKey;
  final Map<String, VanJobService> _guidedAvailabilityDefaults =
      <String, VanJobService>{};
  final Map<String, Map<int, VanServiceDaySchedule>> _guidedAvailabilityDrafts =
      <String, Map<int, VanServiceDaySchedule>>{};

  static const _reviewSectionTitles = <String>[
    'Service Features',
    'Customer Questions',
    'Pricing Extras',
    'Availability',
  ];

  bool get _isGuidedReview => widget.reviewServiceIds.isNotEmpty;
  String get _activeServiceId => _isGuidedReview
      ? widget.reviewServiceIds[_reviewServiceIndex]
      : widget.serviceId;

  @override
  void initState() {
    super.initState();
    if (!_isGuidedReview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowServiceSettingsHelpDialog());
      });
    }
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
    debugPrint('[ServiceDetailPage] load start serviceId=$_activeServiceId');
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
        .where((item) => item.id == _activeServiceId)
        .firstOrNull;
    if (!mounted) {
      return;
    }
    setState(() {
      _service = service;
      if ((_isGuidedReview || widget.existingServiceConfiguration) &&
          service != null) {
        _guidedAvailabilityDefaults.putIfAbsent(service.id, () => service);
      }
      _questionLookup = lookup;
      if (widget.existingServiceConfiguration &&
          !_capturedConfigurationOriginals &&
          service != null) {
        _configurationOriginalQuestionIds = service.linkedQuestionIds.toSet();
        _capturedConfigurationOriginals = true;
      }
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
    await _configureService();
  }

  Future<void> _configureService() async {
    final service = _service;
    if (service == null) return;
    final changed = await openVanExistingServiceEditor(
      context,
      serviceId: service.id,
    );
    if (changed != true || !mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _changed = true);
  }

  Future<void> _editServiceFeatures() async {
    final service = _service;
    if (service == null) return;
    final edited = await Navigator.of(context).push<VanJobService>(
      MaterialPageRoute<VanJobService>(
        builder: (_) => _VanServiceFeaturesEditorPage(
          service: service,
          persistChanges: !widget.existingServiceConfiguration,
        ),
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _service = edited;
      _changed = widget.existingServiceConfiguration;
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
    if (widget.existingServiceConfiguration) {
      setState(() {
        _questionLookup[question.id] = question;
        _service = updatedService;
        _changed = true;
      });
      return;
    }
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
    if (!mounted) {
      return;
    }
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
    if (widget.existingServiceConfiguration) {
      setState(() {
        _service = updatedService;
        _changed = true;
      });
      return;
    }
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

  VanQuoteExtraDefaults _guidedStarterExtras(VanJobService service) {
    final pack = service.starterPackId.isEmpty
        ? null
        : findVanStarterCapabilityPackById(service.starterPackId);
    if (pack != null && service.starterTemplateId.isNotEmpty) {
      final setups = pack.recommendationsFor(
        <String>[service.starterTemplateId],
        capabilityIdsByService: <String, Set<String>>{
          service.starterTemplateId: service.serviceCapabilityIds.toSet(),
        },
      );
      if (setups.isNotEmpty) return setups.first.quoteExtraDefaults();
    }
    return findVanServiceTemplateForService(
          serviceId: service.starterTemplateId.isEmpty
              ? service.id
              : service.starterTemplateId,
          serviceName: service.name,
        )?.quoteExtraDefaults() ??
        service.quoteExtraDefaults;
  }

  void _updateGuidedExtras(
    VanJobService service,
    VanQuoteExtraDefaults defaults,
  ) {
    setState(() {
      _service = service.copyWith(
        quoteExtraDefaults: defaults,
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
  }

  void _updateGuidedExtra(VanJobService service, VanQuoteExtraDefault extra) {
    final defaults = service.quoteExtraDefaults;
    if (isVanQuoteBuiltInExtraKey(extra.key)) {
      _updateGuidedExtras(service, defaults.copyWithExtra(extra));
      return;
    }
    final customExtras = <VanQuoteExtraDefault>[
      for (final current in defaults.customExtras)
        if (current.key == extra.key) extra else current,
    ];
    _updateGuidedExtras(
      service,
      VanQuoteExtraDefaults(
        extras: defaults.extras,
        customExtras: customExtras,
        extraOrder: defaults.extraOrder,
        deletedBuiltInKeys: defaults.deletedBuiltInKeys,
        includedBuiltInKeys: defaults.includedBuiltInKeys,
      ),
    );
  }

  void _resetGuidedExtras(VanJobService service) {
    _guidedExtrasResetRevision++;
    _clearGuidedNewExtraFeedback();
    final current = _withoutBlankGuidedExtras(service.quoteExtraDefaults);
    _updateGuidedExtras(
      service,
      current.resetToStarter(_guidedStarterExtras(service)),
    );
  }

  void _reorderGuidedExtras(VanJobService service, int oldIndex, int newIndex) {
    final order = service.quoteExtraDefaults.orderedExtras
        .map((extra) => extra.key)
        .toList(growable: true);
    if (newIndex > oldIndex) newIndex--;
    final key = order.removeAt(oldIndex);
    order.insert(newIndex, key);
    _updateGuidedExtras(
      service,
      service.quoteExtraDefaults.copyWithOrder(order),
    );
  }

  void _deleteGuidedExtra(VanJobService service, VanQuoteExtraDefault extra) {
    final defaults = service.quoteExtraDefaults;
    if (isVanQuoteBuiltInExtraKey(extra.key)) {
      _updateGuidedExtras(service, defaults.deleteBuiltInExtra(extra.key));
      return;
    }
    if (_guidedExtraDraftServiceId == service.id &&
        _guidedNewExtraKey == extra.key) {
      _clearGuidedNewExtraFeedback();
    }
    _updateGuidedExtras(
      service,
      VanQuoteExtraDefaults(
        extras: defaults.extras,
        customExtras: defaults.customExtras
            .where((item) => item.key != extra.key)
            .toList(growable: false),
        extraOrder: defaults.extraOrder
            .where((key) => key != extra.key)
            .toList(growable: false),
        deletedBuiltInKeys: defaults.deletedBuiltInKeys,
        includedBuiltInKeys: defaults.includedBuiltInKeys,
      ),
    );
  }

  Future<void> _editGuidedExtraLabel(
    VanJobService service,
    VanQuoteExtraDefault extra,
  ) async {
    final updatedLabel = await showDialog<String>(
      context: context,
      builder: (_) => _GuidedExtraNameDialog(
        title: 'Edit extra name',
        actionLabel: 'Save',
        fieldKey: const Key('guided_extra_label_editor'),
        initialValue: extra.resolvedLabel,
      ),
    );
    if (updatedLabel == null || !mounted) return;
    final current = _service;
    if (current == null || current.id != service.id) return;
    _updateGuidedExtra(current, extra.copyWith(label: updatedLabel));
  }

  void _addGuidedCustomExtra(VanJobService service) {
    final current = _service;
    if (current == null || current.id != service.id) return;
    for (final extra in current.quoteExtraDefaults.customExtras) {
      if (extra.label.trim().isEmpty) {
        _prepareGuidedNewExtraFeedback(current.id, extra.key);
        _revealGuidedNewExtra();
        return;
      }
    }
    final defaults = current.quoteExtraDefaults;
    final existingKeys = defaults.orderedExtras
        .map((extra) => extra.key)
        .toSet();
    var index = defaults.customExtras.length;
    var key = buildVanQuoteCustomExtraKey(label: '', index: index);
    while (existingKeys.contains(key)) {
      key = buildVanQuoteCustomExtraKey(label: '', index: ++index);
    }
    final blank = VanQuoteExtraDefault(
      key: key,
      label: '',
      defaultPrice: 0,
      enabled: true,
    );
    _prepareGuidedNewExtraFeedback(current.id, key);
    _updateGuidedExtras(
      current,
      VanQuoteExtraDefaults(
        extras: defaults.extras,
        customExtras: <VanQuoteExtraDefault>[blank, ...defaults.customExtras],
        extraOrder: <String>[
          key,
          ...defaults.orderedExtras.map((extra) => extra.key),
        ],
        deletedBuiltInKeys: defaults.deletedBuiltInKeys,
        includedBuiltInKeys: defaults.includedBuiltInKeys,
      ),
    );
    _revealGuidedNewExtra();
  }

  void _prepareGuidedNewExtraFeedback(String serviceId, String extraKey) {
    final reuseRowKey =
        _guidedExtraDraftServiceId == serviceId &&
        _guidedNewExtraKey == extraKey &&
        _guidedNewExtraRowKey != null;
    setState(() {
      _guidedExtraDraftServiceId = serviceId;
      _guidedNewExtraKey = extraKey;
      _guidedHighlightedExtraKey = extraKey;
      if (!reuseRowKey) {
        _guidedNewExtraRowKey = GlobalKey<_GuidedPricingExtraRowState>();
      }
    });
  }

  void _clearGuidedNewExtraFeedback() {
    _guidedExtraDraftServiceId = '';
    _guidedNewExtraKey = null;
    _guidedHighlightedExtraKey = null;
    _guidedNewExtraRowKey = null;
  }

  void _revealGuidedNewExtra() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _guidedNewExtraRowKey?.currentState?.focusLabelAndReveal();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted && _guidedHighlightedExtraKey == _guidedNewExtraKey) {
        setState(() => _guidedHighlightedExtraKey = null);
      }
    });
  }

  VanQuoteExtraDefaults _withoutBlankGuidedExtras(
    VanQuoteExtraDefaults defaults,
  ) {
    final blanks = defaults.customExtras
        .where((extra) => extra.label.trim().isEmpty)
        .map((extra) => extra.key)
        .toSet();
    if (blanks.isEmpty) return defaults;
    return VanQuoteExtraDefaults(
      extras: defaults.extras,
      customExtras: defaults.customExtras
          .where((extra) => !blanks.contains(extra.key))
          .toList(growable: false),
      extraOrder: defaults.extraOrder
          .where((key) => !blanks.contains(key))
          .toList(growable: false),
      deletedBuiltInKeys: defaults.deletedBuiltInKeys,
      includedBuiltInKeys: defaults.includedBuiltInKeys,
    );
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

  List<_AttachedBuiltInQuestion> _builtInQuestionsForService(
    VanJobService service,
  ) {
    const labels = <String, String>{
      'phone': 'Phone number',
      'email': 'Email address',
      'address': 'Address',
      'collection_address': 'Collection address',
      'delivery_address': 'Delivery address',
      'preferred_date': 'Preferred date',
      'preferred_time': 'Preferred time',
      'photos': 'Photos',
      'exact_pin': 'Exact location after acceptance',
    };
    const order = <String>[
      'phone',
      'email',
      'address',
      'collection_address',
      'delivery_address',
      'preferred_date',
      'preferred_time',
      'photos',
      'exact_pin',
    ];
    final selected = service.effectiveSelectedBuiltInQuestionKeys;
    final orderedKeys = <String>[
      ...order.where(selected.contains),
      ...selected.where((key) => !order.contains(key)).toList()..sort(),
    ];
    return <_AttachedBuiltInQuestion>[
      for (final key in orderedKeys)
        _AttachedBuiltInQuestion(
          label: labels[key] ?? key.replaceAll('_', ' '),
          requiredValue: service.requiresBuiltInQuestion(
            key,
            legacyDefault:
                key == 'phone' || (key == 'address' && service.requireAddress),
          ),
        ),
    ];
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

    if (widget.existingServiceConfiguration) {
      setState(() {
        _service = updatedService;
        _changed = true;
      });
      return;
    }

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
    if (widget.existingServiceConfiguration) {
      setState(() {
        _service = updated;
        _changed = true;
      });
      return;
    }
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
    if (widget.existingServiceConfiguration) {
      setState(() {
        _questionLookup[edited.id] = edited;
        _service = updated;
        _changed = true;
      });
      return;
    }
    await _questionsStorage.upsert(edited);
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

    switch (service.serviceFlow) {
      case VanServiceFlow.standard:
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
      case VanServiceFlow.pickupDelivery:
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
      case VanServiceFlow.dropOffPickup:
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

    if (service.serviceFlow != VanServiceFlow.dropOffPickup) {
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
    await _serviceStorage.delete(service.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<bool> _saveGuidedChanges() async {
    var service = _service;
    if (service == null || _saving) return false;
    if (_reviewSectionIndex == 2) {
      final cleanedExtras = _withoutBlankGuidedExtras(
        service.quoteExtraDefaults,
      );
      if (cleanedExtras.customExtras.length !=
          service.quoteExtraDefaults.customExtras.length) {
        service = service.copyWith(
          quoteExtraDefaults: cleanedExtras,
          updatedAt: DateTime.now(),
        );
        _service = service;
        _clearGuidedNewExtraFeedback();
      }
    }
    if (_reviewSectionIndex == 3) {
      final schedules = _guidedAvailabilityFor(service);
      if (schedules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose at least one working day.')),
        );
        return false;
      }
      if (schedules.values.any(
        (schedule) => schedule.endMinutes <= schedule.startMinutes,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Closing time must be later than opening time.'),
          ),
        );
        return false;
      }
    }
    if (widget.existingServiceConfiguration) return true;
    if (!_changed) return true;
    setState(() => _saving = true);
    try {
      await _serviceStorage.upsert(service.copyWith(updatedAt: DateTime.now()));
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _changed = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this service.')),
      );
      return false;
    }
  }

  Future<void> _nextGuidedSection({bool nextService = false}) async {
    if (!await _saveGuidedChanges() || !mounted) return;
    final isLastSection =
        _reviewSectionIndex == _reviewSectionTitles.length - 1;
    if (widget.existingServiceConfiguration && isLastSection) {
      await _completeExistingServiceConfiguration();
      return;
    }
    if (!nextService && !isLastSection) {
      setState(() => _reviewSectionIndex++);
      return;
    }
    if (_reviewServiceIndex >= widget.reviewServiceIds.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _clearGuidedNewExtraFeedback();
      _reviewServiceIndex++;
      _reviewSectionIndex = 0;
      _service = null;
      _loading = true;
    });
    await _load();
  }

  Future<void> _useGuidedDefaultsAndContinue() async {
    final service = _service;
    if (service == null) return;
    if (_reviewSectionIndex == 2) {
      _resetGuidedExtras(service);
      await _nextGuidedSection();
      return;
    }
    if (_reviewSectionIndex == 3) {
      _restoreGuidedAvailabilityDefaults(service);
      await _nextGuidedSection(nextService: true);
      return;
    }
    await _nextGuidedSection(nextService: true);
  }

  Future<void> _previousGuidedSection() async {
    if (widget.existingServiceConfiguration) {
      if (_reviewSectionIndex > 0) {
        setState(() => _reviewSectionIndex--);
      } else {
        Navigator.of(context).pop(false);
      }
      return;
    }
    if (_reviewSectionIndex == 3) {
      setState(() => _reviewSectionIndex--);
      return;
    }
    if (!await _saveGuidedChanges() || !mounted) return;
    if (_reviewSectionIndex > 0) {
      setState(() => _reviewSectionIndex--);
      return;
    }
    if (_reviewServiceIndex == 0) {
      Navigator.of(context).pop(_changed);
      return;
    }
    setState(() {
      _clearGuidedNewExtraFeedback();
      _reviewServiceIndex--;
      _reviewSectionIndex = _reviewSectionTitles.length - 1;
      _service = null;
      _loading = true;
    });
    await _load();
  }

  Future<void> _completeExistingServiceConfiguration() async {
    final service = _service;
    if (service == null || _saving) return;
    if (!_changed) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    try {
      for (final questionId in service.linkedQuestionIds) {
        final question = _questionLookup[questionId];
        if (question != null) await _questionsStorage.upsert(question);
      }
      await _serviceStorage.upsert(service.copyWith(updatedAt: DateTime.now()));
      for (final removedQuestionId
          in _configurationOriginalQuestionIds.difference(
            service.linkedQuestionIds.toSet(),
          )) {
        await _deleteQuestionDefinitionIfUnused(removedQuestionId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save service configuration.')),
      );
    }
  }

  String _guidedTimeLabel(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Map<int, VanServiceDaySchedule> _guidedAvailabilityFor(
    VanJobService service,
  ) {
    if (_isGuidedReview && !widget.existingServiceConfiguration) {
      return _guidedAvailabilityDrafts[service.id] ??
          const <int, VanServiceDaySchedule>{};
    }
    return _guidedAvailabilityDrafts[service.id] ??
        service.effectiveAvailabilityByDay;
  }

  VanServiceDaySchedule _defaultGuidedDaySchedule(
    VanJobService service,
    int day,
  ) {
    final original = _guidedAvailabilityDefaults[service.id] ?? service;
    return original.effectiveAvailabilityByDay[day] ??
        VanServiceDaySchedule(
          startMinutes: original.businessStartMinutes,
          endMinutes: original.businessEndMinutes,
        );
  }

  void _setGuidedAvailability(
    VanJobService service,
    Map<int, VanServiceDaySchedule> schedules,
  ) {
    final sortedEntries = schedules.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final normalized = <int, VanServiceDaySchedule>{
      for (final entry in sortedEntries) entry.key: entry.value,
    };
    final representative = sortedEntries.firstOrNull?.value;
    setState(() {
      _guidedAvailabilityDrafts[service.id] = normalized;
      _service = service.copyWith(
        workingDays: sortedEntries.map((entry) => entry.key).toList(),
        businessStartMinutes:
            representative?.startMinutes ?? service.businessStartMinutes,
        businessEndMinutes:
            representative?.endMinutes ?? service.businessEndMinutes,
        availabilityByDay: normalized,
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
  }

  void _restoreGuidedAvailabilityDefaults(VanJobService service) {
    final original = _guidedAvailabilityDefaults[service.id] ?? service;
    final schedules = original.effectiveAvailabilityByDay;
    final sortedDays = schedules.keys.toList()..sort();
    setState(() {
      _guidedAvailabilityDrafts[service.id] = Map.of(schedules);
      _service = service.copyWith(
        workingDays: sortedDays,
        businessStartMinutes: original.businessStartMinutes,
        businessEndMinutes: original.businessEndMinutes,
        availabilityByDay: Map.of(schedules),
        appointmentDurationMinutes: original.appointmentDurationMinutes,
        noticeHours: original.noticeHours,
        maxBookingsPerDay: original.maxBookingsPerDay,
        updatedAt: DateTime.now(),
      );
      _changed = true;
    });
  }

  Future<void> _pickGuidedTime({
    required int day,
    required bool opening,
  }) async {
    final service = _service;
    if (service == null) return;
    final schedules = Map<int, VanServiceDaySchedule>.of(
      _guidedAvailabilityFor(service),
    );
    final schedule = schedules[day] ?? _defaultGuidedDaySchedule(service, day);
    final minutes = opening ? schedule.startMinutes : schedule.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    final value = picked.hour * 60 + picked.minute;
    schedules[day] = opening
        ? schedule.copyWith(startMinutes: value)
        : schedule.copyWith(endMinutes: value);
    _setGuidedAvailability(service, schedules);
  }

  Future<void> _applyGuidedHoursToOtherDays(
    VanJobService service,
    int sourceDay,
  ) async {
    final schedules = _guidedAvailabilityFor(service);
    final source = schedules[sourceDay];
    if (source == null) return;
    final targets = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _ApplyAvailabilityDaysDialog(sourceDay: sourceDay),
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    final updated = Map<int, VanServiceDaySchedule>.of(schedules);
    for (final day in targets) {
      updated[day] = source;
    }
    final current = _service;
    if (current != null && current.id == service.id) {
      _setGuidedAvailability(current, updated);
    }
  }

  Widget _buildGuidedFeatures(VanJobService service) {
    final capabilities = <VanServiceCapabilityDefinition>[
      for (final id in service.serviceCapabilityIds)
        for (final capability in kVanServiceCapabilities)
          if (capability.id == id) capability,
    ];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.customerJourneyType.selectorLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            service.customerJourneyType.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .68),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (capabilities.isEmpty)
            const _InfoChip(label: 'Standard service')
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final capability in capabilities)
                  Tooltip(
                    message: capability.description,
                    child: _InfoChip(label: capability.label),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saving ? null : _editServiceFeatures,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Edit service features'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Booking options',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          ..._requestFlowOptionTiles(service),
        ],
      ),
    );
  }

  Widget _buildGuidedQuestions(
    VanJobService service,
    List<_LinkedServiceQuestion> linkedQuestions,
    List<_AttachedBuiltInQuestion> builtInQuestions,
  ) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Preloaded questions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _InfoChip(
                label:
                    '${builtInQuestions.length + linkedQuestions.length} attached',
              ),
            ],
          ),
          if (builtInQuestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final question in builtInQuestions)
                  _AttachedQuestionChip(
                    label: question.label,
                    requiredValue: question.requiredValue,
                  ),
              ],
            ),
          ],
          if (linkedQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Drag to reorder. Each question can be edited, disabled or removed for this service only.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: linkedQuestions.length,
              onReorderItem: _reorderLinkedQuestions,
              itemBuilder: (context, index) {
                final linked = linkedQuestions[index];
                final enabled = !service.disabledLinkedQuestionIds.contains(
                  linked.id,
                );
                return _ResponsiveServiceQuestionRow(
                  key: ValueKey<String>(linked.id),
                  index: index,
                  questionId: linked.id,
                  title: linked.question.questionText,
                  metadata:
                      '${_linkedQuestionMetaLabel(linked.question)}${enabled ? '' : ' · Disabled'}',
                  enabled: enabled,
                  actionsEnabled: !_saving,
                  onToggleEnabled: () =>
                      _setLinkedQuestionEnabled(linked.id, !enabled),
                  onEdit: () => _editLinkedQuestion(linked.id, linked.question),
                  onRemove: () => _removeLinkedQuestion(linked.id),
                );
              },
            ),
          ],
          if (builtInQuestions.isEmpty && linkedQuestions.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No questions are attached yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: .68)),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _addQuestion,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add custom question'),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Question Library · Coming soon'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidedExtras(VanJobService service) {
    final extras = service.quoteExtraDefaults.orderedExtras;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing extras',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Set the optional charges you can quickly add to quotes for this service.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .66),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const Key('guided_extras_reset'),
                onPressed: _saving ? null : () => _resetGuidedExtras(service),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset defaults'),
              ),
              TextButton.icon(
                key: const Key('guided_extras_add_custom'),
                onPressed: _saving
                    ? null
                    : () => _addGuidedCustomExtra(service),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add custom extra'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (extras.isEmpty)
            Text(
              'No pricing extras are configured for this service.',
              style: TextStyle(color: Colors.white.withValues(alpha: .62)),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: extras.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorderGuidedExtras(service, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final extra = extras[index];
                final isNewExtra =
                    _guidedExtraDraftServiceId == service.id &&
                    _guidedNewExtraKey == extra.key;
                return Padding(
                  key: ValueKey<String>(
                    'guided-extra-${service.id}-${extra.key}',
                  ),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GuidedPricingExtraRow(
                    key: isNewExtra ? _guidedNewExtraRowKey : null,
                    serviceId: service.id,
                    extra: extra,
                    resetRevision: _guidedExtrasResetRevision,
                    showLabelField: isNewExtra,
                    highlighted:
                        _guidedExtraDraftServiceId == service.id &&
                        _guidedHighlightedExtraKey == extra.key,
                    onLabelChanged: (label) => _updateGuidedExtra(
                      service,
                      VanQuoteExtraDefault(
                        key: extra.key,
                        label: label,
                        defaultPrice: extra.defaultPrice,
                        enabled: extra.enabled,
                      ),
                    ),
                    onPriceChanged: (price) => _updateGuidedExtra(
                      service,
                      extra.copyWith(defaultPrice: price),
                    ),
                    onEnabledChanged: (enabled) => _updateGuidedExtra(
                      service,
                      extra.copyWith(enabled: enabled),
                    ),
                    onEditLabel: () => _editGuidedExtraLabel(service, extra),
                    onDelete: () => _deleteGuidedExtra(service, extra),
                    dragHandle: ReorderableDelayedDragStartListener(
                      index: index,
                      child: SizedBox(
                        key: ValueKey<String>(
                          'guided-extra-reorder-${service.id}-${extra.key}',
                        ),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.drag_handle_rounded, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGuidedAvailability(VanJobService service) {
    const dayLabels = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    const fullDayLabels = <int, String>{
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    final schedules = _guidedAvailabilityFor(service);
    final selectedDays = schedules.keys.toList()..sort();
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Working days',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final entry in dayLabels.entries)
                FilterChip(
                  key: ValueKey<String>('guided-availability-day-${entry.key}'),
                  label: Text(entry.value),
                  selected: schedules.containsKey(entry.key),
                  onSelected: _saving
                      ? null
                      : (selected) {
                          final updated = Map<int, VanServiceDaySchedule>.of(
                            schedules,
                          );
                          if (selected) {
                            updated[entry.key] = _defaultGuidedDaySchedule(
                              service,
                              entry.key,
                            );
                          } else {
                            updated.remove(entry.key);
                          }
                          _setGuidedAvailability(service, updated);
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedDays.isEmpty
                ? 'Choose the days this service is available.'
                : 'Each selected day can have different hours.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 12,
            ),
          ),
          if (selectedDays.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final day in selectedDays) ...[
              _GuidedDayScheduleCard(
                key: ValueKey<String>(
                  'guided-availability-schedule-${service.id}-$day',
                ),
                day: day,
                dayLabel: fullDayLabels[day]!,
                opensLabel: _guidedTimeLabel(schedules[day]!.startMinutes),
                closesLabel: _guidedTimeLabel(schedules[day]!.endMinutes),
                enabled: !_saving,
                onPickOpening: () => _pickGuidedTime(day: day, opening: true),
                onPickClosing: () => _pickGuidedTime(day: day, opening: false),
                onApplyToOtherDays: () =>
                    _applyGuidedHoursToOtherDays(service, day),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: service.appointmentDurationMinutes,
            decoration: const InputDecoration(labelText: 'Typical duration'),
            items:
                (<int>{
                      15,
                      30,
                      45,
                      60,
                      90,
                      120,
                      180,
                      240,
                      service.appointmentDurationMinutes,
                    }.toList()..sort())
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value minutes'),
                      ),
                    )
                    .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _service = service.copyWith(
                        appointmentDurationMinutes: value,
                      );
                      _changed = true;
                    });
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: service.noticeHours,
            decoration: const InputDecoration(labelText: 'Minimum notice'),
            items:
                (<int>{
                      0,
                      1,
                      2,
                      4,
                      12,
                      24,
                      48,
                      72,
                      168,
                      service.noticeHours,
                    }.toList()..sort())
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value == 0 ? 'No minimum' : '$value hours'),
                      ),
                    )
                    .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _service = service.copyWith(noticeHours: value);
                      _changed = true;
                    });
                  },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: service.maxBookingsPerDay,
            decoration: const InputDecoration(
              labelText: 'Maximum bookings per day',
            ),
            items:
                (<int>{
                      1,
                      2,
                      4,
                      6,
                      8,
                      10,
                      12,
                      16,
                      20,
                      service.maxBookingsPerDay,
                    }.toList()..sort())
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value bookings'),
                      ),
                    )
                    .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _service = service.copyWith(maxBookingsPerDay: value);
                      _changed = true;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildGuidedReviewPage(
    BuildContext context,
    VanJobService service,
    List<_LinkedServiceQuestion> linkedQuestions,
    List<_AttachedBuiltInQuestion> builtInQuestions,
  ) {
    final total = widget.reviewServiceIds.length;
    final sectionTitle = _reviewSectionTitles[_reviewSectionIndex];
    final isLastService = _reviewServiceIndex == total - 1;
    final isLastSection =
        _reviewSectionIndex == _reviewSectionTitles.length - 1;
    final section = switch (_reviewSectionIndex) {
      0 => _buildGuidedFeatures(service),
      1 => _buildGuidedQuestions(service, linkedQuestions, builtInQuestions),
      2 => _buildGuidedExtras(service),
      _ => _buildGuidedAvailability(service),
    };
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.existingServiceConfiguration
              ? 'Configure Service'
              : 'Review Services',
        ),
        leading: IconButton(
          onPressed: _saving ? null : _previousGuidedSection,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          if (widget.existingServiceConfiguration)
            TextButton(
              key: const Key('cancel_service_configuration'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: .38)),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                if (!widget.existingServiceConfiguration) ...[
                  Text(
                    'Service ${_reviewServiceIndex + 1} of $total',
                    key: const Key('service_review_progress'),
                    style: const TextStyle(
                      color: Color(0xFF91E8CE),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  service.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_reviewSectionIndex + 1} of ${_reviewSectionTitles.length} · $sectionTitle',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value:
                      ((_reviewServiceIndex * _reviewSectionTitles.length) +
                          _reviewSectionIndex +
                          1) /
                      (total * _reviewSectionTitles.length),
                ),
                const SizedBox(height: 14),
                section,
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('service_review_next'),
                    onPressed: _saving ? null : _nextGuidedSection,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isLastService && isLastSection
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(
                      widget.existingServiceConfiguration && isLastSection
                          ? 'Save and Return'
                          : isLastService && isLastSection
                          ? 'Finish Setup'
                          : isLastSection
                          ? 'Next Service'
                          : 'Next',
                    ),
                  ),
                ),
                if (!widget.existingServiceConfiguration) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('service_review_use_defaults'),
                      onPressed: _saving ? null : _useGuidedDefaultsAndContinue,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        _reviewSectionIndex == 2
                            ? 'Use Defaults & Continue'
                            : isLastService
                            ? 'Use Defaults & Finish'
                            : 'Use Defaults & Continue',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
    final builtInQuestions = service == null
        ? const <_AttachedBuiltInQuestion>[]
        : _builtInQuestionsForService(service);
    final configuredQuestionCount =
        builtInQuestions.length + linkedQuestions.length;

    if (_isGuidedReview && !_loading && service != null) {
      return _buildGuidedReviewPage(
        context,
        service,
        linkedQuestions,
        builtInQuestions,
      );
    }

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
                              'Journey',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              service.customerJourneyType.selectorLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              service.customerJourneyType.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                height: 1.4,
                                fontWeight: FontWeight.w600,
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
                              'Handover options',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Customers only see the start and end options enabled for this service.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (service.hasHandoverConfiguration)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final start
                                      in service
                                          .effectiveHandover
                                          .allowedStarts)
                                    _InfoChip(label: start.label),
                                  for (final end
                                      in service.effectiveHandover.allowedEnds)
                                    _InfoChip(label: end.label),
                                ],
                              )
                            else
                              Text(
                                'Legacy standard service — no item handover is configured.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .66),
                                ),
                              ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _configureService,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Configure in Service Wizard'),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Booking options',
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
                                  label: '$configuredQuestionCount attached',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (configuredQuestionCount == 0)
                              Text(
                                'No questions yet.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...[
                              if (builtInQuestions.isNotEmpty) ...[
                                Text(
                                  'Included customer details',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .62),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    for (final question in builtInQuestions)
                                      _AttachedQuestionChip(
                                        label: question.label,
                                        requiredValue: question.requiredValue,
                                      ),
                                  ],
                                ),
                                if (linkedQuestions.isNotEmpty)
                                  const SizedBox(height: 14),
                              ],
                              if (linkedQuestions.isNotEmpty)
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
                                        final question =
                                            linkedQuestion.question;
                                        final questionEnabled = !service
                                            .disabledLinkedQuestionIds
                                            .contains(linkedQuestion.id);
                                        return _ResponsiveServiceQuestionRow(
                                          key: ValueKey<String>(
                                            linkedQuestion.id,
                                          ),
                                          index: index,
                                          questionId: linkedQuestion.id,
                                          title: question.questionText,
                                          metadata:
                                              '${_linkedQuestionMetaLabel(question)}${questionEnabled ? '' : ' · Disabled'}',
                                          enabled: questionEnabled,
                                          actionsEnabled: !_saving,
                                          onToggleEnabled: () =>
                                              _setLinkedQuestionEnabled(
                                                linkedQuestion.id,
                                                !questionEnabled,
                                              ),
                                          onEdit: () => _editLinkedQuestion(
                                            linkedQuestion.id,
                                            question,
                                          ),
                                          onRemove: () => _removeLinkedQuestion(
                                            linkedQuestion.id,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                            ],
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
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Extras',
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
                                label: const Text('Edit extras'),
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

class _VanServiceFeaturesEditorPage extends StatefulWidget {
  const _VanServiceFeaturesEditorPage({
    required this.service,
    this.persistChanges = true,
  });

  final VanJobService service;
  final bool persistChanges;

  @override
  State<_VanServiceFeaturesEditorPage> createState() =>
      _VanServiceFeaturesEditorPageState();
}

class _VanServiceFeaturesEditorPageState
    extends State<_VanServiceFeaturesEditorPage> {
  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;
  late Set<String> _selectedCapabilityIds;
  late VanCustomerRequestFlowOptions _flowOptions;
  late bool _requestPhotos;
  late bool _requireAddress;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _selectedCapabilityIds = widget.service.serviceCapabilityIds.toSet();
    _flowOptions = widget.service.effectiveRequestFlowOptions;
    _requestPhotos = widget.service.requestPhotos;
    _requireAddress = widget.service.requireAddress;
  }

  void _toggleCapability(String capabilityId, bool selected) {
    setState(() {
      _selectedCapabilityIds = toggleVanServiceCapability(
        _selectedCapabilityIds,
        capabilityId,
        selected,
      );
      _dirty = true;
    });
  }

  void _updateFlowOptions(
    VanCustomerRequestFlowOptions Function(
      VanCustomerRequestFlowOptions current,
    )
    update,
  ) {
    setState(() {
      _flowOptions = update(_flowOptions);
      _dirty = true;
    });
  }

  bool _validateCapabilities() {
    final hasJourney = _selectedCapabilityIds.any(
      const <String>{
        VanServiceCapabilityIds.placeOrder,
        VanServiceCapabilityIds.requestQuote,
        VanServiceCapabilityIds.bookAppointment,
      }.contains,
    );
    if (!hasJourney) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose one customer journey.')),
      );
      return false;
    }
    final hasStart = _selectedCapabilityIds.any(
      const <String>{
        VanServiceCapabilityIds.customerDropsOff,
        VanServiceCapabilityIds.businessCollects,
      }.contains,
    );
    final hasEnd = _selectedCapabilityIds.any(
      const <String>{
        VanServiceCapabilityIds.customerCollects,
        VanServiceCapabilityIds.businessReturns,
      }.contains,
    );
    if (hasStart != hasEnd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose at least one matching start and end handover option.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final original = widget.service;
    if (!_dirty) {
      Navigator.of(context).pop(original);
      return;
    }
    if (!_validateCapabilities()) return;
    final resolved = resolveVanServiceCapabilities(
      _selectedCapabilityIds,
      recommendedDurationMinutes: original.appointmentDurationMinutes,
      recommendedNoticeHours: original.noticeHours,
    );
    final starts = <VanStartHandover>[
      if (resolved.allowCustomerDropOff) VanStartHandover.customerDropsOff,
      if (resolved.allowBusinessCollection) VanStartHandover.businessCollects,
    ];
    final ends = <VanEndHandover>[
      if (resolved.allowCustomerCollection) VanEndHandover.customerCollects,
      if (resolved.allowBusinessReturn) VanEndHandover.businessReturns,
    ];
    final existingStart = original.startHandover;
    final existingEnd = original.endHandover;
    final updated = original.copyWith(
      requestPhotos: _requestPhotos,
      requireAddress: _requireAddress,
      requestType: resolved.requestType,
      customerJourneyType: resolved.journeyType,
      startHandover: existingStart != null && starts.contains(existingStart)
          ? existingStart
          : starts.firstOrNull,
      endHandover: existingEnd != null && ends.contains(existingEnd)
          ? existingEnd
          : ends.firstOrNull,
      allowedStartHandoverOptions: starts,
      allowedEndHandoverOptions: ends,
      allowCustomerDropOff: resolved.allowCustomerDropOff,
      allowBusinessCollection: resolved.allowBusinessCollection,
      allowCustomerCollection: resolved.allowCustomerCollection,
      allowBusinessReturn: resolved.allowBusinessReturn,
      requestFlowOptions: _flowOptions,
      serviceCapabilityIds: resolved.capabilityIds,
      pricingMode: resolved.pricingMode,
      updatedAt: DateTime.now(),
    );
    if (!widget.persistChanges) {
      Navigator.of(context).pop(updated);
      return;
    }
    setState(() => _saving = true);
    try {
      await _storage.upsert(updated);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save service features.')),
      );
    }
  }

  Widget _flowSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    value: value,
    onChanged: _saving ? null : onChanged,
    title: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );

  List<Widget> _bookingOptionTiles(VanServiceFlow flow) {
    final tiles = <Widget>[];
    if (flow == VanServiceFlow.standard) {
      tiles.add(
        _flowSwitch(
          label: 'Customer address',
          value: _requireAddress,
          onChanged: (value) => setState(() {
            _requireAddress = value;
            _dirty = true;
          }),
        ),
      );
    } else if (flow == VanServiceFlow.pickupDelivery) {
      tiles.addAll(<Widget>[
        _flowSwitch(
          label: 'Pickup address',
          value: _flowOptions.showPickupAddress,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showPickupAddress: value),
          ),
        ),
        _flowSwitch(
          label: 'Delivery address',
          value: _flowOptions.showDeliveryAddress,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showDeliveryAddress: value),
          ),
        ),
      ]);
    } else {
      tiles.addAll(<Widget>[
        _flowSwitch(
          label: 'Drop-off date',
          value: _flowOptions.showDropOffDate,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showDropOffDate: value),
          ),
        ),
        _flowSwitch(
          label: 'Drop-off time',
          value: _flowOptions.showDropOffTime,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showDropOffTime: value),
          ),
        ),
        _flowSwitch(
          label: 'Pick-up date',
          value: _flowOptions.showPickUpDate,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showPickUpDate: value),
          ),
        ),
        _flowSwitch(
          label: 'Pick-up time',
          value: _flowOptions.showPickUpTime,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(showPickUpTime: value),
          ),
        ),
      ]);
    }
    if (flow != VanServiceFlow.dropOffPickup) {
      tiles.addAll(<Widget>[
        _flowSwitch(
          label: 'Preferred date',
          value: _flowOptions.askPreferredDate,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(askPreferredDate: value),
          ),
        ),
        _flowSwitch(
          label: 'Preferred time',
          value: _flowOptions.askPreferredTime,
          onChanged: (value) => _updateFlowOptions(
            (current) => current.copyWith(askPreferredTime: value),
          ),
        ),
      ]);
    }
    tiles.addAll(<Widget>[
      _flowSwitch(
        label: 'Notes',
        value: _flowOptions.showNotes,
        onChanged: (value) =>
            _updateFlowOptions((current) => current.copyWith(showNotes: value)),
      ),
      _flowSwitch(
        label: 'Photos',
        value: _requestPhotos,
        onChanged: (value) => setState(() {
          _requestPhotos = value;
          _dirty = true;
        }),
      ),
    ]);
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final resolved = resolveVanServiceCapabilities(
      _selectedCapabilityIds,
      recommendedDurationMinutes: service.appointmentDurationMinutes,
      recommendedNoticeHours: service.noticeHours,
    );
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Service Features'),
        leading: IconButton(
          key: const Key('cancel_service_features'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: .38)),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                _GlassCard(
                  key: ValueKey<String>('service_features_${service.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Edit only this service. Questions, extras and availability are kept as configured.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .68),
                          height: 1.4,
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
                        'Service features',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final group in VanServiceCapabilityGroup.values) ...[
                        Text(
                          group.label,
                          style: const TextStyle(
                            color: Color(0xFF91E8CE),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final capability in kVanServiceCapabilities)
                              if (capability.group == group)
                                FilterChip(
                                  key: ValueKey<String>(
                                    'service_feature_${capability.id}',
                                  ),
                                  selected: _selectedCapabilityIds.contains(
                                    capability.id,
                                  ),
                                  onSelected: _saving
                                      ? null
                                      : (selected) => _toggleCapability(
                                          capability.id,
                                          selected,
                                        ),
                                  label: Text(capability.label),
                                  tooltip: capability.description,
                                ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking options',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      ..._bookingOptionTiles(resolved.requestType.serviceFlow),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('save_service_features'),
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
                  label: const Text('Save Service Features'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VanJobServiceEditorPage extends StatelessWidget {
  const VanJobServiceEditorPage({
    super.key,
    this.initialService,
    this.duplicateFrom,
    this.suggestedName,
    this.starterTemplate,
  });

  final VanJobService? initialService;
  final VanJobService? duplicateFrom;
  final String? suggestedName;
  final VanServiceTemplate? starterTemplate;

  @override
  Widget build(BuildContext context) => VanServiceWizardPage(
    initialService: initialService,
    duplicateFrom: duplicateFrom,
    suggestedName: suggestedName,
    starterTemplate: starterTemplate,
  );
}

class _LegacyVanJobServiceEditorPage extends StatefulWidget {
  const _LegacyVanJobServiceEditorPage({
    required this.initialService,
    required this.suggestedName,
  });

  final VanJobService? initialService;
  final String? suggestedName;

  @override
  State<_LegacyVanJobServiceEditorPage> createState() =>
      _VanJobServiceEditorPageState();
}

class _VanJobServiceEditorPageState
    extends State<_LegacyVanJobServiceEditorPage> {
  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isActive = true;
  bool _requestPhotos = false;
  bool _requireAddress = true;
  bool _requestExactPinAfterQuoteAccepted = true;
  late VanCustomerJourneyType _customerJourneyType;
  late VanCustomerRequestType _requestType;
  late VanStartHandover _startHandover;
  late VanEndHandover _endHandover;
  late List<VanStartHandover> _allowedStartHandoverOptions;
  late List<VanEndHandover> _allowedEndHandoverOptions;
  late final TextEditingController _businessDropOffInstructionsController;
  late final TextEditingController _businessCollectionInstructionsController;
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
    _customerJourneyType =
        service?.customerJourneyType ??
        defaultVanCustomerJourneyTypeForService(
          serviceId: '',
          serviceName: widget.suggestedName ?? '',
        );
    _requestType =
        service?.requestType ??
        defaultVanServiceFlowForService(
          serviceId: '',
          serviceName: widget.suggestedName ?? '',
        ).requestType;
    final handover =
        service?.effectiveHandover ??
        VanServiceHandoverConfig.resolve(requestType: _requestType);
    _startHandover = handover.start;
    _endHandover = handover.end;
    _allowedStartHandoverOptions = handover.allowedStarts;
    _allowedEndHandoverOptions = handover.allowedEnds;
    _businessDropOffInstructionsController = TextEditingController(
      text: service?.businessDropOffInstructions ?? '',
    );
    _businessCollectionInstructionsController = TextEditingController(
      text: service?.businessCollectionInstructions ?? '',
    );
    _quoteExtraDefaults =
        service?.quoteExtraDefaults ?? VanQuoteExtraDefaults.empty();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _businessDropOffInstructionsController.dispose();
    _businessCollectionInstructionsController.dispose();
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
    final requestType = _requestType;
    final service = VanJobService(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      description: sanitizeVanText(_descriptionController.text).trim(),
      isActive: _isActive,
      requestPhotos: _requestPhotos,
      requireAddress: _requireAddress,
      requestExactPinAfterQuoteAccepted: _requestExactPinAfterQuoteAccepted,
      requestType: requestType,
      customerJourneyType: _customerJourneyType,
      startHandover: _startHandover,
      endHandover: _endHandover,
      allowedStartHandoverOptions: _allowedStartHandoverOptions,
      allowedEndHandoverOptions: _allowedEndHandoverOptions,
      businessDropOffInstructions: sanitizeVanText(
        _businessDropOffInstructionsController.text,
      ).trim(),
      businessCollectionInstructions: sanitizeVanText(
        _businessCollectionInstructionsController.text,
      ).trim(),
      requestFlowOptions:
          (existing != null && existing.serviceFlow == requestType.serviceFlow)
          ? existing.requestFlowOptions
          : VanCustomerRequestFlowOptions.defaultsFor(requestType),
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
                      const SizedBox(height: 12),
                      const Text(
                        'Customer journey',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose how customers buy or request this service.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          height: 1.4,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<VanCustomerJourneyType>(
                        key: ValueKey<VanCustomerJourneyType>(
                          _customerJourneyType,
                        ),
                        initialValue: _customerJourneyType,
                        dropdownColor: const Color(0xFF17253A),
                        iconEnabledColor: Colors.white70,
                        decoration: vanMateFieldDecoration(
                          label: 'Customer journey',
                          prefixIcon: const Icon(Icons.signpost_outlined),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          for (final type in VanCustomerJourneyType.values)
                            DropdownMenuItem<VanCustomerJourneyType>(
                              value: type,
                              child: Text(type.selectorLabel),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _customerJourneyType = value);
                              },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Service flow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose how this service is carried out.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          height: 1.4,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<VanServiceFlow>(
                        key: ValueKey<VanServiceFlow>(_requestType.serviceFlow),
                        initialValue: _requestType.serviceFlow,
                        dropdownColor: const Color(0xFF17253A),
                        iconEnabledColor: Colors.white70,
                        decoration: vanMateFieldDecoration(
                          label: 'Service flow',
                          prefixIcon: const Icon(Icons.alt_route_rounded),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          for (final flow in kVanServiceFlows)
                            DropdownMenuItem<VanServiceFlow>(
                              value: flow,
                              child: Text(flow.label),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                final defaults =
                                    VanServiceHandoverConfig.resolve(
                                      requestType: value.requestType,
                                    );
                                setState(() {
                                  _requestType = value.requestType;
                                  _requireAddress =
                                      value == VanServiceFlow.standard;
                                  _startHandover = defaults.start;
                                  _endHandover = defaults.end;
                                  _allowedStartHandoverOptions =
                                      defaults.allowedStarts;
                                  _allowedEndHandoverOptions =
                                      defaults.allowedEnds;
                                });
                              },
                      ),
                      if (vanRequestTypeSupportsHandover(_requestType)) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Start of service',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<VanStartHandover>(
                          initialValue: _startHandover,
                          dropdownColor: const Color(0xFF17253A),
                          decoration: vanMateFieldDecoration(
                            label: 'Start handover',
                          ),
                          items: [
                            for (final option in VanStartHandover.values)
                              DropdownMenuItem<VanStartHandover>(
                                value: option,
                                child: Text(option.label),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _startHandover = value;
                                      if (_allowedStartHandoverOptions.length <=
                                          1) {
                                        _allowedStartHandoverOptions =
                                            <VanStartHandover>[value];
                                      }
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'End of service',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<VanEndHandover>(
                          initialValue: _endHandover,
                          dropdownColor: const Color(0xFF17253A),
                          decoration: vanMateFieldDecoration(
                            label: 'End handover',
                          ),
                          items: [
                            for (final option in VanEndHandover.values)
                              DropdownMenuItem<VanEndHandover>(
                                value: option,
                                child: Text(option.label),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _endHandover = value;
                                      if (_allowedEndHandoverOptions.length <=
                                          1) {
                                        _allowedEndHandoverOptions =
                                            <VanEndHandover>[value];
                                      }
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        _InfoChip(
                          label: vanBusinessHandoverSummary(
                            _startHandover,
                            _endHandover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ServiceTextField(
                          controller: _businessDropOffInstructionsController,
                          label: 'Business drop-off location/instructions',
                          hint: 'Shown when the customer drops off or collects',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _ServiceTextField(
                          controller: _businessCollectionInstructionsController,
                          label: 'Business collection location/instructions',
                          hint: 'Shown when the customer collects at the end',
                          maxLines: 2,
                        ),
                      ],
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
                                    'Extras',
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
                                label: const Text('Edit extras'),
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

class _GuidedDayScheduleCard extends StatelessWidget {
  const _GuidedDayScheduleCard({
    super.key,
    required this.day,
    required this.dayLabel,
    required this.opensLabel,
    required this.closesLabel,
    required this.enabled,
    required this.onPickOpening,
    required this.onPickClosing,
    required this.onApplyToOtherDays,
  });

  final int day;
  final String dayLabel;
  final String opensLabel;
  final String closesLabel;
  final bool enabled;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;
  final VoidCallback onApplyToOtherDays;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .045),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dayLabel,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: ValueKey<String>('guided-availability-opens-$day'),
              onPressed: enabled ? onPickOpening : null,
              icon: const Icon(Icons.schedule_outlined, size: 17),
              label: Text('Opens $opensLabel'),
            ),
            OutlinedButton.icon(
              key: ValueKey<String>('guided-availability-closes-$day'),
              onPressed: enabled ? onPickClosing : null,
              icon: const Icon(Icons.schedule_outlined, size: 17),
              label: Text('Closes $closesLabel'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: ValueKey<String>('guided-availability-apply-$day'),
            onPressed: enabled ? onApplyToOtherDays : null,
            icon: const Icon(Icons.copy_all_outlined, size: 17),
            label: const Text('Apply to other days'),
          ),
        ),
      ],
    ),
  );
}

class _ApplyAvailabilityDaysDialog extends StatefulWidget {
  const _ApplyAvailabilityDaysDialog({required this.sourceDay});

  final int sourceDay;

  @override
  State<_ApplyAvailabilityDaysDialog> createState() =>
      _ApplyAvailabilityDaysDialogState();
}

class _ApplyAvailabilityDaysDialogState
    extends State<_ApplyAvailabilityDaysDialog> {
  final Set<int> _selectedDays = <int>{};

  static const _dayLabels = <int, String>{
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Apply hours to other days'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose every day that should use these same hours.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final entry in _dayLabels.entries)
              if (entry.key != widget.sourceDay)
                FilterChip(
                  key: ValueKey<String>('apply-availability-day-${entry.key}'),
                  label: Text(entry.value),
                  selected: _selectedDays.contains(entry.key),
                  onSelected: (selected) => setState(() {
                    selected
                        ? _selectedDays.add(entry.key)
                        : _selectedDays.remove(entry.key);
                  }),
                ),
          ],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('apply_availability_days'),
        onPressed: _selectedDays.isEmpty
            ? null
            : () => Navigator.of(context).pop(Set<int>.of(_selectedDays)),
        child: const Text('Apply hours'),
      ),
    ],
  );
}

class _GuidedExtraNameDialog extends StatefulWidget {
  const _GuidedExtraNameDialog({
    required this.title,
    required this.actionLabel,
    required this.fieldKey,
    this.initialValue = '',
  });

  final String title;
  final String actionLabel;
  final Key fieldKey;
  final String initialValue;

  @override
  State<_GuidedExtraNameDialog> createState() => _GuidedExtraNameDialogState();
}

class _GuidedExtraNameDialogState extends State<_GuidedExtraNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _value = widget.initialValue;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_value.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: TextFormField(
        key: widget.fieldKey,
        initialValue: widget.initialValue,
        autofocus: true,
        onChanged: (value) => _value = value,
        onFieldSubmitted: (_) => _submit(),
        validator: (value) =>
            (value ?? '').trim().isEmpty ? 'Enter an extra name.' : null,
        decoration: vanMateFieldDecoration(label: 'Extra name'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
    ],
  );
}

class _GuidedPricingExtraRow extends StatefulWidget {
  const _GuidedPricingExtraRow({
    super.key,
    required this.serviceId,
    required this.extra,
    required this.resetRevision,
    required this.showLabelField,
    required this.highlighted,
    required this.onLabelChanged,
    required this.onPriceChanged,
    required this.onEnabledChanged,
    required this.onEditLabel,
    required this.onDelete,
    required this.dragHandle,
  });

  final String serviceId;
  final VanQuoteExtraDefault extra;
  final int resetRevision;
  final bool showLabelField;
  final bool highlighted;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEditLabel;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  State<_GuidedPricingExtraRow> createState() => _GuidedPricingExtraRowState();
}

class _GuidedPricingExtraRowState extends State<_GuidedPricingExtraRow> {
  late final TextEditingController _labelController;
  late final TextEditingController _priceController;
  late final FocusNode _labelFocusNode;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.extra.label);
    _priceController = TextEditingController(
      text: _displayPrice(widget.extra.defaultPrice),
    );
    _labelFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_GuidedPricingExtraRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetRevision != widget.resetRevision) {
      _labelController.text = widget.extra.label;
      _priceController.text = _displayPrice(widget.extra.defaultPrice);
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _priceController.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  Future<void> focusLabelAndReveal() async {
    await Scrollable.ensureVisible(
      context,
      alignment: 0.15,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    if (mounted) _labelFocusNode.requestFocus();
  }

  String _displayPrice(double price) =>
      price == 0 ? '0' : price.toStringAsFixed(2);

  void _onPriceChanged(String raw) {
    final parsed = double.tryParse(raw.trim()) ?? 0;
    widget.onPriceChanged(parsed < 0 ? 0 : parsed);
  }

  @override
  Widget build(BuildContext context) {
    final keyPrefix = '${widget.serviceId}-${widget.extra.key}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        color: widget.highlighted
            ? const Color(0xFF58D0A4).withValues(alpha: .15)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: widget.highlighted
              ? const Color(0xFF58D0A4).withValues(alpha: .72)
              : Colors.white.withValues(alpha: .10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: widget.showLabelField
                    ? TextField(
                        key: ValueKey<String>('guided-extra-label-$keyPrefix'),
                        controller: _labelController,
                        focusNode: _labelFocusNode,
                        onChanged: widget.onLabelChanged,
                        style: kVanMateFieldTextStyle,
                        decoration: vanMateFieldDecoration(
                          label: 'Label',
                          hintText: 'Name this extra',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 11,
                          ),
                        ),
                      )
                    : Text(
                        widget.extra.resolvedLabel,
                        key: ValueKey<String>('guided-extra-title-$keyPrefix'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (!widget.showLabelField)
                IconButton(
                  key: ValueKey<String>('guided-extra-edit-$keyPrefix'),
                  tooltip: 'Edit extra name',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: widget.onEditLabel,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey<String>('guided-extra-price-$keyPrefix'),
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: _onPriceChanged,
                  style: kVanMateFieldTextStyle,
                  decoration: vanMateFieldDecoration(
                    label: 'Default price',
                    prefixText: '£',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Switch.adaptive(
                key: ValueKey<String>('guided-extra-enabled-$keyPrefix'),
                value: widget.extra.enabled,
                onChanged: widget.onEnabledChanged,
              ),
              IconButton(
                key: ValueKey<String>('guided-extra-delete-$keyPrefix'),
                tooltip: 'Remove extra',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
              widget.dragHandle,
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveServiceQuestionRow extends StatelessWidget {
  const _ResponsiveServiceQuestionRow({
    super.key,
    required this.index,
    required this.questionId,
    required this.title,
    required this.metadata,
    required this.enabled,
    required this.actionsEnabled,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onRemove,
  });

  final int index;
  final String questionId;
  final String title;
  final String metadata;
  final bool enabled;
  final bool actionsEnabled;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            '${index + 1}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w800,
              fontSize: 11.8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: ValueKey<String>('question_title_$questionId'),
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: enabled ? 0.88 : 0.58),
                  fontWeight: FontWeight.w700,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metadata,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: ValueKey<String>('question_visibility_$questionId'),
                      tooltip: enabled
                          ? 'Disable for this service'
                          : 'Enable for this service',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: actionsEnabled ? onToggleEnabled : null,
                      icon: Icon(
                        enabled
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('question_edit_$questionId'),
                      tooltip: 'Edit for this service',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: actionsEnabled ? onEdit : null,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 19,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('question_remove_$questionId'),
                      tooltip: 'Remove from this service',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: actionsEnabled ? onRemove : null,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                    ReorderableDelayedDragStartListener(
                      index: index,
                      enabled: actionsEnabled,
                      child: SizedBox(
                        key: ValueKey<String>('question_reorder_$questionId'),
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LinkedServiceQuestion {
  const _LinkedServiceQuestion({required this.id, required this.question});

  final String id;
  final VanCustomJobQuestion question;
}

class _AttachedBuiltInQuestion {
  const _AttachedBuiltInQuestion({
    required this.label,
    required this.requiredValue,
  });

  final String label;
  final bool requiredValue;
}

class _AttachedQuestionChip extends StatelessWidget {
  const _AttachedQuestionChip({
    required this.label,
    required this.requiredValue,
  });

  final String label;
  final bool requiredValue;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF66D6B5).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFF66D6B5).withValues(alpha: .28)),
    ),
    child: Text(
      '$label · ${requiredValue ? 'Required' : 'Optional'}',
      style: const TextStyle(
        color: Color(0xFF91E8CE),
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
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

class _ServiceListCard extends StatelessWidget {
  const _ServiceListCard({
    required this.service,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final VanJobService service;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
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
      onTap: onOpen,
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
                label: service.isDraft
                    ? 'Draft'
                    : (service.isActive ? 'Active' : 'Inactive'),
                color: service.isDraft
                    ? const Color(0xFFB8A1FF)
                    : service.isActive
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
              _InfoChip(label: '${service.configuredQuestionCount} questions'),
              _InfoChip(label: '${service.enabledQuoteExtraCount} extras'),
              _InfoChip(label: service.customerJourneyType.selectorLabel),
              _InfoChip(
                label: service.hasHandoverConfiguration
                    ? '${service.effectiveHandover.allowedStarts.length} start · ${service.effectiveHandover.allowedEnds.length} end'
                    : 'No handover',
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
              if (!service.isDraft)
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Duplicate'),
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
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
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
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: card,
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
