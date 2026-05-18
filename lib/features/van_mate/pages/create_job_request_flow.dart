import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../helpers/app_theme.dart';
import '../models/van_job_request_draft.dart';
import '../pages/driver_customer_reply_mock_page.dart';
import '../models/van_exact_pin_source.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_exact_pin_flow.dart';

class CreateJobRequestPage extends StatefulWidget {
  const CreateJobRequestPage({super.key});

  @override
  State<CreateJobRequestPage> createState() => _CreateJobRequestPageState();
}

class _CreateJobRequestPageState extends State<CreateJobRequestPage> {
  final String _jobId =
      'job_${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController _customerNameController = TextEditingController(
    text: '',
  );
  final TextEditingController _phoneNumberController = TextEditingController(
    text: '',
  );
  final TextEditingController _customerEmailController =
      TextEditingController(
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

  final List<_JobChecklistOption>
  _checklistOptions = const <_JobChecklistOption>[
    _JobChecklistOption(label: 'Parking available?', icon: Icons.local_parking),
    _JobChecklistOption(
      label: 'Any access restrictions?',
      icon: Icons.lock_outline,
    ),
    _JobChecklistOption(label: 'Stairs or lift?', icon: Icons.stairs_outlined),
    _JobChecklistOption(
      label: 'Help loading/unloading?',
      icon: Icons.support_agent_outlined,
    ),
    _JobChecklistOption(
      label: 'Large or heavy items?',
      icon: Icons.inventory_2_outlined,
    ),
    _JobChecklistOption(
      label: 'Fragile items?',
      icon: Icons.warning_amber_outlined,
    ),
    _JobChecklistOption(
      label: 'Photos needed?',
      icon: Icons.photo_camera_outlined,
    ),
  ];

  late final Map<String, bool> _checklistSelections = <String, bool>{
    for (final option in _checklistOptions) option.label: true,
  };

  late DateTime _jobDate = DateUtils.dateOnly(DateTime.now());
  late TimeOfDay _jobTime = TimeOfDay.fromDateTime(DateTime.now());
  bool _requestExactPin = true;
  final List<String> _customQuestions = <String>[
    'Any gate codes or access instructions?',
  ];

  @override
  void initState() {
    super.initState();
    DriverReplyMockState.instance.resetTransientWorkflowState();
    _syncDateTimeControllers();
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
    super.dispose();
  }

  void _syncDateTimeControllers() {
    _jobDateController.text = _formatJobDate(_jobDate);
    _jobTimeController.text = _formatJobTime(_jobTime);
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

  VanJobRequestDraft _buildDraft() {
    return VanJobRequestDraft(
      jobId: _jobId,
      customerName: _customerNameController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim(),
      customerEmail: _customerEmailController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      scheduledAt: DateTime(
        _jobDate.year,
        _jobDate.month,
        _jobDate.day,
        _jobTime.hour,
        _jobTime.minute,
      ),
      jobDateLabel: _formatJobDate(_jobDate),
      jobTimeLabel: _formatJobTime(_jobTime),
      address: _addressController.text.trim(),
      postcode: _postcodeController.text.trim(),
      requestExactPin: _requestExactPin,
      checklistItems: _checklistOptions
          .where((option) => _checklistSelections[option.label] == true)
          .map((option) => option.label)
          .toList(growable: false),
      customQuestions: List<String>.unmodifiable(_customQuestions),
      notesMessage: _notesController.text.trim(),
    );
  }

  Future<void> _pickJobDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _jobDate,
      firstDate: DateTime(DateTime.now().year - 1),
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
      if (!_customQuestions.contains(value)) {
        _customQuestions.add(value);
      }
      _customQuestionController.clear();
    });
  }

  Future<void> _openPreview() async {
    FocusScope.of(context).unfocus();
    final draft = _buildDraft();
    final job = DriverReplyMockState.instance.upsertDraftJob(draft);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerRequestPreviewPage(
          draft: draft,
          jobId: job.jobId,
        ),
      ),
    );
  }

  bool _validateMainFields() {
    final draft = _buildDraft();
    final hasAddress = draft.address.trim().isNotEmpty ||
        draft.postcode.trim().isNotEmpty;
    final hasRequired = draft.customerName.trim().isNotEmpty &&
        draft.jobTitle.trim().isNotEmpty &&
        draft.jobDateLabel.trim().isNotEmpty &&
        draft.jobTimeLabel.trim().isNotEmpty &&
        hasAddress;

    if (hasRequired) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please add the main job details first.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  void _saveDraft() {
    if (!_validateMainFields()) {
      return;
    }

    FocusScope.of(context).unfocus();
    DriverReplyMockState.instance.saveDraftJob(_buildDraft());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Job draft saved.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendRequest() {
    if (!_validateMainFields()) {
      return;
    }

    FocusScope.of(context).unfocus();
    DriverReplyMockState.instance.sendJobRequest(_buildDraft());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Job request created.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                        'Send a checklist and exact pin request to your customer.',
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
                                    keyboardType:
                                        TextInputType.emailAddress,
                                  ),
                                  _JobRequestInputField(
                                    controller: _jobTitleController,
                                    icon: Icons.checklist,
                                    label: 'Job title / reference',
                                    hintText: 'Add job title or reference',
                                  ),
                                  _JobRequestInputField(
                                    controller: _jobDateController,
                                    icon: Icons.schedule,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.location_on,
                              title: 'Location',
                            ),
                            const SizedBox(height: 14),
                            _JobRequestInputField(
                              controller: _addressController,
                              icon: Icons.location_on,
                              label: 'Address',
                              hintText: 'Enter address or postcode',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _postcodeController,
                              icon: Icons.local_post_office,
                              label: 'Postcode',
                              hintText: 'Enter postcode if separate',
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _requestExactPin,
                              onChanged: (value) {
                                setState(() {
                                  _requestExactPin = value;
                                });
                              },
                              title: const Text(
                                'Request exact pin from customer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'Customer can send the exact entrance, bay or collection point.',
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
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.notes,
                              title: 'Notes / message',
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _notesController,
                              icon: Icons.notes,
                              label: 'Driver notes or message',
                              hintText: 'Add any notes for the customer',
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
                              icon: Icons.checklist,
                              title: 'Checklist',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What do you need to ask?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (
                              var index = 0;
                              index < _checklistOptions.length;
                              index++
                            ) ...[
                              _JobRequestChecklistTile(
                                label: _checklistOptions[index].label,
                                icon: _checklistOptions[index].icon,
                                value:
                                    _checklistSelections[_checklistOptions[index]
                                        .label] ==
                                    true,
                                onChanged: (value) {
                                  setState(() {
                                    _checklistSelections[_checklistOptions[index]
                                            .label] =
                                        value;
                                  });
                                },
                              ),
                              if (index < _checklistOptions.length - 1)
                                const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.question_answer,
                              title: 'Custom questions',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add anything else you need to ask before the job starts.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 420;
                                final addButton = FilledButton.icon(
                                  onPressed: _addCustomQuestion,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Question'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A7DFF),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                );

                                final input = _JobRequestInputField(
                                  controller: _customQuestionController,
                                  icon: Icons.question_answer,
                                  label: 'Add custom question',
                                  hintText: 'Type a custom question',
                                );

                                if (stacked) {
                                  return Column(
                                    children: [
                                      input,
                                      const SizedBox(height: 10),
                                      addButton,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: input),
                                    const SizedBox(width: 12),
                                    SizedBox(width: 156, child: addButton),
                                  ],
                                );
                              },
                            ),
                            if (_customQuestions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _customQuestions
                                    .map(
                                      (question) => InputChip(
                                        label: Text(
                                          question,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.8,
                                            height: 1.15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onDeleted: () {
                                          setState(() {
                                            _customQuestions.remove(question);
                                          });
                                        },
                                        deleteIconColor: Colors.white70,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.08),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        labelPadding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
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
                                'Hi, please fill in this quick job checklist and share the exact location pin so I have the correct details before the job.',
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
                            FilledButton.icon(
                              onPressed: _openPreview,
                              icon: const Icon(Icons.preview),
                              label: const Text('Preview Request'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4A7DFF),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _saveDraft,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Draft'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _sendRequest,
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

                          return Row(
                            children: [
                              Expanded(child: actions[0]),
                              const SizedBox(width: 10),
                              Expanded(child: actions[1]),
                              const SizedBox(width: 10),
                              Expanded(child: actions[2]),
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
  });

  final VanJobRequestDraft draft;
  final String jobId;

  @override
  State<CustomerRequestPreviewPage> createState() =>
      _CustomerRequestPreviewPageState();
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
  late final Map<String, TextEditingController> _customAnswerControllers;
  late final Map<String, TextEditingController> _checklistNoteControllers;
  late final Map<String, String?> _choiceAnswers;
  final ScrollController _scrollController = ScrollController();

  bool _exactPinShared = false;
  VanExactPinSource? _exactPinShareSource;
  bool _photoPlaceholderAdded = false;
  bool _submissionComplete = false;
  DriverCustomerReplyMockData? _savedReply;

  @override
  void initState() {
    super.initState();
    _savedReply = DriverReplyMockState.instance.jobById(widget.jobId);
    _additionalNotesController = TextEditingController();
    _pinNoteController = TextEditingController();
    _customAnswerControllers = <String, TextEditingController>{
      for (final question in widget.draft.customQuestions)
        question: TextEditingController(),
    };
    _checklistNoteControllers = <String, TextEditingController>{
      if (widget.draft.checklistItems.contains(_parkingQuestion))
        _parkingQuestion: TextEditingController(),
      if (widget.draft.checklistItems.contains(_accessQuestion))
        _accessQuestion: TextEditingController(),
      if (widget.draft.checklistItems.contains(_heavyQuestion))
        _heavyQuestion: TextEditingController(),
      if (widget.draft.checklistItems.contains(_fragileQuestion))
        _fragileQuestion: TextEditingController(),
      if (widget.draft.checklistItems.contains(_photosQuestion))
        _photosQuestion: TextEditingController(),
    };
    _choiceAnswers = <String, String?>{};
    final reply = _savedReply;
    if (reply != null) {
      _exactPinShared = reply.exactPinShared;
      _exactPinShareSource = reply.exactPinShareSource;
      _submissionComplete = reply.status == 'replyReceived' ||
          reply.status == 'quoteSent' ||
          reply.status == 'confirmed' ||
          reply.status == 'completed';
      _additionalNotesController.text = reply.additionalNotes;
      _pinNoteController.text = reply.exactPinNote ?? '';
      for (final response in reply.checklistResponses) {
        if (_checklistNoteControllers.containsKey(response.question)) {
          _choiceAnswers[response.question] = response.answer;
          _noteControllerFor(response.question).text = response.note ?? '';
        }
      }
      for (final response in reply.customQuestionResponses) {
        final controller = _customAnswerControllers[response.question];
        if (controller != null) {
          controller.text = response.answer;
        }
      }
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
    _dismissKeyboard();
    final choice = await _showExactPinConfirmationSheet();
    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case _ExactPinChoice.yesHereNow:
        await _shareExactPinFromCurrentLocation();
        break;
      case _ExactPinChoice.chooseOnMap:
        await _showExactPinMapPickerSheet();
        break;
      case _ExactPinChoice.cancel:
        break;
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _shareExactPinFromCurrentLocation() async {
    final currentPosition = await _tryGetCurrentLocation();
    if (!mounted) {
      return;
    }

    _setExactPinShared(
      VanExactPinSource.currentLocation,
      selectedPin: currentPosition == null
          ? null
          : LatLng(currentPosition.latitude, currentPosition.longitude),
    );
  }

  void _setExactPinShared(
    VanExactPinSource source, {
    LatLng? selectedPin,
  }) {
    setState(() {
      _exactPinShared = true;
      _exactPinShareSource = source;
    });
    DriverReplyMockState.instance.setExactPinDetails(
      source: source,
      note: _pinNoteController.text.trim(),
      latitude: selectedPin?.latitude,
      longitude: selectedPin?.longitude,
      jobId: widget.jobId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exact pin shared.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<_ExactPinChoice?> _showExactPinConfirmationSheet() {
    return showModalBottomSheet<_ExactPinChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ExactPinSheet(
          title: 'Are you at the exact pickup/drop-off point now?',
          message:
              'Only share your current location if you are standing at the place the driver needs to go - for example the entrance, loading bay, driveway, gate or collection point.',
          primaryLabel: 'Yes, I\'m here now',
          secondaryLabel: 'No, choose it on a map',
          onPrimary: () =>
              Navigator.of(sheetContext).pop(_ExactPinChoice.yesHereNow),
          onSecondary: () =>
              Navigator.of(sheetContext).pop(_ExactPinChoice.chooseOnMap),
          onCancel: () =>
              Navigator.of(sheetContext).pop(_ExactPinChoice.cancel),
        );
      },
    );
  }

  Future<void> _showExactPinMapPickerSheet() async {
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
    if (!_exactPinShared) {
      return 'Exact pin has not been shared yet.';
    }

    final source = _exactPinShareSource;
    if (source == null) {
      return 'Exact pin shared';
    }

    return source.customerStatusLabel;
  }

  String _exactPinHelperText() {
    if (!_exactPinShared) {
      return 'Only share your current location if you are standing at the place the driver needs to go.';
    }

    final source = _exactPinShareSource;
    if (source == null) {
      return 'This is the location the driver will use for navigation.';
    }

    return source.customerHelperText;
  }

  String _exactPinSummaryText() {
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
    final reply = DriverReplyMockState.instance.jobById(widget.jobId) ?? _savedReply;
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
      widget.draft.address.trim(),
      widget.draft.postcode.trim(),
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
      return CameraPosition(
        target: candidate,
        zoom: 15.1,
      );
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
    for (final item in widget.draft.checklistItems) {
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
    _dismissKeyboard();
    setState(() {
      _submissionComplete = true;
    });

    final checklistAnswers = _answeredChecklistCount();
    final customAnswers = _answeredCustomQuestionCount();

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
                                    'Details submitted',
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
                                    'Your job information has been sent back to the driver.',
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
                        _SummaryLine(
                          label: 'Exact pin',
                          value: _exactPinSummaryStatusLabel(),
                          accent: _exactPinShared
                              ? const Color(0xFF58D0A4)
                              : const Color(0xFFFFC38C),
                          stacked: true,
                        ),
                        const SizedBox(height: 10),
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
                            onPressed: () {
                              final reply = _buildReplyFromPreview();
                              DriverReplyMockState.instance
                                  .saveCustomerReplyForJob(
                                widget.jobId,
                                reply,
                              );
                              Navigator.of(sheetContext).pop();
                              if (mounted) {
                                setState(() {
                                  _savedReply = reply;
                                });
                              }
                            },
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
  }

  DriverCustomerReplyMockData _buildReplyFromPreview() {
    final storedJob = DriverReplyMockState.instance.jobById(widget.jobId);
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
      jobId: widget.jobId,
      customerName: widget.draft.customerName,
      jobTitle: widget.draft.jobTitle,
      scheduledAt: widget.draft.scheduledAt,
      jobDateLabel: widget.draft.jobDateLabel,
      jobTimeLabel: widget.draft.jobTimeLabel,
      address: widget.draft.address,
      phoneNumber: widget.draft.phoneNumber,
      customerEmail: widget.draft.customerEmail,
      postcode: widget.draft.postcode,
      requestExactPin: widget.draft.requestExactPin,
      checklistItems: widget.draft.checklistItems,
      customQuestions: widget.draft.customQuestions,
      notesMessage: widget.draft.notesMessage,
      status: 'replyReceived',
      createdAt: _savedReply?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      replyReceivedAt: DateTime.now(),
      exactPinShared: _exactPinShared,
      exactPinShareSource: _exactPinShareSource,
      exactPinNote: _pinNoteController.text.trim(),
      exactPinLatitude:
          storedJob?.exactPinLatitude ?? _savedReply?.exactPinLatitude,
      exactPinLongitude:
          storedJob?.exactPinLongitude ?? _savedReply?.exactPinLongitude,
      checklistResponses: checklistResponses,
      customQuestionResponses: customResponses,
      additionalNotes: _additionalNotesController.text.trim(),
    );
  }

  Widget _buildRequestedChecklistCard(BuildContext context, String item) {
    switch (item) {
      case _parkingQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.local_parking,
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
                hintText: 'Where should the driver park?',
              ),
            ],
          ),
        );
      case _accessQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.lock_outline,
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
                hintText:
                    'Gate code, height limit, barrier, loading bay, security...',
              ),
            ],
          ),
        );
      case _stairsQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.stairs_outlined,
          title: item,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionWrap(
                selectedValue: _choiceFor(item),
                options: const ['Stairs', 'Lift', 'Ground floor', 'Not sure'],
                onSelected: (value) => _setChoice(item, value),
              ),
              const SizedBox(height: 10),
              _ChecklistNoteField(
                controller: _noteControllerFor(item),
                hintText: 'Floor number, lift size, awkward access...',
              ),
            ],
          ),
        );
      case _loadingQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.support_agent_outlined,
          title: item,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionWrap(
                selectedValue: _choiceFor(item),
                options: const ['Yes', 'No', 'Maybe'],
                onSelected: (value) => _setChoice(item, value),
              ),
              const SizedBox(height: 10),
              _ChecklistNoteField(
                controller: _noteControllerFor(item),
                hintText: 'Who can help, where to meet, anything heavy...',
              ),
            ],
          ),
        );
      case _heavyQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.inventory_2_outlined,
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
                hintText: 'What item is heavy or awkward?',
              ),
            ],
          ),
        );
      case _fragileQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.warning_amber_outlined,
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
                hintText: 'What is fragile?',
              ),
            ],
          ),
        );
      case _photosQuestion:
        return _ChecklistAnswerCard(
          icon: Icons.photo_camera_outlined,
          title: item,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelectionWrap(
                selectedValue: _photoPlaceholderAdded ? 'Add photo' : null,
                options: const ['Add photo', 'Skip for now'],
                onSelected: (value) {
                  setState(() {
                    _photoPlaceholderAdded = value == 'Add photo';
                    _choiceAnswers[item] = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _ChecklistNoteField(
                controller: _noteControllerFor(item),
                hintText:
                    'Add any photo details or explain what needs showing.',
              ),
              const SizedBox(height: 8),
              Text(
                _photoPlaceholderAdded
                    ? 'Mock photo placeholder selected'
                    : 'UI only, no real upload yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      default:
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
                hintText: 'Add any extra details',
              ),
            ],
          ),
        );
    }
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
        label: 'Customer answer',
        hintText: 'Type your answer...',
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
                          'Details submitted',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The driver will see this customer reply in the mock workflow.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.74),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 8),
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
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    final items = widget.draft.checklistItems;

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
                        'Customer Job Request',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete the details below.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSubmissionSuccessCard(context),
                      if (_submissionComplete) const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreviewInfoRow(
                              icon: Icons.checklist,
                              label: 'Job title',
                              value: widget.draft.jobTitle.isEmpty
                                  ? 'No title yet'
                                  : widget.draft.jobTitle,
                            ),
                            const SizedBox(height: 12),
                            _PreviewInfoRow(
                              icon: Icons.person,
                              label: 'Customer name',
                              value: widget.draft.customerName.isEmpty
                                  ? 'No customer name yet'
                                  : widget.draft.customerName,
                            ),
                            const SizedBox(height: 12),
                            _PreviewInfoRow(
                              icon: Icons.phone,
                              label: 'Phone number',
                              value: widget.draft.phoneNumber.isEmpty
                                  ? 'No phone number yet'
                                  : widget.draft.phoneNumber,
                            ),
                            const SizedBox(height: 12),
                            _PreviewInfoRow(
                              icon: Icons.location_on,
                              label: 'Requested pin',
                              value: widget.draft.requestExactPin
                                  ? 'Exact pin requested'
                                  : 'Exact pin not requested',
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
                              icon: Icons.checklist,
                              title: 'Requested checklist items',
                            ),
                            const SizedBox(height: 12),
                            if (items.isEmpty)
                              Text(
                                'No checklist items selected yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              )
                            else
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
                      if (widget.draft.customQuestions.isNotEmpty)
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
                                    index < widget.draft.customQuestions.length;
                                    index++
                                  ) ...[
                                    _buildCustomQuestionAnswer(
                                      widget.draft.customQuestions[index],
                                    ),
                                    if (index <
                                        widget.draft.customQuestions.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (widget.draft.customQuestions.isNotEmpty)
                        const SizedBox(height: 12),
                      _JobRequestGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _JobRequestSectionHeader(
                              icon: Icons.notes,
                              title: 'Additional notes for the driver',
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _additionalNotesController,
                              icon: Icons.edit_note,
                              label: 'Additional notes for the driver',
                              hintText:
                                  'Gate code, where to park, who to ask for, best entrance, anything awkward...',
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Job date: ${widget.draft.jobDateLabel} | Job time: ${widget.draft.jobTimeLabel}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Address: ${widget.draft.address.isEmpty ? "Not added yet" : widget.draft.address}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
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
                              icon: Icons.location_on,
                              title: 'Exact pin',
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _exactPinShared
                                  ? Container(
                                      key: const ValueKey<String>('shared'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: const Color(
                                          0xFF58D0A4,
                                        ).withValues(alpha: 0.14),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF58D0A4,
                                          ).withValues(alpha: 0.26),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _exactPinStatusText(),
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _exactPinHelperText(),
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.74,
                                                            ),
                                                        height: 1.45,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      'Exact pin has not been shared yet.',
                                      key: const ValueKey<String>('pending'),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.72,
                                            ),
                                            height: 1.45,
                                          ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _JobRequestInputField(
                              controller: _pinNoteController,
                              icon: Icons.edit_note,
                              label: 'Add / edit pin note',
                              hintText:
                                  'Use rear gate or loading bay is round the back.',
                              maxLines: 2,
                              onChanged: (_) {
                                DriverReplyMockState.instance.setExactPinDetails(
                                  source: _exactPinShareSource,
                                  note: _pinNoteController.text.trim(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 480;
                          final shareLabel = _exactPinShared
                              ? 'Edit exact pin'
                              : 'Share exact pin';
                          final shareIcon = _exactPinShared
                              ? Icons.edit_location_alt_outlined
                              : Icons.location_on;
                          final actions = <Widget>[
                            FilledButton.icon(
                              onPressed: _shareExactPin,
                              icon: Icon(shareIcon),
                              label: Text(
                                shareLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _exactPinShared
                                    ? const Color(0xFF58D0A4)
                                    : const Color(0xFF4A7DFF),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _submitDetails,
                              icon: const Icon(Icons.send),
                              label: const Text('Submit details'),
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

                          return Row(
                            children: [
                              Expanded(child: actions[0]),
                              const SizedBox(width: 10),
                              Expanded(child: actions[1]),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This reply will save back to the driver\'s job, calendar and place notes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.45,
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

enum _ExactPinChoice { yesHereNow, chooseOnMap, cancel }

class _ExactPinSheet extends StatelessWidget {
  const _ExactPinSheet({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.onCancel,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7DFF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(secondaryLabel),
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              ),
            ),
          ),
        ),
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
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
              fontSize: 12.0,
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

class _JobRequestChecklistTile extends StatelessWidget {
  const _JobRequestChecklistTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF4A7DFF),
        checkColor: Colors.white,
        title: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.2,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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

class _JobChecklistOption {
  const _JobChecklistOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
