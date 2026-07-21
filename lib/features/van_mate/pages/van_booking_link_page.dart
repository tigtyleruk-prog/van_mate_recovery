import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_business_logo_support.dart';
import '../helpers/van_customer_request_questions.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_customer_journey.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_service_handover.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../pages/van_job_types_services_page.dart';
import '../services/van_booking_link_cloud_service.dart';
import '../services/van_booking_link_settings_storage.dart';
import '../services/van_business_profile_scope_storage.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_firebase_auth_service.dart';
import '../services/van_job_request_cloud_service.dart';
import '../services/van_job_services_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

Future<void> openVanBookingLinkPage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanBookingLinkPage()));
}

class VanBookingLinkPage extends StatefulWidget {
  const VanBookingLinkPage({super.key});

  @override
  State<VanBookingLinkPage> createState() => _VanBookingLinkPageState();
}

class _VanBookingLinkPageState extends State<VanBookingLinkPage> {
  static const Duration _loadTimeout = Duration(seconds: 12);
  static final String _defaultBusinessName =
      VanBusinessProfile.defaults().businessName;

  final TextEditingController _titleController = TextEditingController();
  final VanBookingLinkSettingsStorage _settingsStorage =
      VanBookingLinkSettingsStorage.instance;
  final VanBookingLinkCloudService _cloudService =
      VanBookingLinkCloudService.instance;
  final VanBusinessProfileStorage _profileStorage =
      VanBusinessProfileStorage.instance;
  final VanJobServicesStorage _servicesStorage = VanJobServicesStorage.instance;
  final VanCustomJobQuestionsStorage _questionsStorage =
      VanCustomJobQuestionsStorage.instance;

  bool _loading = true;
  bool _linkActive = true;
  String _shareLink = 'https://vanmate-56eac.web.app/booking_link.html';
  VanBusinessProfile _profile = const VanBusinessProfile.defaults();
  List<VanJobService> _activeServices = const <VanJobService>[];
  Map<String, VanCustomJobQuestion> _questionLookup =
      const <String, VanCustomJobQuestion>{};
  String _ownerUid = '';
  String _publicConfigId = '';
  bool _publicSyncSucceeded = false;
  String? _errorMessage;
  Timer? _saveTitleDebounce;

  @override
  void dispose() {
    _saveTitleDebounce?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[BookingLinkPage] opened');
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    debugPrint('[BookingLinkPage] load start');
    try {
      final localResults = await Future.wait<dynamic>([
        _profileStorage.load(),
        _servicesStorage.loadAll(),
        _questionsStorage.loadAll(),
        _settingsStorage.isActive(),
        _settingsStorage.loadTitle(),
      ]).timeout(_loadTimeout);

      _applyLoadedState(localResults, source: 'local');

      try {
        debugPrint(
          '[BookingLinkPage] cloud hydration start paths=users/{uid}/van_business_profile, users/{uid}/van_job_services/library, users/{uid}/van_custom_job_questions/library, users/{uid}/van_booking_link_settings/settings',
        );
        await Future.wait<dynamic>([
          _profileStorage.loadFromCloud(),
          _servicesStorage.loadFromCloud(),
          _questionsStorage.loadFromCloud(),
          _settingsStorage.loadFromCloud(),
        ]).timeout(_loadTimeout);
      } catch (error) {
        debugPrint('[BookingLinkPage] cloud hydration error error=$error');
        if (mounted) {
          setState(() {
            _errorMessage =
                'Could not refresh Booking Link from Firebase. Showing saved data.';
          });
        }
      }

      final refreshedResults = await Future.wait<dynamic>([
        _profileStorage.load(),
        _servicesStorage.loadAll(),
        _questionsStorage.loadAll(),
        _settingsStorage.isActive(),
        _settingsStorage.loadTitle(),
      ]).timeout(_loadTimeout);

      debugPrint(
        '[BookingLinkPage] local/cloud data loaded activeServices=${(refreshedResults[1] as List<VanJobService>).where((service) => service.isActive && !service.isArchived).length} questionCount=${(refreshedResults[2] as List<VanCustomJobQuestion>).length}',
      );

      _applyLoadedState(refreshedResults, source: 'hydrated');
    } catch (error) {
      debugPrint('[BookingLinkPage] load error error=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage =
            'Could not load Booking Link right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      debugPrint('[BookingLinkPage] load complete loading=$_loading');
      unawaited(_resolveOwnerUidAndPublish());
    }
  }

  void _applyLoadedState(List<dynamic> results, {required String source}) {
    final profile = results[0] as VanBusinessProfile;
    final allServices = results[1] as List<VanJobService>;
    final customQuestions = results[2] as List<VanCustomJobQuestion>;
    final linkActive = results[3] as bool;
    final linkTitle = results[4] as String;

    final activeServices =
        allServices
            .where((service) => service.isActive && !service.isArchived)
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final sanitizedServices = activeServices
        .map((service) {
          final filteredIds = service.linkedQuestionIds
              .where((id) => !service.disabledLinkedQuestionIds.contains(id))
              .toList(growable: false);
          if (filteredIds.length == service.linkedQuestionIds.length) {
            return service;
          }
          return service.copyWith(
            linkedQuestionIds: List<String>.unmodifiable(filteredIds),
          );
        })
        .toList(growable: false);

    final questionLookup = <String, VanCustomJobQuestion>{
      for (final question in customQuestions) question.id: question,
    };
    debugPrint(
      '[BookingLinkPage] apply state source=$source activeServices=${activeServices.length} questionLookup=${questionLookup.length}',
    );

    if (!mounted) {
      return;
    }

    // Keep the controller as the profile-scoped override only. Business Profile
    // branding is the public fallback when this value is empty.
    _titleController.text = linkTitle.trim();
    setState(() {
      _profile = profile;
      _activeServices = sanitizedServices;
      _questionLookup = questionLookup;
      _linkActive = linkActive;
      if (source == 'hydrated') {
        _errorMessage = null;
      }
    });
  }

  Future<void> _resolveOwnerUidAndPublish() async {
    try {
      debugPrint('[BookingLinkPage] auth resolve start');
      final ownerUid = await VanFirebaseAuthService.instance
          .ensureCurrentUid(source: 'van_mate.booking_link_setup')
          .timeout(_loadTimeout);
      final linkSeed = ownerUid?.trim() ?? '';
      final activeBusinessId = await VanBusinessProfileScopeStorage.instance
          .activeBusinessId()
          .timeout(_loadTimeout);
      final publicConfigId = await VanBusinessProfileScopeStorage.instance
          .bookingLinkPublicConfigId(linkSeed)
          .timeout(_loadTimeout);
      debugPrint(
        '[BookingLinkPage] identity resolved uid=${linkSeed.isEmpty ? '(none)' : linkSeed} businessProfileId=$activeBusinessId publicConfigId=${publicConfigId.isEmpty ? '(none)' : publicConfigId}',
      );
      final shareLink = linkSeed.isEmpty
          ? 'https://vanmate-56eac.web.app/booking_link.html'
          : 'https://vanmate-56eac.web.app/booking_link.html?owner=$publicConfigId';

      if (!mounted) {
        return;
      }
      setState(() {
        _ownerUid = linkSeed;
        _publicConfigId = publicConfigId;
        _shareLink = shareLink;
        _publicSyncSucceeded = false;
      });

      if (linkSeed.isEmpty) {
        debugPrint('[BookingLinkPage] publish skipped uid=(none)');
        return;
      }

      debugPrint(
        '[BookingLinkPage] publish start uid=$linkSeed path=public_booking_links/$publicConfigId activeServices=${_activeServices.length}',
      );
      await _cloudService
          .savePublicConfig(
            ownerUid: linkSeed,
            publicConfigId: publicConfigId,
            businessProfileId: activeBusinessId,
            title: _titleController.text.trim(),
            isActive: _linkActive,
            profile: _profile,
            activeServices: _activeServices,
            questionLookup: _questionLookup,
          )
          .timeout(_loadTimeout);
      debugPrint('[BookingLinkPage] publish success uid=$linkSeed');
      if (mounted) {
        setState(() {
          _publicSyncSucceeded = true;
          _errorMessage = null;
        });
      }
    } catch (error) {
      debugPrint('[BookingLinkPage] publish error error=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _publicSyncSucceeded = false;
        _errorMessage =
            'Could not sync your Booking Link to Firestore. You can still review setup and retry.';
      });
    }
  }

  Future<void> _setLinkActive(bool value) async {
    setState(() {
      _linkActive = value;
    });
    await _settingsStorage.setActive(value);
    await _publishBookingLinkConfig();
  }

  String _effectiveBusinessName(String rawName) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty) {
      return '';
    }
    if (cleaned.toLowerCase() == _defaultBusinessName.toLowerCase()) {
      return '';
    }
    return cleaned;
  }

  String get _visibleBookingLinkLabel {
    final customHeading = _titleController.text.trim();
    if (customHeading.isNotEmpty) {
      return 'Booking link for $customHeading';
    }
    final businessName = _effectiveBusinessName(_profile.businessName);
    if (businessName.isEmpty) {
      return 'Your booking link is ready';
    }
    return 'Booking link for $businessName';
  }

  Future<void> _publishBookingLinkConfig() async {
    final normalizedOwnerUid = _ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      debugPrint('[BookingLinkPage] publish skipped uid=(none)');
      return;
    }
    final normalizedPublicConfigId = _publicConfigId.trim().isEmpty
        ? normalizedOwnerUid
        : _publicConfigId.trim();
    try {
      debugPrint(
        '[BookingLinkPage] publish retry uid=$normalizedOwnerUid path=public_booking_links/$normalizedPublicConfigId activeServices=${_activeServices.length}',
      );
      await _cloudService
          .savePublicConfig(
            ownerUid: normalizedOwnerUid,
            publicConfigId: normalizedPublicConfigId,
            businessProfileId: await VanBusinessProfileScopeStorage.instance
                .activeBusinessId(),
            title: _titleController.text.trim(),
            isActive: _linkActive,
            profile: _profile,
            activeServices: _activeServices,
            questionLookup: _questionLookup,
          )
          .timeout(_loadTimeout);
      if (!mounted) {
        return;
      }
      setState(() {
        _publicSyncSucceeded = true;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('[BookingLinkPage] publish retry error error=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _publicSyncSucceeded = false;
        _errorMessage =
            'Could not sync your Booking Link to Firestore. Please try again.';
      });
    }
  }

  void _handleTitleChanged(String value) {
    setState(() {});
    _saveTitleDebounce?.cancel();
    _saveTitleDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_settingsStorage.saveTitle(value));
      unawaited(_publishBookingLinkConfig());
    });
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareLink));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking Link copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareLinkAction() async {
    final businessName = _effectiveBusinessName(_profile.businessName);
    final hasBusinessName = businessName.isNotEmpty;
    final bookingLinkTitle = hasBusinessName
        ? '$businessName Booking Link'
        : 'Booking Request';
    final leadLine = hasBusinessName
        ? '$businessName has sent you a booking link.'
        : 'You have received a booking request.';
    const descriptionLine = 'Choose a service and tell us what you need.';
    final sharedUrl = _appendShareVersionParam(_shareLink);
    await SharePlus.instance.share(
      ShareParams(
        text: '$leadLine\n\n$descriptionLine\n$sharedUrl',
        subject: bookingLinkTitle,
      ),
    );
  }

  String _appendShareVersionParam(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final separator = trimmed.contains('?') ? '&' : '?';
    const shareVersion = 'v=20260601';
    if (trimmed.contains('v=')) {
      return trimmed;
    }
    return '$trimmed$separator$shareVersion';
  }

  Future<void> _openCustomerPreview() async {
    if (_activeServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one active service first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    VanBusinessProfile latestProfile = _profile;
    try {
      // Always re-read from local storage before preview to avoid stale in-memory
      // state after Business Profile edits.
      latestProfile = await _profileStorage.load().timeout(_loadTimeout);
      final hasCloudLogo =
          resolveSavedVanBusinessLogoUrl(latestProfile.logoUrl) != null;
      final hasLocalLogo =
          resolveSavedVanBusinessLogoPath(latestProfile.logoPath) != null;
      // Best-effort cloud refresh only when neither cloud nor local logo is available.
      if (!hasCloudLogo && !hasLocalLogo) {
        await _profileStorage.loadFromCloud().timeout(_loadTimeout);
        latestProfile = await _profileStorage.load().timeout(_loadTimeout);
      }
    } catch (error) {
      debugPrint('[BookingLinkPage] preview profile reload error error=$error');
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _profile = latestProfile;
    });

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VanBookingLinkCustomerFormPage(
          profile: latestProfile,
          activeServices: _activeServices,
          questionLookup: _questionLookup,
          bookingLinkActive: _linkActive,
          bookingLinkUrl: _shareLink,
          bookingLinkTitle: _titleController.text.trim(),
        ),
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
        title: const Text('Booking Link'),
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Booking Link',
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
                              'Share this link with customers so they can choose a service, answer your questions and send a request.',
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
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _BookingLinkErrorCard(
                          message: _errorMessage!,
                          onRetry: _loadData,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Custom public heading (optional)',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _BookingTextField(
                              controller: _titleController,
                              label: 'Custom public heading',
                              hint: 'Optional heading shown to customers',
                              icon: Icons.title_rounded,
                              onChanged: _handleTitleChanged,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Leave blank to use your Business Profile name.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
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
                              'Link status',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _linkActive,
                              onChanged: _setLinkActive,
                              title: Text(
                                _linkActive && _publicSyncSucceeded
                                    ? 'Booking Link is active'
                                    : _linkActive
                                    ? 'Booking Link is not live yet'
                                    : 'Booking Link is inactive',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _linkActive && _publicSyncSucceeded
                                    ? 'Customers can submit new requests.'
                                    : _linkActive
                                    ? 'Your setup is saved locally, but customers cannot use the public link until Firestore sync succeeds.'
                                    : 'Disable intake while you update services or questions.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.35,
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
                            const Text(
                              'Public link',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _visibleBookingLinkLabel,
                              style: const TextStyle(
                                color: Color(0xFF8AB4FF),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use Copy link or Share link to send this to customers.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: FilledButton.icon(
                                    onPressed: _copyLink,
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Copy link'),
                                  ),
                                ),
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: _shareLinkAction,
                                    icon: const Icon(Icons.share_outlined),
                                    label: const Text('Share link'),
                                  ),
                                ),
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton.icon(
                                    onPressed: _openCustomerPreview,
                                    icon: const Icon(Icons.preview_outlined),
                                    label: const Text('Preview customer form'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Customers choose a service and tell you what they need. New requests appear in Incoming Jobs.',
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
                              'Active services in this link',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_activeServices.isEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No services created yet. Add a service before sharing this booking link.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: () => unawaited(
                                      openVanJobTypesServicesPage(context),
                                    ),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Add services'),
                                  ),
                                ],
                              )
                            else
                              for (
                                var i = 0;
                                i < _activeServices.length;
                                i++
                              ) ...[
                                _ServiceRow(
                                  service: _activeServices[i],
                                  questionCount: _activeServices[i]
                                      .configuredQuestionCount,
                                ),
                                if (i < _activeServices.length - 1)
                                  Divider(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    height: 18,
                                  ),
                              ],
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
}

class VanBookingLinkCustomerFormPage extends StatefulWidget {
  const VanBookingLinkCustomerFormPage({
    super.key,
    required this.profile,
    required this.activeServices,
    required this.questionLookup,
    required this.bookingLinkActive,
    required this.bookingLinkUrl,
    required this.bookingLinkTitle,
  });

  final VanBusinessProfile profile;
  final List<VanJobService> activeServices;
  final Map<String, VanCustomJobQuestion> questionLookup;
  final bool bookingLinkActive;
  final String bookingLinkUrl;
  final String bookingLinkTitle;

  @override
  State<VanBookingLinkCustomerFormPage> createState() =>
      _VanBookingLinkCustomerFormPageState();
}

class _VanBookingLinkCustomerFormPageState
    extends State<VanBookingLinkCustomerFormPage> {
  static final String _defaultBusinessName =
      VanBusinessProfile.defaults().businessName;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _returnAddressController =
      TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _preferredDateController =
      TextEditingController();
  final TextEditingController _timingNoteController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers =
      <String, TextEditingController>{};
  final Map<String, String> _choiceAnswers = <String, String>{};
  final List<XFile> _selectedPhotos = <XFile>[];

  String? _selectedServiceId;
  DateTime? _preferredDate;
  String _preferredTimeWindow = 'anytime';
  bool _preferredIsFlexible = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _returnAddressSameAsCollection = false;
  String _clientSubmissionId = '';
  VanStartHandover? _selectedStartHandover;
  VanEndHandover? _selectedEndHandover;
  String _confirmationRequestId = '';

  VanJobService? get _selectedService {
    final selectedId = _selectedServiceId?.trim() ?? '';
    if (selectedId.isEmpty) {
      return null;
    }
    for (final service in widget.activeServices) {
      if (service.id == selectedId) {
        return service;
      }
    }
    return null;
  }

  int get _photoLimit => (_selectedService?.maxCustomerPhotos ?? 5).clamp(1, 5);

  VanCustomerJourneyCopy get _journeyCopy =>
      (_selectedService?.customerJourneyType ?? VanCustomerJourneyType.quote)
          .copy;

  VanStartHandover? get _effectiveStartHandover {
    final service = _selectedService;
    if (service == null || !service.hasHandoverConfiguration) {
      return null;
    }
    return _selectedStartHandover ?? service.effectiveHandover.start;
  }

  VanEndHandover? get _effectiveEndHandover {
    final service = _selectedService;
    if (service == null || !service.hasHandoverConfiguration) {
      return null;
    }
    return _selectedEndHandover ?? service.effectiveHandover.end;
  }

  List<VanCustomJobQuestion> get _selectedServiceQuestions {
    final service = _selectedService;
    if (service == null) {
      return const <VanCustomJobQuestion>[];
    }
    final questions = <VanCustomJobQuestion>[];
    for (final id in service.linkedQuestionIds) {
      final question = widget.questionLookup[id];
      if (question != null &&
          question.isActive &&
          !question.isArchived &&
          !isVanSeededQuestionCoveredByBuiltInFlow(
            service: service,
            question: question,
          )) {
        questions.add(question);
      }
    }
    return questions;
  }

  String get _customerFacingBusinessTitle {
    final businessName = _effectiveBusinessName(widget.profile.businessName);
    if (businessName.isNotEmpty) {
      return businessName;
    }
    return 'Booking Link';
  }

  String _effectiveBusinessName(String rawName) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty) {
      return '';
    }
    if (cleaned.toLowerCase() == _defaultBusinessName.toLowerCase()) {
      return '';
    }
    return cleaned;
  }

  String _normalizePostcode(String value) {
    final upper = value.toUpperCase();
    final plain = upper.replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
    return plain.trim();
  }

  String? get _customerFacingCustomHeading {
    final heading = widget.bookingLinkTitle.trim();
    if (heading.isEmpty) {
      return null;
    }
    if (heading.toLowerCase() == _customerFacingBusinessTitle.toLowerCase()) {
      return null;
    }
    return heading;
  }

  Widget _buildBusinessLogo() {
    final logoUrl = resolveSavedVanBusinessLogoUrl(widget.profile.logoUrl);
    if (logoUrl != null) {
      return buildVanBusinessLogoPreview(
        widget.profile.logoPath,
        logoUrl: logoUrl,
      );
    }

    final localLogoPath = resolveSavedVanBusinessLogoPath(
      widget.profile.logoPath,
    );
    if (localLogoPath != null) {
      return buildVanBusinessLogoPreview(localLogoPath);
    }
    return buildVanBusinessLogoPreview(localLogoPath);
  }

  @override
  void initState() {
    super.initState();
    if (widget.activeServices.length == 1) {
      _selectedServiceId = widget.activeServices.first.id;
      _syncQuestionControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _returnAddressController.dispose();
    _postcodeController.dispose();
    _preferredDateController.dispose();
    _timingNoteController.dispose();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncQuestionControllers() {
    final selectedIds = _selectedServiceQuestions
        .map((question) => question.id)
        .toSet();
    _answerControllers.removeWhere((id, controller) {
      if (selectedIds.contains(id)) {
        return false;
      }
      controller.dispose();
      return true;
    });
    _choiceAnswers.removeWhere((id, _) => !selectedIds.contains(id));
    for (final question in _selectedServiceQuestions) {
      if (_needsTextController(question.answerType)) {
        _answerControllers.putIfAbsent(question.id, TextEditingController.new);
      }
    }
  }

  bool _needsTextController(VanCustomQuestionAnswerType answerType) {
    switch (answerType) {
      case VanCustomQuestionAnswerType.shortText:
      case VanCustomQuestionAnswerType.longText:
      case VanCustomQuestionAnswerType.date:
      case VanCustomQuestionAnswerType.time:
      case VanCustomQuestionAnswerType.photoUploadRequest:
        return true;
      case VanCustomQuestionAnswerType.yesNo:
      case VanCustomQuestionAnswerType.multipleChoice:
        return false;
    }
  }

  String _readQuestionAnswer(VanCustomJobQuestion question) {
    switch (question.answerType) {
      case VanCustomQuestionAnswerType.yesNo:
      case VanCustomQuestionAnswerType.multipleChoice:
        return _choiceAnswers[question.id]?.trim() ?? '';
      case VanCustomQuestionAnswerType.shortText:
      case VanCustomQuestionAnswerType.longText:
      case VanCustomQuestionAnswerType.date:
      case VanCustomQuestionAnswerType.time:
      case VanCustomQuestionAnswerType.photoUploadRequest:
        return _answerControllers[question.id]?.text.trim() ?? '';
    }
  }

  bool _validateSubmission() {
    if (!widget.bookingLinkActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking Link is currently inactive.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final service = _selectedService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a service first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (service.showsBuiltInQuestion('phone') &&
        service.requiresBuiltInQuestion('phone', legacyDefault: true) &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your phone number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (service.showsBuiltInQuestion('email') &&
        service.requiresBuiltInQuestion('email') &&
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your email address.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (service.requireAddress &&
        !service.hasHandoverConfiguration &&
        _addressController.text.trim().isEmpty &&
        _postcodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an address or postcode for this service.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final startHandover = _effectiveStartHandover;
    final endHandover = _effectiveEndHandover;
    if (startHandover?.needsCustomerAddress == true &&
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add the business collection address.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    final effectiveReturnAddress = _returnAddressSameAsCollection
        ? _addressController.text.trim()
        : _returnAddressController.text.trim();
    if (endHandover?.needsCustomerAddress == true &&
        effectiveReturnAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add the business return address.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    for (final question in _selectedServiceQuestions) {
      if (service.optionalQuestionIds.contains(question.id)) {
        continue;
      }
      if (_readQuestionAnswer(question).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please answer: ${question.questionText}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }

    if (service.requestPhotos &&
        service.requiresBuiltInQuestion('photos') &&
        _selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one photo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final requiresPreferredTiming =
        service.requiresBuiltInQuestion('preferred_date') ||
        service.requiresBuiltInQuestion('preferred_time');
    final preferredTimingMessage = requiresPreferredTiming
        ? validateVanMatePreferredBookingWindow(
            preferredDate: _preferredDate,
            preferredTimeWindow: _preferredTimeWindow,
            preferredIsFlexible: _preferredIsFlexible,
          )
        : null;
    if (preferredTimingMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(preferredTimingMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    return true;
  }

  bool get _requiresPreferredTiming =>
      _selectedService?.requiresBuiltInQuestion('preferred_date') == true ||
      _selectedService?.requiresBuiltInQuestion('preferred_time') == true;

  bool get _hasValidPreferredTimingSelection =>
      !_requiresPreferredTiming ||
      validateVanMatePreferredBookingWindow(
            preferredDate: _preferredDate,
            preferredTimeWindow: _preferredTimeWindow,
            preferredIsFlexible: _preferredIsFlexible,
          ) ==
          null;

  String? get _preferredTimingValidationMessage => !_requiresPreferredTiming
      ? null
      : validateVanMatePreferredBookingWindow(
          preferredDate: _preferredDate,
          preferredTimeWindow: _preferredTimeWindow,
          preferredIsFlexible: _preferredIsFlexible,
        );

  String _formatDate(DateTime date) {
    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _preferredTimeWindowLabel(String window) {
    switch (window.trim().toLowerCase()) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'evening':
        return 'Evening';
      default:
        return 'Anytime / Flexible';
    }
  }

  Future<void> _pickPreferredDate() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final initial = _preferredDate == null
        ? today
        : (_preferredDate!.isBefore(today) ? today : _preferredDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _preferredDate = DateUtils.dateOnly(picked);
      _preferredDateController.text = _formatDate(_preferredDate!);
    });
  }

  Future<List<Map<String, String>>> _buildSubmitPhotoPayload() async {
    final payload = <Map<String, String>>[];
    for (final photo in _selectedPhotos) {
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) {
        continue;
      }
      final fileName = photo.name.trim().isEmpty
          ? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : photo.name.trim();
      payload.add(<String, String>{
        'fileName': fileName,
        'contentType': photo.mimeType?.trim().isNotEmpty == true
            ? photo.mimeType!.trim()
            : 'image/jpeg',
        'dataBase64': base64Encode(bytes),
      });
    }
    return payload;
  }

  bool get _hasPhotoCapacity => _selectedPhotos.length < _photoLimit;

  void _showPhotoLimitMessage() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You can add up to 5 photos.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<_PhotoSourceChoice?> _showPhotoSourceSheet() {
    return showModalBottomSheet<_PhotoSourceChoice>(
      context: context,
      backgroundColor: const Color(0xFF13233A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Take photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_PhotoSourceChoice.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Choose from gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_PhotoSourceChoice.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.white70),
                  title: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(null);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPhotos() async {
    if (!_hasPhotoCapacity) {
      _showPhotoLimitMessage();
      return;
    }

    try {
      final source = await _showPhotoSourceSheet();
      if (source == null || !mounted) {
        return;
      }

      if (source == _PhotoSourceChoice.camera) {
        final captured = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 82,
          requestFullMetadata: false,
        );
        if (captured == null || !mounted) {
          return;
        }
        if (!_hasPhotoCapacity) {
          _showPhotoLimitMessage();
          return;
        }
        setState(() {
          if (_selectedPhotos.every(
            (existing) => existing.path != captured.path,
          )) {
            _selectedPhotos.add(captured);
          }
        });
        return;
      }

      final remainingSlots = _photoLimit - _selectedPhotos.length;
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 82,
        limit: remainingSlots > 0 ? remainingSlots : null,
        requestFullMetadata: false,
      );
      if (picked.isNotEmpty) {
        setState(() {
          for (final file in picked.take(remainingSlots)) {
            if (_selectedPhotos.every(
              (existing) => existing.path != file.path,
            )) {
              _selectedPhotos.add(file);
            }
          }
        });
        return;
      }
      final single = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (single != null && mounted) {
        if (!_hasPhotoCapacity) {
          _showPhotoLimitMessage();
          return;
        }
        setState(() {
          if (_selectedPhotos.every(
            (existing) => existing.path != single.path,
          )) {
            _selectedPhotos.add(single);
          }
        });
      }
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (!mounted) {
        return;
      }
      if (code.contains('camera') &&
          (code.contains('denied') || code.contains('permission'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is needed to take a photo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open photo picker.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open photo picker.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeSelectedPhotoAt(int index) {
    if (index < 0 || index >= _selectedPhotos.length) {
      return;
    }
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _pickDateAnswer(VanCustomJobQuestion question) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null) {
      return;
    }
    final controller = _answerControllers[question.id];
    if (controller == null) {
      return;
    }
    controller.text = _formatDate(picked);
    setState(() {});
  }

  Future<void> _pickTimeAnswer(VanCustomJobQuestion question) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (pickerContext, child) {
        final mediaQuery = MediaQuery.of(pickerContext);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.1),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) {
      return;
    }
    final controller = _answerControllers[question.id];
    if (controller == null) {
      return;
    }
    controller.text = _formatTime(picked);
    setState(() {});
  }

  Future<void> _submitRequest() async {
    if (_submitting || !_validateSubmission()) {
      return;
    }
    final service = _selectedService;
    if (service == null) {
      return;
    }

    setState(() {
      _submitting = true;
      _clientSubmissionId = _clientSubmissionId.isEmpty
          ? 'booking_${DateTime.now().microsecondsSinceEpoch}'
          : _clientSubmissionId;
    });

    try {
      final ownerUid = await VanFirebaseAuthService.instance
          .ensureCurrentUid(source: 'van_mate.booking_link_submit')
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final normalizedOwnerUid = ownerUid?.trim() ?? '';
      if (normalizedOwnerUid.isEmpty) {
        throw StateError('Booking Link owner is unavailable.');
      }

      final address = sanitizeVanText(_addressController.text).trim();
      final postcode = _normalizePostcode(_postcodeController.text);
      final startHandover = _effectiveStartHandover;
      final endHandover = _effectiveEndHandover;
      final returnAddress = _returnAddressSameAsCollection
          ? address
          : sanitizeVanText(_returnAddressController.text).trim();
      final selectedQuestions = _selectedServiceQuestions;
      final collectedAnswers = selectedQuestions
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final question = entry.value;
            final answer = _readQuestionAnswer(question);
            final payload = <String, dynamic>{
              'questionId': question.id.trim(),
              'questionText': question.questionText.trim(),
              'type': question.answerType.storageKey,
              'answerType': question.answerType.storageKey,
              'category': question.category?.storageKey ?? '',
              'answer': answer,
              'answerValue': answer,
              'order': index,
            };
            debugPrint(
              '[BookingLinkPreviewSubmit] answer collected index=$index questionId=${question.id} questionText=${question.questionText.trim()} type=${question.answerType.storageKey} answer=$answer',
            );
            return payload;
          })
          .where(
            (item) =>
                (item['questionId'] as String).isNotEmpty &&
                (item['questionText'] as String).isNotEmpty &&
                (item['answerValue'] as String).trim().isNotEmpty,
          )
          .toList(growable: false);

      debugPrint(
        '[BookingLinkPreviewSubmit] selected service id=${service.id} name=${service.name.trim()} linkedQuestionsLoaded=${selectedQuestions.length}',
      );

      List<Map<String, String>> photoPayload = const <Map<String, String>>[];
      if (service.requestPhotos && _selectedPhotos.isNotEmpty) {
        photoPayload = await _buildSubmitPhotoPayload().timeout(
          const Duration(seconds: 20),
        );
      }
      debugPrint(
        '[BookingLinkPreviewSubmit] selected photo count=${_selectedPhotos.length} payloadCount=${photoPayload.length}',
      );

      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('submitBookingLinkRequest');
      debugPrint(
        '[BookingLinkPreviewSubmit] callable submit start ownerUid=$normalizedOwnerUid serviceId=${service.id} serviceName=${service.name.trim()} answers=${collectedAnswers.length} photos=${photoPayload.length}',
      );
      final additionalNotes = sanitizeVanText(
        _timingNoteController.text,
      ).trim();
      final callableResult = await callable
          .call(<String, dynamic>{
            'ownerUid': normalizedOwnerUid,
            'serviceId': service.id.trim(),
            'serviceName': service.name.trim(),
            'clientSubmissionId': _clientSubmissionId,
            'requestType': service.serviceFlow.requestType.storageKey,
            'serviceFlow': service.serviceFlow.storageKey,
            'customerJourneyType': service.customerJourneyType.storageKey,
            'customerName': sanitizeVanText(_nameController.text).trim(),
            'phoneNumber': sanitizeVanText(_phoneController.text).trim(),
            'customerEmail': sanitizeVanText(_emailController.text).trim(),
            'address': service.hasHandoverConfiguration ? '' : address,
            'startHandover': startHandover?.storageKey ?? '',
            'endHandover': endHandover?.storageKey ?? '',
            'collectionAddress': startHandover?.needsCustomerAddress == true
                ? address
                : '',
            'returnAddress': endHandover?.needsCustomerAddress == true
                ? returnAddress
                : '',
            'returnAddressSameAsCollection': _returnAddressSameAsCollection,
            'postcode': service.hasHandoverConfiguration ? '' : postcode,
            'additionalNotes': additionalNotes,
            'preferredDate': _preferredDate?.toIso8601String(),
            'preferredDateAt': _preferredDate?.toIso8601String(),
            'preferredTimeWindow': _preferredTimeWindow,
            'preferredWindow': _preferredTimeWindow,
            'preferredIsFlexible': _preferredIsFlexible,
            'timingFlexible': _preferredIsFlexible,
            'preferredTimingNote': '',
            'timingNote': '',
            'photoFileNames': _selectedPhotos
                .map((photo) => photo.name.trim())
                .where((name) => name.isNotEmpty)
                .toList(growable: false),
            'photos': photoPayload,
            'answers': collectedAnswers,
          })
          .timeout(const Duration(seconds: 45));
      final resultData = callableResult.data;
      final resultMap = resultData is Map
          ? Map<String, dynamic>.from(resultData)
          : const <String, dynamic>{};
      final requestId = (resultMap['requestId']?.toString().trim() ?? '');
      final jobId = (resultMap['jobId']?.toString().trim() ?? '');
      debugPrint(
        '[BookingLinkPreviewSubmit] callable submit success requestId=${requestId.isEmpty ? '(none)' : requestId} jobId=${jobId.isEmpty ? '(none)' : jobId}',
      );
      if (requestId.isNotEmpty) {
        await VanJobRequestCloudService.instance
            .mergeRequestFields(
              ownerUid: normalizedOwnerUid,
              requestId: requestId,
              source: 'van_mate.booking_link_submit',
              fields: <String, dynamic>{
                'source': 'preview',
                'isPreview': true,
                'sourceLabel': 'Preview test',
                'requestStatusLabel': 'Request Received',
                'selectedServiceId': service.id,
                'selectedServiceName': service.name.trim(),
                'customerJourneyType': service.customerJourneyType.storageKey,
                'serviceFlow': service.serviceFlow.storageKey,
                'startHandover': startHandover?.storageKey ?? '',
                'endHandover': endHandover?.storageKey ?? '',
                'collectionAddress': startHandover?.needsCustomerAddress == true
                    ? address
                    : '',
                'returnAddress': endHandover?.needsCustomerAddress == true
                    ? returnAddress
                    : '',
                'returnAddressSameAsCollection': _returnAddressSameAsCollection,
                'businessDropOffInstructions':
                    service.businessDropOffInstructions,
                'businessCollectionInstructions':
                    service.businessCollectionInstructions,
                'customerPostcode': postcode,
                'preferredDate': _preferredDate?.toIso8601String(),
                'preferredTimeWindow': _preferredTimeWindow,
                'preferredIsFlexible': _preferredIsFlexible,
                'preferredTimingNote': '',
                'additionalNotes': additionalNotes,
                'photoFileNames': _selectedPhotos
                    .map((photo) => photo.name.trim())
                    .where((name) => name.isNotEmpty)
                    .toList(growable: false),
                'status': 'reply_received',
                'requestStatus': 'reply_received',
              },
            )
            .timeout(const Duration(seconds: 15));
      }
      await DriverReplyMockState.instance
          .refreshJobsFromCloud(forceServer: true)
          .timeout(const Duration(seconds: 15));

      if (!mounted) {
        return;
      }
      setState(() {
        _submitted = true;
        _confirmationRequestId = requestId;
      });
    } catch (error) {
      debugPrint('[BookingLinkPreviewSubmit] submit failure error=$error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TimeoutException
                ? 'Request timed out. Check your connection and try again.'
                : 'Could not submit request. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted && _submitting) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildQuestionAnswerField(VanCustomJobQuestion question) {
    final answerType = question.answerType;
    final helper = question.helperText.trim();

    switch (answerType) {
      case VanCustomQuestionAnswerType.yesNo:
        final value = _choiceAnswers[question.id] ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ChoiceAnswerButton(
                    label: 'Yes',
                    selected: value == 'Yes',
                    onTap: () {
                      setState(() {
                        _choiceAnswers[question.id] = 'Yes';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceAnswerButton(
                    label: 'No',
                    selected: value == 'No',
                    onTap: () {
                      setState(() {
                        _choiceAnswers[question.id] = 'No';
                      });
                    },
                  ),
                ),
              ],
            ),
            if (helper.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                helper,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        );
      case VanCustomQuestionAnswerType.multipleChoice:
        final choices = question.choiceOptions;
        final value = _choiceAnswers[question.id];
        return DropdownButtonFormField<String>(
          initialValue: value != null && choices.contains(value) ? value : null,
          items: choices
              .map(
                (choice) => DropdownMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                ),
              )
              .toList(growable: false),
          decoration: vanMateFieldDecoration(
            label: 'Select answer',
            hintText: choices.isEmpty ? 'No options configured' : null,
            labelOpacity: 0.68,
            hintOpacity: 0.48,
          ),
          style: kVanMateFieldTextStyle,
          dropdownColor: const Color(0xFF13233A),
          iconEnabledColor: Colors.white,
          onChanged: choices.isEmpty
              ? null
              : (next) {
                  setState(() {
                    _choiceAnswers[question.id] = next?.trim() ?? '';
                  });
                },
        );
      case VanCustomQuestionAnswerType.date:
        return _BookingTextField(
          controller: _answerControllers[question.id]!,
          label: 'Date',
          hint: 'Choose date',
          icon: Icons.calendar_today_outlined,
          readOnly: true,
          onTap: () => _pickDateAnswer(question),
          autofillHints: const <String>[],
          textInputAction: TextInputAction.next,
        );
      case VanCustomQuestionAnswerType.time:
        return _BookingTextField(
          controller: _answerControllers[question.id]!,
          label: 'Time',
          hint: 'Choose time',
          icon: Icons.access_time,
          readOnly: true,
          onTap: () => _pickTimeAnswer(question),
          autofillHints: const <String>[],
          textInputAction: TextInputAction.next,
        );
      case VanCustomQuestionAnswerType.photoUploadRequest:
        return _BookingTextField(
          controller: _answerControllers[question.id]!,
          label: 'Photo details',
          hint: 'Add a short description',
          icon: Icons.photo_camera_back_outlined,
          autofillHints: const <String>[],
          textInputAction: TextInputAction.next,
        );
      case VanCustomQuestionAnswerType.shortText:
        return _BookingTextField(
          controller: _answerControllers[question.id]!,
          label: 'Answer',
          hint: 'Type your answer',
          icon: Icons.edit_outlined,
          autofillHints: const <String>[],
          textInputAction: TextInputAction.next,
        );
      case VanCustomQuestionAnswerType.longText:
        return _BookingTextField(
          controller: _answerControllers[question.id]!,
          label: 'Answer',
          hint: 'Type your answer',
          icon: Icons.notes_outlined,
          minLines: 3,
          maxLines: 5,
          autofillHints: const <String>[],
          textInputAction: TextInputAction.next,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final service = _selectedService;
    final serviceQuestions = _selectedServiceQuestions;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Booking Form Preview'),
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
            child: _submitted
                ? ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _journeyCopy.receivedHeading,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _journeyCopy.successMessage,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_confirmationRequestId.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Request ID: $_confirmationRequestId',
                                style: const TextStyle(
                                  color: Color(0xFF8AB4FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Powered by Van Mate',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.2,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              child: _buildBusinessLogo(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_customerFacingCustomHeading != null) ...[
                                    Text(
                                      _customerFacingCustomHeading!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.64,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text(
                                    _customerFacingBusinessTitle,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    service == null
                                        ? 'Choose a service and tell us what you need.'
                                        : _journeyCopy.headingForService(
                                            service.name,
                                          ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.74,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
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
                              'Service',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (widget.activeServices.length == 1 &&
                                service != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  13,
                                  14,
                                  13,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  service.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedServiceId,
                                decoration: vanMateFieldDecoration(
                                  label: 'Select service',
                                  hintText: 'Choose a service',
                                  labelOpacity: 0.68,
                                  hintOpacity: 0.48,
                                ),
                                style: kVanMateFieldTextStyle,
                                dropdownColor: const Color(0xFF13233A),
                                iconEnabledColor: Colors.white,
                                items: widget.activeServices
                                    .map(
                                      (item) => DropdownMenuItem<String>(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedServiceId = value;
                                    _selectedStartHandover = null;
                                    _selectedEndHandover = null;
                                    _returnAddressSameAsCollection = false;
                                    _clientSubmissionId = '';
                                    _addressController.clear();
                                    _returnAddressController.clear();
                                    _syncQuestionControllers();
                                  });
                                },
                              ),
                            if (service != null && service.hasDescription) ...[
                              const SizedBox(height: 8),
                              Text(
                                service.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (service?.customerMessage.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                service!.customerMessage,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (service != null &&
                          (service
                                  .effectiveRequestFlowOptions
                                  .askPreferredDate ||
                              service
                                  .effectiveRequestFlowOptions
                                  .askPreferredTime)) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Contact details',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _BookingTextField(
                                controller: _nameController,
                                label: 'Full name',
                                hint: 'Enter your name',
                                icon: Icons.person_outline,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const <String>[
                                  AutofillHints.name,
                                ],
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                              ),
                              if (service.showsBuiltInQuestion('phone')) ...[
                                const SizedBox(height: 10),
                                _BookingTextField(
                                  controller: _phoneController,
                                  label:
                                      service.requiresBuiltInQuestion(
                                        'phone',
                                        legacyDefault: true,
                                      )
                                      ? 'Phone number'
                                      : 'Phone number (optional)',
                                  hint: 'Enter phone number',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9 +()-]'),
                                    ),
                                  ],
                                  autofillHints: const <String>[
                                    AutofillHints.telephoneNumber,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                ),
                                if (service
                                    .builtInQuestionHelper('phone')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      service.builtInQuestionHelper('phone'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .62,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                              if (service.showsBuiltInQuestion('email')) ...[
                                const SizedBox(height: 10),
                                _BookingTextField(
                                  controller: _emailController,
                                  label:
                                      service.requiresBuiltInQuestion('email')
                                      ? 'Email address'
                                      : 'Email (optional)',
                                  hint: 'Enter email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const <String>[
                                    AutofillHints.email,
                                  ],
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                ),
                                if (service
                                    .builtInQuestionHelper('email')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      service.builtInQuestionHelper('email'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .62,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (service != null &&
                          service.hasHandoverConfiguration) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Handover arrangement',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                vanCustomerHandoverSummary(
                                  _effectiveStartHandover!,
                                  _effectiveEndHandover!,
                                ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (service
                                  .effectiveHandover
                                  .customerChoosesStart) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'How would you like to begin?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                for (final value
                                    in service.effectiveHandover.allowedStarts)
                                  _HandoverRadioTile(
                                    label:
                                        value ==
                                            VanStartHandover.customerDropsOff
                                        ? "I'll drop it off"
                                        : 'Please collect it',
                                    selected: _effectiveStartHandover == value,
                                    onTap: () => setState(
                                      () => _selectedStartHandover = value,
                                    ),
                                  ),
                              ],
                              if (service
                                  .effectiveHandover
                                  .customerChoosesEnd) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'How would you like it returned?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                for (final value
                                    in service.effectiveHandover.allowedEnds)
                                  _HandoverRadioTile(
                                    label:
                                        value == VanEndHandover.customerCollects
                                        ? "I'll collect it"
                                        : 'Please return it',
                                    selected: _effectiveEndHandover == value,
                                    onTap: () => setState(
                                      () => _selectedEndHandover = value,
                                    ),
                                  ),
                              ],
                              if (_effectiveStartHandover ==
                                  VanStartHandover.customerDropsOff) ...[
                                const SizedBox(height: 12),
                                Text(
                                  service.businessDropOffInstructions
                                          .trim()
                                          .isEmpty
                                      ? 'The business will confirm the drop-off location.'
                                      : service.businessDropOffInstructions,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                _BookingTextField(
                                  controller: _addressController,
                                  label: 'Collection address',
                                  hint:
                                      'Where should the business collect from?',
                                  icon: Icons.location_on_outlined,
                                  minLines: 2,
                                  maxLines: 3,
                                  autofillHints: const <String>[],
                                ),
                              ],
                              if (_effectiveEndHandover ==
                                  VanEndHandover.customerCollects) ...[
                                const SizedBox(height: 12),
                                Text(
                                  service.businessCollectionInstructions
                                          .trim()
                                          .isEmpty
                                      ? 'The business will confirm where to collect when ready.'
                                      : service.businessCollectionInstructions,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                if (_effectiveStartHandover ==
                                    VanStartHandover.businessCollects)
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _returnAddressSameAsCollection,
                                    onChanged: (value) => setState(
                                      () => _returnAddressSameAsCollection =
                                          value == true,
                                    ),
                                    title: const Text(
                                      'Same as collection address',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                if (!_returnAddressSameAsCollection)
                                  _BookingTextField(
                                    controller: _returnAddressController,
                                    label: 'Return address',
                                    hint:
                                        'Where should the business return it?',
                                    icon: Icons.keyboard_return_rounded,
                                    minLines: 2,
                                    maxLines: 3,
                                    autofillHints: const <String>[],
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (service?.showsBuiltInQuestion('address') == true &&
                          !service!.hasHandoverConfiguration) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.requireAddress
                                    ? 'Address or postcode'
                                    : 'Address or postcode (optional)',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              if (service
                                  .builtInQuestionHelper('address')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  service.builtInQuestionHelper('address'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .66),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _BookingTextField(
                                controller: _addressController,
                                label: 'Address',
                                hint: 'Enter address',
                                icon: Icons.location_on_outlined,
                                minLines: 2,
                                maxLines: 3,
                                autofillHints: const <String>[],
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 10),
                              _BookingTextField(
                                controller: _postcodeController,
                                label: 'Postcode',
                                hint: 'Enter postcode',
                                icon: Icons.markunread_mailbox_outlined,
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.characters,
                                smartDashesType: SmartDashesType.disabled,
                                smartQuotesType: SmartQuotesType.disabled,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9 ]'),
                                  ),
                                  const _UpperCaseTextFormatter(),
                                ],
                                autofillHints: const <String>[],
                                textInputAction: TextInputAction.next,
                                enableSuggestions: false,
                                autocorrect: false,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (service?.requestPhotos == true) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Photos',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                service!
                                        .builtInQuestionHelper('photos')
                                        .isNotEmpty
                                    ? service.builtInQuestionHelper('photos')
                                    : vanBookingPhotoHelperText(
                                        service.requestType,
                                      ),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    height: 40,
                                    child: FilledButton.icon(
                                      onPressed: _pickPhotos,
                                      icon: const Icon(Icons.add_a_photo),
                                      label: Text(
                                        service.requiresBuiltInQuestion(
                                              'photos',
                                            )
                                            ? 'Add photos'
                                            : 'Add photos (optional)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedPhotos.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                for (var i = 0; i < _selectedPhotos.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '\u2022 ${_selectedPhotos[i].name}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.76,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove photo',
                                          onPressed: () =>
                                              _removeSelectedPhotoAt(i),
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: Colors.white.withValues(
                                              alpha: 0.74,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  '${_selectedPhotos.length} selected (max $_photoLimit)',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (service != null) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _requiresPreferredTiming
                                    ? 'Preferred date and time'
                                    : 'Preferred date and time (optional)',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              if (service
                                  .effectiveRequestFlowOptions
                                  .askPreferredDate) ...[
                                const SizedBox(height: 10),
                                _BookingTextField(
                                  controller: _preferredDateController,
                                  label: 'Preferred date',
                                  hint: 'Choose a preferred date',
                                  icon: Icons.event_outlined,
                                  readOnly: true,
                                  onTap: _pickPreferredDate,
                                  autofillHints: const <String>[],
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                              if (service
                                  .effectiveRequestFlowOptions
                                  .askPreferredTime) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: _preferredTimeWindow,
                                  decoration: vanMateFieldDecoration(
                                    label: 'Preferred time window',
                                    hintText: 'Choose a preferred time',
                                    labelOpacity: 0.68,
                                    hintOpacity: 0.48,
                                  ),
                                  style: kVanMateFieldTextStyle,
                                  dropdownColor: const Color(0xFF13233A),
                                  iconEnabledColor: Colors.white,
                                  items:
                                      const <String>[
                                            'morning',
                                            'afternoon',
                                            'evening',
                                            'anytime',
                                          ]
                                          .map((value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(
                                                _preferredTimeWindowLabel(
                                                  value,
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(growable: false),
                                  onChanged: (value) {
                                    setState(() {
                                      _preferredTimeWindow =
                                          value?.trim().toLowerCase() ??
                                          'anytime';
                                    });
                                  },
                                ),
                              ],
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _preferredIsFlexible,
                                activeColor: const Color(0xFF58D0A4),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                                title: const Text(
                                  'Timing is flexible',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: (next) {
                                  setState(() {
                                    _preferredIsFlexible = next ?? false;
                                  });
                                },
                              ),
                              if (_preferredTimingValidationMessage !=
                                  null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _preferredTimingValidationMessage!,
                                  style: TextStyle(
                                    color: const Color(0xFFFF8B8B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (serviceQuestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Questions linked to this service',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (
                                var i = 0;
                                i < serviceQuestions.length;
                                i++
                              ) ...[
                                Text(
                                  serviceQuestions[i].questionText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildQuestionAnswerField(serviceQuestions[i]),
                                if (i < serviceQuestions.length - 1) ...[
                                  const SizedBox(height: 10),
                                  Divider(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (service != null) ...[
                        const SizedBox(height: 12),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Anything else we should know?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _BookingTextField(
                                controller: _timingNoteController,
                                label: 'Optional details',
                                hint:
                                    'Access notes, parking information, gate codes, timing preferences or anything else that may help...',
                                icon: Icons.notes_outlined,
                                minLines: 2,
                                maxLines: 4,
                                autofillHints: const <String>[],
                                textInputAction: TextInputAction.done,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed:
                                _submitting ||
                                    !_hasValidPreferredTimingSelection
                                ? null
                                : _submitRequest,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(_journeyCopy.submitAction),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Powered by Van Mate',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.questionCount});

  final VanJobService service;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (service.hasDescription) ...[
                const SizedBox(height: 2),
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _StatusChip(
          label: '$questionCount questions',
          color: const Color(0xFF4A7DFF),
        ),
      ],
    );
  }
}

class _BookingLinkErrorCard extends StatelessWidget {
  const _BookingLinkErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load Booking Link',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceAnswerButton extends StatelessWidget {
  const _ChoiceAnswerButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        backgroundColor: selected
            ? const Color(0xFF4A7DFF).withValues(alpha: 0.26)
            : Colors.white.withValues(alpha: 0.04),
        side: BorderSide(
          color: selected
              ? const Color(0xFF4A7DFF).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.16),
        ),
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}

enum _PhotoSourceChoice { camera, gallery }

class _HandoverRadioTile extends StatelessWidget {
  const _HandoverRadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: selected
          ? const Color(0xFF66D6B5).withValues(alpha: .1)
          : Colors.white.withValues(alpha: .035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected
              ? const Color(0xFF66D6B5)
              : Colors.white.withValues(alpha: .11),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? const Color(0xFF66D6B5) : Colors.white54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BookingTextField extends StatelessWidget {
  const _BookingTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.inputFormatters,
    this.autofillHints,
    this.textInputAction,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.smartDashesType = SmartDashesType.enabled,
    this.smartQuotesType = SmartQuotesType.enabled,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final bool enableSuggestions;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final SmartDashesType smartDashesType;
  final SmartQuotesType smartQuotesType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      obscureText: false,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      textCapitalization: textCapitalization,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.70)),
        labelOpacity: 0.68,
        hintOpacity: 0.48,
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper, selection: newValue.selection);
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
