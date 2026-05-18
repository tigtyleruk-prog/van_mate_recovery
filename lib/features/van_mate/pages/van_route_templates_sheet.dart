import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/van_route_template.dart';

Future<void> showVanRouteTemplatesSheet(
  BuildContext context, {
  required Stream<List<VanRouteTemplate>> templatesStream,
  required Future<void> Function(VanRouteTemplate template) onLoadTemplate,
  required Future<void> Function(VanRouteTemplate template) onRenameTemplate,
  required Future<void> Function(VanRouteTemplate template) onDeleteTemplate,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _VanRouteTemplatesSheet(
        templatesStream: templatesStream,
        onLoadTemplate: onLoadTemplate,
        onRenameTemplate: onRenameTemplate,
        onDeleteTemplate: onDeleteTemplate,
      );
    },
  );
}

class _VanRouteTemplatesSheet extends StatelessWidget {
  final Stream<List<VanRouteTemplate>> templatesStream;
  final Future<void> Function(VanRouteTemplate template) onLoadTemplate;
  final Future<void> Function(VanRouteTemplate template) onRenameTemplate;
  final Future<void> Function(VanRouteTemplate template) onDeleteTemplate;

  const _VanRouteTemplatesSheet({
    required this.templatesStream,
    required this.onLoadTemplate,
    required this.onRenameTemplate,
    required this.onDeleteTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.84;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF16253F).withValues(alpha: 0.97),
                  const Color(0xFF0D1627).withValues(alpha: 0.98),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: const Color(
                              0xFF4A7DFF,
                            ).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(
                                0xFF4A7DFF,
                              ).withValues(alpha: 0.26),
                            ),
                          ),
                          child: const Icon(
                            Icons.shuffle_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Route Templates',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap one to load it into today\'s working route, then make quick edits if needed.',
                                style: TextStyle(
                                  fontSize: 12.6,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<VanRouteTemplate>>(
                      stream: templatesStream,
                      builder: (context, snapshot) {
                        final templates =
                            snapshot.data ?? const <VanRouteTemplate>[];
                        if (snapshot.hasError) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            children: [
                              _TemplateErrorCard(
                                message:
                                    'Route templates could not load right now.',
                              ),
                            ],
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            templates.isEmpty) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }

                        if (templates.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                            children: [
                              _EmptyTemplateCard(
                                onSaveHintTap: () =>
                                    Navigator.of(context).pop(),
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          itemCount: templates.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            return _TemplateTile(
                              template: template,
                              onTap: () async {
                                await onLoadTemplate(template);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              onRename: () => onRenameTemplate(template),
                              onDelete: () => onDeleteTemplate(template),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final VanRouteTemplate template;
  final VoidCallback onTap;
  final Future<void> Function() onRename;
  final Future<void> Function() onDelete;

  const _TemplateTile({
    required this.template,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dropCount = template.stops.length;
    final updatedLabel = _formatTimestamp(template.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dropCount stop${dropCount == 1 ? '' : 's'} · updated $updatedLabel',
                      style: TextStyle(
                        fontSize: 11.8,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onTap,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Load'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async => onRename(),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.03),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 17),
                          label: const Text('Rename'),
                        ),
                        TextButton.icon(
                          onPressed: () async => onDelete(),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            foregroundColor: const Color(0xFFFF8A72),
                            backgroundColor:
                                const Color(0xFFFF8A72).withValues(alpha: 0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: const Color(0xFFFF8A72)
                                    .withValues(alpha: 0.16),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTemplateCard extends StatelessWidget {
  final VoidCallback onSaveHintTap;

  const _EmptyTemplateCard({required this.onSaveHintTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No templates saved yet',
            style: TextStyle(
              fontSize: 15.2,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Save as Template on the Route page to keep a repeat run ready for next time.',
            style: TextStyle(
              fontSize: 12.6,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSaveHintTap,
              child: const Text('Back to Route'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateErrorCard extends StatelessWidget {
  final String message;

  const _TemplateErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load templates',
            style: TextStyle(
              fontSize: 15.2,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12.6,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}
