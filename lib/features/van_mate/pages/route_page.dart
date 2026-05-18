part of 'van_firebase_page.dart';

class _VanRoutePage extends StatelessWidget {
  final _VanFirebasePageState state;

  const _VanRoutePage({required this.state});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: VanMatePremiumService.instance,
      builder: (context, _) => state.buildRouteBodyExtracted(bottomInset),
    );
  }
}

class _VanRouteNameField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final double bottomScrollPadding;

  const _VanRouteNameField({
    required this.controller,
    required this.hintText,
    this.icon = Icons.search_rounded,
    this.bottomScrollPadding = 96,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontSize: 14.4,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textInputAction: TextInputAction.done,
                  scrollPadding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    bottomScrollPadding,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (controller.text.trim().isNotEmpty)
                IconButton(
                  onPressed: controller.clear,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

extension _VanFirebaseRouteTab on _VanFirebasePageState {
  Widget buildRouteBodyExtracted(double bottomInset) {
    _routeBodyBuildCount++;
    final premiumService = VanMatePremiumService.instance;
    final canUseSmartAutoPlan = premiumService.canUseSmartAutoPlan;
    final canUseRouteTemplates = premiumService.canUseRouteTemplates;
    final routeStateLabel = _routeDraftDirty ? 'Unsaved' : 'Saved';
    final routeStateAccent = _routeDraftDirty
        ? const Color(0xFFFFB15C)
        : const Color(0xFF58D0A4);
    debugPrint(
      '[Perf] Route body build #$_routeBodyBuildCount draftDirty=$_routeDraftDirty',
    );
    const bottomSpacer = 340.0;

    return ListView(
      key: const ValueKey('route_tab'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        bottomInset + bottomSpacer,
      ),
      children: [
        const _VanSectionHeader(
          title: 'Route Builder',
          subtitle: 'Build today\'s route, save it for Today and the map.',
        ),
        const SizedBox(height: 8),
        _VanGlassPanel(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
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
                          const Text(
                            'Today\'s Route Details',
                            style: TextStyle(
                              fontSize: 16.1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Name it, set anchors, save today\'s stop order.',
                            style: TextStyle(
                              fontSize: 12.0,
                              height: 1.32,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _VanInfoPill(
                      label: routeStateLabel,
                      accent: routeStateAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Route name',
                  style: TextStyle(
                    fontSize: 11.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 6),
                _VanRouteNameField(
                  controller: _routeNameController,
                  hintText: 'Route name for today',
                  icon: Icons.edit_rounded,
                  bottomScrollPadding: 120,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _VanInfoPill(
                      label: _formatRouteDateLabel(_todayRouteDate),
                      accent: const Color(0xFF4A7DFF),
                    ),
                    _VanInfoPill(
                      label:
                          '${_routeDraftStops.length} stop${_routeDraftStops.length == 1 ? '' : 's'}',
                      accent: const Color(0xFF58D0A4),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackAnchors = constraints.maxWidth < 620;

                    if (stackAnchors) {
                      return Column(
                        children: [
                          _VanRouteAnchorCard(
                            title: 'Start',
                            prompt: 'Pick the start anchor',
                            anchor: _routeStartAnchor,
                            onTap: () => _pickRouteAnchor(isStart: true),
                            onClear: _routeStartAnchor == null
                                ? null
                                : () => _updateRouteAnchor(
                                    isStart: true,
                                    anchor: null,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          _VanRouteAnchorCard(
                            title: 'End',
                            prompt: 'Pick the end anchor',
                            anchor: _routeEndAnchor,
                            onTap: () => _pickRouteAnchor(isStart: false),
                            onClear: _routeEndAnchor == null
                                ? null
                                : () => _updateRouteAnchor(
                                    isStart: false,
                                    anchor: null,
                                  ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _VanRouteAnchorCard(
                            title: 'Start',
                            prompt: 'Pick the start anchor',
                            anchor: _routeStartAnchor,
                            onTap: () => _pickRouteAnchor(isStart: true),
                            onClear: _routeStartAnchor == null
                                ? null
                                : () => _updateRouteAnchor(
                                    isStart: true,
                                    anchor: null,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VanRouteAnchorCard(
                            title: 'End',
                            prompt: 'Pick the end anchor',
                            anchor: _routeEndAnchor,
                            onTap: () => _pickRouteAnchor(isStart: false),
                            onClear: _routeEndAnchor == null
                                ? null
                                : () => _updateRouteAnchor(
                                    isStart: false,
                                    anchor: null,
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Add drops from Places. Start and End are anchors only.',
                  style: TextStyle(
                    fontSize: 11.7,
                    height: 1.26,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 8),
                if (canUseSmartAutoPlan) ...[
                  _VanActionRow(
                    stackOnNarrow: true,
                    stackedBreakpoint: 430,
                    leading: _VanInlineButton(
                      label: 'Auto Plan',
                      icon: Icons.alt_route_rounded,
                      filled: true,
                      scaleLabelDown: true,
                      onTap: _autoPlanRoute,
                    ),
                    trailing: _VanInlineButton(
                      label: _isSavingRoute ? 'Saving...' : 'Save Route',
                      icon: Icons.save_outlined,
                      filled: true,
                      busy: _isSavingRoute,
                      scaleLabelDown: true,
                      onTap: _isSavingRoute ? null : _saveRoute,
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: _VanInlineButton(
                      label: _isSavingRoute ? 'Saving...' : 'Save Route',
                      icon: Icons.save_outlined,
                      filled: true,
                      busy: _isSavingRoute,
                      scaleLabelDown: true,
                      onTap: _isSavingRoute ? null : _saveRoute,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: _VanInlineButton(
                    label: 'Clear Route',
                    icon: Icons.clear_rounded,
                    scaleLabelDown: true,
                    onTap: _clearRouteDraft,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  canUseSmartAutoPlan
                      ? 'Save limit: ${premiumService.maxDropsPerRoute} drops per saved route. Premium unlocks Smart Auto Plan.'
                      : 'Save limit: ${premiumService.maxDropsPerRoute} drops per saved route.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.26,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (canUseRouteTemplates)
          _VanRouteTemplatesCard(
            onSaveAsTemplate: () {
              unawaited(_saveRouteAsTemplate());
            },
            onLoadTemplate: () {
              unawaited(_openRouteTemplates());
            },
          ),
        const SizedBox(height: 8),
        _VanSectionHeader(
          title: 'Route Stops',
          subtitle: _routeDraftStops.isEmpty
              ? 'Stops added from Places appear here.'
              : '${_routeDraftStops.length} stop${_routeDraftStops.length == 1 ? '' : 's'} in today\'s route',
        ),
        const SizedBox(height: 5),
        if (_routeDraftStops.isEmpty)
          _VanEmptyCard(
            title: 'No stops in today\'s route yet',
            message: 'Add drops from Places to start building your route.',
          )
        else
          for (final stop in _routeDraftStops) ...[
            _buildRouteDraftCard(stop),
            const SizedBox(height: 5),
          ],
      ],
    );
  }

  Widget _buildRouteDraftCard(VanRouteStop stop) {
    final currentIndex = _routeDraftStops.indexWhere(
      (item) => item.id == stop.id,
    );
    final canMoveUp = currentIndex > 0;
    final canMoveDown =
        currentIndex >= 0 && currentIndex < _routeDraftStops.length - 1;

    return StreamBuilder<VanPinRequest?>(
      stream: _pinRequestStreamForDropId(stop.placeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[PinRequest] Route stream error for ${stop.placeId}: ${snapshot.error}',
          );
        }

        final request = snapshot.data;
        final hasReceivedPin = request?.canUseReceivedPin == true;
        if (request != null) {
          debugPrint(
            '[PinRequest] latest request loaded for drop ${stop.placeId}: ${request.id} status=${request.status}',
          );
          if (request.isPending) {
            debugPrint(
              '[PinRequest] pending request found for drop ${stop.placeId} request=${request.id}',
            );
          }
          if (hasReceivedPin || request.isReceivedNote) {
            debugPrint(
              '[PinRequest] received pin found for drop ${stop.placeId} request=${request.id}',
            );
          }
        }

        return _VanStopCard(
          stop: stop,
          noteLabel: _bestStopNoteLabel(stop),
          notePreview: _bestStopNotePreview(stop),
          noteAccent: _bestStopNoteAccent(stop),
          addressMaxLines: 1,
          compactNotePreview: true,
          helperLabel: 'Planning',
          helperText: stop.hasCoordinates
              ? 'Exact pin saved. Ready for auto planning.'
              : 'No coordinates yet, so it stays manual.',
          actionRows: [
            if (hasReceivedPin) ...[
              Row(
                children: [
                  _VanInfoPill(
                    label: 'Pin received',
                    accent: const Color(0xFF58D0A4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VanInlineButton(
                      label: 'Open shared pin',
                      icon: Icons.open_in_new_rounded,
                      toned: true,
                      accentColor: const Color(0xFF58D0A4),
                      scaleLabelDown: true,
                      onTap: () {
                        final latestRequest = request;
                        if (latestRequest == null) return;
                        unawaited(_openSharedPinFromStop(stop, latestRequest));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            const _VanActionGroupLabel(
              label: 'Plan controls',
              accent: Color(0xFF79A6FF),
            ),
            _VanActionRow(
              stackOnNarrow: true,
              stackedBreakpoint: 430,
              leading: _VanInlineButton(
                label: 'Move Up',
                icon: Icons.arrow_upward_rounded,
                scaleLabelDown: true,
                onTap: canMoveUp ? () => _moveDraftStop(stop, -1) : null,
              ),
              trailing: _VanInlineButton(
                label: 'Move Down',
                icon: Icons.arrow_downward_rounded,
                scaleLabelDown: true,
                onTap: canMoveDown ? () => _moveDraftStop(stop, 1) : null,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: _VanInlineButton(
                label: 'Remove Stop',
                icon: Icons.remove_circle_outline_rounded,
                destructive: true,
                scaleLabelDown: true,
                onTap: () => _removeDraftStop(stop),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VanRouteTemplatesCard extends StatelessWidget {
  final VoidCallback onSaveAsTemplate;
  final VoidCallback onLoadTemplate;

  const _VanRouteTemplatesCard({
    required this.onSaveAsTemplate,
    required this.onLoadTemplate,
  });

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
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
                    const Text(
                      'Route Templates',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Save a repeat run, then load it back as today\'s working route.',
                      style: TextStyle(
                        fontSize: 12.0,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _VanInfoPill(label: 'Premium', accent: const Color(0xFF58D0A4)),
            ],
          ),
          const SizedBox(height: 10),
          _VanActionRow(
            stackOnNarrow: true,
            stackedBreakpoint: 430,
            leading: _VanInlineButton(
              label: 'Save as Template',
              icon: Icons.bookmark_add_outlined,
              filled: true,
              scaleLabelDown: true,
              onTap: onSaveAsTemplate,
            ),
            trailing: _VanInlineButton(
              label: 'Load Template',
              icon: Icons.folder_open_outlined,
              filled: true,
              scaleLabelDown: true,
              onTap: onLoadTemplate,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Templates load into today’s working route and can be edited without changing the original.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.26,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanStopCard extends StatelessWidget {
  final VanRouteStop stop;
  final String? noteLabel;
  final String? notePreview;
  final Color? noteAccent;
  final bool compactNotePreview;
  final int addressMaxLines;
  final String? helperLabel;
  final String? helperText;
  final List<Widget> actionRows;

  const _VanStopCard({
    required this.stop,
    this.noteLabel,
    this.notePreview,
    this.noteAccent,
    this.compactNotePreview = false,
    this.addressMaxLines = 2,
    this.helperLabel,
    this.helperText,
    required this.actionRows,
  });

  @override
  Widget build(BuildContext context) {
    final noteHighlight = noteAccent ?? const Color(0xFF7EA2FF);

    return _VanGlassPanel(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.24),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${stop.routeOrder + 1}',
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.postcodeArea,
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w700,
                        color: stop.placeType.accent,
                      ),
                    ),
                    if (stop.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        stop.address,
                        maxLines: addressMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.8,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _VanStatusBadge(status: stop.status),
            ],
          ),
          if (notePreview != null && notePreview!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            if (compactNotePreview)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: noteHighlight.withValues(alpha: 0.86),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 11.4,
                          height: 1.22,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        children: [
                          TextSpan(
                            text: '${noteLabel ?? 'Note'}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: noteHighlight.withValues(alpha: 0.96),
                            ),
                          ),
                          TextSpan(
                            text: notePreview!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              _VanCompactNoteCard(
                label: noteLabel ?? 'Note',
                value: notePreview!,
                accent: noteAccent,
              ),
          ],
          if (helperText != null && helperText!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.6,
                  height: 1.24,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
                children: [
                  TextSpan(
                    text: '${helperLabel ?? 'Info'}: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7EA2FF),
                    ),
                  ),
                  TextSpan(text: helperText),
                ],
              ),
            ),
          ],
          if (actionRows.isNotEmpty) ...[
            const SizedBox(height: 7),
            for (var index = 0; index < actionRows.length; index++) ...[
              actionRows[index],
              if (index < actionRows.length - 1) const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}

enum _RouteAnchorAction {
  currentLocation,
  savedPlace,
  customPickedPlace,
  clear,
}

class _VanRouteAnchorCard extends StatelessWidget {
  const _VanRouteAnchorCard({
    required this.title,
    required this.prompt,
    required this.anchor,
    required this.onTap,
    this.onClear,
  });

  final String title;
  final String prompt;
  final VanRouteAnchor? anchor;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selectedAnchor = anchor;
    final accent = selectedAnchor != null
        ? const Color(0xFF4A7DFF)
        : Colors.white.withValues(alpha: 0.16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.4,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (selectedAnchor != null)
                    _VanInfoPill(
                      label: selectedAnchor.type.label,
                      accent: const Color(0xFF4A7DFF),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              if (selectedAnchor != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: accent.withValues(alpha: 0.14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        selectedAnchor.type.icon,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAnchor.bestLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Used for route planning.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.4,
                              height: 1.28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.66),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 12.0,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _VanInlineButton(
                    label: selectedAnchor != null ? 'Change' : 'Select',
                    filled: true,
                    scaleLabelDown: true,
                    onTap: onTap,
                  ),
                  if (selectedAnchor != null)
                    _VanInlineButton(
                      label: 'Clear',
                      scaleLabelDown: true,
                      onTap: onClear,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VanAnchorPickerTile extends StatelessWidget {
  const _VanAnchorPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive
        ? const Color(0xFFFF8A72)
        : const Color(0xFF4A7DFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.0,
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
