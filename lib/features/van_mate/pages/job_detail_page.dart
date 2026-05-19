import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import 'driver_customer_reply_mock_page.dart';
import '../widgets/van_form_field_styles.dart';

Future<bool?> openDriverJobDetailMockPage(
  BuildContext context, {
  required DriverCustomerReplyMockData reply,
  required bool completed,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => JobDetailPage(reply: reply, completed: completed),
    ),
  );
}

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.reply,
    required this.completed,
  });

  final DriverCustomerReplyMockData reply;
  final bool completed;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  DriverCustomerReplyMockData get reply =>
      DriverReplyMockState.instance.jobById(_jobId) ?? widget.reply;
  String get _jobId => widget.reply.jobId;
  bool get _completed => reply.isCompleted || widget.completed;
  bool get _cancelled => reply.isCancelled;

  @override
  void initState() {
    super.initState();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _checklistValue(String question, String fallback) {
    final match = reply.checklistResponses.firstWhere(
      (item) => item.question == question,
      orElse: () =>
          DriverChecklistResponse(question: question, answer: fallback),
    );
    return match.answer.isEmpty ? fallback : match.answer;
  }

  String _checklistNote(String question) {
    final match = reply.checklistResponses.firstWhere(
      (item) => item.question == question,
      orElse: () => const DriverChecklistResponse(question: '', answer: ''),
    );
    return formatAnswerWithNote(match.answer, match.note ?? '');
  }

  String? _customQuestionSummary() {
    final parts = <String>[];
    for (final question in reply.customQuestions) {
      final cleanedQuestion = question.trim();
      if (cleanedQuestion.isEmpty) {
        continue;
      }

      final match = reply.customQuestionResponses.firstWhere(
        (item) => item.question.trim() == cleanedQuestion,
        orElse: () =>
            DriverCustomQuestionResponse(question: cleanedQuestion, answer: ''),
      );
      final cleanedAnswer = match.answer.trim();
      if (cleanedAnswer.isEmpty) {
        continue;
      }

      parts.add(formatCustomQuestionAnswer(cleanedQuestion, cleanedAnswer));
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('\n\n');
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

  String _quoteMessageText() {
    final quoteAmount = formatCurrency(reply.quoteAmount ?? 0);
    final quoteText = sanitizeVanText(reply.jobTitle).trim().toLowerCase();
    final scheduledAt = reply.scheduledAtOrParsed;
    final dateText = scheduledAt == null
        ? sanitizeVanText(reply.jobDateLabel).trim()
        : formatDate(scheduledAt);
    return '''
Hi ${sanitizeVanText(reply.customerName).trim()}, here's the quote for your $quoteText.

Job date: $dateText
Address: ${sanitizeVanText(reply.address).trim()}

Quote: $quoteAmount

Please reply to confirm if you're happy to go ahead.
''';
  }

  void _openReply() {
    unawaited(openDriverCustomerReplyMockPage(context, jobId: _jobId));
  }

  void _openQuote() {
    unawaited(openDriverQuoteMockPage(context, reply));
  }

  void _navigate() {
    _showSnack('Navigation would open using your preferred nav app.');
  }

  void _callCustomer() {
    _showSnack('Phone call would start.');
  }

  Widget _editField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        labelOpacity: 0.68,
        hintOpacity: 0.50,
        fillColor: Colors.white.withValues(alpha: 0.06),
        focusedBorderWidth: 1.4,
      ),
    );
  }

  Future<void> _editJobDetails() async {
    final current = reply;
    final customerNameController = TextEditingController(
      text: current.customerName,
    );
    final phoneController = TextEditingController(text: current.phoneNumber);
    final emailController = TextEditingController(text: current.customerEmail);
    final jobTitleController = TextEditingController(text: current.jobTitle);
    final addressController = TextEditingController(text: current.address);
    final postcodeController = TextEditingController(text: current.postcode);
    final notesController = TextEditingController(text: current.notesMessage);
    DateTime selectedDate = DateUtils.dateOnly(
      current.scheduledAtOrParsed ?? DateTime.now(),
    );
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(
      current.scheduledAtOrParsed ?? DateTime.now(),
    );

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      color: const Color(0xFF0E1520).withValues(alpha: 0.97),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit job details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Update the saved local job without creating a duplicate.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _editField(
                                customerNameController,
                                'Customer name',
                              ),
                              const SizedBox(height: 10),
                              _editField(
                                jobTitleController,
                                'Job title / reference',
                              ),
                              const SizedBox(height: 10),
                              _editField(
                                phoneController,
                                'Phone',
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 10),
                              _editField(
                                emailController,
                                'Email',
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 10),
                              _editField(addressController, 'Address'),
                              const SizedBox(height: 10),
                              _editField(postcodeController, 'Postcode'),
                              const SizedBox(height: 10),
                              _editField(
                                notesController,
                                'Notes',
                                minLines: 3,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      label: _formatJobDate(selectedDate),
                                      icon: Icons.event,
                                      color: const Color(0xFF4A7DFF),
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: sheetContext,
                                          initialDate: selectedDate,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2035),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme:
                                                    const ColorScheme.dark(
                                                      primary: Color(
                                                        0xFF4A7DFF,
                                                      ),
                                                      surface: Color(
                                                        0xFF101826,
                                                      ),
                                                    ),
                                                dialogTheme:
                                                    const DialogThemeData(
                                                      backgroundColor: Color(
                                                        0xFF101826,
                                                      ),
                                                    ),
                                              ),
                                              child: child ?? const SizedBox(),
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setSheetState(() {
                                            selectedDate = DateUtils.dateOnly(
                                              picked,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildActionButton(
                                      label: _formatJobTime(selectedTime),
                                      icon: Icons.schedule,
                                      color: const Color(0xFF4A7DFF),
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: sheetContext,
                                          initialTime: selectedTime,
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                timePickerTheme:
                                                    const TimePickerThemeData(
                                                      backgroundColor: Color(
                                                        0xFF101826,
                                                      ),
                                                    ),
                                                colorScheme:
                                                    const ColorScheme.dark(
                                                      primary: Color(
                                                        0xFF4A7DFF,
                                                      ),
                                                      surface: Color(
                                                        0xFF101826,
                                                      ),
                                                    ),
                                              ),
                                              child: child ?? const SizedBox(),
                                            );
                                          },
                                        );
                                        if (picked != null) {
                                          setSheetState(() {
                                            selectedTime = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(sheetContext).pop(false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                        ),
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {
                                        final scheduledAt = DateTime(
                                          selectedDate.year,
                                          selectedDate.month,
                                          selectedDate.day,
                                          selectedTime.hour,
                                          selectedTime.minute,
                                        );
                                        DriverReplyMockState.instance
                                            .updateJobDetails(
                                              jobId: _jobId,
                                              customerName:
                                                  customerNameController.text
                                                      .trim(),
                                              phoneNumber: phoneController.text
                                                  .trim(),
                                              customerEmail: emailController
                                                  .text
                                                  .trim(),
                                              jobTitle: jobTitleController.text
                                                  .trim(),
                                              address: addressController.text
                                                  .trim(),
                                              postcode: postcodeController.text
                                                  .trim(),
                                              notesMessage: notesController.text
                                                  .trim(),
                                              scheduledAt: scheduledAt,
                                            );
                                        Navigator.of(sheetContext).pop(true);
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4A7DFF,
                                        ),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(50),
                                      ),
                                      child: const Text('Save changes'),
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
                ),
              );
            },
          );
        },
      );

      if (saved == true && mounted) {
        setState(() {});
        _showSnack('Job updated.');
      }
    } finally {
      customerNameController.dispose();
      phoneController.dispose();
      emailController.dispose();
      jobTitleController.dispose();
      addressController.dispose();
      postcodeController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _changeJobDateTime() async {
    final current = reply.scheduledAtOrParsed ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(current),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A7DFF),
              surface: Color(0xFF101826),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF101826),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (pickedDate == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Color(0xFF101826),
            ),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4A7DFF),
              surface: Color(0xFF101826),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (pickedTime == null) {
      return;
    }

    final scheduledAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    DriverReplyMockState.instance.updateJobDateTime(
      jobId: _jobId,
      scheduledAt: scheduledAt,
    );
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnack('Job time updated.');
  }

  Future<void> _cancelJob() async {
    if (_completed || _cancelled) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Cancel this job?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will remove it from active work but keep a record.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Text('Keep job'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC38C),
                foregroundColor: Colors.black,
              ),
              child: const Text('Cancel job'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    DriverReplyMockState.instance.cancelJob(jobId: _jobId);
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnack('Job cancelled.');
  }

  Future<void> _deleteJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF142031),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete this job?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This is mainly for removing test jobs. This cannot be undone.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Text('Keep job'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete job'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final deleted = DriverReplyMockState.instance.deleteJob(jobId: _jobId);
    if (!deleted || !mounted) {
      return;
    }

    _showSnack('Job deleted.');
    Navigator.of(context).pop(true);
  }

  Future<void> _markCompleted() async {
    final shouldComplete =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF142031),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Mark this job as completed?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: const Text(
                'This will move it to Completed jobs.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF58D0A4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark completed'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldComplete) {
      return;
    }

    DriverReplyMockState.instance.setJobCompleted(
      true,
      completedAt: DateTime.now(),
      jobId: _jobId,
    );
    DriverReplyMockState.instance.setJobConfirmed(true, jobId: _jobId);
    DriverReplyMockState.instance.setJobReady(true, jobId: _jobId);

    if (!mounted) {
      return;
    }

    setState(() {});
    Navigator.of(context).pop(true);
  }

  Widget _buildShellCard({required Widget child}) {
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

  Widget _buildChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: filled
                ? color.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.8,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final statusChips = _cancelled
        ? const <_JobsChipData>[
            _JobsChipData(
              label: 'Cancelled',
              color: Color(0xFFFFC38C),
              icon: Icons.cancel,
              filled: true,
            ),
            _JobsChipData(
              label: 'Record kept',
              color: Color(0xFF9AA3B2),
              icon: Icons.folder_outlined,
            ),
          ]
        : _completed
        ? const <_JobsChipData>[
            _JobsChipData(
              label: 'Completed',
              color: Color(0xFF58D0A4),
              icon: Icons.check_circle,
              filled: true,
            ),
            _JobsChipData(
              label: 'Quote sent',
              color: Color(0xFF58D0A4),
              icon: Icons.request_quote_outlined,
            ),
            _JobsChipData(
              label: 'Exact pin saved',
              color: Color(0xFF58D0A4),
              icon: Icons.location_on,
            ),
          ]
        : const <_JobsChipData>[
            _JobsChipData(
              label: 'Confirmed',
              color: Color(0xFF58D0A4),
              icon: Icons.check_circle,
              filled: true,
            ),
            _JobsChipData(
              label: 'Exact pin saved',
              color: Color(0xFF58D0A4),
              icon: Icons.location_on,
            ),
            _JobsChipData(
              label: 'Ready to go',
              color: Color(0xFF58D0A4),
              icon: Icons.rocket_launch_outlined,
            ),
            _JobsChipData(
              label: 'Quote sent',
              color: Color(0xFF58D0A4),
              icon: Icons.request_quote_outlined,
            ),
          ];
    final subtitle = _cancelled
        ? 'This job has been cancelled.'
        : _completed
        ? 'Completed job record.'
        : 'Confirmed job ready to go.';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 140 + bottomPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        reply.jobTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: const Color(
                                      0xFF58D0A4,
                                    ).withValues(alpha: 0.18),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF58D0A4,
                                      ).withValues(alpha: 0.32),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reply.customerName,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reply.scheduledAtOrParsed == null
                                            ? '${sanitizeVanText(reply.jobDateLabel).trim()} at ${sanitizeVanText(reply.jobTimeLabel).trim()}'
                                            : formatDateTime(
                                                reply.scheduledAtOrParsed!,
                                                TimeOfDay.fromDateTime(
                                                  reply.scheduledAtOrParsed!,
                                                ),
                                              ),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.70,
                                              ),
                                              height: 1.35,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final chip in statusChips)
                                  _buildChip(
                                    chip.label,
                                    color: chip.color,
                                    icon: chip.icon,
                                    filled: chip.filled,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildSmallInfoCard('Customer', reply.customerName),
                            const SizedBox(height: 10),
                            _buildSmallInfoCard('Job', reply.jobTitle),
                            const SizedBox(height: 10),
                            _buildSmallInfoCard(
                              'Date/time',
                              reply.scheduledAtOrParsed == null
                                  ? '${sanitizeVanText(reply.jobDateLabel).trim()} at ${sanitizeVanText(reply.jobTimeLabel).trim()}'
                                  : formatDateTime(
                                      reply.scheduledAtOrParsed!,
                                      TimeOfDay.fromDateTime(
                                        reply.scheduledAtOrParsed!,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            _buildSmallInfoCard('Address', reply.address),
                            const SizedBox(height: 10),
                            _buildSmallInfoCard('Phone', reply.phoneNumber),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Job management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Edit the saved local job, move it to a new day, or remove a test record.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 520;
                                final actions = <Widget>[
                                  _buildActionButton(
                                    label: 'Edit job details',
                                    icon: Icons.edit_outlined,
                                    color: const Color(0xFF4A7DFF),
                                    filled: true,
                                    onTap: _editJobDetails,
                                  ),
                                  _buildActionButton(
                                    label: 'Change date/time',
                                    icon: Icons.event_available_outlined,
                                    color: const Color(0xFF4A7DFF),
                                    onTap: _changeJobDateTime,
                                  ),
                                  if (!_completed && !_cancelled)
                                    _buildActionButton(
                                      label: 'Cancel job',
                                      icon: Icons.cancel_outlined,
                                      color: const Color(0xFFFFC38C),
                                      onTap: _cancelJob,
                                    ),
                                  _buildActionButton(
                                    label: 'Delete job',
                                    icon: Icons.delete_outline,
                                    color: const Color(0xFFFF6B6B),
                                    onTap: _deleteJob,
                                  ),
                                ];

                                if (stacked) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < actions.length;
                                        i++
                                      ) ...[
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
                                    for (final button in actions)
                                      SizedBox(
                                        width: constraints.maxWidth < 620
                                            ? constraints.maxWidth
                                            : 176,
                                        child: button,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Actions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 520;
                                final actionWidgets = _cancelled
                                    ? <Widget>[
                                        _buildActionButton(
                                          label: 'View quote',
                                          icon: Icons.request_quote_outlined,
                                          color: const Color(0xFF4A7DFF),
                                          filled: true,
                                          onTap: _openQuote,
                                        ),
                                        _buildActionButton(
                                          label: 'View reply',
                                          icon: Icons.question_answer,
                                          color: const Color(0xFF4A7DFF),
                                          onTap: _openReply,
                                        ),
                                      ]
                                    : _completed
                                    ? <Widget>[
                                        _buildActionButton(
                                          label: 'View quote',
                                          icon: Icons.request_quote_outlined,
                                          color: const Color(0xFF4A7DFF),
                                          filled: true,
                                          onTap: _openQuote,
                                        ),
                                        _buildActionButton(
                                          label: 'View reply',
                                          icon: Icons.question_answer,
                                          color: const Color(0xFF4A7DFF),
                                          onTap: _openReply,
                                        ),
                                      ]
                                    : <Widget>[
                                        _buildActionButton(
                                          label: 'Navigate',
                                          icon: Icons.navigation,
                                          color: const Color(0xFF4A7DFF),
                                          filled: true,
                                          onTap: _navigate,
                                        ),
                                        _buildActionButton(
                                          label: 'Call customer',
                                          icon: Icons.phone,
                                          color: const Color(0xFF4A7DFF),
                                          onTap: _callCustomer,
                                        ),
                                        _buildActionButton(
                                          label: 'View quote',
                                          icon: Icons.request_quote_outlined,
                                          color: const Color(0xFF4A7DFF),
                                          onTap: _openQuote,
                                        ),
                                        _buildActionButton(
                                          label: 'View reply',
                                          icon: Icons.question_answer,
                                          color: const Color(0xFF4A7DFF),
                                          onTap: _openReply,
                                        ),
                                      ];

                                if (stacked) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < actionWidgets.length;
                                        i++
                                      ) ...[
                                        actionWidgets[i],
                                        if (i < actionWidgets.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  );
                                }

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final button in actionWidgets)
                                      SizedBox(
                                        width: constraints.maxWidth < 620
                                            ? constraints.maxWidth
                                            : 176,
                                        child: button,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Job details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 620;
                                final cardWidth = wide
                                    ? (constraints.maxWidth - 10) / 2
                                    : constraints.maxWidth;
                                final customQuestionSummary =
                                    _customQuestionSummary();
                                final details = <Widget>[
                                  _buildDetailCard(
                                    'Parking',
                                    formatAnswerWithNote(
                                      _checklistValue(
                                        'Parking available?',
                                        'Yes',
                                      ),
                                      _checklistNote('Parking available?'),
                                    ),
                                  ),
                                  _buildDetailCard('Access', 'No restrictions'),
                                  _buildDetailCard(
                                    'Stairs/lift',
                                    formatAnswerWithNote(
                                      _checklistValue(
                                        'Stairs or lift?',
                                        'Stairs',
                                      ),
                                      _checklistNote('Stairs or lift?'),
                                    ),
                                  ),
                                  _buildDetailCard(
                                    'Loading help',
                                    _checklistValue(
                                      'Help loading/unloading?',
                                      'Maybe',
                                    ),
                                  ),
                                  _buildDetailCard(
                                    'Heavy items',
                                    _checklistValue(
                                      'Large or heavy items?',
                                      'No',
                                    ),
                                  ),
                                  _buildDetailCard('Photos', 'Photo requested'),
                                  _buildDetailCard(
                                    'Custom',
                                    customQuestionSummary ??
                                        'No extra custom questions added.',
                                  ),
                                  _buildDetailCard(
                                    'Additional notes',
                                    reply.additionalNotes.isEmpty
                                        ? 'No extra notes added.'
                                        : reply.additionalNotes,
                                  ),
                                ];

                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final detail in details)
                                      SizedBox(width: cardWidth, child: detail),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildShellCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quote summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailCard(
                              'Quote',
                              formatCurrency(reply.quoteAmount ?? 0),
                            ),
                            const SizedBox(height: 10),
                            _buildDetailCard(
                              'Status',
                              _completed
                                  ? 'Quote sent / Customer confirmed'
                                  : 'Quote sent / Customer confirmed',
                            ),
                            const SizedBox(height: 10),
                            _buildDetailCard(
                              'Extras',
                              'Collection/delivery if selected',
                            ),
                            const SizedBox(height: 10),
                            _buildDetailCard(
                              'Payment note',
                              'Payment arranged directly with driver/business.',
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 520;
                                final buttons = <Widget>[
                                  _buildActionButton(
                                    label: 'View quote',
                                    icon: Icons.open_in_new,
                                    color: const Color(0xFF4A7DFF),
                                    filled: true,
                                    onTap: _openQuote,
                                  ),
                                  _buildActionButton(
                                    label: 'Copy quote message',
                                    icon: Icons.copy,
                                    color: const Color(0xFF4A7DFF),
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: _quoteMessageText(),
                                        ),
                                      );
                                      _showSnack('Quote message copied.');
                                    },
                                  ),
                                ];

                                if (stacked) {
                                  return Column(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < buttons.length;
                                        i++
                                      ) ...[
                                        buttons[i],
                                        if (i < buttons.length - 1)
                                          const SizedBox(height: 10),
                                      ],
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: buttons[0]),
                                    const SizedBox(width: 10),
                                    Expanded(child: buttons[1]),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!_completed && !_cancelled) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _markCompleted,
                            icon: const Icon(Icons.task_alt),
                            label: const Text('Mark job completed'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF58D0A4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _JobsChipData {
  const _JobsChipData({
    required this.label,
    required this.color,
    required this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool filled;
}

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton({required this.onTap});

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
