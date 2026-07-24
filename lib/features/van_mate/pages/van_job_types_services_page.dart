import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_availability_value.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_customer_journey.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_quote_extra_defaults.dart';
import '../models/van_service_capability.dart';
import '../models/van_service_configuration_draft.dart';
import '../models/van_service_template.dart';
import '../models/van_service_handover.dart';
import '../models/van_starter_capability_pack.dart';
import '../pages/van_service_question_editor_page.dart';
import '../pages/van_service_wizard_page.dart';
import '../services/van_business_hub_onboarding_storage.dart';
import '../services/van_business_profile_scope_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_job_services_storage.dart';
import '../services/van_service_configuration_repository.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

Future<void> openVanJobTypesServicesPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanJobTypesServicesPage()),
  );
}

Future<bool?> openVanExistingServiceEditor(
  BuildContext context, {
  required String serviceId,
}) {
  return openVanServiceConfiguration(context, serviceId: serviceId);
}

Future<bool?> openVanServiceConfiguration(
  BuildContext context, {
  required String serviceId,
  VanServiceConfigurationStage initialStage =
      VanServiceConfigurationStage.features,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => VanServiceConfigurationPage(
        serviceIds: <String>[serviceId],
        initialStage: initialStage,
      ),
    ),
  );
}

class VanServiceConfigurationPage extends StatelessWidget {
  const VanServiceConfigurationPage({
    required this.serviceIds,
    this.initialStage = VanServiceConfigurationStage.features,
    this.existingServiceConfiguration = true,
    this.initialService,
    this.initialServices = const <VanJobService>[],
    this.initialQuestions = const <VanCustomJobQuestion>[],
    super.key,
  }) : assert(
         serviceIds.length > 0 ||
             initialService != null ||
             initialServices.length > 0,
       );

  final List<String> serviceIds;
  final VanServiceConfigurationStage initialStage;
  final bool existingServiceConfiguration;
  final VanJobService? initialService;
  final List<VanJobService> initialServices;
  final List<VanCustomJobQuestion> initialQuestions;

  @override
  Widget build(BuildContext context) {
    final stagedServices = initialServices.isNotEmpty
        ? initialServices
        : initialService == null
        ? const <VanJobService>[]
        : <VanJobService>[initialService!];
    final resolvedServiceIds = serviceIds.isNotEmpty
        ? serviceIds
        : stagedServices.map((service) => service.id).toList(growable: false);
    final firstServiceId = resolvedServiceIds.first;
    return VanJobServiceDetailPage(
      serviceId: firstServiceId,
      reviewServiceIds: resolvedServiceIds,
      existingServiceConfiguration: existingServiceConfiguration,
      initialConfigurationStage: initialStage,
      initialConfigurationService: initialService,
      initialConfigurationServices: stagedServices,
      initialConfigurationQuestions: initialQuestions,
      stageChangesUntilCompletion: stagedServices.isNotEmpty,
    );
  }
}

class VanJobTypesServicesPage extends StatefulWidget {
  const VanJobTypesServicesPage({super.key});

  @override
  State<VanJobTypesServicesPage> createState() =>
      _VanJobTypesServicesPageState();
}

class _VanJobTypesServicesPageState extends State<VanJobTypesServicesPage> {
  final VanJobServicesStorage _storage = VanJobServicesStorage.instance;
  final VanServiceConfigurationRepository _configurationRepository =
      VanServiceConfigurationRepository();
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
        builder: (_) => const VanServiceCreationEntryPage(),
      ),
    );
    if (result == true || result is VanServiceCreationEntryResult) {
      await _loadServices(showLoader: false);
    }
    if (!mounted || result is! VanServiceCreationEntryResult) return;
    if (result.createdServiceIds.isNotEmpty) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => VanServiceConfigurationPage(
            serviceIds: result.createdServiceIds,
            existingServiceConfiguration: false,
            initialServices: result.pendingServices,
            initialQuestions: result.pendingQuestions,
          ),
        ),
      );
      if (!mounted) return;
      await _loadServices(showLoader: false);
      if (!mounted) return;
      if (completed != true) return;
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
    final edited = await openVanServiceConfiguration(
      context,
      serviceId: service.id,
    );
    if (edited == true) await _loadServices(showLoader: false);
  }

  Future<void> _duplicateService(VanJobService service) async {
    final now = DateTime.now();
    final duplicate = service.copyWith(
      id: 'service_${now.microsecondsSinceEpoch}',
      name: '${service.name} copy',
      createdAt: now,
      updatedAt: now,
      isDraft: false,
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VanServiceConfigurationPage(
          serviceIds: const <String>[],
          initialService: duplicate,
        ),
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
    await _configurationRepository.deleteServiceAndOwnedQuestions(service);
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
    this.initialConfigurationStage = VanServiceConfigurationStage.features,
    this.initialConfigurationService,
    this.initialConfigurationServices = const <VanJobService>[],
    this.initialConfigurationQuestions = const <VanCustomJobQuestion>[],
    this.stageChangesUntilCompletion = false,
  });

  final String serviceId;
  final List<String> reviewServiceIds;
  final bool existingServiceConfiguration;
  final VanServiceConfigurationStage initialConfigurationStage;
  final VanJobService? initialConfigurationService;
  final List<VanJobService> initialConfigurationServices;
  final List<VanCustomJobQuestion> initialConfigurationQuestions;
  final bool stageChangesUntilCompletion;

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
  final VanServiceConfigurationRepository _configurationRepository =
      VanServiceConfigurationRepository();

  VanJobService? _service;
  Map<String, VanCustomJobQuestion> _questionLookup =
      <String, VanCustomJobQuestion>{};
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  bool _checkedSettingsHelp = false;
  int _reviewServiceIndex = 0;
  int _reviewSectionIndex = 0;
  VanServiceConfigurationDraft? _configurationDraft;
  final Map<String, VanJobService> _stagedServices = <String, VanJobService>{};
  final Map<String, VanCustomJobQuestion> _stagedQuestions =
      <String, VanCustomJobQuestion>{};
  String? _configurationBusinessProfileId;
  int _guidedExtrasResetRevision = 0;
  String _guidedExtraDraftServiceId = '';
  String? _guidedNewExtraKey;
  String? _guidedHighlightedExtraKey;
  GlobalKey<_GuidedPricingExtraRowState>? _guidedNewExtraRowKey;
  final Map<String, VanJobService> _guidedAvailabilityDefaults =
      <String, VanJobService>{};
  final Map<String, VanQuoteExtraDefaults> _guidedExtrasDefaults =
      <String, VanQuoteExtraDefaults>{};
  final Map<String, Map<int, VanServiceDaySchedule>> _guidedAvailabilityDrafts =
      <String, Map<int, VanServiceDaySchedule>>{};
  final Set<String> _guidedAvailabilityInvalidServiceIds = <String>{};

  static const _reviewSectionTitles = <String>[
    'Service Features',
    'Customer Questions',
    'Pricing Extras',
    'Availability',
  ];

  bool get _isGuidedReview => widget.reviewServiceIds.isNotEmpty;
  bool get _stagesConfigurationChanges =>
      widget.existingServiceConfiguration || widget.stageChangesUntilCompletion;
  String get _activeServiceId => _isGuidedReview
      ? widget.reviewServiceIds[_reviewServiceIndex]
      : widget.serviceId;

  @override
  void initState() {
    super.initState();
    _stagedServices.addEntries(
      widget.initialConfigurationServices.map(
        (service) => MapEntry<String, VanJobService>(service.id, service),
      ),
    );
    _stagedQuestions.addEntries(
      widget.initialConfigurationQuestions.map(
        (question) =>
            MapEntry<String, VanCustomJobQuestion>(question.id, question),
      ),
    );
    _reviewSectionIndex = widget.initialConfigurationStage.index;
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
      ..._stagedQuestions,
    };
    final service =
        services.where((item) => item.id == _activeServiceId).firstOrNull ??
        _stagedServices[_activeServiceId] ??
        (widget.initialConfigurationService?.id == _activeServiceId
            ? widget.initialConfigurationService
            : null);
    _configurationBusinessProfileId ??= await VanBusinessProfileScopeStorage
        .instance
        .activeBusinessId();
    VanServiceConfigurationDraft? configurationDraft = _configurationDraft;
    if (widget.existingServiceConfiguration &&
        configurationDraft == null &&
        service != null) {
      final businessProfileId = await VanBusinessProfileScopeStorage.instance
          .activeBusinessId();
      final linkedIds = service.linkedQuestionIds.toSet();
      final linkedQuestions = <String, VanCustomJobQuestion>{
        for (final entry in lookup.entries)
          if (linkedIds.contains(entry.key)) entry.key: entry.value,
      };
      configurationDraft = VanServiceConfigurationDraft(
        businessProfileId: businessProfileId,
        mode: widget.initialConfigurationService == null
            ? (service.isDraft
                  ? VanServiceConfigurationMode.resumedDraft
                  : VanServiceConfigurationMode.existing)
            : VanServiceConfigurationMode.duplicate,
        originalService: widget.initialConfigurationService == null
            ? service
            : null,
        service: service,
        originalQuestions: widget.initialConfigurationService == null
            ? linkedQuestions
            : const <String, VanCustomJobQuestion>{},
        questions: linkedQuestions,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _service = service;
      if ((_isGuidedReview || widget.existingServiceConfiguration) &&
          service != null) {
        _guidedAvailabilityDefaults.putIfAbsent(service.id, () => service);
        _guidedExtrasDefaults.putIfAbsent(
          service.id,
          () => service.quoteExtraDefaults,
        );
      }
      _questionLookup = lookup;
      _configurationDraft = configurationDraft;
      if (widget.initialConfigurationService != null ||
          (widget.existingServiceConfiguration && service?.isDraft == true)) {
        _changed = true;
      }
      _loading = false;
    });
  }

  Future<void> _editService() async {
    await _configureService(
      initialStage: VanServiceConfigurationStage.questions,
    );
  }

  Future<void> _configureService({
    VanServiceConfigurationStage initialStage =
        VanServiceConfigurationStage.features,
  }) async {
    final service = _service;
    if (service == null) return;
    final changed = await openVanServiceConfiguration(
      context,
      serviceId: service.id,
      initialStage: initialStage,
    );
    if (changed != true || !mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _changed = true);
  }

  void _setGuidedCapability(
    VanJobService service,
    String capabilityId,
    bool selected,
  ) {
    final selectedIds = toggleVanServiceCapability(
      service.serviceCapabilityIds.toSet(),
      capabilityId,
      selected,
    );
    final resolved = resolveVanServiceCapabilities(
      selectedIds,
      recommendedDurationMinutes: service.appointmentDurationMinutes,
      recommendedNoticeHours: service.noticeHours.ceil(),
    );
    final starts = <VanStartHandover>[
      if (resolved.allowCustomerDropOff) VanStartHandover.customerDropsOff,
      if (resolved.allowBusinessCollection) VanStartHandover.businessCollects,
    ];
    final ends = <VanEndHandover>[
      if (resolved.allowCustomerCollection) VanEndHandover.customerCollects,
      if (resolved.allowBusinessReturn) VanEndHandover.businessReturns,
      if (resolved.allowBusinessDelivery) VanEndHandover.businessDelivers,
    ];
    final updated = service.copyWith(
      requestType: resolved.requestType,
      customerJourneyType: resolved.journeyType,
      startHandover: starts.contains(service.startHandover)
          ? service.startHandover
          : starts.firstOrNull,
      endHandover: ends.contains(service.endHandover)
          ? service.endHandover
          : ends.firstOrNull,
      allowedStartHandoverOptions: starts,
      allowedEndHandoverOptions: ends,
      allowCustomerDropOff: resolved.allowCustomerDropOff,
      allowBusinessCollection: resolved.allowBusinessCollection,
      allowCustomerCollection: resolved.allowCustomerCollection,
      allowBusinessReturn: resolved.allowBusinessReturn,
      allowBusinessDelivery: resolved.allowBusinessDelivery,
      serviceCapabilityIds: resolved.capabilityIds,
      pricingMode: resolved.pricingMode,
      updatedAt: DateTime.now(),
    );
    setState(() {
      _service = updated;
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
    if (_stagesConfigurationChanges) {
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
    if (service == null) return;
    await _configureService(initialStage: VanServiceConfigurationStage.extras);
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
        _guidedExtrasDefaults[service.id] ??
        service.quoteExtraDefaults;
  }

  void _updateGuidedExtras(
    VanJobService service,
    VanQuoteExtraDefaults defaults,
  ) {
    final changed =
        defaults.toJson().toString() !=
        service.quoteExtraDefaults.toJson().toString();
    setState(() {
      _service = service.copyWith(
        quoteExtraDefaults: defaults,
        updatedAt: changed ? DateTime.now() : service.updatedAt,
      );
      _changed = _changed || changed;
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

    if (_stagesConfigurationChanges) {
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
    if (_stagesConfigurationChanges) {
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
    if (_stagesConfigurationChanges) {
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
    ValueChanged<bool>? onChanged,
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

  List<Widget> _requestFlowOptionTiles(
    VanJobService service, {
    bool readOnly = false,
  }) {
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
          onChanged: readOnly
              ? null
              : (enabled) =>
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
            onChanged: readOnly
                ? null
                : (enabled) {
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
        onChanged: readOnly
            ? null
            : (enabled) {
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
    if (_reviewSectionIndex == 0 &&
        (service.serviceCapabilityIds.isNotEmpty ||
            (widget.stageChangesUntilCompletion &&
                !widget.existingServiceConfiguration))) {
      final capabilityIds = service.serviceCapabilityIds.toSet();
      final hasJourney = capabilityIds.any(
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
    }
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
      if (_guidedAvailabilityInvalidServiceIds.contains(service.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fix the custom availability values.')),
        );
        return false;
      }
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
    if (widget.stageChangesUntilCompletion) {
      _stagedServices[service.id] = service;
      for (final questionId in service.linkedQuestionIds) {
        final question = _questionLookup[questionId];
        if (question != null) _stagedQuestions[questionId] = question;
      }
      return true;
    }
    if (widget.existingServiceConfiguration) return true;
    if (!_changed) return true;
    setState(() => _saving = true);
    try {
      await _serviceStorage.upsert(
        service.copyWith(isDraft: false, updatedAt: DateTime.now()),
      );
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
    if (widget.stageChangesUntilCompletion &&
        isLastSection &&
        _reviewServiceIndex >= widget.reviewServiceIds.length - 1) {
      await _completeNewServiceSession();
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
    await _nextGuidedSection();
  }

  Future<void> _previousGuidedSection() async {
    if (widget.stageChangesUntilCompletion &&
        !widget.existingServiceConfiguration) {
      final service = _service;
      if (service != null) _stagedServices[service.id] = service;
      if (_reviewSectionIndex > 0) {
        setState(() => _reviewSectionIndex--);
        return;
      }
      if (_reviewServiceIndex == 0) {
        Navigator.of(context).pop(false);
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
      return;
    }
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
    final originalDraft = _configurationDraft;
    if (service == null || _saving) return;
    if (!_changed) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    try {
      if (originalDraft == null) {
        throw StateError('Service configuration was not loaded.');
      }
      final linkedQuestions = <String, VanCustomJobQuestion>{};
      for (final questionId in service.linkedQuestionIds) {
        final question = _questionLookup[questionId];
        if (question != null) linkedQuestions[questionId] = question;
      }
      await _configurationRepository.commit(
        originalDraft.copyWith(
          service: service.copyWith(isDraft: false),
          questions: linkedQuestions,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is VanServiceConfigurationConflict
                ? error.message
                : 'Could not save service configuration.',
          ),
        ),
      );
    }
  }

  Future<void> _completeNewServiceSession() async {
    if (_saving) return;
    final businessProfileId = _configurationBusinessProfileId;
    if (businessProfileId == null || businessProfileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service configuration was not loaded.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final orderedServices = <VanJobService>[];
      for (final serviceId in widget.reviewServiceIds) {
        final service = _stagedServices[serviceId];
        if (service != null) orderedServices.add(service);
      }
      if (orderedServices.length != widget.reviewServiceIds.length) {
        throw StateError('One or more service drafts could not be loaded.');
      }
      final linkedQuestionIds = <String>{
        for (final service in orderedServices) ...service.linkedQuestionIds,
      };
      final questions = <String, VanCustomJobQuestion>{
        for (final entry in _stagedQuestions.entries)
          if (linkedQuestionIds.contains(entry.key)) entry.key: entry.value,
      };
      await _configurationRepository.commitNewSession(
        businessProfileId: businessProfileId,
        services: orderedServices,
        questions: questions,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is VanServiceConfigurationConflict
                ? error.message
                : 'Could not save these services. Please try again.',
          ),
        ),
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
    final restored = service.copyWith(
      workingDays: sortedDays,
      businessStartMinutes: original.businessStartMinutes,
      businessEndMinutes: original.businessEndMinutes,
      availabilityByDay: original.availabilityByDay,
      clearAvailabilityByDay: original.availabilityByDay == null,
      appointmentDurationMinutes: original.appointmentDurationMinutes,
      noticeHours: original.noticeHours,
      maxBookingsPerDay: original.maxBookingsPerDay,
      updatedAt: service.updatedAt,
    );
    final changed = restored.toJson().toString() != service.toJson().toString();
    setState(() {
      _guidedAvailabilityInvalidServiceIds.remove(service.id);
      _guidedAvailabilityDrafts[service.id] = Map.of(schedules);
      _service = restored.copyWith(
        updatedAt: changed ? DateTime.now() : service.updatedAt,
      );
      _changed = _changed || changed;
    });
  }

  void _setGuidedAvailabilityValues(VanJobService service) {
    setState(() {
      _service = service.copyWith(updatedAt: DateTime.now());
      _changed = true;
    });
  }

  void _setGuidedAvailabilityValuesValid(String serviceId, bool valid) {
    setState(() {
      if (valid) {
        _guidedAvailabilityInvalidServiceIds.remove(serviceId);
      } else {
        _guidedAvailabilityInvalidServiceIds.add(serviceId);
      }
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
          if (service.serviceCapabilityIds.isEmpty) ...[
            const _InfoChip(label: 'Standard service'),
            const SizedBox(height: 12),
          ],
          const Text(
            'Service features',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
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
                      key: ValueKey<String>('service_feature_${capability.id}'),
                      selected: service.serviceCapabilityIds.contains(
                        capability.id,
                      ),
                      onSelected: _saving
                          ? null
                          : (selected) => _setGuidedCapability(
                              service,
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
          _GuidedAvailabilityValueFields(
            key: ValueKey<String>('guided-availability-values-${service.id}'),
            service: service,
            enabled: !_saving,
            onChanged: _setGuidedAvailabilityValues,
            onValidityChanged: (valid) =>
                _setGuidedAvailabilityValuesValid(service.id, valid),
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
      resizeToAvoidBottomInset: true,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        onPressed: _saving
                            ? null
                            : _useGuidedDefaultsAndContinue,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          isLastService && isLastSection
                              ? 'Use Defaults & Finish'
                              : 'Use Defaults & Continue',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
                            ..._requestFlowOptionTiles(service, readOnly: true),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              key: const Key('edit_service_booking_options'),
                              onPressed: _saving ? null : _configureService,
                              icon: const Icon(Icons.tune_outlined),
                              label: const Text('Edit booking options'),
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
                                      onReorderItem: (_, _) {},
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
                                          actionsEnabled: false,
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
                                  child: OutlinedButton.icon(
                                    key: const Key('edit_service_questions'),
                                    onPressed: canAddQuestions
                                        ? _editService
                                        : null,
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
                              onChanged: null,
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

class _GuidedAvailabilityValueFields extends StatefulWidget {
  const _GuidedAvailabilityValueFields({
    super.key,
    required this.service,
    required this.enabled,
    required this.onChanged,
    required this.onValidityChanged,
  });

  final VanJobService service;
  final bool enabled;
  final ValueChanged<VanJobService> onChanged;
  final ValueChanged<bool> onValidityChanged;

  @override
  State<_GuidedAvailabilityValueFields> createState() =>
      _GuidedAvailabilityValueFieldsState();
}

class _GuidedAvailabilityValueFieldsState
    extends State<_GuidedAvailabilityValueFields> {
  static const String _custom = 'custom';

  late final TextEditingController _durationController;
  late final TextEditingController _noticeController;
  late final TextEditingController _bookingLimitController;
  late final FocusNode _durationFocus;
  late final FocusNode _noticeFocus;
  late final FocusNode _bookingLimitFocus;
  late bool _customDuration;
  late bool _customNotice;
  late bool _customBookingLimit;
  late VanAvailabilityValueUnit _durationUnit;
  late VanAvailabilityValueUnit _noticeUnit;
  String? _durationError;
  String? _noticeError;
  String? _bookingLimitError;

  @override
  void initState() {
    super.initState();
    final duration = widget.service.appointmentDurationMinutes;
    _customDuration = !kVanDurationPresetMinutes.contains(duration);
    _durationUnit = _customDuration && duration % 60 == 0
        ? VanAvailabilityValueUnit.hours
        : VanAvailabilityValueUnit.minutes;
    _durationController = TextEditingController(
      text: _durationUnit == VanAvailabilityValueUnit.hours
          ? '${duration ~/ 60}'
          : '$duration',
    );

    final noticeMinutes = (widget.service.noticeHours * 60).round();
    _customNotice = !kVanNoticePresetHours.contains(widget.service.noticeHours);
    _noticeUnit = noticeMinutes % 60 == 0
        ? VanAvailabilityValueUnit.hours
        : VanAvailabilityValueUnit.minutes;
    _noticeController = TextEditingController(
      text: _noticeUnit == VanAvailabilityValueUnit.hours
          ? '${noticeMinutes ~/ 60}'
          : '$noticeMinutes',
    );

    _customBookingLimit = !kVanBookingLimitPresets.contains(
      widget.service.maxBookingsPerDay,
    );
    _bookingLimitController = TextEditingController(
      text: '${widget.service.maxBookingsPerDay}',
    );
    _durationFocus = FocusNode();
    _noticeFocus = FocusNode();
    _bookingLimitFocus = FocusNode();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _noticeController.dispose();
    _bookingLimitController.dispose();
    _durationFocus.dispose();
    _noticeFocus.dispose();
    _bookingLimitFocus.dispose();
    super.dispose();
  }

  void _focus(FocusNode focusNode, TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void _reportValidity() {
    widget.onValidityChanged(
      _durationError == null &&
          _noticeError == null &&
          _bookingLimitError == null,
    );
  }

  void _validateDuration() {
    final error = validateVanCustomDuration(
      _durationController.text,
      _durationUnit,
    );
    setState(() => _durationError = error);
    if (error == null) {
      final minutes = normalizeVanCustomDurationMinutes(
        _durationController.text,
        _durationUnit,
      )!;
      widget.onChanged(
        widget.service.copyWith(appointmentDurationMinutes: minutes),
      );
    }
    _reportValidity();
  }

  void _validateNotice() {
    final error = validateVanCustomNotice(_noticeController.text, _noticeUnit);
    setState(() => _noticeError = error);
    if (error == null) {
      final hours = normalizeVanCustomNoticeHours(
        _noticeController.text,
        _noticeUnit,
      )!;
      widget.onChanged(widget.service.copyWith(noticeHours: hours));
    }
    _reportValidity();
  }

  void _validateBookingLimit() {
    final error = validateVanCustomBookingLimit(_bookingLimitController.text);
    setState(() => _bookingLimitError = error);
    if (error == null) {
      final bookings = normalizeVanCustomBookingLimit(
        _bookingLimitController.text,
      )!;
      widget.onChanged(widget.service.copyWith(maxBookingsPerDay: bookings));
    }
    _reportValidity();
  }

  String _durationSelection() => _customDuration
      ? _custom
      : 'preset:${widget.service.appointmentDurationMinutes}';

  String _noticeSelection() {
    if (_customNotice) return _custom;
    final preset = kVanNoticePresetHours.firstWhere(
      (value) => value == widget.service.noticeHours,
      orElse: () => widget.service.noticeHours,
    );
    return 'preset:$preset';
  }

  String _bookingLimitSelection() => _customBookingLimit
      ? _custom
      : 'preset:${widget.service.maxBookingsPerDay}';

  @override
  Widget build(BuildContext context) {
    final durationSelection = _durationSelection();
    final noticeSelection = _noticeSelection();
    final bookingLimitSelection = _bookingLimitSelection();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const Key('guided-duration-dropdown'),
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('duration-$durationSelection'),
            initialValue: durationSelection,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Typical duration'),
            items: <DropdownMenuItem<String>>[
              for (final value in kVanDurationPresetMinutes)
                DropdownMenuItem<String>(
                  value: 'preset:$value',
                  child: Text('$value minutes'),
                ),
              const DropdownMenuItem<String>(
                value: _custom,
                child: Text('Custom duration…'),
              ),
            ],
            selectedItemBuilder: (context) => <Widget>[
              for (final value in kVanDurationPresetMinutes)
                Text('$value minutes'),
              Text(
                formatVanDurationMinutes(
                  widget.service.appointmentDurationMinutes,
                ),
              ),
            ],
            onChanged: !widget.enabled
                ? null
                : (selection) {
                    if (selection == null) return;
                    if (selection == _custom) {
                      setState(() {
                        _customDuration = true;
                        _durationError = null;
                      });
                      _reportValidity();
                      _focus(_durationFocus, _durationController);
                      return;
                    }
                    final value = int.parse(selection.split(':').last);
                    _durationFocus.unfocus();
                    setState(() {
                      _customDuration = false;
                      _durationError = null;
                    });
                    widget.onChanged(
                      widget.service.copyWith(
                        appointmentDurationMinutes: value,
                      ),
                    );
                    _reportValidity();
                  },
          ),
        ),
        if (_customDuration) ...[
          const SizedBox(height: 8),
          _CustomAvailabilityInputRow(
            fieldKey: const Key('guided-custom-duration-input'),
            unitKey: const Key('guided-custom-duration-unit'),
            controller: _durationController,
            focusNode: _durationFocus,
            label: 'Custom duration',
            errorText: _durationError,
            unit: _durationUnit,
            units: const <VanAvailabilityValueUnit>[
              VanAvailabilityValueUnit.minutes,
              VanAvailabilityValueUnit.hours,
            ],
            enabled: widget.enabled,
            onChanged: (_) => _validateDuration(),
            onUnitChanged: (unit) {
              setState(() => _durationUnit = unit);
              _validateDuration();
            },
          ),
        ],
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('guided-notice-dropdown'),
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('notice-$noticeSelection'),
            initialValue: noticeSelection,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Minimum notice'),
            items: <DropdownMenuItem<String>>[
              for (final value in kVanNoticePresetHours)
                DropdownMenuItem<String>(
                  value: 'preset:$value',
                  child: Text(
                    value == 0 ? 'No minimum' : '${value.toInt()} hours',
                  ),
                ),
              const DropdownMenuItem<String>(
                value: _custom,
                child: Text('Custom notice…'),
              ),
            ],
            selectedItemBuilder: (context) => <Widget>[
              for (final value in kVanNoticePresetHours)
                Text(value == 0 ? 'No minimum' : '${value.toInt()} hours'),
              Text(formatVanNoticeHours(widget.service.noticeHours)),
            ],
            onChanged: !widget.enabled
                ? null
                : (selection) {
                    if (selection == null) return;
                    if (selection == _custom) {
                      setState(() {
                        _customNotice = true;
                        _noticeError = null;
                      });
                      _reportValidity();
                      _focus(_noticeFocus, _noticeController);
                      return;
                    }
                    final value = num.parse(selection.split(':').last);
                    _noticeFocus.unfocus();
                    setState(() {
                      _customNotice = false;
                      _noticeError = null;
                    });
                    widget.onChanged(
                      widget.service.copyWith(noticeHours: value),
                    );
                    _reportValidity();
                  },
          ),
        ),
        if (_customNotice) ...[
          const SizedBox(height: 8),
          _CustomAvailabilityInputRow(
            fieldKey: const Key('guided-custom-notice-input'),
            unitKey: const Key('guided-custom-notice-unit'),
            controller: _noticeController,
            focusNode: _noticeFocus,
            label: 'Custom minimum notice',
            errorText: _noticeError,
            unit: _noticeUnit,
            units: const <VanAvailabilityValueUnit>[
              VanAvailabilityValueUnit.minutes,
              VanAvailabilityValueUnit.hours,
              VanAvailabilityValueUnit.days,
            ],
            enabled: widget.enabled,
            onChanged: (_) => _validateNotice(),
            onUnitChanged: (unit) {
              setState(() => _noticeUnit = unit);
              _validateNotice();
            },
          ),
        ],
        const SizedBox(height: 10),
        KeyedSubtree(
          key: const Key('guided-booking-limit-dropdown'),
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('booking-limit-$bookingLimitSelection'),
            initialValue: bookingLimitSelection,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Maximum bookings per day',
            ),
            items: <DropdownMenuItem<String>>[
              for (final value in kVanBookingLimitPresets)
                DropdownMenuItem<String>(
                  value: 'preset:$value',
                  child: Text(formatVanBookingLimit(value)),
                ),
              const DropdownMenuItem<String>(
                value: _custom,
                child: Text('Custom booking limit…'),
              ),
            ],
            selectedItemBuilder: (context) => <Widget>[
              for (final value in kVanBookingLimitPresets)
                Text(formatVanBookingLimit(value)),
              Text(formatVanBookingLimit(widget.service.maxBookingsPerDay)),
            ],
            onChanged: !widget.enabled
                ? null
                : (selection) {
                    if (selection == null) return;
                    if (selection == _custom) {
                      setState(() {
                        _customBookingLimit = true;
                        _bookingLimitError = null;
                      });
                      _reportValidity();
                      _focus(_bookingLimitFocus, _bookingLimitController);
                      return;
                    }
                    final value = int.parse(selection.split(':').last);
                    _bookingLimitFocus.unfocus();
                    setState(() {
                      _customBookingLimit = false;
                      _bookingLimitError = null;
                    });
                    widget.onChanged(
                      widget.service.copyWith(maxBookingsPerDay: value),
                    );
                    _reportValidity();
                  },
          ),
        ),
        if (_customBookingLimit) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('guided-custom-booking-limit-input'),
            controller: _bookingLimitController,
            focusNode: _bookingLimitFocus,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Custom booking limit',
              suffixText: 'per day',
              errorText: _bookingLimitError,
            ),
            onChanged: (_) => _validateBookingLimit(),
            onSubmitted: (_) => _bookingLimitFocus.unfocus(),
          ),
        ],
      ],
    );
  }
}

class _CustomAvailabilityInputRow extends StatelessWidget {
  const _CustomAvailabilityInputRow({
    required this.fieldKey,
    required this.unitKey,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.errorText,
    required this.unit,
    required this.units,
    required this.enabled,
    required this.onChanged,
    required this.onUnitChanged,
  });

  final Key fieldKey;
  final Key unitKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? errorText;
  final VanAvailabilityValueUnit unit;
  final List<VanAvailabilityValueUnit> units;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<VanAvailabilityValueUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label, errorText: errorText),
            onChanged: onChanged,
            onSubmitted: (_) => focusNode.unfocus(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<VanAvailabilityValueUnit>(
            key: unitKey,
            initialValue: unit,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              for (final value in units)
                DropdownMenuItem<VanAvailabilityValueUnit>(
                  value: value,
                  child: Text(_unitLabel(value)),
                ),
            ],
            onChanged: !enabled
                ? null
                : (value) {
                    if (value != null) onUnitChanged(value);
                  },
          ),
        ),
      ],
    );
  }

  static String _unitLabel(VanAvailabilityValueUnit unit) => switch (unit) {
    VanAvailabilityValueUnit.minutes => 'Minutes',
    VanAvailabilityValueUnit.hours => 'Hours',
    VanAvailabilityValueUnit.days => 'Days',
  };
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
  const _GlassCard({required this.child, this.onTap});

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
