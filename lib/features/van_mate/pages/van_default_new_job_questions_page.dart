import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_default_new_job_question_set.dart';
import '../services/van_default_new_job_questions_storage.dart';

Future<void> openVanDefaultNewJobQuestionsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const VanDefaultNewJobQuestionsPage(),
    ),
  );
}

class VanDefaultNewJobQuestionsPage extends StatefulWidget {
  const VanDefaultNewJobQuestionsPage({super.key});

  @override
  State<VanDefaultNewJobQuestionsPage> createState() =>
      _VanDefaultNewJobQuestionsPageState();
}

class _VanDefaultNewJobQuestionsPageState
    extends State<VanDefaultNewJobQuestionsPage> {
  final VanDefaultNewJobQuestionsStorage _storage =
      VanDefaultNewJobQuestionsStorage.instance;
  final List<TextEditingController> _controllers = <TextEditingController>[];
  bool _loading = true;
  bool _saving = false;
  VanDefaultNewJobQuestionSet? _loadedSet;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      var loadedSet = await _storage.load();
      await _storage.loadFromCloud();
      loadedSet = await _storage.load();
      loadedSet ??= VanDefaultNewJobQuestionSet.starter();
      if (!mounted) {
        return;
      }
      _setQuestions(loadedSet.questions);
      setState(() {
        _loadedSet = loadedSet;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setQuestions(VanDefaultNewJobQuestionSet.starter().questions);
      setState(() {
        _loadedSet = VanDefaultNewJobQuestionSet.starter();
        _loading = false;
      });
    }
  }

  void _setQuestions(List<String> questions) {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addAll(
        questions.map(
          (question) =>
              TextEditingController(text: sanitizeVanText(question).trim()),
        ),
      );
  }

  void _addQuestion() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  void _moveQuestion(int index, int offset) {
    final nextIndex = index + offset;
    if (nextIndex < 0 || nextIndex >= _controllers.length) {
      return;
    }
    setState(() {
      final item = _controllers.removeAt(index);
      _controllers.insert(nextIndex, item);
    });
  }

  List<String> _cleanedQuestions() {
    final questions = <String>[];
    final seen = <String>{};
    for (final controller in _controllers) {
      final cleaned = sanitizeVanText(
        controller.text,
      ).trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleaned.isEmpty) {
        continue;
      }
      final normalized = cleaned.toLowerCase();
      if (seen.add(normalized)) {
        questions.add(cleaned);
      }
    }
    return questions;
  }

  Future<void> _saveQuestions() async {
    if (_saving) {
      return;
    }

    final now = DateTime.now();
    final questions = _cleanedQuestions();
    final set = VanDefaultNewJobQuestionSet(
      id: VanDefaultNewJobQuestionSet.defaultId,
      title: VanDefaultNewJobQuestionSet.defaultTitle,
      questions: List<String>.unmodifiable(questions),
      isDefaultForNewJob: true,
      createdAt: _loadedSet?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _saving = true;
    });

    try {
      await _storage.save(set);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default job questions saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _loadedSet = set;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save default job questions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final starterQuestions = VanDefaultNewJobQuestionSet.starterQuestions;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Custom Job Questions'),
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
                            Text(
                              'Custom Job Questions',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'These questions are used when you send a New Job request to a customer.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.76),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                'Default New Job questions',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      height: 1.3,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'This is the one default set used by New Job for now.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.66),
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Questions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                _StatusChip(
                                  label: '${_controllers.length} total',
                                  color: const Color(0xFF4A7DFF),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_controllers.isEmpty)
                              Text(
                                'No questions saved yet. Start with the starter questions below or add your own.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.74),
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              for (var i = 0; i < _controllers.length; i++) ...[
                                _QuestionEditorRow(
                                  index: i,
                                  controller: _controllers[i],
                                  onRemove: () => _removeQuestion(i),
                                  onMoveUp: i == 0
                                      ? null
                                      : () => _moveQuestion(i, -1),
                                  onMoveDown: i == _controllers.length - 1
                                      ? null
                                      : () => _moveQuestion(i, 1),
                                ),
                                if (i < _controllers.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: _addQuestion,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add question'),
                                  ),
                                ),
                                SizedBox(
                                  height: 44,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _setQuestions(starterQuestions);
                                      });
                                    },
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Use starter set'),
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
                            const Text(
                              'Starter questions',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Can the van park close to the door?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                height: 1.45,
                              ),
                            ),
                            Text(
                              'What needs collecting or delivering?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                height: 1.45,
                              ),
                            ),
                            Text(
                              'Are there stairs, lifts or access issues?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                height: 1.45,
                              ),
                            ),
                            Text(
                              'Anything else the driver should know?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _saveQuestions,
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
                          label: const Text('Save questions'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7DFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
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

class _QuestionEditorRow extends StatelessWidget {
  const _QuestionEditorRow({
    required this.index,
    required this.controller,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onMoveUp,
                tooltip: 'Move up',
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                color: Colors.white,
              ),
              IconButton(
                onPressed: onMoveDown,
                tooltip: 'Move down',
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: Colors.white,
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 2,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Enter a question',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.70),
                  width: 1.2,
                ),
              ),
            ),
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
