import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_prefilled_job_questions.dart';
import '../models/van_question_template.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_question_templates_storage.dart';

Future<List<String>?> pickVanCustomJobQuestionsForOneOff(
  BuildContext context, {
  List<String> initialSelectedQuestionTexts = const <String>[],
}) {
  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute<List<String>>(
      builder: (_) => VanQuestionQuickSelectPage(
        initialSelectedQuestionTexts: initialSelectedQuestionTexts,
        returnQuestionIds: false,
      ),
    ),
  );
}

Future<List<String>?> pickVanQuestionIdsForOneOff(
  BuildContext context, {
  List<String> initialSelectedQuestionIds = const <String>[],
}) {
  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute<List<String>>(
      builder: (_) => VanQuestionQuickSelectPage(
        initialSelectedQuestionIds: initialSelectedQuestionIds,
        returnQuestionIds: true,
      ),
    ),
  );
}

class VanQuestionQuickSelectPage extends StatefulWidget {
  const VanQuestionQuickSelectPage({
    super.key,
    this.initialSelectedQuestionTexts = const <String>[],
    this.initialSelectedQuestionIds = const <String>[],
    this.returnQuestionIds = false,
  });

  final List<String> initialSelectedQuestionTexts;
  final List<String> initialSelectedQuestionIds;
  final bool returnQuestionIds;

  @override
  State<VanQuestionQuickSelectPage> createState() =>
      _VanQuestionQuickSelectPageState();
}

class _VanQuestionQuickSelectPageState
    extends State<VanQuestionQuickSelectPage> {
  final VanCustomJobQuestionsStorage _questionStorage =
      VanCustomJobQuestionsStorage.instance;
  final VanQuestionTemplatesStorage _templateStorage =
      VanQuestionTemplatesStorage.instance;

  List<VanCustomJobQuestion> _customQuestions = <VanCustomJobQuestion>[];
  List<VanQuestionTemplate> _templates = <VanQuestionTemplate>[];
  final Set<String> _selectedIds = <String>{};
  bool _loading = true;

  Map<String, VanCustomJobQuestion> get _questionLookup {
    return <String, VanCustomJobQuestion>{
      for (final question in <VanCustomJobQuestion>[
        ...VanPrefilledJobQuestions.all,
        ..._customQuestions,
      ])
        question.id: question,
    };
  }

  List<VanCustomJobQuestion> get _activeCustomQuestions {
    return _customQuestions
        .where((question) => question.isActive && !question.isArchived)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final questions = await _questionStorage.loadAll();
    final templates = await _templateStorage.loadActiveTemplates();
    if (!mounted) {
      return;
    }

    final lookup = <String, VanCustomJobQuestion>{
      for (final question in <VanCustomJobQuestion>[
        ...VanPrefilledJobQuestions.all,
        ...questions,
      ])
        question.id: question,
    };

    final selected = <String>{};
    final initialIds = widget.initialSelectedQuestionIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (initialIds.isNotEmpty) {
      for (final id in initialIds) {
        if (lookup.containsKey(id)) {
          selected.add(id);
        }
      }
    } else {
      final initialTexts = widget.initialSelectedQuestionTexts
          .map((text) => text.trim().toLowerCase())
          .where((text) => text.isNotEmpty)
          .toSet();
      for (final entry in lookup.entries) {
        if (initialTexts.contains(
          entry.value.questionText.trim().toLowerCase(),
        )) {
          selected.add(entry.key);
        }
      }
    }

    setState(() {
      _customQuestions = questions;
      _templates = templates;
      _selectedIds
        ..clear()
        ..addAll(selected);
      _loading = false;
    });
  }

  void _toggle(String id, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _applyTemplate(VanQuestionTemplate template) {
    setState(() {
      for (final id in template.selectedQuestionIds) {
        if (_questionLookup.containsKey(id)) {
          _selectedIds.add(id);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  List<String> _selectedTexts() {
    final results = <String>[];
    for (final id in _selectedIds) {
      final question = _questionLookup[id];
      if (question == null) {
        continue;
      }
      final text = question.questionText.trim();
      if (text.isNotEmpty && !results.contains(text)) {
        results.add(text);
      }
    }
    results.sort();
    return results;
  }

  List<String> _selectedIdsResult() {
    final results = _selectedIds
        .where((id) => _questionLookup.containsKey(id))
        .toList(growable: false);
    results.sort();
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Quick Question Pick'),
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
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'One-off request',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  label: '${_selectedIds.length} selected',
                                  color: const Color(0xFF4A7DFF),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tick questions for this job. No template needed.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.74),
                                fontSize: 13.0,
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
                                  child: OutlinedButton.icon(
                                    onPressed: _clearSelection,
                                    icon: const Icon(Icons.clear_all_rounded),
                                    label: const Text('Clear'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_templates.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _GlassCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Use template',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final template in _templates)
                                    FilledButton.tonalIcon(
                                      onPressed: () => _applyTemplate(template),
                                      icon: const Icon(
                                        Icons.playlist_add_check,
                                      ),
                                      label: Text(template.name),
                                      style: FilledButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color(
                                          0xFF4A7DFF,
                                        ).withValues(alpha: 0.22),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      for (final category in VanCustomQuestionCategory.values)
                        ..._buildCategory(category),
                      if (_activeCustomQuestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _GlassCard(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Questions',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (
                                var i = 0;
                                i < _activeCustomQuestions.length;
                                i++
                              ) ...[
                                _QuestionTickRow(
                                  question: _activeCustomQuestions[i],
                                  value: _selectedIds.contains(
                                    _activeCustomQuestions[i].id,
                                  ),
                                  onChanged: (value) => _toggle(
                                    _activeCustomQuestions[i].id,
                                    value,
                                  ),
                                ),
                                if (i < _activeCustomQuestions.length - 1)
                                  Divider(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    height: 1,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            height: 42,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          SizedBox(
                            height: 42,
                            child: FilledButton.icon(
                              onPressed: _selectedIds.isEmpty
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pop(
                                      widget.returnQuestionIds
                                          ? _selectedIdsResult()
                                          : _selectedTexts(),
                                    ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Use selected'),
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

  List<Widget> _buildCategory(VanCustomQuestionCategory category) {
    final items = VanPrefilledJobQuestions.byCategory(category);
    if (items.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      _GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < items.length; i++) ...[
              _QuestionTickRow(
                question: items[i],
                value: _selectedIds.contains(items[i].id),
                onChanged: (value) => _toggle(items[i].id, value),
              ),
              if (i < items.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
            ],
          ],
        ),
      ),
      const SizedBox(height: 10),
    ];
  }
}

class _QuestionTickRow extends StatelessWidget {
  const _QuestionTickRow({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final VanCustomJobQuestion question;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF4A7DFF),
      onChanged: (checked) => onChanged(checked ?? false),
      title: Text(
        question.questionText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        question.answerType.label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.64),
          fontSize: 11.7,
          fontWeight: FontWeight.w600,
        ),
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: padding,
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
          ),
          child: child,
        ),
      ),
    );
  }
}
