import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_note_utils.dart';
import '../models/van_pin_request.dart';
import '../models/van_place.dart';
import '../models/today_route_summary.dart';
import '../models/van_route.dart';
import '../models/van_route_template.dart';
import '../models/van_route_stop.dart';
import '../services/premium_route_summary_service.dart';
import '../services/van_invoice_reminder_service.dart';
import '../services/van_push_notification_service.dart';
import '../services/van_premium_service.dart';
import '../services/van_first_use_help_service.dart';
import '../services/van_pin_request_service.dart';
import '../services/van_navigation_service.dart';
import '../services/van_route_preview_service.dart';
import '../services/van_storage_service.dart';
import 'van_scan_drop_page.dart';
import 'driver_customer_reply_mock_page.dart';
import 'job_detail_page.dart';
import '../../../pages/profile_page.dart';
import 'business_hub_page.dart';
import 'van_add_drop_page.dart';
import '../widgets/van_current_job_sheet.dart';
import '../widgets/van_first_use_help_dialog.dart';
import '../widgets/van_mate_bottom_nav.dart';
import '../widgets/van_guide_dialog.dart';
import '../widgets/van_premium_gate_sheet.dart';
import 'van_route_templates_sheet.dart';
import 'van_home_page.dart';
import 'van_places_page.dart';
import 'van_map_page.dart';
import 'jobs_calendar_page.dart';
import 'van_incoming_requests_page.dart';
import 'van_invoice_history_page.dart';
import 'van_invoice_preview_page.dart';

part 'route_page.dart';
part 'today_page.dart';

enum VanTab { home, today, map, places, route }

const List<VanTab> _mainTabs = <VanTab>[
  VanTab.today,
  VanTab.map,
  VanTab.places,
  VanTab.route,
];

class VanFirebasePage extends StatefulWidget {
  const VanFirebasePage({super.key});

  @override
  State<VanFirebasePage> createState() => _VanFirebasePageState();
}

class _VanFirebasePageState extends State<VanFirebasePage>
    with WidgetsBindingObserver {
  final VanStorageService _storage = VanStorageService();
  final TextEditingController _placesSearchController = TextEditingController();
  final TextEditingController _routeNameController = TextEditingController();

  StreamSubscription<List<VanPlace>>? _placesSubscription;
  StreamSubscription<VanRoute?>? _routeSubscription;

  VanTab _selectedTab = VanTab.home;
  String? _currentUserId;
  String? _loadError;
  List<VanPlace> _savedPlaces = const <VanPlace>[];
  List<VanRouteStop> _routeDraftStops = const <VanRouteStop>[];
  VanRoute? _activeRoute;
  VanRouteAnchor? _routeStartAnchor;
  VanRouteAnchor? _routeEndAnchor;
  bool _placesLoaded = false;
  bool _isInitializing = true;
  bool _isSavingRoute = false;
  bool _routeDraftDirty = false;
  bool _updatingRouteName = false;
  bool _placesStreamStarted = false;
  bool _routeStreamStarted = false;
  bool _mapTabRoutePreviewEnabled = false;
  String? _placesLoadError;
  TodayRouteSummary? _routePreviewSummary;
  String? _routePreviewSummaryError;
  bool _routePreviewSummaryLoading = false;
  int _routePreviewSummaryRequestId = 0;
  String _todayRoutePreviewDebugSignature = '';
  DateTime? _lastExitBackPressAt;
  final List<_VanHelpPopupRequest> _helpPopupQueue = <_VanHelpPopupRequest>[];
  final Set<String> _queuedHelpPopupKeys = <String>{};
  bool _isProcessingHelpPopupQueue = false;
  int _routeNameInputCount = 0;
  int _routeBodyBuildCount = 0;
  int _placesResetNonce = 0;
  CameraPosition? _mapTabCameraPosition;
  LatLng? _mapTabSelectedPin;

  final Set<String> _busyStopIds = <String>{};
  final Set<String> _deletingPlaceIds = <String>{};
  final Map<String, Stream<VanPinRequest?>> _pinRequestStreamCache = {};

  String get _todayRouteDate =>
      VanStorageService.routeDateFromDate(DateTime.now());

  String get _defaultRouteName =>
      _storage.defaultRouteNameForDate(_todayRouteDate);

  String get _routeDraftName {
    final value = _routeNameController.text.trim();
    return value.isEmpty ? _defaultRouteName : value;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeNameController.addListener(_handleRouteNameChanged);
    VanMatePremiumService.instance.addListener(_handlePremiumChanged);
    _setRouteNameText(_defaultRouteName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      VanMatePushNotificationService.instance.registerOpenHandler(
        _handleNotificationOpen,
      );
      VanMatePushNotificationService.instance.registerForegroundHandler(
        _handleForegroundNotification,
      );
      VanInvoiceReminderService.instance.registerOpenHandler(
        _handleInvoiceReminderOpen,
      );
    });
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VanMatePushNotificationService.instance.clearOpenHandler();
    VanMatePushNotificationService.instance.clearForegroundHandler();
    VanInvoiceReminderService.instance.clearOpenHandler();
    VanMatePremiumService.instance.removeListener(_handlePremiumChanged);
    _placesSubscription?.cancel();
    _routeSubscription?.cancel();
    _placesSearchController.dispose();
    _routeNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());
    }
  }

  void _handleRouteNameChanged() {
    if (_updatingRouteName || !mounted) return;
    _routeNameInputCount++;
    debugPrint(
      '[Perf] Route name onChanged #$_routeNameInputCount length=${_routeNameController.text.trim().length}',
    );
    if (_routeDraftDirty) {
      return;
    }

    setState(() {
      _routeDraftDirty = true;
    });
  }

  void _handlePremiumChanged() {
    if (!mounted) {
      return;
    }

    if (_routePreviewSummaryLoading) {
      return;
    }

    Future<void>.delayed(Duration.zero, () {
      if (!mounted || _routePreviewSummaryLoading) {
        return;
      }
      unawaited(
        _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
      );
    });
  }

  void _handleNotificationOpen(VanMateExactPinNotificationPayload payload) {
    unawaited(_openNotificationPayload(payload));
  }

  void _handleForegroundNotification(
    VanMateExactPinNotificationPayload payload,
  ) {
    if (!payload.isBookingRequestNotification) {
      return;
    }
    unawaited(
      DriverReplyMockState.instance.refreshIncomingRequestById(
        requestId: payload.requestId,
        expectedOwnerUid: payload.ownerUid,
      ),
    );
  }

  Future<void> _handleInvoiceReminderOpen(
    VanInvoiceReminderOpenTarget target,
  ) async {
    await _openInvoiceReminderTarget(target);
  }

  Future<void> _handleAppResumed() async {
    await _refreshDriverJobsFromCloud(reason: 'resume');
    if (!mounted) {
      return;
    }
    await VanInvoiceReminderService.instance.runReminderCheck(
      invoices: DriverReplyMockState.instance.savedInvoiceHistory,
      onReminderSent: (jobKey, stageDays, sentAt) async {
        DriverReplyMockState.instance.markInvoiceReminderSentForJob(
          jobKey,
          stageDays: stageDays,
          sentAt: sentAt,
        );
      },
    );
  }

  Future<void> _openInvoiceReminderTarget(
    VanInvoiceReminderOpenTarget target,
  ) async {
    final jobKey = target.jobKey.trim();
    if (jobKey.isNotEmpty) {
      final draft = DriverReplyMockState.instance.invoiceForJob(jobKey);
      if (draft != null) {
        await openVanInvoicePreviewPage(context, draft);
        return;
      }
    }

    await openVanInvoiceHistoryPage(
      context,
      initialFilter: target.openUnpaidFilter
          ? VanInvoiceHistoryFilter.unpaid
          : VanInvoiceHistoryFilter.all,
    );
  }

  Future<void> _openNotificationPayload(
    VanMateExactPinNotificationPayload payload,
  ) async {
    if (payload.isBookingRequestNotification) {
      final requestId = payload.requestId.trim();
      final refreshedRequest = await DriverReplyMockState.instance
          .refreshIncomingRequestById(
            requestId: requestId,
            expectedOwnerUid: payload.ownerUid,
          );
      if (!mounted) {
        return;
      }
      final linkedJobId = refreshedRequest?.linkedJobId.trim() ?? '';
      final requestJobId = refreshedRequest?.jobId.trim() ?? '';
      final jobId = linkedJobId.isNotEmpty
          ? linkedJobId
          : requestJobId.isNotEmpty
          ? requestJobId
          : '';

      final freshJob = jobId.isNotEmpty
          ? DriverReplyMockState.instance.jobById(jobId)
          : null;
      if (freshJob != null) {
        await openDriverJobDetailMockPage(
          context,
          reply: freshJob,
          completed: freshJob.isCompletedJob,
        );
        return;
      }

      await openVanIncomingRequestsPage(context);
      return;
    }

    if (payload.isQuoteReplyNotification) {
      await _refreshDriverJobsFromCloud(reason: 'notification_tap');
      if (!mounted) {
        return;
      }

      final requestId = payload.requestId.trim();
      var jobId = payload.jobId.trim();
      if (jobId.isEmpty && requestId.isNotEmpty) {
        jobId =
            DriverReplyMockState.instance
                .jobByRequestId(requestId)
                ?.jobId
                .trim() ??
            '';
      }

      final freshJob = jobId.isNotEmpty
          ? DriverReplyMockState.instance.jobById(jobId)
          : null;
      if (freshJob != null) {
        await openDriverJobDetailMockPage(
          context,
          reply: freshJob,
          completed: freshJob.isCompletedJob,
        );
        return;
      }

      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const JobsCalendarPage()));
      return;
    }

    if (payload.isCustomerReplyNotification) {
      final requestId = payload.requestId.trim();
      if (requestId.isNotEmpty) {
        final refreshedRequest = await DriverReplyMockState.instance
            .refreshRequestFromCloud(requestId);
        if (!mounted) {
          return;
        }
        var jobId = payload.jobId.trim();
        if (jobId.isEmpty) {
          jobId = refreshedRequest?.jobId.trim().isNotEmpty == true
              ? refreshedRequest!.jobId.trim()
              : DriverReplyMockState.instance
                        .jobByRequestId(requestId)
                        ?.jobId
                        .trim() ??
                    '';
        }
        final freshJob = jobId.isNotEmpty
            ? DriverReplyMockState.instance.jobById(jobId)
            : null;
        if (freshJob != null) {
          await openDriverJobDetailMockPage(
            context,
            reply: freshJob,
            completed: freshJob.isCompletedJob,
          );
          return;
        }
      } else {
        await _refreshDriverJobsFromCloud(reason: 'notification_tap');
        if (!mounted) {
          return;
        }
        final jobId = payload.jobId.trim();
        final freshJob = jobId.isNotEmpty
            ? DriverReplyMockState.instance.jobById(jobId)
            : null;
        if (freshJob != null) {
          await openDriverJobDetailMockPage(
            context,
            reply: freshJob,
            completed: freshJob.isCompletedJob,
          );
          return;
        }
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const JobsCalendarPage()));
      return;
    }

    await _refreshDriverJobsFromCloud(reason: 'notification_tap');
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTab = VanTab.places;
    });
  }

  Future<void> _refreshDriverJobsFromCloud({required String reason}) async {
    try {
      debugPrint('[VanFirebase][Jobs] refresh start reason=$reason');
      await DriverReplyMockState.instance.refreshJobsFromCloud(
        forceServer: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {});
      debugPrint('[VanFirebase][Jobs] refresh complete reason=$reason');
    } catch (error, stackTrace) {
      debugPrint(
        '[VanFirebase][Jobs] refresh failed reason=$reason error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _logTodayRoutePreviewState({
    required VanRoute? route,
    required List<VanRouteStop> remainingStops,
    required VanRouteStop? currentStop,
    required VanRouteStop? nextStop,
    required int coordinateCount,
  }) {
    final routeId = route?.id.trim().isNotEmpty == true ? route!.id : 'none';
    final stopSignature = remainingStops
        .map(
          (stop) => [
            stop.routeOrder,
            stop.id,
            stop.name,
            stop.status.storageValue,
            stop.latitude?.toStringAsFixed(6) ?? 'null',
            stop.longitude?.toStringAsFixed(6) ?? 'null',
          ].join(':'),
        )
        .join('|');
    final signature =
        '$routeId|${route?.stops.length ?? 0}|${remainingStops.length}|$coordinateCount|'
        '${currentStop?.id ?? 'none'}|${nextStop?.id ?? 'none'}|$stopSignature';

    if (signature == _todayRoutePreviewDebugSignature) {
      return;
    }

    _todayRoutePreviewDebugSignature = signature;

    debugPrint(
      '[TodayRoute] active route id=$routeId totalStops=${route?.stops.length ?? 0} '
      'remainingStops=${remainingStops.length}',
    );
    for (var index = 0; index < remainingStops.length; index++) {
      final stop = remainingStops[index];
      final rawLat = stop.latitude?.toStringAsFixed(6) ?? 'null';
      final rawLng = stop.longitude?.toStringAsFixed(6) ?? 'null';
      debugPrint(
        '[TodayRoute] remaining[$index] name=${stop.name} id=${stop.id} '
        'postcode=${stop.postcodeArea} address=${stop.address} '
        'rawLat=$rawLat rawLng=$rawLng '
        'status=${stop.status.storageValue} routeOrder=${stop.routeOrder}',
      );
    }
    debugPrint(
      '[TodayRoute] current stop name=${currentStop?.name ?? 'none'} '
      'id=${currentStop?.id ?? 'none'}',
    );
    debugPrint(
      '[TodayRoute] next stop name=${nextStop?.name ?? 'none'} '
      'id=${nextStop?.id ?? 'none'}',
    );
    debugPrint('[TodayRoute] coordinate count for preview=$coordinateCount');
  }

  Future<void> _queueFirstUseHelpPopup({
    required String storageKey,
    required String title,
    required String body,
  }) async {
    final helpService = VanMateFirstUseHelpService.instance;
    await helpService.ensureLoaded();
    if (!mounted || await helpService.hasSeen(storageKey)) {
      return;
    }

    if (_queuedHelpPopupKeys.contains(storageKey)) {
      return;
    }

    _queuedHelpPopupKeys.add(storageKey);
    _helpPopupQueue.add(
      _VanHelpPopupRequest(storageKey: storageKey, title: title, body: body),
    );

    if (_isProcessingHelpPopupQueue) {
      return;
    }

    _isProcessingHelpPopupQueue = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_processHelpPopupQueue());
    });
  }

  Future<void> _processHelpPopupQueue() async {
    final helpService = VanMateFirstUseHelpService.instance;
    await helpService.ensureLoaded();
    if (!context.mounted) {
      return;
    }

    try {
      while (context.mounted && _helpPopupQueue.isNotEmpty) {
        final request = _helpPopupQueue.removeAt(0);
        _queuedHelpPopupKeys.remove(request.storageKey);

        if (await helpService.hasSeen(request.storageKey)) {
          continue;
        }

        if (!context.mounted) {
          return;
        }
        final dialogContext = context;
        await showVanMateFirstUseHelpDialog(
          dialogContext,
          storageKey: request.storageKey,
          title: request.title,
          body: request.body,
        );
      }
    } finally {
      if (context.mounted) {
        _isProcessingHelpPopupQueue = false;
        if (_helpPopupQueue.isNotEmpty) {
          _isProcessingHelpPopupQueue = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_processHelpPopupQueue());
          });
        }
      } else {
        _isProcessingHelpPopupQueue = false;
        _helpPopupQueue.clear();
        _queuedHelpPopupKeys.clear();
      }
    }
  }

  void _maybeShowTodayRouteHelp(VanRoute? route) {
    if (route == null ||
        (route.remainingStops.isEmpty && route.currentJob == null)) {
      return;
    }

    unawaited(
      _queueFirstUseHelpPopup(
        storageKey: VanMateFirstUseHelpKeys.seenRoutePreviewHelp,
        title: 'Today\'s route',
        body:
            'Work the current stop, navigate when ready, then mark it Done or Failed. Van Mate keeps the remaining stops in order.',
      ),
    );
  }

  void _maybeShowPremiumRouteSummaryHelp(TodayRouteSummary? summary) {
    if (summary == null || summary.hasError || summary.summaryHash.isEmpty) {
      return;
    }

    unawaited(
      _queueFirstUseHelpPopup(
        storageKey: VanMateFirstUseHelpKeys.seenPremiumRouteSummaryHelp,
        title: 'Premium route estimate',
        body:
            'Van Mate shows the remaining route distance, time, and estimated finish. Your navigation app still handles live traffic and current-drop ETA.',
      ),
    );
  }

  Stream<VanPinRequest?> _pinRequestStreamForDropId(String dropId) {
    final normalizedDropId = dropId.trim();
    if (normalizedDropId.isEmpty) {
      return const Stream<VanPinRequest?>.empty();
    }

    return _pinRequestStreamCache.putIfAbsent(
      normalizedDropId,
      () => VanPinRequestService.instance.watchLatestExactPinRequestForDropId(
        normalizedDropId,
      ),
    );
  }

  Future<void> _openSharedPinCoordinates({
    required String dropLabel,
    required double latitude,
    required double longitude,
    String? requestId,
  }) async {
    debugPrint(
      '[PinRequest] opening shared pin for $dropLabel request=${requestId ?? 'n/a'}',
    );

    final query = '$latitude,$longitude';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;
    _showError('Could not open Google Maps just now.');
  }

  Future<void> _openSharedPinFromPlace(
    VanPlace place,
    VanPinRequest request,
  ) async {
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    if (responseLat == null || responseLng == null) {
      _showError('That request does not have coordinates yet.');
      return;
    }

    await _openSharedPinCoordinates(
      dropLabel: place.name,
      latitude: responseLat,
      longitude: responseLng,
      requestId: request.id,
    );
  }

  Future<void> _openSharedPinFromStop(
    VanRouteStop stop,
    VanPinRequest request,
  ) async {
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    if (responseLat == null || responseLng == null) {
      _showError('That request does not have coordinates yet.');
      return;
    }

    await _openSharedPinCoordinates(
      dropLabel: stop.name,
      latitude: responseLat,
      longitude: responseLng,
      requestId: request.id,
    );
  }

  Future<void> _adjustReceivedExactPin(
    VanPlace place,
    VanPinRequest request,
  ) async {
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    if (responseLat == null || responseLng == null) {
      _showError('That exact pin does not have coordinates yet.');
      return;
    }

    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before drops can save.');
      return;
    }

    debugPrint(
      '[PinRequest] adjusting received pin for ${place.id} request=${request.id}',
    );

    final receivedPin = LatLng(responseLat, responseLng);

    final pickerResult = await Navigator.of(context).push<VanMapPageResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VanMapPage(
          places: List<VanPlace>.from(_savedPlaces),
          initialCameraPosition: CameraPosition(
            target: receivedPin,
            zoom: 16.0,
          ),
          initialSelectedPin: receivedPin,
          selectedPinActionLabel: 'Use This Pin',
          selectedPinMarkerLabel: 'Received pin',
          selectedPinHelperText: 'Use this pin for this drop.',
        ),
      ),
    );
    if (!mounted || pickerResult == null || !pickerResult.useSelectedPin) {
      return;
    }

    final selectedPin = pickerResult.selectedPin;
    if (selectedPin == null) {
      return;
    }

    final result = await _openPlaceEditor(
      existingPlace: place,
      initialSelectedPin: selectedPin,
    );
    if (!mounted || result == null) {
      return;
    }

    try {
      await VanPinRequestService.instance.markUsedAsExactPin(request.id);
    } catch (error, stackTrace) {
      debugPrint('Exact pin request mark-used failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      _showError('Exact pin saved, but request could not be marked used.');
      return;
    }

    if (!mounted) {
      return;
    }

    debugPrint(
      '[PinRequest] adjusted pin saved for ${place.id} request=${request.id}',
    );
    _showSuccess('Exact pin saved.');
  }

  Future<void> _createDropFromEmergencyPinRequest(VanPinRequest request) async {
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    final responseNote = request.responseNote.trim();
    final hasCoordinates = responseLat != null && responseLng != null;

    final result = await _openPlaceEditor(
      initialSelectedPin: hasCoordinates
          ? LatLng(responseLat, responseLng)
          : null,
      initialDeliveryNote: responseNote.isNotEmpty ? responseNote : null,
      allowMissingExactPin: !hasCoordinates,
    );
    if (!mounted || result == null) {
      return;
    }

    try {
      await VanPinRequestService.instance.markEmergencyRequestLinkedToDrop(
        request.id,
        linkedDropId: result.id,
      );
    } catch (error, stackTrace) {
      debugPrint('Emergency request link update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }

      _showError('Drop saved, but the request could not be linked.');
    }
  }

  Future<void> _archiveEmergencyPinRequest(VanPinRequest request) async {
    try {
      await VanPinRequestService.instance.archiveRequest(request.id);
      if (!mounted) {
        return;
      }
      _showSuccess('Emergency location request deleted from the list.');
    } catch (error, stackTrace) {
      debugPrint('Emergency request archive failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      _showError('Could not delete the request just now.');
    }
  }

  Future<void> _useReceivedExactPinForStop(
    VanRouteStop stop,
    VanPinRequest request,
  ) async {
    final place = _findPlaceById(stop.placeId);
    if (place == null) {
      _showError('Could not find the saved drop for this stop.');
      return;
    }

    await _useReceivedExactPin(place, request);
  }

  Future<void> _adjustReceivedExactPinForStop(
    VanRouteStop stop,
    VanPinRequest request,
  ) async {
    final place = _findPlaceById(stop.placeId);
    if (place == null) {
      _showError('Could not find the saved drop for this stop.');
      return;
    }

    await _adjustReceivedExactPin(place, request);
  }

  void _setRouteNameText(String value) {
    _updatingRouteName = true;
    _routeNameController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _updatingRouteName = false;
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _loadError = null;
        _placesLoadError = null;
        _placesLoaded = false;
      });
    }

    try {
      final uid = await _storage.ensureCurrentUid(source: 'van_mate.page');
      if (!mounted) return;

      debugPrint(
        '[PlacesLoad] init auth uid=${uid ?? 'null'} currentUser=${FirebaseAuth.instance.currentUser?.uid ?? 'null'}',
      );

      if (uid == null) {
        debugPrint('[PlacesLoad] auth uid missing; placing error state');
        setState(() {
          _isInitializing = false;
          _loadError =
              'Van Mate could not start its Firebase session right now.';
          _placesLoadError =
              'Van Mate could not start its Firebase session right now.';
          _placesLoaded = true;
        });
        return;
      }

      _currentUserId = uid;

      await _placesSubscription?.cancel();
      await _routeSubscription?.cancel();
      if (!mounted) return;

      _placesSubscription = _storage
          .watchPlaces(ownerId: uid)
          .listen(
            _handlePlacesStream,
            onError: (error, stackTrace) {
              debugPrint(
                '[PlacesLoad] Firestore error from places stream: $error',
              );
              debugPrintStack(stackTrace: stackTrace);
              if (!mounted) return;
              setState(() {
                _placesLoadError = error.toString();
                _placesLoaded = true;
                _isInitializing = false;
              });
            },
          );
      if (mounted) {
        setState(() {
          _placesStreamStarted = true;
        });
        debugPrint('[PlacesLoad] places stream started');
      }

      _routeSubscription = _storage
          .watchActiveRouteForDate(ownerId: uid, routeDate: _todayRouteDate)
          .listen(
            _handleRouteStream,
            onError: (error, stackTrace) {
              debugPrint(
                '[PlacesLoad] Firestore error from route stream: $error',
              );
              debugPrintStack(stackTrace: stackTrace);
              if (!mounted) return;
              setState(() {
                _isInitializing = false;
              });
            },
          );
      if (mounted) {
        setState(() {
          _routeStreamStarted = true;
        });
        debugPrint('[PlacesLoad] route stream started');
      }

      setState(() {
        _isInitializing = false;
        _loadError = null;
        if (_routeNameController.text.trim().isEmpty) {
          _setRouteNameText(_defaultRouteName);
        }
      });
    } catch (_) {
      if (!mounted) return;
      debugPrint('[PlacesLoad] init failed while connecting to Firebase');
      setState(() {
        _isInitializing = false;
        _loadError = 'Van Mate could not finish connecting to Firebase.';
        _placesLoadError = 'Van Mate could not finish connecting to Firebase.';
        _placesLoaded = true;
      });
    }
  }

  void _handlePlacesStream(List<VanPlace> places) {
    if (!mounted) return;
    debugPrint(
      '[PlacesLoad] places snapshot count=${places.length} currentUser=${_currentUserId ?? 'null'}',
    );
    setState(() {
      _savedPlaces = places;
      _placesLoaded = true;
      _placesLoadError = null;
      final activeRoute = _activeRoute;
      if (activeRoute != null) {
        _activeRoute = activeRoute.copyWith(
          stops: _syncStopsWithLatestPlaces(activeRoute.stops),
          startAnchor: _syncAnchorWithLatestPlace(activeRoute.startAnchor),
          endAnchor: _syncAnchorWithLatestPlace(activeRoute.endAnchor),
        );
      }
      _routeDraftStops = _syncStopsWithLatestPlaces(_routeDraftStops);
      _routeStartAnchor = _syncAnchorWithLatestPlace(_routeStartAnchor);
      _routeEndAnchor = _syncAnchorWithLatestPlace(_routeEndAnchor);
      _isInitializing = false;
      _loadError = null;
    });
  }

  void _handleRouteStream(VanRoute? route) {
    if (!mounted) return;
    VanRoute? syncedRoute;
    if (route != null) {
      syncedRoute = route.copyWith(
        stops: _syncStopsWithLatestPlaces(route.stops),
        startAnchor: _syncAnchorWithLatestPlace(route.startAnchor),
        endAnchor: _syncAnchorWithLatestPlace(route.endAnchor),
      );
    }
    if (syncedRoute != null) {}
    debugPrint(
      '[PlacesLoad] route snapshot loaded=${route != null} routeId=${route?.id ?? 'null'}',
    );
    setState(() {
      _activeRoute = syncedRoute;
      _isInitializing = false;
      _loadError = null;
      if (!_routeDraftDirty) {
        _routeDraftStops = syncedRoute?.stops ?? const [];
        _routeStartAnchor = syncedRoute?.startAnchor;
        _routeEndAnchor = syncedRoute?.endAnchor;
        _setRouteNameText(syncedRoute?.routeName ?? _defaultRouteName);
      } else {
        _routeDraftStops = _mergeDraftStopStatuses(
          _routeDraftStops,
          syncedRoute?.stops ?? const <VanRouteStop>[],
        );
      }
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
  }

  List<VanRouteStop> _syncStopsWithLatestPlaces(List<VanRouteStop> stops) {
    return VanStorageService.normalizeStops(
      stops
          .map((stop) {
            final latestPlace = _findPlaceById(stop.placeId);
            return latestPlace == null ? stop : stop.syncWithPlace(latestPlace);
          })
          .toList(growable: false),
    );
  }

  VanPlace? _findPlaceById(String placeId) {
    for (final place in _savedPlaces) {
      if (place.id == placeId) {
        return place;
      }
    }
    return null;
  }

  VanRouteAnchor? _syncAnchorWithLatestPlace(VanRouteAnchor? anchor) {
    if (anchor == null || anchor.type != VanRouteAnchorType.savedPlace) {
      return anchor;
    }

    final savedPlaceId = anchor.savedPlaceId.trim();
    if (savedPlaceId.isEmpty) {
      return anchor;
    }

    final latestPlace = _findPlaceById(savedPlaceId);
    if (latestPlace == null) {
      return anchor;
    }

    return anchor.copyWith(
      label: latestPlace.name,
      latitude: latestPlace.latitude,
      longitude: latestPlace.longitude,
    );
  }

  List<VanRouteStop> _mergeDraftStopStatuses(
    List<VanRouteStop> draftStops,
    List<VanRouteStop> persistedStops,
  ) {
    if (draftStops.isEmpty) {
      return const <VanRouteStop>[];
    }

    final persistedById = <String, VanRouteStop>{
      for (final stop in persistedStops) stop.id: stop,
    };

    return VanStorageService.normalizeStops(
      draftStops
          .map((draftStop) {
            final persistedStop = persistedById[draftStop.id];
            if (persistedStop == null) {
              return draftStop;
            }

            return draftStop.copyWith(
              status: persistedStop.status,
              completedAt: persistedStop.completedAt,
              failureNote: persistedStop.failureNote,
              podRequired: persistedStop.podRequired,
            );
          })
          .toList(growable: false),
    );
  }

  VanRoute _buildRouteSnapshotForStops(List<VanRouteStop> stops) {
    final baseRoute = _activeRoute;
    final now = DateTime.now();
    final ownerId =
        _currentUserId ??
        baseRoute?.ownerId ??
        baseRoute?.createdBy ??
        'anonymous';

    return VanRoute(
      id:
          baseRoute?.id ??
          _storage.routeIdForDate(ownerId: ownerId, routeDate: _todayRouteDate),
      routeDate: baseRoute?.routeDate ?? _todayRouteDate,
      routeName: _routeDraftName,
      createdAt: baseRoute?.createdAt ?? now,
      updatedAt: now,
      ownerId: ownerId,
      createdBy: ownerId,
      isActive: true,
      startAnchor: _routeStartAnchor,
      endAnchor: _routeEndAnchor,
      stops: VanStorageService.normalizeStops(stops),
    );
  }

  VanRoute? get _todayDisplayRoute {
    return _activeRoute;
  }

  Map<String, VanPlace> get _savedPlacesById {
    return <String, VanPlace>{
      for (final place in _savedPlaces) place.id: place,
    };
  }

  Future<void> _refreshRoutePreviewSummary({
    bool force = false,
    PremiumRouteSummaryMode summaryMode = PremiumRouteSummaryMode.start,
  }) async {
    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    if (!premiumService.isPremium) {
      if (_routePreviewSummary != null ||
          _routePreviewSummaryError != null ||
          _routePreviewSummaryLoading) {
        setState(() {
          _routePreviewSummary = null;
          _routePreviewSummaryError = null;
          _routePreviewSummaryLoading = false;
        });
      }
      return;
    }

    final route = _activeRoute;
    if (route == null) {
      if (_routePreviewSummary != null ||
          _routePreviewSummaryError != null ||
          _routePreviewSummaryLoading) {
        setState(() {
          _routePreviewSummary = null;
          _routePreviewSummaryError = null;
          _routePreviewSummaryLoading = false;
        });
      }
      return;
    }

    final remainingStops = route
        .getActiveOrderedStops()
        .where((stop) => stop.isQueued)
        .toList(growable: false);
    if (remainingStops.isEmpty) {
      if (_routePreviewSummary != null ||
          _routePreviewSummaryError != null ||
          _routePreviewSummaryLoading) {
        setState(() {
          _routePreviewSummary = null;
          _routePreviewSummaryError = null;
          _routePreviewSummaryLoading = false;
        });
      }
      return;
    }

    try {
      final summaryService = PremiumRouteSummaryService.instance;
      final summaryHash = summaryService.buildTodayRouteSummaryHash(
        route: route,
        remainingStops: remainingStops,
        placesById: _savedPlacesById,
      );

      if (!force && _routePreviewSummaryLoading) {
        final loadingHash = _routePreviewSummary?.summaryHash.trim() ?? '';
        if (loadingHash == summaryHash) {
          debugPrint(
            '[RouteSummary] refresh skipped mode=${summaryMode.name} hash=$summaryHash reason=already_loading',
          );
          return;
        }
      }

      final allowCacheShortcut =
          summaryMode != PremiumRouteSummaryMode.halfway ||
          route.hasHalfwayRefreshDone;

      if (!force && allowCacheShortcut) {
        final cachedSummary = route.premiumSummaryCacheIfMatches(summaryHash);
        if (cachedSummary != null) {
          if (_routePreviewSummary != cachedSummary ||
              _routePreviewSummaryError != null ||
              _routePreviewSummaryLoading) {
            setState(() {
              _routePreviewSummary = cachedSummary;
              _routePreviewSummaryError = null;
              _routePreviewSummaryLoading = false;
            });
          }
          return;
        }

        final previousSummary = _routePreviewSummary;
        if (summaryMode == PremiumRouteSummaryMode.start &&
            previousSummary != null) {
          final updatedSummary = summaryService
              .buildLocalSummaryAfterCurrentStopCompleted(
                currentSummary: previousSummary,
                route: route,
                remainingStops: remainingStops,
                placesById: _savedPlacesById,
              );
          if (updatedSummary != null) {
            if (_routePreviewSummary != updatedSummary ||
                _routePreviewSummaryError != null ||
                _routePreviewSummaryLoading) {
              setState(() {
                _routePreviewSummary = updatedSummary;
                _routePreviewSummaryError = null;
                _routePreviewSummaryLoading = false;
              });
            }

            unawaited(
              _storage.updatePremiumRouteSummaryCache(
                ownerId: route.ownerId,
                routeDate: route.routeDate,
                summary: updatedSummary,
              ),
            );
            return;
          }
        }
      }

      final requestId = ++_routePreviewSummaryRequestId;
      debugPrint(
        '[RouteSummary] refresh started mode=${summaryMode.name} force=$force hash=$summaryHash remaining=${remainingStops.length}',
      );

      setState(() {
        _routePreviewSummary = null;
        _routePreviewSummaryError = 'Route summary unavailable';
        _routePreviewSummaryLoading = true;
      });

      final summary = await summaryService.loadSummaryForRoute(
        route: route,
        remainingStops: remainingStops,
        placesById: _savedPlacesById,
        summaryMode: summaryMode,
        force: force,
      );
      if (!mounted || requestId != _routePreviewSummaryRequestId) {
        return;
      }

      if (summary == null) {
        setState(() {
          _routePreviewSummary = null;
          _routePreviewSummaryError = null;
          _routePreviewSummaryLoading = false;
        });
        return;
      }

      setState(() {
        _routePreviewSummary = summary;
        _routePreviewSummaryError = null;
        _routePreviewSummaryLoading = false;
      });
      debugPrint(
        '[RouteSummary] refresh success remaining=${summary.stopCount} duration=${summary.totalDurationSeconds} distance=${summary.totalDistanceMeters}',
      );
      _maybeShowPremiumRouteSummaryHelp(summary);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint('[RouteSummary] refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final errorMessage = error is TodayRouteSummaryException
          ? error.message
          : 'Route summary unavailable';
      setState(() {
        _routePreviewSummary = null;
        _routePreviewSummaryError = errorMessage;
        _routePreviewSummaryLoading = false;
      });
    }
  }

  Future<void> _applyPremiumRouteSummaryAfterStopStatusChange({
    required VanRoute savedRoute,
  }) async {
    final premiumService = PremiumRouteSummaryService.instance;
    final currentSummary = _routePreviewSummary;
    final route = savedRoute;
    final remainingStops = route
        .getActiveOrderedStops()
        .where((stop) => stop.isQueued)
        .toList(growable: false);
    final shouldRefreshHalfway = premiumService.shouldTriggerHalfwayRefresh(
      route,
    );

    if (!mounted || !VanMatePremiumService.instance.isPremium) {
      return;
    }

    if (currentSummary != null) {
      final updatedSummary = premiumService
          .buildLocalSummaryAfterCurrentStopCompleted(
            currentSummary: currentSummary,
            route: route,
            remainingStops: remainingStops,
            placesById: _savedPlacesById,
          );
      if (updatedSummary != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _routePreviewSummary = updatedSummary;
          _routePreviewSummaryError = null;
          _routePreviewSummaryLoading = false;
        });

        try {
          await _storage.updatePremiumRouteSummaryCache(
            ownerId: route.ownerId,
            routeDate: route.routeDate,
            summary: updatedSummary,
          );
        } catch (error, stackTrace) {
          debugPrint('[RouteSummary] local cache update failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }

        if (shouldRefreshHalfway) {
          unawaited(
            _refreshRoutePreviewSummary(
              summaryMode: PremiumRouteSummaryMode.halfway,
            ),
          );
        }

        return;
      }
    }

    unawaited(
      _refreshRoutePreviewSummary(
        summaryMode: shouldRefreshHalfway
            ? PremiumRouteSummaryMode.halfway
            : PremiumRouteSummaryMode.routeChanged,
      ),
    );
  }

  void _updateRouteAnchor({
    required bool isStart,
    required VanRouteAnchor? anchor,
  }) {
    setState(() {
      if (isStart) {
        _routeStartAnchor = anchor;
      } else {
        _routeEndAnchor = anchor;
      }
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
  }

  Future<VanPlace?> _openPlaceEditor({
    VanPlace? existingPlace,
    LatLng? initialSelectedPin,
    String? initialDeliveryNote,
    bool allowMissingExactPin = false,
  }) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before drops can save.');
      return null;
    }

    final result = await Navigator.of(context).push<VanAddDropPageResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VanAddDropPage(
          storage: _storage,
          currentUserId: uid,
          initialPlace: existingPlace,
          initialSelectedPin: initialSelectedPin,
          initialDeliveryNote: initialDeliveryNote,
          allowMissingExactPin: allowMissingExactPin,
        ),
      ),
    );
    if (!mounted || result == null) return null;

    setState(() {
      _savedPlaces = _upsertSavedPlace(_savedPlaces, result.place);
      _placesLoaded = true;
      _placesResetNonce++;
      _placesSearchController.clear();
      _selectedTab = VanTab.places;
    });
    _showSuccess(result.wasEdit ? 'Drop updated.' : 'Drop saved to Places.');
    return result.place;
  }

  Future<VanPlace?> _saveUpdatedPlace(VanPlace place) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before drops can save.');
      return null;
    }

    try {
      final result = await _storage.savePlace(
        place,
        checkForDuplicate: false,
        excludePlaceId: place.id,
      );
      if (!mounted || !result.didSave || result.place == null) {
        return null;
      }

      setState(() {
        _savedPlaces = _upsertSavedPlace(_savedPlaces, result.place!);
        _placesLoaded = true;
      });

      return result.place;
    } catch (error, stackTrace) {
      debugPrint('Manage place save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return null;
      }
      _showError('Could not save the drop changes right now.');
      return null;
    }
  }

  Future<void> _useReceivedExactPin(
    VanPlace place,
    VanPinRequest request,
  ) async {
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    if (responseLat == null || responseLng == null) {
      _showError('That exact pin does not have coordinates yet.');
      return;
    }

    final updatedPlace = place.copyWith(
      latitude: responseLat,
      longitude: responseLng,
      trustedExactPin: true,
      updatedAt: DateTime.now(),
    );

    try {
      final result = await _storage.savePlace(
        updatedPlace,
        checkForDuplicate: false,
        excludePlaceId: place.id,
      );
      if (!mounted) {
        return;
      }
      if (!result.didSave || result.place == null) {
        _showError('Exact pin save failed in Firebase.');
        return;
      }

      setState(() {
        _savedPlaces = _upsertSavedPlace(_savedPlaces, result.place!);
        _placesLoaded = true;
      });

      try {
        await VanPinRequestService.instance.markUsedAsExactPin(request.id);
      } catch (error, stackTrace) {
        debugPrint('Exact pin request mark-used failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (!mounted) {
          return;
        }

        _showError('Exact pin saved, but request could not be marked used.');
        return;
      }
      if (!mounted) {
        return;
      }

      _showSuccess('Exact pin saved.');
    } catch (error, stackTrace) {
      debugPrint('Exact pin save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showError('Exact pin save failed in Firebase.');
    }
  }

  Future<void> _openScanDropFlowExtracted() async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before Scan Drop can save.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    if (!premiumService.isPremium) {
      await showVanMatePremiumGate(
        context,
        featureName: 'Scan Drop OCR',
        headline: 'Scan Drop is Premium',
        message:
            'Scan a photo of a drop label or delivery note, review the editable fields, then add it to Route or save it in Places.',
        ctaLabel: 'Open Premium screen',
      );
      return;
    }

    final result = await Navigator.of(context).push<VanScanDropPageResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VanScanDropPage(storage: _storage, currentUserId: uid),
      ),
    );
    if (!mounted || result == null) return;

    setState(() {
      _savedPlaces = _upsertSavedPlace(_savedPlaces, result.place);
      _placesLoaded = true;
      _placesResetNonce++;
      _placesSearchController.clear();
    });

    if (result.addToRoute) {
      _addPlaceToRoute(result.place);
      return;
    }

    setState(() {
      _selectedTab = VanTab.places;
    });
    _showSuccess(
      result.wasDuplicate
          ? 'Drop already existed in Places.'
          : 'Drop saved to Places.',
    );
  }

  Future<void> _pickRouteAnchor({required bool isStart}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final anchorLabel = isStart ? 'Start' : 'End';

    final selectedAction = await showModalBottomSheet<_RouteAnchorAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102038),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.78;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.paddingOf(sheetContext).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select $anchorLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$anchorLabel stays fixed as a route anchor and does not become a delivery stop.',
                    style: TextStyle(
                      fontSize: 12.8,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _VanAnchorPickerTile(
                    icon: Icons.my_location_rounded,
                    title: 'Current Location',
                    subtitle:
                        'Use your live position as the $anchorLabel anchor',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_RouteAnchorAction.currentLocation),
                  ),
                  const SizedBox(height: 8),
                  _VanAnchorPickerTile(
                    icon: Icons.place_outlined,
                    title: 'Saved Place',
                    subtitle: 'Reuse a saved drop as the $anchorLabel anchor',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_RouteAnchorAction.savedPlace),
                  ),
                  const SizedBox(height: 8),
                  _VanAnchorPickerTile(
                    icon: Icons.map_outlined,
                    title: 'Custom Picked Place',
                    subtitle: 'Search or long press a custom point on the map',
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_RouteAnchorAction.customPickedPlace),
                  ),
                  if ((isStart ? _routeStartAnchor : _routeEndAnchor) !=
                      null) ...[
                    const SizedBox(height: 8),
                    _VanAnchorPickerTile(
                      icon: Icons.clear_rounded,
                      title: 'Clear Anchor',
                      subtitle: 'Remove this route anchor for now',
                      destructive: true,
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_RouteAnchorAction.clear),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedAction == null) {
      return;
    }

    switch (selectedAction) {
      case _RouteAnchorAction.currentLocation:
        await _setRouteAnchorToCurrentLocation(isStart: isStart);
        return;
      case _RouteAnchorAction.savedPlace:
        await _setRouteAnchorFromSavedPlace(isStart: isStart);
        return;
      case _RouteAnchorAction.customPickedPlace:
        await _setRouteAnchorFromCustomPicker(isStart: isStart);
        return;
      case _RouteAnchorAction.clear:
        _updateRouteAnchor(isStart: isStart, anchor: null);
        _showInfo('$anchorLabel anchor cleared.');
        return;
    }
  }

  Future<void> _setRouteAnchorToCurrentLocation({required bool isStart}) async {
    final anchorLabel = isStart ? 'Start' : 'End';

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _showError('Turn on location services to use Current Location.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission is needed to set $anchorLabel.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final label = await _reverseGeocodeAnchorLabel(
        latitude: position.latitude,
        longitude: position.longitude,
        fallbackLabel: 'Current Location',
      );

      _updateRouteAnchor(
        isStart: isStart,
        anchor: VanRouteAnchor(
          type: VanRouteAnchorType.currentLocation,
          label: label,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      _showInfo('$anchorLabel anchor set from current location.');
    } catch (_) {
      _showError('Could not read the current location right now.');
    }
  }

  Future<void> _setRouteAnchorFromSavedPlace({required bool isStart}) async {
    final anchorLabel = isStart ? 'Start' : 'End';
    if (_savedPlaces.isEmpty) {
      _showInfo('Save a drop in Places first, then reuse it as $anchorLabel.');
      return;
    }

    final selectedPlace = await showModalBottomSheet<VanPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102038),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.paddingOf(sheetContext).bottom + 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Place for $anchorLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _savedPlaces.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final place = _savedPlaces[index];
                        return _VanAnchorPickerTile(
                          icon: place.placeType.icon,
                          title: place.name,
                          subtitle: place.bestLocationLabel,
                          onTap: () => Navigator.of(sheetContext).pop(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selectedPlace == null) {
      return;
    }

    _updateRouteAnchor(
      isStart: isStart,
      anchor: VanRouteAnchor(
        type: VanRouteAnchorType.savedPlace,
        label: selectedPlace.name,
        latitude: selectedPlace.latitude,
        longitude: selectedPlace.longitude,
        savedPlaceId: selectedPlace.id,
      ),
    );
    _showInfo('$anchorLabel anchor set to ${selectedPlace.name}.');
  }

  Future<void> _setRouteAnchorFromCustomPicker({required bool isStart}) async {
    final anchorLabel = isStart ? 'Start' : 'End';
    final result = await Navigator.of(context).push<VanMapPageResult>(
      MaterialPageRoute<VanMapPageResult>(
        builder: (_) => VanMapPage(
          places: List<VanPlace>.from(_savedPlaces),
          initialCameraPosition:
              _mapTabCameraPosition ??
              _cameraPositionForAnchor(
                isStart ? _routeStartAnchor : _routeEndAnchor,
              ),
          initialSelectedPin: _anchorLatLng(
            isStart ? _routeStartAnchor : _routeEndAnchor,
          ),
          selectedPinActionLabel: 'Use as $anchorLabel',
        ),
      ),
    );

    if (!mounted || result == null || !result.useSelectedPin) {
      return;
    }

    setState(() {
      _mapTabCameraPosition = result.cameraPosition;
    });

    final selectedPin = result.selectedPin;
    if (selectedPin == null) {
      _showError('Pick a point on the map before using it as $anchorLabel.');
      return;
    }

    final label = await _reverseGeocodeAnchorLabel(
      latitude: selectedPin.latitude,
      longitude: selectedPin.longitude,
      fallbackLabel: '$anchorLabel Point',
    );

    _updateRouteAnchor(
      isStart: isStart,
      anchor: VanRouteAnchor(
        type: VanRouteAnchorType.customPlace,
        label: label,
        latitude: selectedPin.latitude,
        longitude: selectedPin.longitude,
      ),
    );
    _showInfo('$anchorLabel anchor picked from the map.');
  }

  LatLng? _anchorLatLng(VanRouteAnchor? anchor) {
    if (anchor == null || !anchor.hasCoordinates) {
      return null;
    }

    return LatLng(anchor.latitude!, anchor.longitude!);
  }

  CameraPosition? _cameraPositionForAnchor(VanRouteAnchor? anchor) {
    final latLng = _anchorLatLng(anchor);
    if (latLng == null) {
      return null;
    }

    return CameraPosition(target: latLng, zoom: 15.1);
  }

  Future<String> _reverseGeocodeAnchorLabel({
    required double latitude,
    required double longitude,
    required String fallbackLabel,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return fallbackLabel;
      }

      final placemark = placemarks.first;
      final parts =
          <String>[
                placemark.name ?? '',
                placemark.locality ?? '',
                placemark.postalCode ?? '',
              ]
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);

      if (parts.isEmpty) {
        return fallbackLabel;
      }

      return parts.join(', ');
    } catch (_) {
      return fallbackLabel;
    }
  }

  Future<void> _deletePlace(VanPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102038),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete saved drop?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Remove ${place.name} from van_places? Existing route copies stay until you remove or resave them.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDA6A54),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingPlaceIds.add(place.id);
    });

    try {
      await _storage.deletePlace(place);
      if (!mounted) return;
      setState(() {
        _savedPlaces = _savedPlaces
            .where((existing) => existing.id != place.id)
            .toList(growable: false);
      });
      _showSuccess('Drop deleted.');
    } catch (_) {
      if (!mounted) return;
      _showError('Drop delete failed in Firebase.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingPlaceIds.remove(place.id);
        });
      }
    }
  }

  void _addPlaceToRoute(VanPlace place) {
    if (_isPlaceInRouteDraft(place.id)) {
      _showInfo('${place.name} is already in today\'s route draft.');
      return;
    }

    setState(() {
      _routeDraftStops = VanStorageService.normalizeStops([
        ..._routeDraftStops,
        VanRouteStop.fromPlace(
          id: _storage.createStopId(),
          place: place,
          routeOrder: _routeDraftStops.length,
        ),
      ]);
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
    final routeCount = _routeDraftStops.length;
    _showInfo(
      '${place.name} added to route. $routeCount stop${routeCount == 1 ? '' : 's'} in today\'s draft.',
    );
  }

  void _removeDraftStop(VanRouteStop stop) {
    setState(() {
      _routeDraftStops = VanStorageService.normalizeStops(
        _routeDraftStops.where((item) => item.id != stop.id).toList(),
      );
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
  }

  void _moveDraftStop(VanRouteStop stop, int direction) {
    final currentIndex = _routeDraftStops.indexWhere(
      (item) => item.id == stop.id,
    );
    if (currentIndex < 0) return;

    final targetIndex = currentIndex + direction;
    if (targetIndex < 0 || targetIndex >= _routeDraftStops.length) return;

    final nextStops = List<VanRouteStop>.from(_routeDraftStops);
    final moving = nextStops.removeAt(currentIndex);
    nextStops.insert(targetIndex, moving);

    setState(() {
      _routeDraftStops = VanStorageService.normalizeStops(nextStops);
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
  }

  void _clearRouteDraft() {
    setState(() {
      _routeDraftStops = const <VanRouteStop>[];
      _routeStartAnchor = null;
      _routeEndAnchor = null;
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
    );
    _showInfo('Route draft, Start, and End anchors cleared.');
  }

  Future<void> _saveRouteAsTemplate() async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before route templates can save.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    if (!premiumService.canUseRouteTemplates) {
      await showVanMatePremiumGate(
        context,
        featureName: 'Route Templates',
        headline: 'Route Templates are Premium',
        message:
            'Save named repeat runs, load them later, and make small edits without changing the original template.',
        ctaLabel: 'Open Premium screen',
      );
      return;
    }

    if (_routeDraftStops.isEmpty) {
      _showInfo('Add at least one stop before saving a route template.');
      return;
    }

    final normalizedStops = VanStorageService.normalizeTemplateStops(
      _routeDraftStops,
    );
    if (!premiumService.canSaveRouteWithStopCount(normalizedStops.length)) {
      _showError(
        premiumService.routeSaveLimitMessage(stopCount: normalizedStops.length),
      );
      return;
    }

    final templateName = await _promptForRouteTemplateName(
      initialValue: _routeDraftName,
      title: 'Save as Template',
      helperText: 'Give this repeat run a name so you can load it again later.',
      confirmLabel: 'Save Template',
    );
    if (!mounted || templateName == null) {
      return;
    }

    try {
      await _storage.saveRouteTemplate(
        ownerId: uid,
        templateName: templateName,
        maxStopsAllowed: premiumService.maxDropsPerRoute,
        stops: normalizedStops,
        startAnchor: _routeStartAnchor,
        endAnchor: _routeEndAnchor,
      );
      if (!mounted) return;
      _showSuccess('Saved "$templateName" as a route template.');
    } on VanRouteStopLimitExceeded {
      if (!mounted) return;
      _showError(
        premiumService.routeSaveLimitMessage(stopCount: normalizedStops.length),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Route template save Firebase error: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showError(
        error.message?.trim().isNotEmpty == true
            ? 'Template save failed: ${error.message}'
            : 'Template save failed: ${error.code}',
      );
    } catch (error, stackTrace) {
      debugPrint('Route template save error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showError('Route template save failed in Firebase.');
    }
  }

  Future<void> _openRouteTemplates() async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before route templates can open.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    if (!premiumService.canUseRouteTemplates) {
      await showVanMatePremiumGate(
        context,
        featureName: 'Route Templates',
        headline: 'Route Templates are Premium',
        message:
            'Save named repeat runs, load them later, and make small edits without changing the original template.',
        ctaLabel: 'Open Premium screen',
      );
      return;
    }

    await showVanRouteTemplatesSheet(
      context,
      templatesStream: _storage.watchRouteTemplates(ownerId: uid),
      onLoadTemplate: _loadRouteTemplate,
      onRenameTemplate: _renameRouteTemplate,
      onDeleteTemplate: _deleteRouteTemplate,
    );
  }

  Future<void> _loadRouteTemplate(VanRouteTemplate template) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before route templates can load.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    final loadedStops = _buildWorkingStopsFromTemplate(template.stops);
    try {
      final savedRoute = await _storage.saveActiveRoute(
        ownerId: uid,
        routeDate: _todayRouteDate,
        routeName: template.name,
        maxStopsAllowed: premiumService.maxDropsPerRoute,
        startAnchor: template.startAnchor,
        endAnchor: template.endAnchor,
        stops: loadedStops,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routeNameController.value = TextEditingValue(
          text: savedRoute.routeName,
          selection: TextSelection.collapsed(
            offset: savedRoute.routeName.length,
          ),
        );
        _routeDraftStops = _syncStopsWithLatestPlaces(savedRoute.stops);
        _routeStartAnchor = _syncAnchorWithLatestPlace(savedRoute.startAnchor);
        _routeEndAnchor = _syncAnchorWithLatestPlace(savedRoute.endAnchor);
        _routeDraftDirty = false;
        _activeRoute = savedRoute;
      });
      unawaited(
        _refreshRoutePreviewSummary(
          summaryMode: PremiumRouteSummaryMode.routeChanged,
        ),
      );
      _showSuccess('Loaded "${template.name}" into today\'s route.');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Route template load Firebase error: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showError(
        error.message?.trim().isNotEmpty == true
            ? 'Template load failed: ${error.message}'
            : 'Template load failed: ${error.code}',
      );
    } catch (error, stackTrace) {
      debugPrint('Route template load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showError('Template load failed in Firebase.');
    }
  }

  Future<void> _renameRouteTemplate(VanRouteTemplate template) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before route templates can rename.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    if (!premiumService.canUseRouteTemplates) {
      await showVanMatePremiumGate(
        context,
        featureName: 'Route Templates',
        headline: 'Route Templates are Premium',
        message:
            'Save named repeat runs, load them later, and make small edits without changing the original template.',
        ctaLabel: 'Open Premium screen',
      );
      return;
    }

    final nextName = await _promptForRouteTemplateName(
      initialValue: template.name,
      title: 'Rename Template',
      helperText: 'Give this repeat run a new name.',
      confirmLabel: 'Rename Template',
    );
    if (!mounted || nextName == null) {
      return;
    }

    try {
      await _storage.updateRouteTemplateName(
        ownerId: uid,
        templateId: template.id,
        name: nextName,
      );
      if (!mounted) return;
      _showSuccess('Renamed template to "$nextName".');
    } catch (_) {
      if (!mounted) return;
      _showError('Route template rename failed in Firebase.');
    }
  }

  Future<void> _deleteRouteTemplate(VanRouteTemplate template) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before route templates can delete.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102038),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete route template?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Remove "${template.name}" from Route Templates? This will not affect saved routes.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDA6A54),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _storage.deleteRouteTemplate(ownerId: uid, templateId: template.id);
      if (!mounted) return;
      _showSuccess('Deleted "${template.name}".');
    } catch (_) {
      if (!mounted) return;
      _showError('Route template delete failed in Firebase.');
    }
  }

  List<VanRouteStop> _buildWorkingStopsFromTemplate(List<VanRouteStop> stops) {
    final normalizedStops = VanStorageService.normalizeTemplateStops(stops);
    return [
      for (final stop in normalizedStops)
        stop.copyWith(id: _storage.createStopId()),
    ];
  }

  Future<String?> _promptForRouteTemplateName({
    required String initialValue,
    required String title,
    required String helperText,
    required String confirmLabel,
  }) async {
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) {
        return _RouteTemplateNameDialog(
          initialValue: initialValue,
          title: title,
          helperText: helperText,
          confirmLabel: confirmLabel,
        );
      },
    );

    final trimmedResult = result?.trim() ?? '';
    return trimmedResult.isEmpty ? null : trimmedResult;
  }

  Future<void> _autoPlanRoute() async {
    final canUsePremium = await requireVanMatePremium(
      context,
      featureName: 'Smart Auto Plan',
      headline: 'Smart Auto Plan is Premium',
      message:
          'Free users can still build and save smaller routes manually. Upgrade to Premium for Smart Auto Plan and bigger saved routes.',
      ctaLabel: 'Open Premium screen',
    );
    if (!mounted || !canUsePremium) {
      return;
    }

    if (_routeDraftStops.length < 2) {
      _showInfo('Add at least 2 route stops to auto-plan.');
      return;
    }

    final plannedStopCount = _routeDraftStops
        .where((stop) => stop.hasCoordinates)
        .length;
    if (plannedStopCount < 2) {
      _showInfo('Need 2 exact pins to auto-plan.');
      return;
    }

    final planResult = _storage.autoPlanRoute(
      _routeDraftStops,
      startAnchor: _routeStartAnchor,
      endAnchor: _routeEndAnchor,
    );
    setState(() {
      _routeDraftStops = planResult.orderedStops;
      _activeRoute = _buildRouteSnapshotForStops(planResult.orderedStops);
      _routeDraftDirty = true;
    });
    unawaited(
      _refreshRoutePreviewSummary(
        summaryMode: PremiumRouteSummaryMode.routeChanged,
      ),
    );

    var successMessage = 'Route reordered.';
    if (planResult.manualStopCount > 0) {
      final stopWord = planResult.manualStopCount == 1 ? 'stop' : 'stops';
      final pinWord = planResult.manualStopCount == 1
          ? 'needs an exact pin'
          : 'need exact pins';
      successMessage =
          '$successMessage ${planResult.manualStopCount} $stopWord $pinWord.';
    }
    await _saveRoute(successMessage: successMessage);
  }

  Future<void> _saveRoute({String? successMessage}) async {
    final uid = _currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _showError('Van Mate needs Firebase before routes can save.');
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    try {
      final syncedStops = _syncStopsWithLatestPlaces(
        _mergeDraftStopStatuses(
          _routeDraftStops,
          _activeRoute?.stops ?? const <VanRouteStop>[],
        ),
      );

      if (!premiumService.canSaveRouteWithStopCount(syncedStops.length)) {
        await showVanMatePremiumGate(
          context,
          featureName: 'Route saving limit',
          headline: 'Route limit reached',
          message: premiumService.routeSaveLimitMessage(
            stopCount: syncedStops.length,
          ),
          ctaLabel: 'Open Premium screen',
        );
        return;
      }

      setState(() {
        _isSavingRoute = true;
      });

      final savedRoute = await _storage.saveActiveRoute(
        ownerId: uid,
        routeDate: _todayRouteDate,
        routeName: _routeDraftName,
        maxStopsAllowed: premiumService.maxDropsPerRoute,
        startAnchor: _routeStartAnchor,
        endAnchor: _routeEndAnchor,
        stops: syncedStops,
      );

      if (!mounted) return;
      setState(() {
        _activeRoute = savedRoute;
        _routeDraftStops = _syncStopsWithLatestPlaces(savedRoute.stops);
        _routeStartAnchor = _syncAnchorWithLatestPlace(savedRoute.startAnchor);
        _routeEndAnchor = _syncAnchorWithLatestPlace(savedRoute.endAnchor);
        _routeDraftDirty = false;
        _setRouteNameText(savedRoute.routeName);
      });
      unawaited(
        _refreshRoutePreviewSummary(
          summaryMode: PremiumRouteSummaryMode.routeChanged,
        ),
      );

      if (successMessage != null) {
        _showSuccess(successMessage);
      } else {
        _showSuccess(
          savedRoute.stops.isEmpty &&
                  savedRoute.startAnchor == null &&
                  savedRoute.endAnchor == null
              ? 'Today\'s route cleared.'
              : 'Today\'s route saved.',
        );
      }
    } on VanRouteStopLimitExceeded {
      if (!mounted) return;
      await showVanMatePremiumGate(
        context,
        featureName: 'Route saving limit',
        headline: 'Route limit reached',
        message: premiumService.routeSaveLimitMessage(
          stopCount: _routeDraftStops.length,
        ),
        ctaLabel: 'Open Premium screen',
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Route save failed in Firebase. Check connection and rules.');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingRoute = false;
        });
      }
    }
  }

  Future<void> _setStopStatus(
    VanRouteStop stop,
    VanRouteStopStatus status, {
    String failureNote = '',
  }) async {
    final uid = _currentUserId;
    final route = _activeRoute;
    if (uid == null || uid.trim().isEmpty || route == null) {
      _showError('There is no active Van Mate route to update yet.');
      return;
    }

    final previousRoute = route;
    final now = DateTime.now();
    final optimisticStops = route.stops
        .map((item) {
          if (item.id != stop.id) {
            return item;
          }

          switch (status) {
            case VanRouteStopStatus.queued:
              return item.copyWith(
                status: status,
                clearCompletedAt: true,
                failureNote: '',
              );
            case VanRouteStopStatus.done:
              return item.copyWith(
                status: status,
                completedAt: now,
                failureNote: '',
              );
            case VanRouteStopStatus.failed:
              return item.copyWith(
                status: status,
                completedAt: now,
                failureNote: failureNote.trim(),
              );
          }
        })
        .toList(growable: false);

    final optimisticRoute = route.copyWith(
      updatedAt: now,
      stops: VanStorageService.normalizeStops(optimisticStops),
    );

    setState(() {
      _busyStopIds.add(stop.id);
      _activeRoute = optimisticRoute;
      _routeDraftStops = _mergeDraftStopStatuses(
        _routeDraftStops,
        optimisticRoute.stops,
      );
    });

    try {
      final savedRoute = await _storage.updateStopStatus(
        ownerId: uid,
        routeDate: _todayRouteDate,
        stopId: stop.id,
        status: status,
        failureNote: failureNote,
      );

      if (!mounted) return;
      setState(() {
        _activeRoute = savedRoute;
        _routeDraftStops = _mergeDraftStopStatuses(
          _routeDraftStops,
          savedRoute.stops,
        );
      });
      unawaited(
        _applyPremiumRouteSummaryAfterStopStatusChange(savedRoute: savedRoute),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeRoute = previousRoute;
        _routeDraftStops = _mergeDraftStopStatuses(
          _routeDraftStops,
          previousRoute.stops,
        );
      });
      unawaited(
        _refreshRoutePreviewSummary(summaryMode: PremiumRouteSummaryMode.start),
      );
      _showError('Stop update failed in Firebase.');
    } finally {
      if (mounted) {
        setState(() {
          _busyStopIds.remove(stop.id);
        });
      }
    }
  }

  Future<void> _openCurrentJob(VanRouteStop stop) async {
    final result = await showVanCurrentJobSheet(
      context,
      stop: stop,
      onNavigate: () => _openStopInMaps(stop),
    );
    if (!mounted || result == null) return;

    switch (result.type) {
      case VanJobActionType.delivered:
        await _setStopStatus(stop, VanRouteStopStatus.done);
      case VanJobActionType.failed:
        await _setStopStatus(
          stop,
          VanRouteStopStatus.failed,
          failureNote: result.failureNote,
        );
    }
  }

  Future<void> _markFailedFromCard(VanRouteStop stop) async {
    final noteController = TextEditingController();
    final failureNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102038),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Mark ${stop.name} as failed?',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Optional failure note',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(noteController.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A72),
              ),
              child: const Text('Save Failed'),
            ),
          ],
        );
      },
    ).whenComplete(noteController.dispose);

    if (!mounted || failureNote == null) return;
    await _setStopStatus(
      stop,
      VanRouteStopStatus.failed,
      failureNote: failureNote,
    );
  }

  Future<void> _openPlaceInMaps(VanPlace place) async {
    await VanMateNavigationService.instance.openNavigationForPlace(
      context,
      place,
    );
  }

  Future<void> _openStopInMaps(VanRouteStop stop) async {
    debugPrint(
      '[TodayRoute] Navigate next stop URL: ${_todayRouteNavigationUriForStop(stop)}',
    );
    await VanMateNavigationService.instance.openNavigationForStop(
      context,
      stop,
    );
  }

  Future<void> _openFullScreenMap({
    VanRoute? route,
    bool routeViewOnly = false,
  }) async {
    final result = await Navigator.of(context).push<VanMapPageResult>(
      MaterialPageRoute<VanMapPageResult>(
        builder: (_) => VanMapPage(
          places: routeViewOnly
              ? const <VanPlace>[]
              : List<VanPlace>.from(_savedPlaces),
          activeRoute: routeViewOnly ? route : null,
          initialCameraPosition: routeViewOnly ? null : _mapTabCameraPosition,
          initialSelectedPin: routeViewOnly ? null : _mapTabSelectedPin,
          selectedPinActionLabel: routeViewOnly
              ? 'Use Selected Pin'
              : 'Add Drop',
          routeViewOnly: routeViewOnly,
          routeViewTitle: routeViewOnly ? _displayRouteName(route) : null,
          showCommunityPins: !routeViewOnly,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (routeViewOnly) {
      return;
    }

    setState(() {
      _mapTabCameraPosition = result.cameraPosition;
      _mapTabSelectedPin = result.selectedPin;
    });

    if (result.useSelectedPin && result.selectedPin != null) {
      await _openPlaceEditor(initialSelectedPin: result.selectedPin);
    }
  }

  void _showSuccess(String message) {
    _showMessage(message, backgroundColor: const Color(0xFF2FBC88));
  }

  void _showError(String message) {
    _showMessage(message, backgroundColor: const Color(0xFFB9504B));
  }

  void _showInfo(String message) {
    _showMessage(message, backgroundColor: const Color(0xFF3155B7));
  }

  void _showMessage(String message, {required Color backgroundColor}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewPaddingOf(context).bottom + 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: backgroundColor,
          content: Text(message),
        ),
      );
  }

  bool _isPlaceInRouteDraft(String placeId) {
    return _routeDraftStops.any((stop) => stop.placeId == placeId);
  }

  String _formatRouteDateLabel(String routeDate) {
    return formatRouteDateLabelExtracted(routeDate);
  }

  String _displayRouteName(VanRoute? route) {
    if (route == null) {
      return 'Route Preview';
    }

    final rawName = route.routeName.trim();
    if (rawName.isEmpty ||
        rawName == _storage.defaultRouteNameForDate(route.routeDate)) {
      return 'Route Preview';
    }

    final words = rawName.split(RegExp(r'\s+'));
    final normalizedWords = words
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          if (word != lower) {
            return word;
          }
          return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
        })
        .toList(growable: false);

    return normalizedWords.isEmpty
        ? 'Route Preview'
        : normalizedWords.join(' ');
  }

  String? _bestStopNotePreview(VanRouteStop stop) {
    final deliveryNote = cleanVanNoteText(
      stop.deliveryNote,
      postcode: stop.postcodeArea,
    );
    final warningNote = cleanVanNoteText(
      stop.warningNote,
      postcode: stop.postcodeArea,
    );

    if (stop.isFailed && stop.failureNote.trim().isNotEmpty) {
      return stop.failureNote.trim();
    }
    if (deliveryNote != null) {
      return deliveryNote;
    }
    if (warningNote != null) {
      return warningNote;
    }
    return null;
  }

  String _bestStopNoteLabel(VanRouteStop stop) {
    final deliveryNote = cleanVanNoteText(
      stop.deliveryNote,
      postcode: stop.postcodeArea,
    );
    final warningNote = cleanVanNoteText(
      stop.warningNote,
      postcode: stop.postcodeArea,
    );

    if (stop.isFailed && stop.failureNote.trim().isNotEmpty) {
      return 'Failure note';
    }
    if (deliveryNote != null) {
      return 'Delivery note';
    }
    if (warningNote != null) {
      return 'Warning';
    }
    return 'Note';
  }

  Color? _bestStopNoteAccent(VanRouteStop stop) {
    final deliveryNote = cleanVanNoteText(
      stop.deliveryNote,
      postcode: stop.postcodeArea,
    );
    final warningNote = cleanVanNoteText(
      stop.warningNote,
      postcode: stop.postcodeArea,
    );

    if (stop.isFailed && stop.failureNote.trim().isNotEmpty) {
      return const Color(0xFFFF8A72);
    }
    if (warningNote != null && deliveryNote == null) {
      return const Color(0xFFFFC38C);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleShellBackPressed());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            AppTheme.backgroundImage(),
            Container(color: Colors.black.withValues(alpha: 0.34)),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: _buildHeader(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: VanMateBottomNav(
                      items: _mainTabs
                          .map(
                            (tab) =>
                                VanMateBottomNavItem(label: _tabLabel(tab)),
                          )
                          .toList(growable: false),
                      selectedIndex: _mainTabs.contains(_selectedTab)
                          ? _mainTabs.indexOf(_selectedTab)
                          : null,
                      onSelected: (index) {
                        _switchTab(_mainTabs[index]);
                      },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: _VanGlassPanel(
                        padding: EdgeInsets.zero,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _buildTabBody(bottomInset),
                        ),
                      ),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 96),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab(VanTab.home),
                  behavior: HitTestBehavior.opaque,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Van Mate',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VanHeaderIconButton(
                    icon: Icons.help_outline_rounded,
                    onTap: () => showVanMateGuideDialog(context),
                  ),
                  const SizedBox(width: 10),
                  _VanHeaderIconButton(
                    icon: Icons.person_outline_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(
                            name: ProfilePage.routeName,
                          ),
                          builder: (_) => const ProfilePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _headerSubtitle(),
          style: TextStyle(
            fontSize: 13.4,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }

  String _tabLabel(VanTab tab) {
    switch (tab) {
      case VanTab.home:
        return 'Home';
      case VanTab.today:
        return 'Today';
      case VanTab.map:
        return 'Map';
      case VanTab.places:
        return 'Places';
      case VanTab.route:
        return 'Route';
    }
  }

  Widget _buildTabBody(double bottomInset) {
    debugPrint(
      '[PlacesLoad] build tab=${_selectedTab.name} authUid=${_currentUserId ?? 'null'} initializing=$_isInitializing placesLoaded=$_placesLoaded placesCount=${_savedPlaces.length} routeLoaded=$_routeStreamStarted placesStreamStarted=$_placesStreamStarted loadError=${_loadError != null} placesError=${_placesLoadError != null}',
    );
    if (_selectedTab == VanTab.home) {
      return VanHomePage(
        isLoading:
            _isInitializing && _savedPlaces.isEmpty && _activeRoute == null,
        loadError: _loadError,
        onRetry: _initialize,
        onOpenCalendar: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const JobsCalendarPage()));
        },
        onOpenBusinessHub: () {
          unawaited(openVanBusinessHubPage(context));
        },
      );
    }

    if (_selectedTab == VanTab.places) {
      return VanPlacesTabPage(
        places: _savedPlaces,
        placesLoaded: _placesLoaded,
        routeDraftStops: _routeDraftStops,
        searchController: _placesSearchController,
        deletingPlaceIds: _deletingPlaceIds,
        onScanDrop: _openScanDropFlowExtracted,
        onAddDrop: () => _openPlaceEditor(),
        onOpenPlaceEditor: (place) => _openPlaceEditor(existingPlace: place),
        onOpenPlaceInMaps: _openPlaceInMaps,
        onAddPlaceToRoute: _addPlaceToRoute,
        onDeletePlace: _deletePlace,
        onSavePlaceChanges: _saveUpdatedPlace,
        onOpenSharedPin: _openSharedPinFromPlace,
        onUseReceivedPin: _useReceivedExactPin,
        onAdjustReceivedPin: _adjustReceivedExactPin,
        onCreateDropFromReceivedPin: _createDropFromEmergencyPinRequest,
        onArchiveEmergencyPinRequest: _archiveEmergencyPinRequest,
        onUnmatchedRequestsVisible: _maybeShowUnmatchedLocationsHelp,
        resetNonce: _placesResetNonce,
        loadError: _placesLoadError,
        onRetryLoad: _initialize,
      );
    }

    if (_isInitializing && _savedPlaces.isEmpty && _activeRoute == null) {
      return _VanLoadingBody(key: ValueKey(_selectedTab.name));
    }

    if (_loadError != null && _savedPlaces.isEmpty && _activeRoute == null) {
      return _VanMessageBody(
        key: ValueKey(_selectedTab.name),
        title: 'Van Mate is not ready yet',
        message: _loadError!,
        actionLabel: 'Retry',
        onAction: _initialize,
      );
    }

    switch (_selectedTab) {
      case VanTab.today:
        return _VanTodayPage(state: this);
      case VanTab.home:
        return const SizedBox.shrink();
      case VanTab.map:
        final previewRoute = _mapTabRoutePreviewEnabled
            ? _todayDisplayRoute
            : null;
        return VanMapTabPage(
          places: _savedPlaces,
          cameraPosition: _mapTabCameraPosition,
          selectedPin: _mapTabSelectedPin,
          activeRoute: previewRoute,
          onOpenFullScreenMap: () => _openFullScreenMap(
            route: previewRoute,
            routeViewOnly: previewRoute != null,
          ),
        );
      case VanTab.route:
        return _VanRoutePage(state: this);
      case VanTab.places:
        return const SizedBox.shrink();
    }
  }

  List<VanPlace> _upsertSavedPlace(List<VanPlace> places, VanPlace place) {
    final nextPlaces = <VanPlace>[
      place,
      for (final existing in places)
        if (existing.id != place.id) existing,
    ];

    nextPlaces.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return nextPlaces;
  }

  void _switchTab(VanTab tab) {
    setState(() {
      _selectedTab = tab;
      if (tab != VanTab.map) {
        _mapTabRoutePreviewEnabled = false;
      }
    });
  }

  bool get _isOnOverviewHomeShellTab => _selectedTab == VanTab.home;

  Future<void> _handleShellBackPressed() async {
    if (!_isOnOverviewHomeShellTab) {
      _switchTab(VanTab.home);
      return;
    }

    final now = DateTime.now();
    final lastPressedAt = _lastExitBackPressAt;
    final shouldExit =
        lastPressedAt != null &&
        now.difference(lastPressedAt) <= const Duration(seconds: 2);

    if (shouldExit) {
      await SystemNavigator.pop();
      return;
    }

    _lastExitBackPressAt = now;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openRouteInGoogleMapsFromToday() async {
    final route = _todayDisplayRoute;
    if (route == null) {
      _showInfo('Build or open a route first.');
      return;
    }

    final result = _buildTodayRoutePreviewDirectionsResult(route);
    debugPrint(
      '[TodayRoute] Open route in Google Maps URL: ${result.uri?.toString() ?? 'null'}',
    );
    if (!result.hasUri) {
      _showInfo('No remaining route can be opened in Google Maps yet.');
      return;
    }

    if (result.isTruncated) {
      _showInfo(
        'Google Maps may only show part of large routes. Use Navigate next stop for the full route.',
      );
    }

    final launched = await launchUrl(
      result.uri!,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) {
      return;
    }
    _showError('Could not open Google Maps just now.');
  }

  VanGoogleMapsDirectionsLaunchResult _buildTodayRoutePreviewDirectionsResult(
    VanRoute route,
  ) {
    return buildVanGoogleMapsDirectionsResultForRemainingRoute(
      route,
      placeLookup: _savedPlacesById,
    );
  }

  Future<void> _maybeShowUnmatchedLocationsHelp(
    List<VanPinRequest> requests,
  ) async {
    if (requests.isEmpty) {
      return;
    }

    unawaited(
      _queueFirstUseHelpPopup(
        storageKey: VanMateFirstUseHelpKeys.seenUnmatchedLocationsHelp,
        title: 'Unmatched location received',
        body:
            'This pin is not linked to a saved drop yet. You can open it in Google Maps, create a drop from it, or dismiss it.',
      ),
    );
  }

  String _headerSubtitle() {
    switch (_selectedTab) {
      case VanTab.home:
        return 'Your driver overview at a glance';
      case VanTab.today:
        return 'Your delivery day at a glance';
      case VanTab.map:
        return 'Browse the live map and saved pins';
      case VanTab.places:
        return 'Manage saved drops and quick actions';
      case VanTab.route:
        return "Plan and refine today's route";
    }
  }
}

class _VanHelpPopupRequest {
  const _VanHelpPopupRequest({
    required this.storageKey,
    required this.title,
    required this.body,
  });

  final String storageKey;
  final String title;
  final String body;
}

class _VanLoadingBody extends StatelessWidget {
  const _VanLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: Color(0xFF4A7DFF),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading Van Mate...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _VanMessageBody extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _VanMessageBody({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _VanGlassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white70,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7DFF),
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
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
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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

class _VanSummaryGrid extends StatelessWidget {
  final List<_VanSummaryMetric> metrics;
  final bool muted;

  const _VanSummaryGrid({required this.metrics, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (metrics.length == 3 && constraints.maxWidth >= 330) {
          final maxWidth = constraints.maxWidth >= 620
              ? 560.0
              : constraints.maxWidth;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SizedBox(
                height: 90,
                child: Row(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      Expanded(
                        child: _VanMetricCard(
                          metric: metrics[index],
                          muted: muted,
                        ),
                      ),
                      if (index < metrics.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        final crossAxisCount = metrics.length == 4
            ? 2
            : constraints.maxWidth >= 540
            ? 4
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: crossAxisCount == 4 ? 94 : 96,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _VanMetricCard(metric: metric, muted: muted);
          },
        );
      },
    );
  }
}

class _VanMetricCard extends StatelessWidget {
  final _VanSummaryMetric metric;
  final bool muted;

  const _VanMetricCard({required this.metric, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: metric.accent.withValues(alpha: muted ? 0.14 : 0.20),
              border: Border.all(
                color: metric.accent.withValues(alpha: muted ? 0.24 : 0.32),
              ),
            ),
            child: Icon(
              metric.icon,
              color: Colors.white.withValues(alpha: muted ? 0.82 : 1),
              size: 16.5,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.4,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: muted ? 0.88 : 1),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metric.labelTop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.2,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: muted ? 0.60 : 0.70),
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
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.8,
            height: 1.45,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _VanEmptyCard extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _VanEmptyCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _VanGlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white70, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4A7DFF),
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanStatusBadge extends StatelessWidget {
  final VanRouteStopStatus status;
  final bool isCurrent;

  const _VanStatusBadge({required this.status, this.isCurrent = false});

  @override
  Widget build(BuildContext context) {
    late final Color accent;
    late final String label;

    if (isCurrent && status == VanRouteStopStatus.queued) {
      accent = const Color(0xFF4A7DFF);
      label = 'Current';
    } else {
      switch (status) {
        case VanRouteStopStatus.queued:
          accent = const Color(0xFF7EA2FF);
          label = 'Queued';
        case VanRouteStopStatus.done:
          accent = const Color(0xFF58D0A4);
          label = 'Done';
        case VanRouteStopStatus.failed:
          accent = const Color(0xFFFF8A72);
          label = 'Failed';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.6,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.4,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanActionGroupLabel extends StatelessWidget {
  final String label;
  final Color accent;

  const _VanActionGroupLabel({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right_rounded,
          size: 15,
          color: accent.withValues(alpha: 0.88),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: accent.withValues(alpha: 0.92),
          ),
        ),
      ],
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
        final gap = constraints.maxWidth < 390 ? 8.0 : 10.0;
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
          height: 46,
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
                            fontSize: 12.4,
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
                          fontSize: 12.4,
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

class _VanInfoPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _VanInfoPill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 1),
        ),
      ),
    );
  }
}

class _VanHeaderIconButton extends StatelessWidget {
  const _VanHeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
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
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}

class _VanSummaryMetric {
  final String labelTop;
  final String value;
  final IconData icon;
  final Color accent;

  const _VanSummaryMetric({
    required this.labelTop,
    required this.value,
    required this.icon,
    required this.accent,
  });
}

class _RouteTemplateNameDialog extends StatefulWidget {
  final String initialValue;
  final String title;
  final String helperText;
  final String confirmLabel;

  const _RouteTemplateNameDialog({
    required this.initialValue,
    required this.title,
    required this.helperText,
    required this.confirmLabel,
  });

  @override
  State<_RouteTemplateNameDialog> createState() =>
      _RouteTemplateNameDialogState();
}

class _RouteTemplateNameDialogState extends State<_RouteTemplateNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        _errorText = 'Enter a template name first.';
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pop(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF102038),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Template name',
          hintText: 'Monday Route',
          helperText: widget.helperText,
          errorText: _errorText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          helperStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            height: 1.35,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4A7DFF),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
