import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

// ignore_for_file: use_build_context_synchronously

import '../helpers/app_theme.dart';
import '../helpers/van_customer_request_questions.dart';
import '../helpers/van_customer_request_actions.dart';
import '../helpers/van_job_request_state.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_request_draft.dart';
import '../models/van_job_request_record.dart';
import '../pages/van_custom_job_questions_page.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../models/van_exact_pin_source.dart';
import '../services/van_job_request_cloud_service.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_default_new_job_questions_storage.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_premium_service.dart';
import '../widgets/van_duration_picker_sheet.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_exact_pin_flow.dart';
import '../widgets/van_premium_gate_sheet.dart';

const bool kVanMateDeveloperToolsEnabled = false;

String? validateVanJobRequestDraftForSend(VanJobRequestDraft draft) {
  final hasContactMethod =
      draft.phoneNumber.trim().isNotEmpty ||
      draft.customerEmail.trim().isNotEmpty;
  final hasCustomerReference =
      draft.customerName.trim().isNotEmpty || hasContactMethod;
  final hasJobReference = draft.jobTitle.trim().isNotEmpty;

  if (!hasCustomerReference || !hasContactMethod || !hasJobReference) {
    return 'Please add the customer and job details first.';
  }

  if (!draft.requiresExactPinAfterQuoteAccepted && !draft.hasLocationDetails) {
    return 'Add an address or switch on exact pin request.';
  }

  return null;
}

class CreateJobRequestPage extends StatefulWidget {
  const CreateJobRequestPage({
    super.key,
    this.initialCustomQuestions = const <String>[],
  });

  final List<String> initialCustomQuestions;

  @override
  State<CreateJobRequestPage> createState() => _CreateJobRequestPageState();
}

class _CreateJobRequestPageState extends State<CreateJobRequestPage> {
  final VanMatePremiumService _premiumService = VanMatePremiumService.instance;
  final VanCustomJobQuestionsStorage _customJobQuestionsStorage =
      VanCustomJobQuestionsStorage.instance;
  final VanDefaultNewJobQuestionsStorage _defaultQuestionStorage =
      VanDefaultNewJobQuestionsStorage.instance;
  final String _jobId = 'job_${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController _customerNameController = TextEditingController(
    text: '',
  );
  final TextEditingController _phoneNumberController = TextEditingController(
    text: '',
  );
  final TextEditingController _customerEmailController = TextEditingController(
    text: '',
  );
  final TextEditingController _jobTitleController = TextEditingController(
    text: '',
  );
  final TextEditingController _addressController = TextEditingController(
    text: '',
  );
  final TextEditingController _postcodeController = TextEditingController(
    text: '',
  );
  final TextEditingController _customQuestionController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _jobDateController = TextEditingController();
  final TextEditingController _jobTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  late DateTime _jobDate = DateUtils.dateOnly(DateTime.now());
  late TimeOfDay _jobTime = TimeOfDay.fromDateTime(DateTime.now());
  int? _estimatedDurationMinutes = 60;
  bool _requestPhotos = false;
  bool _requestExactPin = false;
  bool _premiumLoaded = false;
  Map<String, VanCustomJobQuestion> _questionLookup =
      const <String, VanCustomJobQuestion>{};
  final Set<String> _selectedQuestionIds = <String>{};
  final List<String> _manualQuestions = <String>[];
  bool _defaultQuestionsLoaded = false;

  @override
  void initState() {
    super.initState();
    DriverReplyMockState.instance.resetTransientWorkflowState();
    for (final question in widget.initialCustomQuestions) {
      final cleaned = sanitizeVanText(question).trim();
      if (cleaned.isNotEmpty && !_manualQuestions.contains(cleaned)) {
        _manualQuestions.add(cleaned);
      }
    }
    _syncDateTimeControllers();
    unawaited(_loadPremiumAndQuestions());
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _customerEmailController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _customQuestionController.dispose();
    _notesController.dispose();
    _jobDateController.dispose();
    _jobTimeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadPremiumAndQuestions() async {
    await _premiumService.ensureLoaded();
    List<VanCustomJobQuestion> customQuestions = const <VanCustomJobQuestion>[];
    List<String> defaultQuestionTexts = const <String>[];
    try {
      customQuestions =
          await _customJobQuestionsStorage.loadFromCloud() ??
          await _customJobQuestionsStorage.loadAll();
      await _defaultQuestionStorage.loadFromCloud();
      defaultQuestionTexts = await _defaultQuestionStorage.loadSavedQuestions();
    } catch (_) {
      customQuestions = await _customJobQuestionsStorage.loadAll();
      defaultQuestionTexts = await _defaultQuestionStorage.loadSavedQuestions();
    }
    final questionLookup = buildVanCustomerRequestQuestionLookup(
      customQuestions,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _premiumLoaded = true;
      _questionLookup = questionLookup;
      if (!_premiumService.isPremium) {
        _requestPhotos = false;
      }
    });
    _applyDefaultQuestionSet(defaultQuestionTexts);
  }

  void _applyDefaultQuestionSet(List<String> defaultQuestionTexts) {
    if (_defaultQuestionsLoaded) {
      return;
    }

    final resolved = resolveVanQuestionTextsForSelection(
      defaultQuestionTexts,
      _questionLookup,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedQuestionIds.addAll(resolved.selectedQuestionIds);
      for (final question in resolved.manualQuestions) {
        if (!_manualQuestions.contains(question)) {
          _manualQuestions.add(question);
        }
      }
      _defaultQuestionsLoaded = true;
    });
  }

  Future<void> _toggleRequestPhotos(bool value) async {
    if (!_premiumLoaded) {
      return;
    }
    if (!_premiumService.isPremium) {
      await requireVanMatePremium(
        context,
        featureName: 'Customer request photos',
        headline: 'Customer request photos are Premium',
        message:
            'Ask customers to attach photos before you quote. Premium unlocks photo requests on New Job links.',
        ctaLabel: 'Open Premium screen',
      );
      return;
    }
    setState(() {
      _requestPhotos = value;
    });
  }

  void _syncDateTimeControllers() {
    _jobDateController.text = _formatJobDate(_jobDate);
    _jobTimeController.text = _formatJobTime(_jobTime);
    _durationController.text = _durationLabel(_estimatedDurationMinutes);
  }

  String _formatJobDate(DateTime date) {
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

  String _formatJobTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatScheduledDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _durationLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'Not set';
    }
    switch (minutes) {
      case 30:
        return '30m';
      case 60:
        return '1h';
      case 120:
        return '2h';
      case 240:
        return 'Half day';
      default:
        return '${minutes}m';
    }
  }

  VanJobRequestDraft _buildDraft() {
    final scheduledAt = DateTime(
      _jobDate.year,
      _jobDate.month,
      _jobDate.day,
      _jobTime.hour,
      _jobTime.minute,
    );
    final answers = buildVanRequestAnswersFromSelection(
      selectedQuestionIds: _selectedQuestionIds.toList(growable: false),
      manualQuestions: _manualQuestions,
      questionLookup: _questionLookup,
    );
    final resolvedJobTitle = _jobTitleController.text.trim();
    final trimmedAddress = _addressController.text.trim();
    final trimmedPostcode = _postcodeController.text.trim();
    final locationPending =
        _requestExactPin && trimmedAddress.isEmpty && trimmedPostcode.isEmpty;
    return VanJobRequestDraft(
      jobId: _jobId,
      customerName: _customerNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      customerEmail: _customerEmailController.text.trim(),
      jobTitle: resolvedJobTitle,
      scheduledAt: scheduledAt,
      jobDateLabel: _formatJobDate(_jobDate),
      jobTimeLabel: _formatJobTime(_jobTime),
      scheduledDate: _formatScheduledDate(_jobDate),
      scheduledStartTime: _formatJobTime(_jobTime),
      estimatedDurationMinutes: _estimatedDurationMinutes,
      calendarStatus: 'unscheduled',
      address: trimmedAddress,
      postcode: trimmedPostcode,
      requestExactPin: false,
      requestPhotos: _requestPhotos && _premiumService.isPremium,
      requiresExactPinAfterQuoteAccepted: _requestExactPin,
      locationPending: locationPending,
      selectedServiceId: '',
      selectedServiceName: '',
      selectedQuestionIds: List<String>.unmodifiable(
        _selectedQuestionIds.toList(growable: false),
      ),
      answers: answers,
      checklistItems: buildVanLegacyChecklistItemsFromAnswers(answers),
      customQuestions: buildVanLegacyCustomQuestionsFromAnswers(answers),
      notesMessage: _notesController.text.trim(),
    );
  }

  Future<void> _pickJobDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _jobDate,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime(DateTime.now().year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: const Color(0xFF111B2B),
              primary: const Color(0xFF4A7DFF),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _jobDate = DateUtils.dateOnly(picked);
      _syncDateTimeControllers();
    });
  }

  Future<void> _pickJobTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _jobTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: const Color(0xFF111B2B),
              primary: const Color(0xFF4A7DFF),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _jobTime = picked;
      _syncDateTimeControllers();
    });
  }

  void _addCustomQuestion() {
    final value = _customQuestionController.text.trim();
    if (value.isEmpty) {
      return;
    }

    setState(() {
      if (!_manualQuestions.contains(value)) {
        _manualQuestions.add(value);
      }
      _customQuestionController.clear();
    });
  }

  Future<void> _openQuestionSetup() async {
    await openVanCustomJobQuestionsPage(context);
    if (!mounted) {
      return;
    }

    final customQuestions = await _customJobQuestionsStorage.loadAll();
    final defaultQuestionTexts = await _defaultQuestionStorage
        .loadSavedQuestions();
    final questionLookup = buildVanCustomerRequestQuestionLookup(
      customQuestions,
    );
    final resolved = resolveVanQuestionTextsForSelection(
      defaultQuestionTexts,
      questionLookup,
    );
    setState(() {
      _questionLookup = questionLookup;
      _selectedQuestionIds
        ..clear()
        ..addAll(resolved.selectedQuestionIds);
      _manualQuestions
        ..clear()
        ..addAll(resolved.manualQuestions);
    });
  }

  Future<void> _openPreview() async {
    FocusScope.of(context).unfocus();
    final draft = _buildDraft();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerRequestPreviewPage(draft: draft, jobId: draft.jobId),
      ),
    );
  }

  bool _validateMainFields() {
    final draft = _buildDraft();
    final validationMessage = validateVanJobRequestDraftForSend(draft);

    if (validationMessage == null) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(validationMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  DateTime _selectedScheduledAt() {
    return DateTime(
      _jobDate.year,
      _jobDate.month,
      _jobDate.day,
      _jobTime.hour,
      _jobTime.minute,
    );
  }

  String? _scheduledAtValidationMessage() {
    return validateVanMateScheduledAt(_selectedScheduledAt());
  }

  bool _validateScheduledAt() {
    final message = _scheduledAtValidationMessage();
    if (message == null) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  Future<void> _sendRequest() async {
    if (!_validateMainFields()) {
      return;
    }
    if (!_validateScheduledAt()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final DriverCustomerReplyMockData job;
    try {
      job = await DriverReplyMockState.instance.sendJobRequest(_buildDraft());
    } on VanPastScheduleException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    await _showRequestLinkSheet(job);
  }

  Future<void> _showRequestLinkSheet(DriverCustomerReplyMockData job) async {
    final requestId = job.requestId?.trim().isNotEmpty == true
        ? job.requestId!.trim()
        : job.jobId.trim();
    final requestLink = resolveVanJobRequestDisplayLink(
      requestId: requestId,
      requestLink: job.requestLink,
    );
    final customerName = job.customerName.trim();
    final businessName = await _requestMessageBusinessName();
    final visibleRequestLabel = customerName.isNotEmpty
        ? 'Request link for $customerName'
        : 'Customer request link ready';
    final shareMessage = buildRequestShareMessage(
      link: requestLink,
      customerName: customerName,
      jobTitle: job.jobTitle,
      businessName: businessName,
      address: job.address,
      exactPinRequestedAfterQuoteAccepted: _requestExactPin,
    );
    final emailBody = buildRequestEmailBody(
      link: requestLink,
      jobTitle: job.jobTitle,
      address: job.address,
      exactPinRequestedAfterQuoteAccepted: _requestExactPin,
    );
    final customerPhone = sanitizeVanCustomerPhoneNumber(job.phoneNumber);
    final customerEmail = job.customerEmail.trim();
    final hasCustomerPhone = customerPhone.isNotEmpty;
    final hasCustomerEmail = customerEmail.isNotEmpty;
    debugPrint('[VanJobRequestShare]\n$shareMessage');
    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.11),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer request link',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _requestExactPin
                            ? 'Share this link so the customer can send their job details.\n\nIf they accept the quote, they will then be asked for the exact pin.'
                            : 'Share this link so the customer can send their job details.',
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.74),
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        visibleRequestLabel,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (hasCustomerEmail)
                            FilledButton.icon(
                              onPressed: () async {
                                final launched = await emailCustomerRequest(
                                  email: customerEmail,
                                  subject: 'Van Mate job request',
                                  message: emailBody,
                                );
                                if (launched) {
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.of(context).maybePop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Email opened. Send it from your mail app.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final shared = await shareRequestMessage(
                                  shareMessage,
                                );
                                if (shared.status ==
                                    ShareResultStatus.unavailable) {
                                  final copied = await copyRequestMessage(
                                    shareMessage,
                                  );
                                  if (sheetContext.mounted && copied) {
                                    Navigator.of(sheetContext).pop();
                                    if (mounted) {
                                      Navigator.of(context).maybePop();
                                    }
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not open email. Message copied instead.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (!mounted) {
                                  return;
                                }
                                Navigator.of(context).maybePop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Email unavailable. Share sheet opened instead.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.email_outlined),
                              label: const Text('Email customer'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4A7DFF),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          if (hasCustomerPhone)
                            FilledButton.icon(
                              onPressed: () async {
                                final launched = await textCustomerRequest(
                                  phoneNumber: customerPhone,
                                  message: shareMessage,
                                );
                                if (!launched) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not open text message. Use Share link instead.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                if (!mounted) {
                                  return;
                                }
                                Navigator.of(context).maybePop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Text message opened. Send it from your SMS app.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.sms_outlined),
                              label: const Text('Text customer'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          hasCustomerPhone
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    final result = await shareRequestMessage(
                                      shareMessage,
                                    );
                                    if (result.status ==
                                        ShareResultStatus.unavailable) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not open sharing. Use Copy link instead.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    Navigator.of(context).maybePop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Customer request sent - awaiting reply.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share link'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: () async {
                                    final result = await shareRequestMessage(
                                      shareMessage,
                                    );
                                    if (result.status ==
                                        ShareResultStatus.unavailable) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not open sharing. Use Copy link instead.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    Navigator.of(context).maybePop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Customer request sent - awaiting reply.',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share link'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF58D0A4),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                          hasCustomerPhone
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await copyRequestLink(requestLink);
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Link copied'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Copy failed - long press the address bar or open in Chrome/Safari.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy link'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: () async {
                                    try {
                                      await copyRequestLink(requestLink);
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Link copied'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(
                                          sheetContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Copy failed - long press the address bar or open in Chrome/Safari.',
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy link'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A7DFF),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                          if (kDebugMode && kVanMateDeveloperToolsEnabled)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                if (!mounted) {
                                  return;
                                }
                                navigator.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        CustomerRequestPreviewPage.forRequestId(
                                          requestId: requestId,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open test form'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _requestMessageBusinessName() async {
    try {
      final profile = await VanBusinessProfileStorage.instance
          .loadCanonicalProfile();
      return sanitizeVanText(profile.businessName).trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickEstimatedDuration() async {
    final selected = await showVanDurationPickerSheet(
      context: context,
      initialMinutes: _estimatedDurationMinutes ?? 0,
      durationLabel: _durationLabel,
      title: 'Choose duration',
    );
    if (!mounted || selected == null || selected <= 0) {
      return;
    }
    setState(() {
      _estimatedDurationMinutes = selected;
      _durationController.text = _durationLabel(_estimatedDurationMinutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkflowBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Create Job Request',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _requestExactPin
                            ? 'Send a customer request powered by your shared service questions, then collect the exact pin after quote acceptance.'
                            : 'Send a customer request now and collect the exact pin after quote acceptance.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.person,
                              title: 'Customer details',
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 560;
                                final fields = <Widget>[
                                  _JobRequestInputField(
                                    controller: _customerNameController,
                                    icon: Icons.person,
                                    label: 'Customer name',
                                    hintText: 'Enter customer name',
                                  ),
                                  _JobRequestInputField(
                                    controller: _phoneNumberController,
                                    icon: Icons.phone,
                                    label: 'Phone number',
                                    hintText: 'Enter phone number',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: null,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9 +()-]'),
                                      ),
                                    ],
                                  ),
                                  _JobRequestInputField(
                                    controller: _customerEmailController,
                                    icon: Icons.email,
                                    label: 'Customer email',
                                    hintText: 'Enter customer email',
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  _JobRequestInputField(
                                    controller: _jobTitleController,
                                    icon: Icons.work_outline,
                                    label: 'Job title / reference',
                                    hintText: 'Add job title or reference',
                                  ),
                                  _JobRequestInputField(
                                    controller: _jobDateController,
                                    icon: Icons.event_outlined,
                                    label: 'Job date',
                                    hintText: 'Choose job date',
                                    readOnly: true,
                                    onTap: _pickJobDate,
                                  ),
                                  _JobRequestInputField(
                                    controller: _jobTimeController,
                                    icon: Icons.schedule_outlined,
                                    label: 'Job time',
                                    hintText: 'Choose job time',
                                    readOnly: true,
                                    onTap: _pickJobTime,
                                  ),
                                  _JobRequestInputField(
                                    controller: _durationController,
                                    icon: Icons.timelapse_outlined,
                                    label: 'Estimated duration',
                                    hintText: 'Choose duration',
                                    readOnly: true,
                                    onTap: _pickEstimatedDuration,
                                  ),
                                  _JobRequestInputField(
                                    controller: _postcodeController,
                                    icon: Icons.local_post_office_outlined,
                                    label: 'Postcode',
                                    hintText: 'Add postcode if needed',
                                  ),
                                ];

                                if (isWide) {
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: fields
                                        .map(
                                          (field) => SizedBox(
                                            width:
                                                (constraints.maxWidth - 12) / 2,
                                            child: field,
                                          ),
                                        )
                                        .toList(growable: false),
                                  );
                                }

                                return Column(
                                  children: [
                                    for (var i = 0; i < fields.length; i++) ...[
                                      fields[i],
                                      if (i < fields.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _addressController,
                              icon: Icons.location_on_outlined,
                              label: 'Address',
                              hintText: 'Enter address or postcode area',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _requestExactPin,
                              onChanged: (value) {
                                setState(() {
                                  _requestExactPin = value;
                                });
                              },
                              title: const Text(
                                'Request exact pin after quote accepted',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'Customer can confirm the exact entrance, bay or drop-off point later.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _requestPhotos,
                              onChanged: _toggleRequestPhotos,
                              title: const Text(
                                'Request customer photos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _premiumService.isPremium
                                    ? 'Ask the customer to attach useful photos before you quote.'
                                    : 'Premium feature. Lets customers attach photos with their request.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openQuestionSetup,
                              icon: const Icon(Icons.tune),
                              label: Text(
                                'Question setup (${_selectedQuestionIds.length + _manualQuestions.length})',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            if (_manualQuestions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final question in _manualQuestions)
                                      Chip(
                                        label: Text(question),
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.10),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.10,
                                          ),
                                        ),
                                        labelStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _customQuestionController,
                              icon: Icons.question_answer_outlined,
                              label: 'Add a one-off question',
                              hintText: 'Anything else you want to ask?',
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _addCustomQuestion,
                                icon: const Icon(Icons.add),
                                label: const Text('Add custom question'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A7DFF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _notesController,
                              icon: Icons.notes,
                              label: 'Driver notes or message',
                              hintText: 'Add anything the customer should know',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.preview,
                              title: 'Message preview',
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                _requestExactPin
                                    ? 'Hi, please fill in this quick job request so I can prepare your quote. If you accept the quote later, I\'ll ask for the exact pickup/drop-off pin.'
                                    : 'Hi, please fill in this quick job request so I can prepare your quote.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'vanmate.app/request/preview',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF8AB4FF),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 480;
                          final actions = <Widget>[
                            if (kDebugMode && kVanMateDeveloperToolsEnabled)
                              FilledButton.icon(
                                onPressed: _openPreview,
                                icon: const Icon(Icons.preview),
                                label: const Text('Open test form'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A7DFF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            FilledButton.icon(
                              onPressed: _scheduledAtValidationMessage() == null
                                  ? _sendRequest
                                  : null,
                              icon: const Icon(Icons.send),
                              label: const Text('Send Request'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ];

                          if (stacked) {
                            return Column(
                              children: [
                                for (var i = 0; i < actions.length; i++) ...[
                                  actions[i],
                                  if (i < actions.length - 1)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            );
                          }

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final action in actions)
                                SizedBox(
                                  width: constraints.maxWidth < 760
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 20) / 3,
                                  child: action,
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerRequestPreviewPage extends StatefulWidget {
  const CustomerRequestPreviewPage({
    super.key,
    required this.draft,
    required this.jobId,
    this.requestId,
  });

  final VanJobRequestDraft draft;
  final String jobId;
  final String? requestId;

  factory CustomerRequestPreviewPage.forRequestId({
    Key? key,
    required String requestId,
  }) {
    return CustomerRequestPreviewPage(
      key: key,
      draft: VanJobRequestDraft(
        jobId: requestId,
        customerName: '',
        phoneNumber: '',
        jobTitle: '',
        scheduledAt: DateTime.now(),
        jobDateLabel: '',
        jobTimeLabel: '',
        address: '',
        requestExactPin: false,
        requestPhotos: false,
        requiresExactPinAfterQuoteAccepted: false,
        selectedQuestionIds: const <String>[],
        answers: const <VanJobRequestAnswer>[],
        checklistItems: const <String>[],
        customQuestions: const <String>[],
        notesMessage: '',
      ),
      jobId: requestId,
      requestId: requestId,
    );
  }

  @override
  State<CustomerRequestPreviewPage> createState() =>
      _CustomerRequestPreviewPageState();
}

bool isVanCustomerCurrentLocationExactPinCaptured({
  required bool exactPinShared,
  required VanExactPinSource? source,
}) {
  return exactPinShared && source == VanExactPinSource.currentLocation;
}

bool hasVanCustomerExactPinSelection({
  required bool exactPinShared,
  required VanExactPinSource? source,
  required double? latitude,
  required double? longitude,
}) {
  return exactPinShared &&
      source != null &&
      latitude != null &&
      longitude != null;
}

bool isVanCustomerExactPinSelectionLocked({
  bool isCapturingCurrentLocation = false,
  required bool isSubmittingExactPin,
  required bool exactPinSubmitted,
}) {
  return isCapturingCurrentLocation ||
      isSubmittingExactPin ||
      exactPinSubmitted;
}

bool canVanCustomerSubmitExactPin({
  required bool requestUnavailable,
  required bool hasValidExactPinSelection,
  required bool isCapturingCurrentLocation,
  required bool isSubmittingExactPin,
  required bool exactPinSubmitted,
}) {
  return !requestUnavailable &&
      hasValidExactPinSelection &&
      !isCapturingCurrentLocation &&
      !isSubmittingExactPin &&
      !exactPinSubmitted;
}

String vanCustomerCurrentLocationExactPinButtonLabel({
  required bool exactPinShared,
  required VanExactPinSource? source,
}) {
  return isVanCustomerCurrentLocationExactPinCaptured(
        exactPinShared: exactPinShared,
        source: source,
      )
      ? 'Current location captured \u2713'
      : 'I\'m at the exact spot now';
}

String vanCustomerRetakeCurrentLocationExactPinButtonLabel() {
  return 'Retake current location';
}

String? vanCustomerExactPinHelperText({
  required bool exactPinShared,
  required VanExactPinSource? source,
  required bool exactPinSubmitted,
}) {
  if (exactPinSubmitted) {
    return 'Exact location sent. No further changes are needed.';
  }
  if (isVanCustomerCurrentLocationExactPinCaptured(
    exactPinShared: exactPinShared,
    source: source,
  )) {
    return 'Current location captured. Add any access notes, then send exact location.';
  }
  return null;
}

String vanCustomerExactPinMapButtonLabel({required bool exactPinShared}) {
  return 'Choose the spot on a map';
}

String vanCustomerExactPinConfirmButtonLabel({
  required bool isSubmittingExactPin,
  required bool exactPinSubmitted,
}) {
  if (exactPinSubmitted) {
    return 'Exact location sent \u2713';
  }
  if (isSubmittingExactPin) {
    return 'Sending exact location...';
  }
  return 'Confirm and send exact location';
}

class _CustomerRequestPreviewPageState
    extends State<CustomerRequestPreviewPage> {
  static const String _parkingQuestion = 'Parking available?';
  static const String _accessQuestion = 'Any access restrictions?';
  static const String _stairsQuestion = 'Stairs or lift?';
  static const String _loadingQuestion = 'Help loading/unloading?';
  static const String _heavyQuestion = 'Large or heavy items?';
  static const String _fragileQuestion = 'Fragile items?';
  static const String _photosQuestion = 'Photos needed?';

  late final TextEditingController _additionalNotesController;
  late final TextEditingController _pinNoteController;
  final Map<String, TextEditingController> _customAnswerControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _checklistNoteControllers =
      <String, TextEditingController>{};
  final Map<String, String?> _choiceAnswers = <String, String?>{};
  final ScrollController _scrollController = ScrollController();

  bool _exactPinShared = false;
  bool _exactPinSkipped = false;
  VanExactPinSource? _exactPinShareSource;
  double? _exactPinLatitude;
  double? _exactPinLongitude;
  bool _isCapturingCurrentLocation = false;
  bool _isSubmittingExactPin = false;
  bool _submissionComplete = false;
  DriverCustomerReplyMockData? _savedReply;
  VanJobRequestRecord? _loadedRequest;
  bool _isLoadingRequest = false;
  String? _requestLoadError;

  VanJobRequestDraft get _draft => _loadedRequest?.toDraft() ?? widget.draft;
  String get _resolvedJobId => _loadedRequest?.jobId ?? widget.jobId;

  String _introName() {
    final loadedName = _draft.customerName.trim();
    if (loadedName.isNotEmpty) {
      return loadedName;
    }

    return 'Your driver';
  }

  String _summaryJobTitle() {
    final title = _draft.jobTitle.trim();
    if (title.isNotEmpty) {
      return title;
    }

    final notes = _draft.notesMessage.trim();
    if (notes.isNotEmpty) {
      return notes;
    }

    return 'Job details';
  }

  String? _summaryJobDescription() {
    final notes = _draft.notesMessage.trim();
    return notes.isEmpty ? null : notes;
  }

  String _summaryCustomerName() {
    final customer = _draft.customerName.trim();
    return customer.isEmpty ? 'Not added yet' : customer;
  }

  String _summaryAddress() {
    return buildVanJobLocationSummary(
      address: _draft.address,
      postcode: _draft.postcode,
      locationPending: _draft.locationPending,
      requiresExactPinAfterQuoteAccepted:
          _draft.requiresExactPinAfterQuoteAccepted,
      hasExactPin: _exactPinShared,
      emptyFallback: 'Not added yet',
    );
  }

  String _summaryDateTime() {
    final date = _draft.jobDateLabel.trim().isNotEmpty
        ? _draft.jobDateLabel.trim()
        : formatDate(_draft.scheduledAt);
    final time = _draft.jobTimeLabel.trim();
    if (date.isNotEmpty && time.isNotEmpty) {
      return '$date at $time';
    }
    if (date.isNotEmpty) {
      return date;
    }
    if (time.isNotEmpty) {
      return time;
    }
    return 'To be confirmed';
  }

  @override
  void initState() {
    super.initState();
    _additionalNotesController = TextEditingController();
    _pinNoteController = TextEditingController();
    _savedReply = DriverReplyMockState.instance.jobById(_resolvedJobId);
    _populateFromDraft(_draft);
    if (widget.requestId?.trim().isNotEmpty == true) {
      _isLoadingRequest = true;
      unawaited(_loadRequestFromCloud(widget.requestId!.trim()));
    } else {
      _applySavedReply(_savedReply);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _additionalNotesController.dispose();
    _pinNoteController.dispose();
    for (final controller in _customAnswerControllers.values) {
      controller.dispose();
    }
    for (final controller in _checklistNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populateFromDraft(VanJobRequestDraft draft) {
    for (final question in draft.customQuestions) {
      _customAnswerControllers.putIfAbsent(
        question,
        () => TextEditingController(),
      );
    }
    for (final item in draft.checklistItems) {
      _checklistNoteControllers.putIfAbsent(
        item,
        () => TextEditingController(),
      );
    }
  }

  void _applySavedReply(DriverCustomerReplyMockData? reply) {
    final resolved = reply;
    if (resolved == null) {
      return;
    }

    _exactPinShared = resolved.exactPinShared;
    _exactPinSkipped = false;
    _exactPinShareSource = resolved.exactPinShareSource;
    _exactPinLatitude = resolved.exactPinLatitude;
    _exactPinLongitude = resolved.exactPinLongitude;
    _submissionComplete =
        resolved.status == 'replyReceived' ||
        resolved.status == 'quoteSent' ||
        resolved.status == 'confirmed' ||
        resolved.status == 'completed';
    _additionalNotesController.text = resolved.additionalNotes;
    _pinNoteController.text = resolved.exactPinNote ?? '';
    for (final response in resolved.checklistResponses) {
      if (_checklistNoteControllers.containsKey(response.question)) {
        _choiceAnswers[response.question] = response.answer;
        _noteControllerFor(response.question).text = response.note ?? '';
      }
    }
    for (final response in resolved.customQuestionResponses) {
      final controller = _customAnswerControllers[response.question];
      if (controller != null) {
        controller.text = response.answer;
      }
    }
  }

  DriverCustomerReplyMockData _replyFromRequestRecord(
    VanJobRequestRecord record,
  ) {
    return DriverCustomerReplyMockData(
      jobId: record.jobId,
      customerName: record.publicCustomerName,
      jobTitle: record.publicJobTitle,
      scheduledAt: record.scheduledAt,
      jobDateLabel: record.jobDateLabel,
      jobTimeLabel: record.jobTimeLabel,
      address: record.publicAddressSummary,
      phoneNumber: record.publicPhoneNumber,
      customerEmail: record.publicCustomerEmail,
      postcode: record.customerPostcode,
      requestExactPin: record.exactPinRequested,
      checklistItems: record.checklistItems,
      customQuestions: record.customQuestions,
      status: record.isSubmitted || record.hasReply
          ? 'replyReceived'
          : 'requestSent',
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      requestSentAt: record.createdAt,
      replyReceivedAt: record.customerSubmittedAt,
      exactPinShared: record.hasExactPin,
      checklistResponses: record.checklistResponses
          .map(
            (response) => DriverChecklistResponse(
              question: response.question,
              answer: response.answer,
              note: response.note.isEmpty ? null : response.note,
              icon: Icons.checklist,
            ),
          )
          .toList(growable: false),
      customQuestionResponses: record.customQuestionResponses
          .map(
            (response) => DriverCustomQuestionResponse(
              question: response.question,
              answer: response.answer,
            ),
          )
          .toList(growable: false),
      additionalNotes: record.additionalNotes,
      exactPinShareSource: vanExactPinSourceFromStorage(record.exactPinSource),
      exactPinNote: record.exactPinNote,
      exactPinLatitude: record.exactPinLat,
      exactPinLongitude: record.exactPinLng,
      requestId: record.requestId,
      requestStatus: record.status,
      requestCreatedAt: record.createdAt,
      requestUpdatedAt: record.updatedAt,
      requestSubmittedAt: record.customerSubmittedAt,
      requestExpiresAt: record.expiresAt,
      requestLink: buildVanJobRequestLink(
        record.requestId,
        shortCode: record.shortCode,
      ),
      scheduledDate: record.scheduledDate,
      scheduledStartTime: record.scheduledStartTime,
      estimatedDurationMinutes: record.estimatedDurationMinutes,
      calendarStatus: record.calendarStatus,
      locationPending: record.locationPending,
      exactPinSource: record.exactPinSource,
    );
  }

  Future<void> _loadRequestFromCloud(String requestId) async {
    try {
      final request = await VanJobRequestCloudService.instance.loadRequestById(
        requestId,
      );
      if (!mounted) {
        return;
      }
      if (request == null) {
        final localRequest = DriverReplyMockState.instance.requestForId(
          requestId,
        );
        if (localRequest != null) {
          setState(() {
            _loadedRequest = localRequest;
            _savedReply =
                DriverReplyMockState.instance.jobById(localRequest.jobId) ??
                _replyFromRequestRecord(localRequest);
            _populateFromDraft(localRequest.toDraft());
            _applySavedReply(_savedReply);
            _isLoadingRequest = false;
            _requestLoadError = null;
          });
          return;
        }
        setState(() {
          _requestLoadError = 'Request not found.';
          _isLoadingRequest = false;
        });
        return;
      }

      setState(() {
        _loadedRequest = request;
        _savedReply =
            DriverReplyMockState.instance.jobById(request.jobId) ??
            _replyFromRequestRecord(request);
        _populateFromDraft(request.toDraft());
        _applySavedReply(_savedReply);
        _isLoadingRequest = false;
        _requestLoadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requestLoadError = error.toString();
        _isLoadingRequest = false;
      });
    }
  }

  TextEditingController _noteControllerFor(String item) {
    return _checklistNoteControllers.putIfAbsent(
      item,
      () => TextEditingController(),
    );
  }

  String? _choiceFor(String item) => _choiceAnswers[item];

  void _setChoice(String item, String value) {
    setState(() {
      _choiceAnswers[item] = value;
    });
  }

  Future<void> _shareExactPin() async {
    if (_isCapturingCurrentLocation ||
        _submissionComplete ||
        _isSubmittingExactPin) {
      return;
    }

    _dismissKeyboard();
    await _shareExactPinFromCurrentLocation();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _shareExactPinFromCurrentLocation() async {
    if (_isCapturingCurrentLocation ||
        _submissionComplete ||
        _isSubmittingExactPin) {
      return;
    }

    setState(() {
      _isCapturingCurrentLocation = true;
    });

    try {
      final currentPosition = await _tryGetCurrentLocation();
      if (!mounted) {
        return;
      }

      if (currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture your current location yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _setExactPinShared(
        VanExactPinSource.currentLocation,
        selectedPin: LatLng(
          currentPosition.latitude,
          currentPosition.longitude,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturingCurrentLocation = false;
        });
      }
    }
  }

  void _setExactPinShared(
    VanExactPinSource source, {
    required LatLng selectedPin,
  }) {
    if (_submissionComplete || _isSubmittingExactPin) {
      return;
    }

    setState(() {
      _exactPinShared = true;
      _exactPinSkipped = false;
      _exactPinShareSource = source;
      _exactPinLatitude = selectedPin.latitude;
      _exactPinLongitude = selectedPin.longitude;
    });
    final message = source == VanExactPinSource.currentLocation
        ? 'Current location captured. Add any access notes, then send exact location.'
        : 'Map location selected. Add any access notes, then send exact location.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _skipExactPin() {
    if (_submissionComplete || _isSubmittingExactPin) {
      return;
    }

    setState(() {
      _exactPinShared = false;
      _exactPinSkipped = true;
      _exactPinShareSource = null;
      _exactPinLatitude = null;
      _exactPinLongitude = null;
    });
  }

  Future<void> _showExactPinMapPickerSheet() async {
    if (_submissionComplete || _isSubmittingExactPin) {
      return;
    }

    final initialCameraPosition = await _resolveExactPinPickerCameraPosition();
    if (!mounted) {
      return;
    }

    final selection = await showVanExactPinMapPickerSheet(
      context,
      initialCameraPosition: initialCameraPosition,
      initialSelectedPin: _exactPinSelectedLatLng(),
      primaryLabel: 'Use pin',
    );

    if (selection != null && mounted) {
      final note = await showVanExactPinNoteSheet(
        context,
        initialNote: _pinNoteController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      if (note != null && note.trim().isNotEmpty) {
        _pinNoteController.text = note.trim();
      }
      _setExactPinShared(
        VanExactPinSource.mapSelection,
        selectedPin: selection.selectedPin,
      );
    }
  }

  String _exactPinStatusText() {
    if (_exactPinShared) {
      final source = _exactPinShareSource;
      if (source == null) {
        return 'Exact location shared.';
      }
      return source.customerStatusLabel;
    }

    if (_exactPinSkipped) {
      return 'Pin skipped for now.';
    }

    return 'No exact location shared yet.';
  }

  String _exactPinSummaryText() {
    if (!_draft.requestExactPin) {
      return '';
    }

    if (!_exactPinShared) {
      return 'Exact pin: not shared.';
    }

    final source = _exactPinShareSource;
    if (source == null) {
      return 'Exact pin: shared.';
    }

    return source.submitSummaryText;
  }

  String _exactPinSummaryStatusLabel() {
    if (!_exactPinShared) {
      return 'Not shared yet';
    }

    final source = _exactPinShareSource;
    if (source == null) {
      return 'Shared';
    }

    switch (source) {
      case VanExactPinSource.currentLocation:
        return 'Shared - confirmed here now';
      case VanExactPinSource.mapSelection:
        return 'Chosen on map';
    }
  }

  LatLng? _exactPinSelectedLatLng() {
    final reply =
        DriverReplyMockState.instance.jobById(_resolvedJobId) ?? _savedReply;
    if (reply?.hasExactPinCoordinates == true) {
      return LatLng(reply!.exactPinLatitude!, reply.exactPinLongitude!);
    }
    return null;
  }

  Future<CameraPosition> _resolveExactPinPickerCameraPosition() async {
    final existingPin = _exactPinSelectedLatLng();
    if (existingPin != null && _isValidPickerCoordinate(existingPin)) {
      return CameraPosition(target: existingPin, zoom: 15.2);
    }

    final approxCamera = await _approximateCameraFromJobDetails();
    if (approxCamera != null &&
        _isUsablePickerCoordinate(approxCamera.target)) {
      return approxCamera;
    }

    final currentLocation = await _tryGetCurrentLocation();
    if (currentLocation != null) {
      final currentLatLng = LatLng(
        currentLocation.latitude,
        currentLocation.longitude,
      );
      if (_isUsablePickerCoordinate(currentLatLng)) {
        return CameraPosition(target: currentLatLng, zoom: 15.2);
      }
    }

    return const CameraPosition(target: LatLng(53.4808, -2.2426), zoom: 6.2);
  }

  bool _isUsablePickerCoordinate(LatLng coordinate) {
    if (coordinate.latitude == 0 && coordinate.longitude == 0) {
      return false;
    }

    if (coordinate.latitude < -90 ||
        coordinate.latitude > 90 ||
        coordinate.longitude < -180 ||
        coordinate.longitude > 180) {
      return false;
    }

    return coordinate.latitude >= 49.0 &&
        coordinate.latitude <= 61.8 &&
        coordinate.longitude >= -11.0 &&
        coordinate.longitude <= 3.8;
  }

  bool _isValidPickerCoordinate(LatLng coordinate) {
    if (coordinate.latitude == 0 && coordinate.longitude == 0) {
      return false;
    }

    return coordinate.latitude >= -90 &&
        coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 &&
        coordinate.longitude <= 180;
  }

  Future<CameraPosition?> _approximateCameraFromJobDetails() async {
    final query = [
      _draft.address.trim(),
      _draft.postcode.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    if (query.isEmpty) {
      return null;
    }

    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        return null;
      }
      final location = locations.first;
      final candidate = LatLng(location.latitude, location.longitude);
      if (!_isUsablePickerCoordinate(candidate)) {
        return null;
      }
      return CameraPosition(target: candidate, zoom: 15.1);
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _tryGetCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  int _answeredChecklistCount() {
    var answered = 0;
    for (final item in _draft.checklistItems) {
      switch (item) {
        case _parkingQuestion:
        case _stairsQuestion:
        case _loadingQuestion:
        case _photosQuestion:
          if ((_choiceFor(item)?.isNotEmpty ?? false)) {
            answered++;
          }
          break;
        case _accessQuestion:
          if (_noteControllerFor(item).text.trim().isNotEmpty) {
            answered++;
          }
          break;
        case _heavyQuestion:
        case _fragileQuestion:
          if ((_choiceFor(item)?.isNotEmpty ?? false) ||
              _noteControllerFor(item).text.trim().isNotEmpty) {
            answered++;
          }
          break;
        default:
          if (_choiceFor(item)?.isNotEmpty == true) {
            answered++;
          }
      }
    }
    return answered;
  }

  int _answeredCustomQuestionCount() {
    return _customAnswerControllers.values
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;
  }

  Future<void> _submitDetails() async {
    if (_isSubmittingExactPin || _submissionComplete) {
      return;
    }

    final request = _loadedRequest;
    if (request != null &&
        (request.isExpired ||
            request.status == 'cancelled' ||
            request.isSubmitted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This request can no longer be submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _dismissKeyboard();
    if (_draft.requestExactPin &&
        !hasVanCustomerExactPinSelection(
          exactPinShared: _exactPinShared,
          source: _exactPinShareSource,
          latitude: _exactPinLatitude,
          longitude: _exactPinLongitude,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select your exact location before sending it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingExactPin = true;
    });

    final reply = _buildReplyFromPreview();
    final checklistAnswers = _answeredChecklistCount();
    final customAnswers = _answeredCustomQuestionCount();
    final checklistKeys = reply.checklistResponses
        .map((response) => response.question.trim())
        .where((question) => question.isNotEmpty)
        .join(', ');
    final customKeys = reply.customQuestionResponses
        .map((response) => response.question.trim())
        .where((question) => question.isNotEmpty)
        .join(', ');

    if (_loadedRequest != null) {
      debugPrint(
        '[VanJobRequestSubmit] requestId=${_loadedRequest!.requestId} ownerUid=${_loadedRequest!.ownerUid} jobId=$_resolvedJobId checklistResponses keys=${checklistKeys.isEmpty ? '(none)' : checklistKeys} customQuestionResponses keys=${customKeys.isEmpty ? '(none)' : customKeys} exactPinShared=${reply.exactPinShared}',
      );
      try {
        await VanJobRequestCloudService.instance.submitCustomerReply(
          requestId: _loadedRequest!.requestId,
          ownerUid: _loadedRequest!.ownerUid,
          jobId: _resolvedJobId,
          checklistResponses: reply.checklistResponses
              .map(
                (response) => VanJobRequestChecklistResponse(
                  question: response.question,
                  answer: response.answer,
                  note: response.note ?? '',
                ),
              )
              .toList(growable: false),
          customQuestionResponses: reply.customQuestionResponses
              .map(
                (response) => VanJobRequestCustomQuestionResponse(
                  question: response.question,
                  answer: response.answer,
                ),
              )
              .toList(growable: false),
          additionalNotes: reply.additionalNotes,
          exactPinSource:
              vanExactPinSourceToStorage(_exactPinShareSource) ?? '',
          exactPinNote: reply.exactPinNote ?? '',
          exactPinLat: reply.exactPinLatitude,
          exactPinLng: reply.exactPinLongitude,
        );
        debugPrint(
          '[VanJobRequestSubmit] request doc sync success requestId=${_loadedRequest!.requestId} ownerUid=${_loadedRequest!.ownerUid} jobId=$_resolvedJobId',
        );
      } catch (error) {
        debugPrint(
          '[VanJobRequestSubmit] request doc sync failed requestId=${_loadedRequest!.requestId} ownerUid=${_loadedRequest!.ownerUid} jobId=$_resolvedJobId error=$error',
        );
      }
    }

    try {
      await DriverReplyMockState.instance.saveCustomerReplyForJob(
        _resolvedJobId,
        reply,
      );
      if (mounted) {
        setState(() {
          _submissionComplete = true;
          _savedReply = reply;
        });
      }

      if (!mounted) {
        return;
      }
      final scaffoldContext = context;
      await showModalBottomSheet<void>(
        context: scaffoldContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.11),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: const Color(
                                    0xFF58D0A4,
                                  ).withValues(alpha: 0.18),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF58D0A4,
                                    ).withValues(alpha: 0.30),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Request Sent',
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Thank you for your interest. We\'ve received your request and will get back to you with a quote as soon as possible.',
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                            height: 1.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_draft.requestExactPin) ...[
                            _SummaryLine(
                              label: 'Exact pin',
                              value: _exactPinSummaryStatusLabel(),
                              accent: _exactPinShared
                                  ? const Color(0xFF58D0A4)
                                  : const Color(0xFFFFC38C),
                              stacked: true,
                            ),
                            const SizedBox(height: 10),
                          ],
                          _SummaryLine(
                            label: 'Checklist',
                            value: '$checklistAnswers answered',
                            accent: const Color(0xFF4A7DFF),
                            labelMaxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          _SummaryLine(
                            label: 'Custom questions',
                            value: '$customAnswers answered',
                            accent: const Color(0xFFB48CFF),
                            labelMaxLines: 2,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF58D0A4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[VanJobRequestSubmit] submit failed requestId=${_loadedRequest?.requestId ?? _resolvedJobId} jobId=$_resolvedJobId error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send details. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingExactPin = false;
        });
      }
    }
  }

  DriverCustomerReplyMockData _buildReplyFromPreview() {
    final exactPinRequested = _draft.requestExactPin;
    final hasExactPinSelection =
        exactPinRequested &&
        hasVanCustomerExactPinSelection(
          exactPinShared: _exactPinShared,
          source: _exactPinShareSource,
          latitude: _exactPinLatitude,
          longitude: _exactPinLongitude,
        );
    final exactPinLatitude = hasExactPinSelection ? _exactPinLatitude : null;
    final exactPinLongitude = hasExactPinSelection ? _exactPinLongitude : null;
    final exactPinNote = exactPinRequested
        ? _pinNoteController.text.trim()
        : '';
    final checklistResponses = <DriverChecklistResponse>[
      for (final entry in _checklistNoteControllers.entries)
        DriverChecklistResponse(
          question: entry.key,
          answer: _choiceFor(entry.key) ?? 'Yes',
          note: entry.value.text.trim(),
        ),
    ];
    final customResponses = <DriverCustomQuestionResponse>[
      for (final entry in _customAnswerControllers.entries)
        DriverCustomQuestionResponse(
          question: entry.key,
          answer: entry.value.text.trim(),
        ),
    ];

    return DriverCustomerReplyMockData(
      jobId: _resolvedJobId,
      customerName: _draft.customerName,
      jobTitle: _draft.jobTitle,
      scheduledAt: _draft.scheduledAt,
      jobDateLabel: _draft.jobDateLabel,
      jobTimeLabel: _draft.jobTimeLabel,
      address: _draft.address,
      phoneNumber: _draft.phoneNumber,
      customerEmail: _draft.customerEmail,
      postcode: _draft.postcode,
      requestExactPin: _draft.requestExactPin,
      checklistItems: _draft.checklistItems,
      customQuestions: _draft.customQuestions,
      scheduledDate: _draft.scheduledDate,
      scheduledStartTime: _draft.scheduledStartTime,
      estimatedDurationMinutes: _draft.estimatedDurationMinutes,
      calendarStatus: _draft.calendarStatus,
      exactPinSource: _draft.exactPinSource,
      notesMessage: _draft.notesMessage,
      status: 'replyReceived',
      createdAt: _savedReply?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      replyReceivedAt: DateTime.now(),
      exactPinShared: hasExactPinSelection,
      exactPinShareSource: hasExactPinSelection ? _exactPinShareSource : null,
      exactPinNote: exactPinNote,
      exactPinLatitude: exactPinLatitude,
      exactPinLongitude: exactPinLongitude,
      checklistResponses: checklistResponses,
      customQuestionResponses: customResponses,
      additionalNotes: _additionalNotesController.text.trim(),
    );
  }

  Widget _buildRequestedChecklistCard(BuildContext context, String item) {
    return _ChecklistAnswerCard(
      icon: Icons.checklist,
      title: item,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectionWrap(
            selectedValue: _choiceFor(item),
            options: const ['Yes', 'No', 'Not sure'],
            onSelected: (value) => _setChoice(item, value),
          ),
          const SizedBox(height: 10),
          _ChecklistNoteField(
            controller: _noteControllerFor(item),
            hintText: 'Optional note',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomQuestionAnswer(String question) {
    final controller = _customAnswerControllers[question];
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return _ChecklistAnswerCard(
      icon: Icons.question_answer,
      title: question,
      child: _JobRequestInputField(
        controller: controller,
        icon: Icons.edit_note,
        label: 'Your answer',
        hintText: 'Type your answer',
        maxLines: 3,
      ),
    );
  }

  Widget _buildSubmissionSuccessCard(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _submissionComplete
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF58D0A4).withValues(alpha: 0.14),
                border: Border.all(
                  color: const Color(0xFF58D0A4).withValues(alpha: 0.26),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Details sent',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The driver now has your reply.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.74),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_exactPinSummaryText().isNotEmpty)
                          Text(
                            _exactPinSummaryText(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.45,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRequest) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppTheme.backgroundImage(),
            Container(color: Colors.black.withValues(alpha: 0.34)),
            const SafeArea(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF58D0A4)),
              ),
            ),
          ],
        ),
      );
    }

    if (_requestLoadError != null) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppTheme.backgroundImage(),
            Container(color: Colors.black.withValues(alpha: 0.34)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.black.withValues(alpha: 0.24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load customer request.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _requestLoadError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final introName = _introName();
    final summaryDescription = _summaryJobDescription();

    final items = _draft.checklistItems;
    final requestUnavailable =
        _loadedRequest != null &&
        (_loadedRequest!.isExpired ||
            _loadedRequest!.status == 'cancelled' ||
            _loadedRequest!.isSubmitted);
    final showExactPinSection = _draft.requestExactPin;
    final hasValidExactPinSelection = hasVanCustomerExactPinSelection(
      exactPinShared: _exactPinShared,
      source: _exactPinShareSource,
      latitude: _exactPinLatitude,
      longitude: _exactPinLongitude,
    );
    final exactPinSelectionLocked = isVanCustomerExactPinSelectionLocked(
      isCapturingCurrentLocation: _isCapturingCurrentLocation,
      isSubmittingExactPin: _isSubmittingExactPin,
      exactPinSubmitted: _submissionComplete,
    );
    final canSubmitExactPin = canVanCustomerSubmitExactPin(
      requestUnavailable: requestUnavailable,
      hasValidExactPinSelection: hasValidExactPinSelection,
      isCapturingCurrentLocation: _isCapturingCurrentLocation,
      isSubmittingExactPin: _isSubmittingExactPin,
      exactPinSubmitted: _submissionComplete,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + bottomPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WorkflowBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Fill in job details',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$introName needs a few details before the job.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (requestUnavailable) ...[
                        _JobRequestGlassCard(
                          child: Text(
                            _loadedRequest!.isExpired
                                ? 'This request is no longer active. Please ask the driver for a new link.'
                                : _loadedRequest!.status == 'cancelled'
                                ? 'This request was cancelled. Please ask the driver for a new link.'
                                : 'Your details for this request have already been sent.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildSubmissionSuccessCard(context),
                      if (_submissionComplete) const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.work_outline,
                              title: 'Job summary',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _summaryJobTitle(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            if (summaryDescription != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                summaryDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _PreviewInfoRow(
                              icon: Icons.person,
                              label: 'Customer',
                              value: _summaryCustomerName(),
                            ),
                            const SizedBox(height: 12),
                            _PreviewInfoRow(
                              icon: Icons.location_on,
                              label: 'Address',
                              value: _summaryAddress(),
                            ),
                            const SizedBox(height: 12),
                            _PreviewInfoRow(
                              icon: Icons.calendar_today,
                              label: 'Date and time',
                              value: _summaryDateTime(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (items.isNotEmpty) ...[
                        _JobRequestGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _JobRequestSectionHeader(
                                icon: Icons.checklist,
                                title: 'Questions',
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < items.length;
                                    index++
                                  ) ...[
                                    _buildRequestedChecklistCard(
                                      context,
                                      items[index],
                                    ),
                                    if (index < items.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_draft.customQuestions.isNotEmpty)
                        _JobRequestGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _JobRequestSectionHeader(
                                icon: Icons.question_answer,
                                title: 'Custom questions',
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < _draft.customQuestions.length;
                                    index++
                                  ) ...[
                                    _buildCustomQuestionAnswer(
                                      _draft.customQuestions[index],
                                    ),
                                    if (index <
                                        _draft.customQuestions.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (_draft.customQuestions.isNotEmpty)
                        const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.notes,
                              title: 'Anything else?',
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _additionalNotesController,
                              icon: Icons.edit_note,
                              label: 'Anything else?',
                              hintText: 'Optional note',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      if (showExactPinSection) ...[
                        const SizedBox(height: 12),
                        _JobRequestGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _JobRequestSectionHeader(
                                icon: Icons.location_on,
                                title: 'Exact location',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Only share this if you are at the entrance, bay or drop-off point.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _exactPinStatusText(),
                                  key: ValueKey<String>(
                                    '${_exactPinShared}_${_exactPinSkipped}_${_exactPinShareSource?.name ?? 'none'}',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.80),
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _JobRequestInputField(
                                controller: _pinNoteController,
                                icon: Icons.edit_note,
                                label: 'Any entrance, gate or drop-off notes?',
                                hintText: 'Optional note',
                                maxLines: 2,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 14),
                              Builder(
                                builder: (context) {
                                  final currentLocationCaptured =
                                      isVanCustomerCurrentLocationExactPinCaptured(
                                        exactPinShared: _exactPinShared,
                                        source: _exactPinShareSource,
                                      );
                                  final helperText =
                                      vanCustomerExactPinHelperText(
                                        exactPinShared: _exactPinShared,
                                        source: _exactPinShareSource,
                                        exactPinSubmitted: _submissionComplete,
                                      );
                                  final showCompletedCurrentLocationState =
                                      currentLocationCaptured &&
                                      !_isCapturingCurrentLocation;

                                  return Column(
                                    children: [
                                      if (showCompletedCurrentLocationState) ...[
                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: OutlinedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(
                                              Icons.check_circle,
                                            ),
                                            label: Text(
                                              vanCustomerCurrentLocationExactPinButtonLabel(
                                                exactPinShared: _exactPinShared,
                                                source: _exactPinShareSource,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              disabledForegroundColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.92),
                                              backgroundColor: const Color(
                                                0xFF58D0A4,
                                              ).withValues(alpha: 0.12),
                                              disabledBackgroundColor:
                                                  const Color(
                                                    0xFF58D0A4,
                                                  ).withValues(alpha: 0.12),
                                              side: BorderSide(
                                                color: const Color(
                                                  0xFF58D0A4,
                                                ).withValues(alpha: 0.38),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                exactPinSelectionLocked ||
                                                    _isCapturingCurrentLocation
                                                ? null
                                                : _shareExactPin,
                                            icon: _isCapturingCurrentLocation
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(Icons.refresh),
                                            label: Text(
                                              _isCapturingCurrentLocation
                                                  ? 'Capturing current location...'
                                                  : vanCustomerRetakeCurrentLocationExactPinButtonLabel(),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              disabledForegroundColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.62),
                                              side: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.18,
                                                ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: FilledButton.icon(
                                            onPressed:
                                                exactPinSelectionLocked ||
                                                    _isCapturingCurrentLocation
                                                ? null
                                                : _shareExactPin,
                                            icon: _isCapturingCurrentLocation
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2.2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Icon(Icons.my_location),
                                            label: Text(
                                              _isCapturingCurrentLocation
                                                  ? 'Capturing current location...'
                                                  : vanCustomerCurrentLocationExactPinButtonLabel(
                                                      exactPinShared:
                                                          _exactPinShared,
                                                      source:
                                                          _exactPinShareSource,
                                                    ),
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF4A7DFF,
                                              ),
                                              disabledBackgroundColor:
                                                  const Color(
                                                    0xFF4A7DFF,
                                                  ).withValues(alpha: 0.42),
                                              foregroundColor: Colors.white,
                                              disabledForegroundColor: Colors
                                                  .white
                                                  .withValues(alpha: 0.72),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (helperText != null) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          helperText,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.68,
                                                ),
                                                height: 1.4,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton.icon(
                                          onPressed: exactPinSelectionLocked
                                              ? null
                                              : _showExactPinMapPickerSheet,
                                          icon: const Icon(Icons.map_outlined),
                                          label: Text(
                                            vanCustomerExactPinMapButtonLabel(
                                              exactPinShared: _exactPinShared,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            disabledForegroundColor: Colors
                                                .white
                                                .withValues(alpha: 0.62),
                                            side: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.18,
                                              ),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: TextButton(
                                  onPressed: exactPinSelectionLocked
                                      ? null
                                      : _skipExactPin,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor: Colors.white
                                        .withValues(alpha: 0.52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Skip pin'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.send,
                              title: 'Send back to driver',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Once everything looks right, send the details back.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.74),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: showExactPinSection
                                    ? (canSubmitExactPin
                                          ? _submitDetails
                                          : null)
                                    : (requestUnavailable
                                          ? null
                                          : _submitDetails),
                                icon: _isSubmittingExactPin
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _submissionComplete
                                            ? Icons.check_circle
                                            : Icons.send,
                                      ),
                                label: Text(
                                  showExactPinSection
                                      ? vanCustomerExactPinConfirmButtonLabel(
                                          isSubmittingExactPin:
                                              _isSubmittingExactPin,
                                          exactPinSubmitted:
                                              _submissionComplete,
                                        )
                                      : 'Send details',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF58D0A4),
                                  disabledBackgroundColor: const Color(
                                    0xFF58D0A4,
                                  ).withValues(alpha: 0.42),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white
                                      .withValues(alpha: 0.74),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Only this request will update.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.58),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowBackButton extends StatelessWidget {
  const _WorkflowBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ChecklistAnswerCard extends StatelessWidget {
  const _ChecklistAnswerCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SelectionWrap extends StatelessWidget {
  const _SelectionWrap({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => _SelectionPill(
              label: option,
              selected: selectedValue == option,
              onTap: () => onSelected(option),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected
        ? const Color(0xFF4A7DFF).withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.08);
    final borderColor = selected
        ? const Color(0xFF4A7DFF).withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: backgroundColor,
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: selected ? 1 : 0.86),
              fontSize: 13.4,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistNoteField extends StatelessWidget {
  const _ChecklistNoteField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      minLines: 1,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.6,
        height: 1.22,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.44),
          fontSize: 12.0,
          height: 1.2,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: const Color(0xFF4A7DFF).withValues(alpha: 0.68),
            width: 1.1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.accent,
    this.stacked = false,
    this.labelMaxLines = 1,
  });

  final String label;
  final String value;
  final Color accent;
  final bool stacked;
  final int labelMaxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: labelMaxLines,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: labelMaxLines,
                    softWrap: true,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _JobRequestGlassCard extends StatelessWidget {
  const _JobRequestGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _JobRequestSectionHeader extends StatelessWidget {
  const _JobRequestSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _JobRequestInputField extends StatelessWidget {
  const _JobRequestInputField({
    required this.controller,
    required this.icon,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: kVanMateFieldTextStyle,
        decoration: vanMateFieldDecoration(
          label: label,
          hintText: hintText,
          prefixIcon: Icon(icon),
          labelOpacity: 0.68,
          hintOpacity: 0.50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  const _PreviewInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
