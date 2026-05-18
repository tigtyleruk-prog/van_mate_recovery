part of 'van_firebase_page.dart';

class _VanTodayPage extends StatelessWidget {
  final _VanFirebasePageState state;

  const _VanTodayPage({required this.state});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: VanMatePremiumService.instance,
      builder: (context, _) => state.buildTodayBodyExtracted(bottomInset),
    );
  }
}

LatLng? _todayRouteStopCoordinate(VanRouteStop stop) {
  if (!stop.hasCoordinates) {
    return null;
  }

  return LatLng(stop.latitude!, stop.longitude!);
}

String _todayRouteStopLocationQuery(VanRouteStop stop) {
  final coordinate = _todayRouteStopCoordinate(stop);
  if (coordinate != null) {
    return '${coordinate.latitude},${coordinate.longitude}';
  }

  final postcode = stop.postcodeArea.trim();
  final address = stop.address.trim();
  final parts = <String>[
    if (postcode.isNotEmpty) postcode,
    if (address.isNotEmpty) address,
  ];
  if (parts.isNotEmpty) {
    return parts.join(', ');
  }

  return stop.name.trim();
}

Uri _todayRouteNavigationUriForStop(VanRouteStop stop) {
  final query = _todayRouteStopLocationQuery(stop);
  final coordinate = _todayRouteStopCoordinate(stop);
  if (coordinate != null) {
    return Uri.parse(
      'geo:${coordinate.latitude},${coordinate.longitude}?q=${Uri.encodeComponent(query)}',
    );
  }

  return Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}');
}

extension _VanFirebaseTodayTab on _VanFirebasePageState {
  String formatRouteDateLabelExtracted(String routeDate) {
    final parsed = DateTime.tryParse(routeDate);
    if (parsed == null) {
      return routeDate;
    }

    const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = <String>[
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

    return '${weekdays[parsed.weekday - 1]} ${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String routeSummaryLineExtracted(VanRoute? route) {
    if (route == null) {
      return 'Build a route in Route, save it, and Today will show your current job here automatically.';
    }

    final currentJob = route.currentJob;
    if (currentJob != null) {
      return 'Tap Open Job to work the current stop, or Navigate to open your preferred navigation app.';
    }

    return route.stops.isEmpty
        ? 'Add stops from Places in Route to start the day.'
        : 'All stops are marked done or failed.';
  }

  String _todayRouteTitle(VanRoute? route) {
    if (route == null) {
      return 'Today Route';
    }

    final rawName = route.routeName.trim();
    if (rawName.isNotEmpty) {
      return rawName;
    }

    return _storage.defaultRouteNameForDate(route.routeDate);
  }

  List<_VanSummaryMetric> summaryMetricsForRouteExtracted(VanRoute? route) {
    final stops = route?.stops ?? const <VanRouteStop>[];
    final queuedCount = route?.queuedCount ?? 0;
    final completedCount = route?.completedCount ?? 0;
    final failedCount = route?.failedCount ?? 0;

    return <_VanSummaryMetric>[
      _VanSummaryMetric(
        labelTop: 'Stops',
        value: '${stops.length}',
        icon: Icons.route_outlined,
        accent: const Color(0xFF67A1FF),
      ),
      _VanSummaryMetric(
        labelTop: 'Done',
        value: '$completedCount',
        icon: Icons.task_alt_outlined,
        accent: const Color(0xFF58D0A4),
      ),
      _VanSummaryMetric(
        labelTop: 'Failed',
        value: '$failedCount',
        icon: Icons.report_problem_outlined,
        accent: const Color(0xFFFF8A72),
      ),
      _VanSummaryMetric(
        labelTop: 'Left',
        value: '$queuedCount',
        icon: Icons.pending_actions_outlined,
        accent: const Color(0xFF8EA7FF),
      ),
    ];
  }

  String _formatRoutePreviewDuration(Duration? duration) {
    if (duration == null || duration.inSeconds <= 0) {
      return 'Calculating...';
    }

    final minutes = duration.inMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours <= 0) {
      return '${remainingMinutes}m';
    }
    return remainingMinutes <= 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }

  String _formatRoutePreviewDistance(double? meters) {
    if (meters == null || meters <= 0) {
      return 'Calculating...';
    }

    final miles = meters / 1609.344;
    if (miles >= 10) {
      return '${miles.round()} mi';
    }
    return '${miles.toStringAsFixed(1)} mi';
  }

  String _formatRoutePreviewFinishTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Calculating...';
    }

    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _formatRoutePreviewStopCount(int count) {
    return count == 1 ? '1 stop' : '$count stops';
  }

  String _premiumRouteSummaryHelperText(String? error) {
    final message = error?.trim() ?? '';
    if (message.isEmpty) {
      return 'Open Google Maps for navigation.';
    }

    final normalized = message
        .replaceFirst(RegExp(r'^Route summary unavailable\.?\s*'), '')
        .trim();
    if (normalized.isEmpty) {
      return 'Open Google Maps for navigation.';
    }

    return normalized;
  }

  int _missingExactPinCount(List<VanRouteStop> remainingStops) {
    return remainingStops.where((stop) => !stop.hasCoordinates).length;
  }

  Widget _buildPremiumRouteSummaryCard({
    required bool premiumEnabled,
    required List<VanRouteStop> remainingStops,
    required TodayRouteSummary? summary,
    required bool loading,
    required String? error,
  }) {
    if (!premiumEnabled) {
      return const SizedBox.shrink();
    }

    final remainingCount = remainingStops.length;
    final hasSummary =
        summary?.summaryHash.trim().isNotEmpty == true &&
        summary?.hasError == false;
    final missingExactPinCount = _missingExactPinCount(remainingStops);
    final helperText = _premiumRouteSummaryHelperText(error);

    Widget body;
    if (remainingCount == 0) {
      body = Text(
        'No stops left',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.2,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      );
    } else if (loading) {
      body = Text(
        'Calculating route summary...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.2,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      );
    } else if (error != null || !hasSummary) {
      final needsPinsText = missingExactPinCount > 0
          ? missingExactPinCount == 1
                ? '1 stop needs an exact pin.'
                : '$missingExactPinCount stops need exact pins.'
          : helperText;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route summary unavailable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            needsPinsText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.7,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          if (missingExactPinCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Set exact pins from Places or Add Drop.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.54),
              ),
            ),
          ],
        ],
      );
    } else {
      final routeSummary = summary!;
      final distanceText = _formatRoutePreviewDistance(
        routeSummary.totalDistanceMeters,
      );
      final durationText = _formatRoutePreviewDuration(
        routeSummary.totalDuration,
      );

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatRoutePreviewStopCount(routeSummary.stopCount)} • $distanceText • $durationText',
            softWrap: true,
            style: const TextStyle(
              fontSize: 13.6,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Finish around ${_formatRoutePreviewFinishTime(routeSummary.estimatedFinish)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.1,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Remaining route estimate',
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.4,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.60),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: const Color(0xFF79A6FF).withValues(alpha: 0.16),
              border: Border.all(
                color: const Color(0xFF79A6FF).withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget buildTodayBodyExtracted(double bottomInset) {
    final route = _todayDisplayRoute;
    _maybeShowTodayRouteHelp(route);
    final currentJob = route?.currentJob;
    final activeStops =
        route?.getActiveOrderedStops() ?? const <VanRouteStop>[];
    final remainingStops = activeStops
        .where((stop) => stop.isQueued)
        .toList(growable: false);
    final currentStop = remainingStops.isNotEmpty ? remainingStops.first : null;
    final nextStop = remainingStops.length > 1 ? remainingStops[1] : null;
    final remainingCount = remainingStops.length;
    final previewRoute = route?.copyWith(stops: remainingStops);
    final premiumService = VanMatePremiumService.instance;
    final premiumEnabled = premiumService.isPremium;
    final summary = _routePreviewSummary;
    final routePreviewTitle = premiumEnabled ? 'Route preview' : 'Route ready';
    final routePreviewSubtitle = 'Numbered stop preview';

    _logTodayRoutePreviewState(
      route: route,
      remainingStops: remainingStops,
      currentStop: currentStop,
      nextStop: nextStop,
      coordinateCount: remainingStops
          .where((stop) => stop.hasCoordinates)
          .length,
    );

    return ListView(
      key: const ValueKey('today_tab'),
      clipBehavior: Clip.none,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 84),
      children: [
        _VanSummaryGrid(
          metrics: summaryMetricsForRouteExtracted(route),
          muted: route == null,
        ),
        const SizedBox(height: 6),
        if (route == null)
          _VanEmptyCard(
            title: 'No active route yet.',
            message: 'Build a route from Places, then start it here.',
            actionLabel: 'Open Route',
            onAction: () => _switchTab(VanTab.route),
          )
        else ...[
          _VanSectionHeader(
            title: _todayRouteTitle(route),
            subtitle: routeSummaryLineExtracted(route),
          ),
          const SizedBox(height: 6),
          if (currentJob != null)
            buildCurrentJobCardExtracted(
              currentJob,
              totalStops: route.stops.length,
            )
          else
            _VanEmptyCard(
              title: route.stops.isEmpty
                  ? 'No stops saved yet'
                  : 'Route complete',
              message: route.stops.isEmpty
                  ? 'Add stops from Places in Route to start the day.'
                  : 'All stops are marked done or failed.',
            ),
          if (remainingStops.isNotEmpty) ...[
            const SizedBox(height: 16),
            _VanSectionHeader(
              title: 'Remaining Stops',
              subtitle:
                  '$remainingCount remaining stop${remainingCount == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 8),
            for (final stop in remainingStops) ...[
              buildQueuedStopPreviewCardExtracted(stop),
              const SizedBox(height: 5),
            ],
          ],
          _VanGlassPanel(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
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
                        borderRadius: BorderRadius.circular(13),
                        color: const Color(0xFF4A7DFF).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(
                            0xFF4A7DFF,
                          ).withValues(alpha: 0.24),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.route_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routePreviewTitle,
                            style: const TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            routePreviewSubtitle,
                            style: TextStyle(
                              fontSize: 11.4,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (remainingStops.isEmpty)
                  _VanRoutePreviewPlaceholder(
                    title: 'Route complete',
                    message: 'No remaining stops.',
                    icon: Icons.check_circle_outline_rounded,
                  )
                else
                  VanRouteMiniMapCard(
                    route: previewRoute,
                    showActionChips: false,
                    interactiveMap: false,
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _VanCompactNoteCard(
                        label: 'Current stop',
                        value: currentStop?.name.trim().isNotEmpty == true
                            ? currentStop!.name
                            : 'No current stop',
                        accent: const Color(0xFF79A6FF),
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VanCompactNoteCard(
                        label: 'Next stop',
                        value: nextStop?.name.trim().isNotEmpty == true
                            ? nextStop!.name
                            : 'No next stop',
                        accent: const Color(0xFF58D0A4),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                if (premiumEnabled) ...[
                  const SizedBox(height: 9),
                  _buildPremiumRouteSummaryCard(
                    premiumEnabled: premiumEnabled,
                    remainingStops: remainingStops,
                    summary: summary,
                    loading: _routePreviewSummaryLoading,
                    error: _routePreviewSummaryError,
                  ),
                ],
                const SizedBox(height: 6),
                _VanActionRow(
                  stackOnNarrow: true,
                  stackedBreakpoint: 430,
                  leading: _VanInlineButton(
                    label: 'Open route in Google Maps',
                    icon: Icons.route_outlined,
                    filled: true,
                    scaleLabelDown: true,
                    onTap: remainingStops.isEmpty
                        ? null
                        : _openRouteInGoogleMapsFromToday,
                  ),
                  trailing: _VanInlineButton(
                    label: 'Navigate next stop',
                    icon: Icons.navigation_outlined,
                    toned: true,
                    accentColor: const Color(0xFF58D0A4),
                    scaleLabelDown: true,
                    onTap: currentStop == null
                        ? null
                        : () => _openStopInMaps(currentStop),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget buildCurrentJobCardExtracted(
    VanRouteStop stop, {
    required int totalStops,
  }) {
    final isBusy = _busyStopIds.contains(stop.id);
    final primaryNote =
        cleanVanNoteText(stop.deliveryNote, postcode: stop.postcodeArea) ?? '';
    final warningNote =
        cleanVanNoteText(stop.warningNote, postcode: stop.postcodeArea) ?? '';

    return _VanGlassPanel(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
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
                      'Current / Next Stop',
                      style: TextStyle(
                        fontSize: 17.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalStops <= 0
                          ? 'Stop ${stop.routeOrder + 1}'
                          : 'Stop ${stop.routeOrder + 1} of $totalStops',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              _VanStatusBadge(status: stop.status, isCurrent: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.30),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${stop.routeOrder + 1}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.postcodeArea,
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                        color: stop.placeType.accent,
                      ),
                    ),
                    if (stop.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        stop.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.8,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.74),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (primaryNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _VanCompactNoteCard(
              label: 'Delivery note',
              value: primaryNote,
              maxLines: 3,
            ),
          ],
          if (warningNote.isNotEmpty) ...[
            const SizedBox(height: 5),
            _VanCompactNoteCard(
              label: 'Warning',
              value: warningNote,
              accent: const Color(0xFFFFC38C),
              maxLines: 3,
            ),
          ],
          const SizedBox(height: 10),
          _buildCurrentJobPinRequestSection(stop),
          const SizedBox(height: 10),
          const _VanActionGroupLabel(
            label: 'Main actions',
            accent: Color(0xFF79A6FF),
          ),
          const SizedBox(height: 5),
          _VanActionRow(
            stackOnNarrow: true,
            stackedBreakpoint: 430,
            leading: _VanInlineButton(
              label: 'Open Job',
              icon: Icons.open_in_new_rounded,
              filled: true,
              scaleLabelDown: true,
              onTap: isBusy ? null : () => _openCurrentJob(stop),
            ),
            trailing: _VanInlineButton(
              label: 'Navigate',
              icon: Icons.navigation_outlined,
              filled: true,
              scaleLabelDown: true,
              onTap: isBusy ? null : () => _openStopInMaps(stop),
            ),
          ),
          const SizedBox(height: 7),
          const _VanActionGroupLabel(
            label: 'Completion / status',
            accent: Color(0xFFFFC38C),
          ),
          const SizedBox(height: 5),
          _VanActionRow(
            stackOnNarrow: true,
            stackedBreakpoint: 430,
            leading: _VanInlineButton(
              label: 'Done',
              icon: Icons.task_alt_rounded,
              toned: true,
              accentColor: const Color(0xFF58D0A4),
              scaleLabelDown: true,
              onTap: isBusy
                  ? null
                  : () => _setStopStatus(stop, VanRouteStopStatus.done),
            ),
            trailing: _VanInlineButton(
              label: 'Failed',
              icon: Icons.report_problem_outlined,
              toned: true,
              accentColor: const Color(0xFFFF8A72),
              scaleLabelDown: true,
              onTap: isBusy ? null : () => _markFailedFromCard(stop),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQueuedStopPreviewCardExtracted(VanRouteStop stop) {
    final isBusy = _busyStopIds.contains(stop.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : () => _openCurrentJob(stop),
        borderRadius: BorderRadius.circular(28),
        child: _VanGlassPanel(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
                  border: Border.all(
                    color: const Color(0xFF4A7DFF).withValues(alpha: 0.26),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${stop.routeOrder + 1}',
                  style: const TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    if (stop.postcodeArea.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.postcodeArea,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                          color: stop.placeType.accent,
                        ),
                      ),
                    ],
                    _buildQueuedStopPinRequestSection(stop),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _VanStatusBadge(status: stop.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentJobPinRequestSection(VanRouteStop stop) {
    return StreamBuilder<VanPinRequest?>(
      stream: _pinRequestStreamForDropId(stop.placeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[PinRequest] Today stream error for ${stop.placeId}: ${snapshot.error}',
          );
          return const SizedBox.shrink();
        }

        final request = snapshot.data;
        if (request == null) {
          return const SizedBox.shrink();
        }

        final requestNote = request.responseNote.trim();
        final hasReceivedPin = request.canUseReceivedPin;
        final hasSavedPin = request.usedAsExactPin;
        final isNoteRequest = request.isReceivedNote;
        final isPending = request.isPending && !request.isExpired;
        final isExpired = request.isExpired;

        debugPrint(
          '[PinRequest] latest request loaded for drop ${stop.placeId}: ${request.id} status=${request.status}',
        );
        if (isPending) {
          debugPrint(
            '[PinRequest] pending request found for drop ${stop.placeId} request=${request.id}',
          );
        }
        if (hasReceivedPin || isNoteRequest) {
          debugPrint(
            '[PinRequest] received pin found for drop ${stop.placeId} request=${request.id}',
          );
        }

        final title = hasSavedPin
            ? 'Exact pin saved'
            : isNoteRequest
            ? 'Location note received'
            : hasReceivedPin
            ? 'Exact pin received'
            : isExpired
            ? 'Request expired'
            : isPending
            ? 'Exact pin request sent'
            : 'Exact pin received';
        final body = hasSavedPin
            ? 'The received pin is already applied to this stop.'
            : isNoteRequest
            ? (requestNote.isNotEmpty
                  ? requestNote
                  : 'The customer/site sent a location note instead of coordinates.')
            : hasReceivedPin
            ? request.responseSourceLabel
            : isExpired
            ? 'This request has expired. Create a fresh link if needed.'
            : 'Waiting for customer/site to send the pin.';
        final accent = hasSavedPin
            ? const Color(0xFF58D0A4)
            : isExpired
            ? const Color(0xFFFF8A72)
            : isNoteRequest
            ? const Color(0xFFF8C76C)
            : hasReceivedPin
            ? const Color(0xFF58D0A4)
            : const Color(0xFF4A7DFF);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VanGlassPanel(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                            fontSize: 13.8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _VanInfoPill(label: title, accent: accent),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 11.8,
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  if (hasReceivedPin) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _VanInlineButton(
                            label: 'Open in Google Maps',
                            icon: Icons.open_in_new_rounded,
                            toned: true,
                            accentColor: const Color(0xFF3155B7),
                            scaleLabelDown: true,
                            onTap: () {
                              unawaited(_openSharedPinFromStop(stop, request));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _VanInlineButton(
                            label: 'Use as exact pin',
                            icon: Icons.check_circle_outline_rounded,
                            filled: true,
                            scaleLabelDown: true,
                            onTap: hasSavedPin
                                ? null
                                : () {
                                    unawaited(
                                      _useReceivedExactPinForStop(
                                        stop,
                                        request,
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _VanInlineButton(
                            label: 'Adjust / Set exact pin',
                            icon: Icons.tune_rounded,
                            scaleLabelDown: true,
                            onTap: hasSavedPin
                                ? null
                                : () {
                                    unawaited(
                                      _adjustReceivedExactPinForStop(
                                        stop,
                                        request,
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isNoteRequest && requestNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _VanCompactNoteCard(
                      label: 'Location note',
                      value: requestNote,
                      accent: const Color(0xFFF8C76C),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: _VanInlineButton(
                        label: 'Copy note',
                        icon: Icons.copy_rounded,
                        toned: true,
                        accentColor: const Color(0xFFF8C76C),
                        scaleLabelDown: true,
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: requestNote),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(content: Text('Note copied.')),
                            );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueuedStopPinRequestSection(VanRouteStop stop) {
    return StreamBuilder<VanPinRequest?>(
      stream: _pinRequestStreamForDropId(stop.placeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[PinRequest] Today queued stream error for ${stop.placeId}: ${snapshot.error}',
          );
          return const SizedBox.shrink();
        }

        final request = snapshot.data;
        if (request == null || !request.canUseReceivedPin) {
          return const SizedBox.shrink();
        }

        debugPrint(
          '[PinRequest] latest request loaded for drop ${stop.placeId}: ${request.id} status=${request.status}',
        );
        debugPrint(
          '[PinRequest] received pin found for drop ${stop.placeId} request=${request.id}',
        );

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    unawaited(_openSharedPinFromStop(stop, request));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VanRoutePreviewPlaceholder extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _VanRoutePreviewPlaceholder({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF0D1728),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.2,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.8,
              height: 1.22,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}
