import 'package:flutter/material.dart';

import '../models/van_community_review_models.dart';
import '../services/van_community_admin_service.dart';

class VanCommunityReviewPage extends StatefulWidget {
  const VanCommunityReviewPage({super.key});

  @override
  State<VanCommunityReviewPage> createState() => _VanCommunityReviewPageState();
}

class _VanCommunityReviewPageState extends State<VanCommunityReviewPage> {
  final VanCommunityAdminService _adminService =
      VanCommunityAdminService.instance;
  String? _busySubmissionId;

  Future<void> _approve(
    BuildContext context,
    VanCommunityReviewSubmission submission,
    VanCommunityReviewDraft draft,
  ) async {
    if (_busySubmissionId == submission.id) {
      return;
    }

    setState(() {
      _busySubmissionId = submission.id;
    });

    try {
      await _adminService.approveSubmission(
        submission: submission,
        draft: draft,
      );
      if (!mounted) return;
      _showSnack('Approved and added to community map.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Approval failed. Check Firestore rules or connection.');
      debugPrint('[CommunityReview] approve failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busySubmissionId = null;
        });
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    VanCommunityReviewSubmission submission, {
    String? reason,
  }) async {
    if (_busySubmissionId == submission.id) {
      return;
    }

    setState(() {
      _busySubmissionId = submission.id;
    });

    try {
      await _adminService.rejectSubmission(
        submission: submission,
        rejectReason: reason,
      );
      if (!mounted) return;
      _showSnack('Submission rejected.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Reject failed. Check Firestore rules or connection.');
      debugPrint('[CommunityReview] reject failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busySubmissionId = null;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _adminService.currentUserId;
    return Scaffold(
      appBar: AppBar(title: const Text('Community Review')),
      body: StreamBuilder<bool>(
        stream: _adminService.watchIsAdmin(uid),
        initialData: false,
        builder: (context, adminSnapshot) {
          final isAdmin = adminSnapshot.data == true;
          if (!isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Admin access only.'),
              ),
            );
          }

          return StreamBuilder<List<VanCommunityReviewSubmission>>(
            stream: _adminService.watchPendingSubmissions(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load pending submissions: ${snapshot.error}',
                    ),
                  ),
                );
              }

              final submissions =
                  snapshot.data ?? const <VanCommunityReviewSubmission>[];
              if (submissions.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No pending community submissions.'),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      'Check notes for private info before approving.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final submission in submissions) ...[
                    _CommunityReviewCard(
                      submission: submission,
                      busy: _busySubmissionId == submission.id,
                      onApprove: () => _approve(
                        context,
                        submission,
                        VanCommunityReviewDraft(
                          placeName: submission.placeName,
                          dropType: submission.dropType,
                          postcodeArea: submission.postcodeArea,
                          deliveryNote: submission.deliveryNote,
                          warningNote: submission.warningNote,
                          accessNote: submission.accessNote,
                        ),
                      ),
                      onEditBeforeApprove: (draft) =>
                          _approve(context, submission, draft),
                      onReject: (reason) =>
                          _reject(context, submission, reason: reason),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CommunityReviewCard extends StatelessWidget {
  final VanCommunityReviewSubmission submission;
  final bool busy;
  final Future<void> Function() onApprove;
  final Future<void> Function(VanCommunityReviewDraft draft)
  onEditBeforeApprove;
  final Future<void> Function(String? reason) onReject;

  const _CommunityReviewCard({
    required this.submission,
    required this.busy,
    required this.onApprove,
    required this.onEditBeforeApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final submittedAt = submission.submittedAt.toLocal();
    final displayName = submission.placeName.trim().isNotEmpty
        ? submission.placeName.trim()
        : submission.dropName.trim();
    final originalDropName = submission.dropName.trim();
    final submittedLabel =
        '${MaterialLocalizations.of(context).formatShortDate(submittedAt)} '
        '• ${TimeOfDay.fromDateTime(submittedAt).format(context)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (submission.privateFieldDetected)
                const _CommunityWarningPill(label: 'Private field detected'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${submission.dropType} • ${submission.postcodeArea}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (originalDropName.isNotEmpty &&
              originalDropName != displayName) ...[
            const SizedBox(height: 4),
            Text(
              'Drop name: $originalDropName',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Exact pin: ${submission.hasExactPin ? '${submission.exactLat.toStringAsFixed(5)}, ${submission.exactLng.toStringAsFixed(5)}' : 'Missing'}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted by ${submission.submittedBy} • $submittedLabel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 11.6,
            ),
          ),
          const SizedBox(height: 10),
          _CommunityNoteCard(
            label: 'Delivery note',
            value: submission.deliveryNote,
          ),
          if (submission.warningNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _CommunityNoteCard(
              label: 'Warning note',
              value: submission.warningNote,
              accent: const Color(0xFFFFC38C),
            ),
          ],
          if (submission.accessNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _CommunityNoteCard(
              label: 'Access note',
              value: submission.accessNote,
              accent: const Color(0xFF8FA6FF),
            ),
          ],
          const SizedBox(height: 12),
          _CommunityActionRow(
            busy: busy,
            onApprove: onApprove,
            onReject: () async {
              final reason = await _showRejectReasonDialog(context);
              if (reason == null) {
                return;
              }
              await onReject(reason);
            },
            onEdit: () async {
              final draft = await showDialog<VanCommunityReviewDraft>(
                context: context,
                builder: (_) =>
                    _CommunityEditBeforeApproveDialog(submission: submission),
              );
              if (draft == null) {
                return;
              }
              await onEditBeforeApprove(draft);
            },
          ),
        ],
      ),
    );
  }
}

Future<String?> _showRejectReasonDialog(BuildContext context) {
  const reasons = <String>[
    'contains private info',
    'duplicate',
    'bad pin',
    'not useful',
    'other',
  ];

  String selectedReason = reasons.first;
  return showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: _CommunityPanelShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reject submission',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose a simple reason for the review log.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final reason in reasons)
                        ChoiceChip(
                          label: Text(reason),
                          selected: selectedReason == reason,
                          onSelected: (_) {
                            setState(() {
                              selectedReason = reason;
                            });
                          },
                          labelStyle: const TextStyle(color: Colors.white),
                          selectedColor: const Color(
                            0xFF8FA6FF,
                          ).withValues(alpha: 0.28),
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          side: BorderSide(
                            color: selectedReason == reason
                                ? const Color(
                                    0xFF8FA6FF,
                                  ).withValues(alpha: 0.44)
                                : Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(selectedReason),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CommunityWarningPill extends StatelessWidget {
  final String label;

  const _CommunityWarningPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CommunityNoteCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _CommunityNoteCard({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final noteAccent = accent ?? const Color(0xFF8FA6FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: noteAccent,
              fontWeight: FontWeight.w800,
              fontSize: 11.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityActionRow extends StatelessWidget {
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  const _CommunityActionRow({
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onEdit,
                child: const Text('Edit before approve'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: busy ? null : onReject,
            child: const Text('Reject'),
          ),
        ),
      ],
    );
  }
}

class _CommunityEditBeforeApproveDialog extends StatefulWidget {
  final VanCommunityReviewSubmission submission;

  const _CommunityEditBeforeApproveDialog({required this.submission});

  @override
  State<_CommunityEditBeforeApproveDialog> createState() =>
      _CommunityEditBeforeApproveDialogState();
}

class _CommunityEditBeforeApproveDialogState
    extends State<_CommunityEditBeforeApproveDialog> {
  late final TextEditingController _placeNameController;
  late final TextEditingController _dropTypeController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _deliveryNoteController;
  late final TextEditingController _warningNoteController;
  late final TextEditingController _accessNoteController;

  @override
  void initState() {
    super.initState();
    final submission = widget.submission;
    _placeNameController = TextEditingController(text: submission.placeName);
    _dropTypeController = TextEditingController(text: submission.dropType);
    _postcodeController = TextEditingController(text: submission.postcodeArea);
    _deliveryNoteController = TextEditingController(
      text: submission.deliveryNote,
    );
    _warningNoteController = TextEditingController(
      text: submission.warningNote,
    );
    _accessNoteController = TextEditingController(text: submission.accessNote);
  }

  @override
  void dispose() {
    _placeNameController.dispose();
    _dropTypeController.dispose();
    _postcodeController.dispose();
    _deliveryNoteController.dispose();
    _warningNoteController.dispose();
    _accessNoteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      VanCommunityReviewDraft(
        placeName: _placeNameController.text.trim(),
        dropType: _dropTypeController.text.trim(),
        postcodeArea: _postcodeController.text.trim(),
        deliveryNote: _deliveryNoteController.text.trim(),
        warningNote: _warningNoteController.text.trim(),
        accessNote: _accessNoteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.viewPaddingOf(context).vertical -
                48,
          ),
          child: _CommunityEditCard(
            placeNameController: _placeNameController,
            dropTypeController: _dropTypeController,
            postcodeController: _postcodeController,
            deliveryNoteController: _deliveryNoteController,
            warningNoteController: _warningNoteController,
            accessNoteController: _accessNoteController,
            onCancel: () => Navigator.of(context).pop(),
            onSave: _submit,
          ),
        ),
      ),
    );
  }
}

class _CommunityEditCard extends StatelessWidget {
  final TextEditingController placeNameController;
  final TextEditingController dropTypeController;
  final TextEditingController postcodeController;
  final TextEditingController deliveryNoteController;
  final TextEditingController warningNoteController;
  final TextEditingController accessNoteController;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _CommunityEditCard({
    required this.placeNameController,
    required this.dropTypeController,
    required this.postcodeController,
    required this.deliveryNoteController,
    required this.warningNoteController,
    required this.accessNoteController,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _CommunityPanelShell(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit before approve',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CommunityField(
                    controller: placeNameController,
                    label: 'Place name',
                  ),
                  const SizedBox(height: 8),
                  _CommunityField(
                    controller: dropTypeController,
                    label: 'Drop type',
                  ),
                  const SizedBox(height: 8),
                  _CommunityField(
                    controller: postcodeController,
                    label: 'Postcode area',
                  ),
                  const SizedBox(height: 8),
                  _CommunityField(
                    controller: deliveryNoteController,
                    label: 'Delivery note',
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  _CommunityField(
                    controller: warningNoteController,
                    label: 'Warning note',
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  _CommunityField(
                    controller: accessNoteController,
                    label: 'Access note',
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Save & approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  const _CommunityField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _CommunityPanelShell extends StatelessWidget {
  final Widget child;

  const _CommunityPanelShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1727).withValues(alpha: 0.96),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    );
  }
}
