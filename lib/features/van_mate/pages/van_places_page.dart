import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../helpers/van_note_utils.dart';
import '../helpers/van_live_pin_request.dart';
import '../services/van_first_use_help_service.dart';
import '../models/van_pin_request.dart';
import '../models/van_place.dart';
import '../models/van_route_stop.dart';
import '../services/van_community_share_service.dart';
import '../services/van_premium_service.dart';
import '../services/van_pin_request_service.dart';
import '../widgets/van_exact_pin_flow.dart';
import '../widgets/van_first_use_help_dialog.dart';

class VanPlacesTabPage extends StatefulWidget {
  const VanPlacesTabPage({
    super.key,
    required this.places,
    required this.placesLoaded,
    required this.routeDraftStops,
    required this.searchController,
    required this.deletingPlaceIds,
    required this.onScanDrop,
    required this.onAddDrop,
    required this.onOpenPlaceEditor,
    required this.onOpenPlaceInMaps,
    required this.onAddPlaceToRoute,
    required this.onDeletePlace,
    required this.onSavePlaceChanges,
    required this.onOpenSharedPin,
    required this.onUseReceivedPin,
    required this.onAdjustReceivedPin,
    required this.onCreateDropFromReceivedPin,
    required this.onArchiveEmergencyPinRequest,
    this.onUnmatchedRequestsVisible,
    required this.resetNonce,
    this.loadError,
    this.onRetryLoad,
  });

  final List<VanPlace> places;
  final bool placesLoaded;
  final List<VanRouteStop> routeDraftStops;
  final TextEditingController searchController;
  final Set<String> deletingPlaceIds;
  final Future<void> Function() onScanDrop;
  final VoidCallback onAddDrop;
  final ValueChanged<VanPlace> onOpenPlaceEditor;
  final ValueChanged<VanPlace> onOpenPlaceInMaps;
  final ValueChanged<VanPlace> onAddPlaceToRoute;
  final Future<void> Function(VanPlace place) onDeletePlace;
  final Future<VanPlace?> Function(VanPlace place) onSavePlaceChanges;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onOpenSharedPin;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onUseReceivedPin;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onAdjustReceivedPin;
  final Future<void> Function(VanPinRequest request)
  onCreateDropFromReceivedPin;
  final Future<void> Function(VanPinRequest request)
  onArchiveEmergencyPinRequest;
  final Future<void> Function(List<VanPinRequest> requests)?
  onUnmatchedRequestsVisible;
  final int resetNonce;
  final String? loadError;
  final Future<void> Function()? onRetryLoad;

  @override
  State<VanPlacesTabPage> createState() => _VanPlacesTabPageState();
}

class _VanPlacesTabPageState extends State<VanPlacesTabPage> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  VanPlaceType? _selectedType;
  int _lastResetNonce = 0;
  String? _expandedManagePlaceId;
  String _effectiveSearchQuery = '';
  int _buildCount = 0;
  int _searchInputCount = 0;
  Timer? _searchDebounceTimer;
  bool _emergencyPinHelpDialogVisible = false;
  String? _sharingEntranceInfoPlaceId;
  bool _manageHelpDialogVisible = false;
  final Map<String, Stream<VanPinRequest?>> _pinRequestStreamCache = {};
  final Map<String, Stream<List<VanPinRequest>>>
  _emergencyPinRequestStreamCache = {};
  final VanCommunityShareService _communityShareService =
      VanCommunityShareService();

  @override
  void initState() {
    super.initState();
    _selectedType = null;
    _lastResetNonce = widget.resetNonce;
    _effectiveSearchQuery = widget.searchController.text.trim();
    widget.searchController.addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant VanPlacesTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_handleSearchChanged);
      widget.searchController.addListener(_handleSearchChanged);
      _searchDebounceTimer?.cancel();
      _effectiveSearchQuery = widget.searchController.text.trim();
    }

    if (widget.resetNonce != _lastResetNonce) {
      _lastResetNonce = widget.resetNonce;
      _selectedType = null;
      _expandedManagePlaceId = null;
      _sharingEntranceInfoPlaceId = null;
      _pinRequestStreamCache.clear();
      _emergencyPinRequestStreamCache.clear();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    widget.searchController.removeListener(_handleSearchChanged);
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      final nextQuery = widget.searchController.text.trim();
      if (nextQuery == _effectiveSearchQuery) {
        return;
      }

      setState(() {
        _effectiveSearchQuery = nextQuery;
      });
    });
  }

  void _handleSearchInputChanged(String value) {
    _searchInputCount++;
    debugPrint(
      '[Perf] Places search onChanged #$_searchInputCount queryLength=${value.trim().length}',
    );
  }

  Future<void> _requestExactPinWithHelp(VanPlace place) async {
    if (_emergencyPinHelpDialogVisible) {
      return;
    }

    _emergencyPinHelpDialogVisible = true;
    try {
      await showVanMateFirstUseHelpDialog(
        context,
        storageKey: VanMateFirstUseHelpKeys.seenRequestExactPinHelp,
        title: 'Request exact pin',
        body:
            'Send a one-time link to the customer or site so they can share the actual delivery entrance, bay, or drop-off point. It does not track them live.',
      );
      if (!mounted) {
        return;
      }
      await requestVanLivePinForPlace(context, place);
    } finally {
      if (mounted) {
        _emergencyPinHelpDialogVisible = false;
      }
    }
  }

  Future<void> _pinCurrentLocationForPlace(VanPlace place) async {
    if (_emergencyPinHelpDialogVisible || _sharingEntranceInfoPlaceId != null) {
      return;
    }

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _showSnack('Turn on location services to pin your position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showSnack(
          'Location permission is needed to pin your current position.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permission is turned off for Van Mate. Enable it in app settings to use your current position.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) {
        return;
      }

      final accuracyWarning = position.accuracy > 50
          ? 'GPS accuracy looks weak. You can still save it, but check the pin later.'
          : null;
      final confirmed = await showVanExactPinConfirmDialog(
        context,
        body:
            'Use your current GPS position as the exact entrance or bay for this drop. You can adjust it later if needed.${accuracyWarning == null ? '' : '\n\n$accuracyWarning'}',
      );
      if (!mounted || confirmed != true) {
        return;
      }

      final now = DateTime.now();
      final updatedPlace = place.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        trustedExactPin: true,
        exactPinUpdatedAt: now,
        exactPinSource: 'current_location',
        updatedAt: now,
      );

      final savedPlace = await widget.onSavePlaceChanges(updatedPlace);
      if (!mounted || savedPlace == null) {
        return;
      }
      _showSnack('Exact pin saved.');
    } catch (_) {
      _showSnack(
        'Could not get your current location. Try again or use Open Picker.',
      );
    }
  }

  Future<void> _showEmergencyPinRequestHelpThenOpenSheet() async {
    if (_emergencyPinHelpDialogVisible) {
      return;
    }

    _emergencyPinHelpDialogVisible = true;
    try {
      await showVanMateFirstUseHelpDialog(
        context,
        storageKey: VanMateFirstUseHelpKeys.seenEmergencyPinHelp,
        title: 'Emergency pin request',
        body:
            'Use this when you have a customer/site phone number but the location is still unclear. Ask them to share the pin only if they are at the correct delivery entrance or drop-off point.',
      );
      if (!mounted) {
        return;
      }
      await _openEmergencyPinRequestSheet();
    } finally {
      if (mounted) {
        _emergencyPinHelpDialogVisible = false;
      }
    }
  }

  void _toggleManageSection(String placeId) {
    debugPrint('Manage tapped: placeId=$placeId');
    final isOpenAlready = _expandedManagePlaceId == placeId;
    setState(() {
      if (isOpenAlready) {
        _expandedManagePlaceId = null;
      } else {
        _expandedManagePlaceId = placeId;
      }
      debugPrint('Expanded manage place id=$_expandedManagePlaceId');
    });

    if (!isOpenAlready) {
      unawaited(_showManageHelpIfNeeded());
    }
  }

  Future<void> _showManageHelpIfNeeded() async {
    if (_manageHelpDialogVisible) {
      return;
    }

    final helpService = VanMateFirstUseHelpService.instance;
    await helpService.ensureLoaded();
    if (!mounted ||
        await helpService.hasSeen(VanMateFirstUseHelpKeys.seenManageDropHelp)) {
      return;
    }

    _manageHelpDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }

        await showVanMateFirstUseHelpDialog(
          context,
          storageKey: VanMateFirstUseHelpKeys.seenManageDropHelp,
          title: 'Managing a drop',
          body:
              'Request exact pin if you don\'t know the entrance.\nPin current location when you\'re at the gate or bay.\nShare entrance info to help other drivers after checking private info is not included.',
        );
      } finally {
        _manageHelpDialogVisible = false;
      }
    });
  }

  Stream<VanPinRequest?> _pinRequestStreamForPlace(VanPlace place) {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final placeId = place.id.trim();
    final cacheKey = '$currentUserUid::$placeId';

    if (currentUserUid.isEmpty || placeId.isEmpty) {
      debugPrint(
        '[PinRequest] No pin request stream for place.name=${place.name} place.id=$placeId current user uid=$currentUserUid',
      );
      return const Stream<VanPinRequest?>.empty();
    }

    return _pinRequestStreamCache.putIfAbsent(cacheKey, () {
      debugPrint(
        '[PinRequest] building stream current user uid=$currentUserUid place.name=${place.name} place.id=$placeId place.id.length=${place.id.length}',
      );

      return FirebaseFirestore.instance
          .collection('van_pin_requests')
          .where('ownerId', isEqualTo: currentUserUid)
          .where('dropId', isEqualTo: placeId)
          .snapshots()
          .map((snapshot) {
            final requests = snapshot.docs
                .map(VanPinRequest.fromFirestore)
                .toList(growable: false);

            debugPrint(
              '[PinRequest] loaded ${requests.length} matching pin request(s) for place.name=${place.name} place.id=$placeId current user uid=$currentUserUid place.id.length=${place.id.length}',
            );

            for (final request in requests) {
              debugPrint(
                '[PinRequest] request.id=${request.id} request.dropId=${request.dropId} request.dropId.length=${request.dropId.length} request.status=${request.status} request.responseLat=${request.responseLat} request.responseLng=${request.responseLng} place.id == request.dropId: ${place.id == request.dropId}',
              );
            }

            if (requests.isEmpty) {
              debugPrint('No pin request found for place.id = $placeId');
              return null;
            }

            final latestRequest = _latestPinRequestFromList(requests);
            debugPrint(
              '[PinRequest] latest for place.id=$placeId: ${latestRequest.id} status=${latestRequest.status} responseLat=${latestRequest.responseLat} responseLng=${latestRequest.responseLng}',
            );
            return latestRequest;
          });
    });
  }

  Future<void> _shareEntranceInfo(VanPlace place) async {
    if (!place.hasTrustedExactPin || !place.hasCoordinates) {
      _showSnack('Add an exact entrance pin before sharing.');
      return;
    }

    if (_sharingEntranceInfoPlaceId == place.id) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _VanShareEntranceInfoDialog(place: place);
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _sharingEntranceInfoPlaceId = place.id;
    });

    try {
      final result = await _communityShareService.shareEntranceInfo(place);
      if (!mounted) {
        return;
      }

      switch (result.outcome) {
        case VanCommunityShareOutcome.shared:
          _showSnack(result.message);
          break;
        case VanCommunityShareOutcome.duplicate:
          _showSnack(result.message);
          break;
        case VanCommunityShareOutcome.missingExactPin:
          _showSnack(result.message);
          break;
        case VanCommunityShareOutcome.notSignedIn:
          _showSnack(result.message);
          break;
        case VanCommunityShareOutcome.failed:
          _showSnack(result.message);
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharingEntranceInfoPlaceId = null;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Stream<List<VanPinRequest>> _emergencyPinRequestsStreamForCurrentUser() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (currentUserUid.isEmpty) {
      return const Stream<List<VanPinRequest>>.empty();
    }

    return _emergencyPinRequestStreamCache.putIfAbsent(currentUserUid, () {
      debugPrint(
        '[PinRequest] building emergency stream current user uid=$currentUserUid',
      );
      return VanPinRequestService.instance.watchEmergencyUnmatchedRequests(
        ownerId: currentUserUid,
      );
    });
  }

  VanPinRequest _latestPinRequestFromList(List<VanPinRequest> requests) {
    final sortedRequests = List<VanPinRequest>.from(requests)
      ..sort((a, b) {
        final aFreshness = a.responseAt ?? a.createdAt;
        final bFreshness = b.responseAt ?? b.createdAt;
        final freshnessComparison = bFreshness.compareTo(aFreshness);
        if (freshnessComparison != 0) {
          return freshnessComparison;
        }

        return b.createdAt.compareTo(a.createdAt);
      });
    return sortedRequests.first;
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final searchQuery = _effectiveSearchQuery;
    final loadError = widget.loadError?.trim();
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid.trim();
    final premiumService = VanMatePremiumService.instance;
    debugPrint(
      '[Perf] Places page build #$_buildCount bottomInset=$bottomInset effectiveQueryLength=${searchQuery.length} loadError=${loadError != null && loadError.isNotEmpty} placesLoaded=${widget.placesLoaded} placesCount=${widget.places.length} authUid=${currentUserUid ?? 'null'} premiumLoaded=${premiumService.isLoaded} premium=${premiumService.isPremium}',
    );
    if (loadError != null && loadError.isNotEmpty) {
      debugPrint('[PlacesLoad] showing places error card: $loadError');
    } else if (!widget.placesLoaded && widget.places.isEmpty) {
      debugPrint(
        '[PlacesLoad] showing local loading placeholder for saved drops',
      );
    } else {
      debugPrint(
        '[PlacesLoad] showing places content count=${widget.places.length}',
      );
    }
    const bottomSpacer = 320.0;

    final filteredPlaces = _filteredPlaces(searchQuery);
    final visibleDropCount = filteredPlaces.length;
    final totalDropCount = widget.places.length;
    final inRouteDropCount = widget.places
        .where((place) => _isPlaceInRouteDraft(place.id))
        .length;
    final hasActiveFilter = _selectedType != null || searchQuery.isNotEmpty;
    final summaryHelperText = totalDropCount == 0
        ? 'Save your first precise drop, then reuse it in Route or on the map.'
        : hasActiveFilter
        ? 'Showing $visibleDropCount matching drop${visibleDropCount == 1 ? '' : 's'}.'
        : 'Tap a saved drop to navigate, edit, or add it to Route.';

    return ListView(
      key: const ValueKey('places_tab'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + bottomSpacer),
      children: [
        const _VanSectionHeader(
          title: 'Saved Drop Library',
          subtitle: 'Save drops here, then reuse them in Route or on the map.',
        ),
        const SizedBox(height: 12),
        if (loadError != null && loadError.isNotEmpty) ...[
          _VanPlacesErrorCard(
            title: 'Couldn\'t load saved drops',
            message: loadError,
            onRetry: widget.onRetryLoad,
          ),
          const SizedBox(height: 10),
        ] else if (!widget.placesLoaded && widget.places.isEmpty) ...[
          const _VanCompactStatusCard(
            title: 'Loading saved drops',
            body: 'Van Mate is syncing your Places library now.',
            accent: Color(0xFF4A7DFF),
          ),
          const SizedBox(height: 10),
        ],
        AnimatedBuilder(
          animation: premiumService,
          builder: (context, _) {
            debugPrint(
              '[Premium] loaded=${premiumService.isLoaded} premium=${premiumService.isPremium} scanDropVisible=${premiumService.canUseScanDrop}',
            );

            return _VanPlacesTopActions(
              onScanDrop: widget.onScanDrop,
              onAddDrop: widget.onAddDrop,
              onEmergencyPinRequest: _showEmergencyPinRequestHelpThenOpenSheet,
            );
          },
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: _VanSearchField(
            controller: widget.searchController,
            hintText: 'Search saved drops',
            bottomScrollPadding: 120,
            onChanged: _handleSearchInputChanged,
          ),
        ),
        const SizedBox(height: 7),
        RepaintBoundary(
          child: _VanFilterWrap(
            selectedType: _selectedType,
            onSelected: (type) {
              setState(() {
                _selectedType = type;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: _VanPlacesSummaryCard(
            totalDropCount: totalDropCount,
            inRouteDropCount: inRouteDropCount,
            helperText: summaryHelperText,
          ),
        ),
        RepaintBoundary(
          child: _VanEmergencyPinRequestsSection(
            requestStream: _emergencyPinRequestsStreamForCurrentUser(),
            onCreateDropFromRequest: widget.onCreateDropFromReceivedPin,
            onArchiveRequest: widget.onArchiveEmergencyPinRequest,
            onRequestsVisible: widget.onUnmatchedRequestsVisible,
          ),
        ),
        const SizedBox(height: 10),
        RepaintBoundary(
          child: filteredPlaces.isEmpty
              ? _VanPlacesEmptyCard(
                  title: searchQuery.isEmpty
                      ? 'No saved drops yet'
                      : 'No saved drops found',
                  message: searchQuery.isEmpty
                      ? 'Use Add Drop to place the exact pin, then save the drop details.'
                      : null,
                )
              : Column(
                  children: [
                    for (final place in filteredPlaces)
                      RepaintBoundary(
                        child: Column(
                          children: _buildPlaceLibraryEntries(context, place),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  List<VanPlace> _filteredPlaces(String query) {
    return widget.places
        .where((place) {
          final matchesFilter =
              _selectedType == null || place.placeType == _selectedType;
          return matchesFilter && place.matchesQuery(query);
        })
        .toList(growable: false);
  }

  bool _isPlaceInRouteDraft(String placeId) {
    return widget.routeDraftStops.any((stop) => stop.placeId == placeId);
  }

  List<Widget> _buildPlaceLibraryEntries(BuildContext context, VanPlace place) {
    final isInRoute = _isPlaceInRouteDraft(place.id);
    final routeIndex = widget.routeDraftStops.indexWhere(
      (stop) => stop.placeId == place.id,
    );
    final deliveryNote = cleanVanNoteText(
      place.deliveryNote,
      postcode: place.postcodeArea,
    );
    final warningNote = cleanVanNoteText(
      place.warningNote,
      postcode: place.postcodeArea,
    );
    final notePreview = deliveryNote ?? warningNote;
    final noteLabel = deliveryNote != null
        ? 'Delivery note'
        : warningNote != null
        ? 'Warning'
        : null;
    final noteAccent = deliveryNote != null ? null : const Color(0xFFFFC38C);
    final exactPinLabel = place.hasCoordinates
        ? 'Exact pin saved'
        : 'Exact pin not saved yet';

    return <Widget>[
      _VanPlaceCard(
        key: ValueKey(place.id),
        place: place,
        locationLabel: place.postcodeArea.trim().isEmpty
            ? place.placeType.label
            : place.postcodeArea.trim(),
        addressLabel: place.bestLocationLabel,
        coordinateLabel: exactPinLabel,
        routeBadgeLabel: routeIndex >= 0 ? 'Stop ${routeIndex + 1}' : null,
        noteLabel: noteLabel,
        notePreview: notePreview,
        noteAccent: noteAccent,
        manageExpanded: _expandedManagePlaceId == place.id,
        isSharingEntranceInfo: _sharingEntranceInfoPlaceId == place.id,
        onToggleManage: () => _toggleManageSection(place.id),
        onOpenManage: () {
          setState(() {
            _expandedManagePlaceId = place.id;
          });
          unawaited(_showManageHelpIfNeeded());
        },
        onTap: () => widget.onOpenPlaceEditor(place),
        isInRoute: isInRoute,
        isDeleting: widget.deletingPlaceIds.contains(place.id),
        onNavigate: () => widget.onOpenPlaceInMaps(place),
        onAddToRoute: () => widget.onAddPlaceToRoute(place),
        onEdit: () => widget.onOpenPlaceEditor(place),
        onDelete: () => widget.onDeletePlace(place),
        onShareEntranceInfo: _shareEntranceInfo,
        onPinCurrentLocation: _pinCurrentLocationForPlace,
        pinRequestStream: _pinRequestStreamForPlace(place),
        onOpenSharedPin: widget.onOpenSharedPin,
        onUseReceivedPin: widget.onUseReceivedPin,
        onAdjustReceivedPin: widget.onAdjustReceivedPin,
        onRequestExactPin: _requestExactPinWithHelp,
      ),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _openEmergencyPinRequestSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _VanEmergencyPinRequestSheet(
          onSend: (phoneNumber, driverNote) {
            return requestVanEmergencyPinForPhoneNumber(
              context,
              phoneNumber: phoneNumber,
              driverNote: driverNote,
            );
          },
        );
      },
    );
  }
}

class _VanPlacesTopActions extends StatelessWidget {
  final Future<void> Function() onScanDrop;
  final VoidCallback onAddDrop;
  final Future<void> Function() onEmergencyPinRequest;

  const _VanPlacesTopActions({
    required this.onScanDrop,
    required this.onAddDrop,
    required this.onEmergencyPinRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VanPlacesActionCard(
          title: 'Scan Drop',
          subtitle: 'Scan label, crop address, save fast',
          icon: Icons.document_scanner_outlined,
          accent: const Color(0xFF4A7DFF),
          onTap: () {
            unawaited(onScanDrop());
          },
        ),
        const SizedBox(height: 10),
        _VanPlacesActionCard(
          title: 'Add Drop',
          subtitle: 'Manually add a delivery',
          icon: Icons.add_rounded,
          accent: const Color(0xFF58D0A4),
          onTap: onAddDrop,
        ),
        const SizedBox(height: 10),
        _VanPlacesActionCard(
          title: 'Emergency Pin',
          subtitle: 'Only got a phone number? Request a pin.',
          icon: Icons.phone_in_talk_outlined,
          accent: const Color(0xFFFFA94D),
          onTap: () {
            unawaited(onEmergencyPinRequest());
          },
          actionLabel: 'Emergency pin request',
        ),
      ],
    );
  }
}

class _VanEmergencyPinRequestsSection extends StatelessWidget {
  final Stream<List<VanPinRequest>> requestStream;
  final Future<void> Function(VanPinRequest request) onCreateDropFromRequest;
  final Future<void> Function(VanPinRequest request) onArchiveRequest;
  final Future<void> Function(List<VanPinRequest> requests)? onRequestsVisible;

  const _VanEmergencyPinRequestsSection({
    required this.requestStream,
    required this.onCreateDropFromRequest,
    required this.onArchiveRequest,
    this.onRequestsVisible,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VanPinRequest>>(
      stream: requestStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[PinRequest] emergency unmatched locations stream error: ${snapshot.error}',
          );
          return _VanPlacesErrorCard(
            title: 'Couldn\'t load unmatched locations',
            message:
                'Van Mate could not read your emergency pin requests right now.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data ?? const <VanPinRequest>[];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        if (onRequestsVisible != null) {
          unawaited(onRequestsVisible!(requests));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const _VanSectionHeader(
              title: 'Unmatched locations',
              subtitle:
                  'Emergency pin requests that have not been linked to a saved drop yet.',
            ),
            const SizedBox(height: 8),
            for (final request in requests) ...[
              _VanUnmatchedLocationCard(
                request: request,
                onCreateDrop: () {
                  unawaited(onCreateDropFromRequest(request));
                },
                onArchive: () {
                  unawaited(onArchiveRequest(request));
                },
                onOpenInMaps: request.hasResponse
                    ? () {
                        unawaited(
                          openVanGoogleMapsAtCoordinates(
                            context,
                            latitude: request.responseLat!,
                            longitude: request.responseLng!,
                          ),
                        );
                      }
                    : null,
                onCopyNote: request.responseNote.trim().isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: request.responseNote.trim()),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location note copied.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _VanUnmatchedLocationCard extends StatelessWidget {
  final VanPinRequest request;
  final VoidCallback onCreateDrop;
  final VoidCallback onArchive;
  final VoidCallback? onOpenInMaps;
  final Future<void> Function()? onCopyNote;

  const _VanUnmatchedLocationCard({
    required this.request,
    required this.onCreateDrop,
    required this.onArchive,
    required this.onOpenInMaps,
    required this.onCopyNote,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = request.hasResponse;
    final responseNote = request.responseNote.trim();
    final driverNote = request.driverNote.trim();
    final phoneNumber = _formatPhoneNumberDisplay(request.phoneNumber);
    final createdLabel = request.createdAt.millisecondsSinceEpoch > 0
        ? _formatTimeOfDay(context, request.createdAt)
        : null;
    final receivedLabel = request.responseAt == null
        ? null
        : _formatTimeOfDay(context, request.responseAt!);
    final coordinatesLabel = hasCoordinates
        ? '${request.responseLat!.toStringAsFixed(5)}, ${request.responseLng!.toStringAsFixed(5)}'
        : null;
    final isNoteOnly =
        request.status == VanPinRequestStatus.receivedNote && !hasCoordinates;

    return _VanGlassPanel(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFFFFA94D).withValues(alpha: 0.18),
                  border: Border.all(
                    color: const Color(0xFFFFA94D).withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNoteOnly
                          ? 'Location note received'
                          : 'Location received',
                      style: const TextStyle(
                        fontSize: 15.8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNoteOnly
                          ? 'Emergency request received a written access note.'
                          : 'Emergency pin request received.',
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (phoneNumber != null) ...[
            const SizedBox(height: 7),
            Text(
              'From: $phoneNumber',
              style: TextStyle(
                fontSize: 12.3,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
          ],
          if (receivedLabel != null) ...[
            const SizedBox(height: 3),
            Text(
              'Received: $receivedLabel',
              style: TextStyle(
                fontSize: 12.0,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
          if (createdLabel != null) ...[
            const SizedBox(height: 3),
            Text(
              'Created: $createdLabel',
              style: TextStyle(
                fontSize: 12.0,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
          if (driverNote.isNotEmpty) ...[
            const SizedBox(height: 7),
            _VanCompactNoteCard(
              label: 'Reference',
              value: driverNote,
              accent: const Color(0xFFFFA94D),
              maxLines: 2,
            ),
          ],
          if (responseNote.isNotEmpty) ...[
            const SizedBox(height: 7),
            _VanCompactNoteCard(
              label: isNoteOnly ? 'Note' : 'Location note',
              value: responseNote,
              accent: const Color(0xFFF8C76C),
              maxLines: 3,
            ),
          ],
          if (coordinatesLabel != null) ...[
            const SizedBox(height: 7),
            _VanCompactNoteCard(
              label: 'Coordinates',
              value: coordinatesLabel,
              accent: const Color(0xFF58D0A4),
              maxLines: 1,
            ),
          ],
          const SizedBox(height: 9),
          if (hasCoordinates) ...[
            _VanActionRow(
              stackOnNarrow: true,
              stackedBreakpoint: 405,
              leading: _VanInlineButton(
                label: 'Open in Google Maps',
                icon: Icons.open_in_new_rounded,
                filled: true,
                scaleLabelDown: true,
                onTap: onOpenInMaps,
              ),
              trailing: _VanInlineButton(
                label: 'Create drop from this location',
                icon: Icons.add_location_alt_outlined,
                toned: true,
                accentColor: const Color(0xFF58D0A4),
                scaleLabelDown: true,
                onTap: onCreateDrop,
              ),
            ),
          ] else ...[
            _VanActionRow(
              stackOnNarrow: true,
              stackedBreakpoint: 405,
              leading: _VanInlineButton(
                label: 'Copy note',
                icon: Icons.copy_rounded,
                filled: true,
                scaleLabelDown: true,
                onTap: onCopyNote == null
                    ? null
                    : () => unawaited(onCopyNote!()),
              ),
              trailing: _VanInlineButton(
                label: 'Create drop from note',
                icon: Icons.add_location_alt_outlined,
                toned: true,
                accentColor: const Color(0xFF58D0A4),
                scaleLabelDown: true,
                onTap: onCreateDrop,
              ),
            ),
          ],
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: _VanInlineButton(
              label: 'Delete request',
              icon: Icons.archive_outlined,
              destructive: true,
              scaleLabelDown: true,
              onTap: onArchive,
            ),
          ),
        ],
      ),
    );
  }

  String? _formatPhoneNumberDisplay(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _formatTimeOfDay(BuildContext context, DateTime dateTime) {
    final materialLocalizations = MaterialLocalizations.of(context);
    return materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
    );
  }
}

class _VanPlacesActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? actionLabel;

  const _VanPlacesActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.7,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      actionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.4,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanPlacesEmptyCard extends StatelessWidget {
  final String title;
  final String? message;

  const _VanPlacesEmptyCard({required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white70, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: TextStyle(
                fontSize: 12.8,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanPlacesErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  const _VanPlacesErrorCard({
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white70,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  unawaited(onRetry!());
                },
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final double bottomScrollPadding;
  final ValueChanged<String>? onChanged;

  const _VanSearchField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.bottomScrollPadding = 96,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white70, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 14.2,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
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

class _VanFilterWrap extends StatelessWidget {
  final VanPlaceType? selectedType;
  final ValueChanged<VanPlaceType?> onSelected;

  const _VanFilterWrap({required this.selectedType, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _VanFilterChip(
          label: 'All',
          selected: selectedType == null,
          accent: const Color(0xFF4A7DFF),
          onTap: () => onSelected(null),
        ),
        for (final type in VanPlaceType.values)
          _VanFilterChip(
            label: type.label,
            selected: selectedType == type,
            accent: type.accent,
            onTap: () => onSelected(type),
          ),
      ],
    );
  }
}

class _VanFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _VanFilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? accent.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.6,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _VanPlacesSummaryCard extends StatelessWidget {
  const _VanPlacesSummaryCard({
    required this.totalDropCount,
    required this.inRouteDropCount,
    required this.helperText,
  });

  final int totalDropCount;
  final int inRouteDropCount;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _VanPlacesSummaryTile(
                  label: 'Drops',
                  value: '$totalDropCount',
                  icon: Icons.inventory_2_outlined,
                  accent: const Color(0xFF4A7DFF),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _VanPlacesSummaryTile(
                  label: 'In Route',
                  value: '$inRouteDropCount',
                  icon: Icons.alt_route_rounded,
                  accent: const Color(0xFF58D0A4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 11.6,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanPlacesSummaryTile extends StatelessWidget {
  const _VanPlacesSummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.4,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.70),
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

class _VanPlaceCard extends StatelessWidget {
  final VanPlace place;
  final String locationLabel;
  final String addressLabel;
  final String coordinateLabel;
  final String? routeBadgeLabel;
  final String? noteLabel;
  final String? notePreview;
  final Color? noteAccent;
  final bool manageExpanded;
  final bool isSharingEntranceInfo;
  final VoidCallback? onTap;
  final VoidCallback onToggleManage;
  final VoidCallback onOpenManage;
  final bool isInRoute;
  final bool isDeleting;
  final VoidCallback onNavigate;
  final VoidCallback onAddToRoute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(VanPlace place) onShareEntranceInfo;
  final Future<void> Function(VanPlace place) onPinCurrentLocation;
  final Stream<VanPinRequest?>? pinRequestStream;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onOpenSharedPin;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onUseReceivedPin;
  final Future<void> Function(VanPlace place, VanPinRequest request)
  onAdjustReceivedPin;
  final Future<void> Function(VanPlace place) onRequestExactPin;

  const _VanPlaceCard({
    super.key,
    required this.place,
    required this.locationLabel,
    required this.addressLabel,
    required this.coordinateLabel,
    this.onTap,
    this.routeBadgeLabel,
    this.noteLabel,
    this.notePreview,
    this.noteAccent,
    required this.manageExpanded,
    required this.isSharingEntranceInfo,
    required this.onToggleManage,
    required this.onOpenManage,
    required this.isInRoute,
    required this.isDeleting,
    required this.onNavigate,
    required this.onAddToRoute,
    required this.onEdit,
    required this.onDelete,
    required this.onShareEntranceInfo,
    required this.onPinCurrentLocation,
    this.pinRequestStream,
    required this.onOpenSharedPin,
    required this.onUseReceivedPin,
    required this.onAdjustReceivedPin,
    required this.onRequestExactPin,
  });

  @override
  Widget build(BuildContext context) {
    final isManageOpen = manageExpanded;
    debugPrint('Rendering manage for placeId=${place.id} isOpen=$isManageOpen');
    debugPrint(
      '[PinRequest] manage UI current user uid=${FirebaseAuth.instance.currentUser?.uid ?? ''} place.name=${place.name} place.id=${place.id} place.id.length=${place.id.length}',
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _VanGlassPanel(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: place.placeType.accent.withValues(alpha: 0.18),
                    border: Border.all(
                      color: place.placeType.accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(place.placeType.icon, color: Colors.white),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.8,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.3,
                          fontWeight: FontWeight.w700,
                          color: place.placeType.accent,
                        ),
                      ),
                      if (addressLabel.trim().isNotEmpty &&
                          addressLabel.trim() != locationLabel.trim()) ...[
                        const SizedBox(height: 4),
                        Text(
                          addressLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.0,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _VanInfoPill(
                      label: place.placeType.label,
                      accent: place.placeType.accent,
                    ),
                    if (routeBadgeLabel != null) ...[
                      const SizedBox(height: 4),
                      _VanInfoPill(
                        label: routeBadgeLabel!,
                        accent: const Color(0xFF58D0A4),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(height: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (pinRequestStream != null) ...[
              const SizedBox(height: 7),
              StreamBuilder<VanPinRequest?>(
                stream: pinRequestStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint(
                      '[PinRequest] Place chip stream error for ${place.id}: ${snapshot.error}',
                    );
                    return const SizedBox.shrink();
                  }

                  final request = snapshot.data;
                  if (request == null) {
                    return const SizedBox.shrink();
                  }

                  final isSavedPin = place.hasCoordinates;
                  final isPending =
                      request.status == VanPinRequestStatus.pending;
                  final isReceived =
                      request.status == VanPinRequestStatus.received;
                  final isNoteReceived =
                      request.status == VanPinRequestStatus.receivedNote;
                  final hasResponse = request.hasResponse;
                  final showReviewLine = hasResponse && !isSavedPin;
                  final chipLabel = isSavedPin
                      ? 'Exact pin saved'
                      : isPending
                      ? 'Pin requested'
                      : isNoteReceived
                      ? 'Note received'
                      : isReceived
                      ? 'Pin received'
                      : null;
                  final chipAccent = isSavedPin
                      ? const Color(0xFF58D0A4)
                      : isPending
                      ? const Color(0xFF4A7DFF)
                      : isNoteReceived
                      ? const Color(0xFFF8C76C)
                      : isReceived
                      ? const Color(0xFF58D0A4)
                      : const Color(0xFF7EA2FF);
                  final chipIcon = isSavedPin
                      ? Icons.check_circle_outline_rounded
                      : isPending
                      ? Icons.schedule_rounded
                      : isNoteReceived
                      ? Icons.note_alt_outlined
                      : isReceived
                      ? Icons.place_outlined
                      : Icons.info_outline_rounded;

                  if (chipLabel == null) {
                    debugPrint(
                      '[PinRequest] place=${place.id} no pin request chip to show',
                    );
                    return const SizedBox.shrink();
                  }

                  debugPrint(
                    '[PinRequest] place=${place.id} chip=$chipLabel responseLat=${request.responseLat != null} responseLng=${request.responseLng != null}',
                  );

                  final reviewText = isReceived && hasResponse
                      ? 'Pin received - tap to review'
                      : 'Pin received - review in Manage';

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpenManage,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _VanInlineStatusBadge(
                              label: chipLabel,
                              icon: chipIcon,
                              accent: chipAccent,
                            ),
                            if (showReviewLine) ...[
                              const SizedBox(height: 5),
                              Text(
                                reviewText,
                                style: TextStyle(
                                  fontSize: 11.4,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (notePreview != null && notePreview!.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              _VanCompactNoteCard(
                label: noteLabel ?? 'Note',
                value: notePreview!,
                accent: noteAccent,
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 7),
            Text(
              coordinateLabel,
              style: TextStyle(
                fontSize: 11.8,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 9),
            _VanActionRow(
              stackOnNarrow: true,
              stackedBreakpoint: 405,
              leading: _VanInlineButton(
                label: 'Navigate',
                icon: Icons.navigation_outlined,
                scaleLabelDown: true,
                onTap: onNavigate,
              ),
              trailing: isInRoute
                  ? const _VanInlineStatusBadge(
                      label: 'In Route',
                      icon: Icons.check_circle_outline_rounded,
                      accent: Color(0xFF58D0A4),
                    )
                  : _VanInlineButton(
                      label: 'Add to Route',
                      icon: Icons.route_outlined,
                      filled: true,
                      scaleLabelDown: true,
                      onTap: onAddToRoute,
                    ),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: _ManageToggleButton(
                expanded: manageExpanded,
                onTap: onToggleManage,
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeOutCubic,
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: manageExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 7),
                  const Text(
                    'Need the exact entrance?',
                    style: TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pinRequestStream != null)
                    StreamBuilder<VanPinRequest?>(
                      stream: pinRequestStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint(
                            '[PinRequest] Manage stream error for ${place.id}: ${snapshot.error}',
                          );
                          return const SizedBox.shrink();
                        }

                        final request = snapshot.data;
                        if (request == null) {
                          debugPrint(
                            '[PinRequest] place=${place.id} manage section rendered with no request',
                          );
                          return _VanCompactStatusCard(
                            title: 'No exact pin request yet',
                            body:
                                'Send a link if the entrance or bay is unclear.',
                            accent: const Color(0xFF7EA2FF),
                          );
                        }

                        final requestNote = request.responseNote.trim();
                        final hasSavedPin =
                            place.hasCoordinates ||
                            request.usedAsExactPin == true;
                        final hasCoords =
                            request.responseLat != null &&
                            request.responseLng != null;
                        final isReceived =
                            request.status == VanPinRequestStatus.received;
                        final isNoteRequest =
                            request.status == VanPinRequestStatus.receivedNote;
                        final isPending =
                            request.status == VanPinRequestStatus.pending &&
                            !request.isExpired;
                        final isExpired = request.isExpired;

                        debugPrint(
                          '[PinRequest] place=${place.id} manage request=${request.id} status=${request.status} responseLat=${request.responseLat != null} responseLng=${request.responseLng != null}',
                        );

                        final title = hasSavedPin
                            ? 'Exact pin already saved'
                            : isNoteRequest
                            ? 'Location note received'
                            : isReceived && hasCoords
                            ? 'Exact pin received'
                            : isExpired
                            ? 'Request expired'
                            : isPending
                            ? 'Exact pin request pending'
                            : 'Exact pin received';
                        final body = hasSavedPin
                            ? 'The received pin is already applied to this drop.'
                            : isNoteRequest
                            ? (requestNote.isNotEmpty
                                  ? requestNote
                                  : 'The customer/site sent a location note instead of coordinates.')
                            : isReceived && hasCoords
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
                            : hasCoords
                            ? const Color(0xFF58D0A4)
                            : const Color(0xFF4A7DFF);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _VanCompactStatusCard(
                              title: title,
                              body: body,
                              accent: accent,
                            ),
                            if (isNoteRequest && requestNote.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              _VanCompactNoteCard(
                                label: 'Location note',
                                value: requestNote,
                                accent: const Color(0xFFF8C76C),
                                maxLines: 3,
                              ),
                            ],
                            if (isReceived && hasCoords) ...[
                              const SizedBox(height: 7),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final request = snapshot.data;
                                    if (request == null) return;
                                    unawaited(onOpenSharedPin(place, request));
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF3155B7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text(
                                    'Open in Google Maps',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final request = snapshot.data;
                                    if (request == null) return;
                                    unawaited(onUseReceivedPin(place, request));
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2FBC88),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                                  label: const Text(
                                    'Use received pin',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final request = snapshot.data;
                                    if (request == null) return;
                                    unawaited(
                                      onAdjustReceivedPin(place, request),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Adjust / Set exact pin',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (isNoteRequest && requestNote.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final note = requestNote;
                                    if (note.isEmpty) return;
                                    await Clipboard.setData(
                                      ClipboardData(text: note),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text('Note copied.'),
                                        ),
                                      );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Copy note',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: _VanInlineButton(
                          label: 'Request exact pin',
                          icon: Icons.share_outlined,
                          toned: true,
                          accentColor: const Color(0xFF4A7DFF),
                          scaleLabelDown: true,
                          onTap: () {
                            unawaited(onRequestExactPin(place));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: _VanInlineButton(
                          label: 'Copy request link',
                          icon: Icons.copy_rounded,
                          toned: true,
                          accentColor: const Color(0xFF7EA2FF),
                          scaleLabelDown: true,
                          onTap: () {
                            unawaited(
                              copyVanLivePinRequestForPlace(
                                context,
                                place,
                              ).then((_) {}),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _VanCompactStatusCard(
                    title: 'At the drop now?',
                    body: 'Save this location as the exact entrance or bay.',
                    accent: const Color(0xFF58D0A4),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        unawaited(onPinCurrentLocation(place));
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2FBC88),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text(
                        'Pin current location',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (place.privateInfo.trim().isNotEmpty) ...[
                    _VanPrivateInfoCard(value: place.privateInfo.trim()),
                    const SizedBox(height: 8),
                  ],
                  _VanCommunityShareSection(
                    description: 'Private info is never shared.',
                    privacyText: '',
                  ),
                  const SizedBox(height: 8),
                  if (place.hasTrustedExactPin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _VanInlineButton(
                            label: 'Share entrance info',
                            icon: Icons.share_outlined,
                            toned: true,
                            accentColor: const Color(0xFF8FA6FF),
                            busy: isSharingEntranceInfo,
                            scaleLabelDown: true,
                            onTap: isSharingEntranceInfo
                                ? null
                                : () {
                                    unawaited(onShareEntranceInfo(place));
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                  ],
                  _VanActionRow(
                    stackOnNarrow: true,
                    stackedBreakpoint: 405,
                    leading: _VanInlineButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      scaleLabelDown: true,
                      onTap: onEdit,
                    ),
                    trailing: _VanInlineButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                      busy: isDeleting,
                      scaleLabelDown: true,
                      onTap: onDelete,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanCommunityShareSection extends StatelessWidget {
  final String description;
  final String privacyText;

  const _VanCommunityShareSection({
    required this.description,
    required this.privacyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: Color(0xFF8FA6FF)),
              SizedBox(width: 8),
              Text(
                'Help other drivers',
                style: TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.3,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          if (privacyText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              privacyText,
              style: TextStyle(
                fontSize: 11.4,
                height: 1.28,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanShareEntranceInfoDialog extends StatelessWidget {
  final VanPlace place;

  const _VanShareEntranceInfoDialog({required this.place});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: _VanGlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share entrance info?',
              style: TextStyle(
                fontSize: 17.2,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This will submit the entrance pin and useful access notes for review. Private info, key codes, phone numbers and personal notes will not be shared.',
              style: TextStyle(
                fontSize: 12.4,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.74),
              ),
            ),
            const SizedBox(height: 10),
            _VanCompactStatusCard(
              title: place.name,
              body: place.postcodeArea.trim().isNotEmpty
                  ? place.postcodeArea.trim()
                  : place.bestLocationLabel,
              accent: const Color(0xFF8FA6FF),
            ),
            const SizedBox(height: 14),
            _VanActionRow(
              stackOnNarrow: true,
              stackedBreakpoint: 405,
              leading: _VanInlineButton(
                label: 'Cancel',
                icon: Icons.close_rounded,
                scaleLabelDown: true,
                onTap: () => Navigator.of(context).pop(false),
              ),
              trailing: _VanInlineButton(
                label: 'Share for review',
                icon: Icons.share_outlined,
                filled: true,
                scaleLabelDown: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanEmergencyPinRequestSheet extends StatefulWidget {
  final Future<VanPinRequest?> Function(String phoneNumber, String? note)
  onSend;

  const _VanEmergencyPinRequestSheet({required this.onSend});

  @override
  State<_VanEmergencyPinRequestSheet> createState() =>
      _VanEmergencyPinRequestSheetState();
}

class _VanEmergencyPinRequestSheetState
    extends State<_VanEmergencyPinRequestSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _noteController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final request = await widget.onSend(
      _phoneController.text.trim(),
      _noteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });

    if (request != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: _VanGlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency pin request',
                  style: TextStyle(
                    fontSize: 16.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Send a one-time pin request without creating a drop yet.',
                  style: TextStyle(
                    fontSize: 12.4,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: null,
                  enableSuggestions: false,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Customer/site phone number',
                    hintText: 'Enter the contact number',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Phone number is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [],
                  enableSuggestions: false,
                  autocorrect: false,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Optional note/reference',
                    hintText:
                        'Damaged label, red pallet, booking ref, customer name, etc.',
                  ),
                ),
                const SizedBox(height: 14),
                _VanActionRow(
                  stackOnNarrow: true,
                  stackedBreakpoint: 405,
                  leading: _VanInlineButton(
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    scaleLabelDown: true,
                    onTap: _isSending
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  trailing: _VanInlineButton(
                    label: _isSending ? 'Sending...' : 'Send pin request',
                    icon: Icons.send_rounded,
                    filled: true,
                    scaleLabelDown: true,
                    busy: _isSending,
                    onTap: _isSending ? null : _send,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ManageToggleButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _VanInlineButton(
      label: expanded ? 'Hide Manage' : 'Manage',
      icon: expanded ? Icons.expand_less_rounded : Icons.more_horiz_rounded,
      scaleLabelDown: true,
      onTap: onTap,
    );
  }
}

class _VanCompactNoteCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  final int maxLines;

  const _VanCompactNoteCard({
    required this.label,
    required this.value,
    this.accent,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? const Color(0xFF7EA2FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: highlight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanPrivateInfoCard extends StatelessWidget {
  final String value;

  const _VanPrivateInfoCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0E1726).withValues(alpha: 0.78),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: const Color(0xFF9FB8FF).withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                'Private info',
                style: TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: const Color(0xFF9FB8FF).withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanCompactStatusCard extends StatelessWidget {
  final String title;
  final String body;
  final Color accent;

  const _VanCompactStatusCard({
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.32,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanActionRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final bool stackOnNarrow;
  final double stackedBreakpoint;

  const _VanActionRow({
    required this.leading,
    required this.trailing,
    this.stackOnNarrow = false,
    this.stackedBreakpoint = 390,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 390 ? 8.0 : 9.0;
        final shouldStack =
            stackOnNarrow && constraints.maxWidth < stackedBreakpoint;

        if (shouldStack) {
          return Column(
            children: [
              leading,
              SizedBox(height: gap),
              trailing,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: leading),
            SizedBox(width: gap),
            Expanded(child: trailing),
          ],
        );
      },
    );
  }
}

class _VanInlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool destructive;
  final bool toned;
  final bool busy;
  final IconData? icon;
  final Color? accentColor;
  final bool scaleLabelDown;

  const _VanInlineButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
    this.toned = false,
    this.busy = false,
    this.icon,
    this.accentColor,
    this.scaleLabelDown = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final accent =
        accentColor ??
        (destructive ? const Color(0xFFFF8A72) : const Color(0xFF4A7DFF));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: scaleLabelDown ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: filled
                ? accent.withValues(alpha: enabled ? 0.92 : 0.28)
                : toned
                ? accent.withValues(alpha: enabled ? 0.14 : 0.05)
                : Colors.white.withValues(alpha: enabled ? 0.07 : 0.04),
            border: Border.all(
              color: filled
                  ? accent.withValues(alpha: enabled ? 0.30 : 0.14)
                  : toned
                  ? accent.withValues(alpha: enabled ? 0.42 : 0.16)
                  : Colors.white.withValues(alpha: enabled ? 0.12 : 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (!busy && icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                SizedBox(width: scaleLabelDown ? 8 : 9),
              ],
              Flexible(
                child: scaleLabelDown
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w800,
                            color: enabled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                          color: enabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VanInlineStatusBadge extends StatelessWidget {
  const _VanInlineStatusBadge({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanInfoPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _VanInfoPill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.6,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 1),
        ),
      ),
    );
  }
}

class _VanGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _VanGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

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

class _VanSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _VanSectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.6,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}
