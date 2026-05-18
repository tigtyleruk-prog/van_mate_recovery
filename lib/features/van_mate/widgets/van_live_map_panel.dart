import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/van_route_marker_icons.dart';
import '../models/van_community_place.dart';
import '../models/van_place.dart';
import '../models/van_route.dart';
import '../models/van_route_stop.dart';
import '../services/van_community_places_service.dart';
import '../services/van_navigation_service.dart';
import '../services/van_premium_service.dart';
import '../services/van_route_preview_service.dart';
import '../services/places_autocomplete_controller.dart';
import '../services/places_search_service.dart';

class VanLiveMapPanel extends StatefulWidget {
  final List<VanPlace> places;
  final List<VanRouteStop> routeStops;
  final VanRouteAnchor? routeStartAnchor;
  final VanRouteAnchor? routeEndAnchor;
  final String? initialSelectedPlaceId;
  final CameraPosition? initialCameraPosition;
  final LatLng? initialSelectedPin;
  final bool routeViewOnly;
  final String? routeViewTitle;
  final bool allowPinPlacement;
  final bool showCommunityPins;
  final String? selectedPinMarkerLabel;
  final String? selectedPinHelperText;
  final bool showBackButton;
  final VoidCallback? onBack;
  final ValueChanged<VanPlace>? onOpenPlace;
  final ValueChanged<VanPlace>? onAddToRoute;
  final ValueChanged<LatLng?>? onSelectedPinChanged;
  final ValueChanged<CameraPosition>? onCameraPositionChanged;
  final VoidCallback? onUseSelectedPin;
  final String selectedPinActionLabel;
  final EdgeInsetsGeometry padding;
  final bool showNoResultsEmptyState;

  const VanLiveMapPanel({
    super.key,
    required this.places,
    this.routeStops = const <VanRouteStop>[],
    this.routeStartAnchor,
    this.routeEndAnchor,
    this.initialSelectedPlaceId,
    this.initialCameraPosition,
    this.initialSelectedPin,
    this.routeViewOnly = false,
    this.routeViewTitle,
    this.allowPinPlacement = false,
    this.showCommunityPins = false,
    this.selectedPinMarkerLabel,
    this.selectedPinHelperText,
    this.showBackButton = false,
    this.onBack,
    this.onOpenPlace,
    this.onAddToRoute,
    this.onSelectedPinChanged,
    this.onCameraPositionChanged,
    this.onUseSelectedPin,
    this.selectedPinActionLabel = 'Use Selected Pin',
    this.padding = EdgeInsets.zero,
    this.showNoResultsEmptyState = true,
  });

  @override
  State<VanLiveMapPanel> createState() => _VanLiveMapPanelState();
}

class _VanLiveMapPanelState extends State<VanLiveMapPanel> {
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(54.4, -3.0),
    zoom: 5.9,
  );
  static const Duration _searchDebounceDuration = Duration(milliseconds: 240);

  final TextEditingController _searchController = TextEditingController();
  late final PlacesAutocompleteController _autocompleteController;
  Timer? _searchDebounceTimer;

  late CameraPosition _cameraPosition;
  GoogleMapController? _mapController;
  bool _showFilters = false;
  bool _myLocationEnabled = false;
  MapType _mapType = MapType.normal;
  VanPlaceType? _selectedFilter;
  bool _showSavedDrops = true;
  VanPlace? _selectedPlace;
  LatLng? _selectedPin;
  PlacesSearchResult? _selectedGoogleResult;
  bool _hasFittedPreferredRoute = false;
  bool _showPinPlacementHint = false;
  bool _showCommunityPins = false;
  Map<String, BitmapDescriptor> _routeStopIcons =
      const <String, BitmapDescriptor>{};
  final ValueNotifier<String> _debouncedSearchQuery = ValueNotifier<String>('');
  Set<Marker> _cachedMarkers = const <Marker>{};
  String _cachedMarkersSignature = '';
  List<VanCommunityPlace> _communityPlaces = const <VanCommunityPlace>[];
  StreamSubscription<List<VanCommunityPlace>>? _communityPlacesSubscription;
  VanCommunityPlace? _selectedCommunityPlace;
  String? _busyCommunityPlaceId;
  Set<Polyline> _cachedPolylines = const <Polyline>{};
  String _cachedPolylinesSignature = '';
  VanRoadRoutePreviewResult? _roadRoutePreview;
  bool _roadRouteLoading = false;
  String _roadRouteSignature = '';
  int _roadRouteRequestId = 0;
  String _roadRouteErrorSignature = '';
  bool _premiumRoutePreviewEnabled = false;
  int _buildCount = 0;
  int _searchInputCount = 0;

  @override
  void initState() {
    super.initState();
    _autocompleteController = PlacesAutocompleteController(
      searchService: PlacesSearchService(),
    );
    _debouncedSearchQuery.value = _searchController.text.trim();
    _applyPreferredSelection(force: true);
    _cameraPosition = widget.initialCameraPosition ?? _preferredCameraPosition;
    _selectedPin = widget.initialSelectedPin;
    _showPinPlacementHint = widget.allowPinPlacement;
    _showCommunityPins = widget.showCommunityPins;
    VanMatePremiumService.instance.addListener(_handlePremiumChanged);
    unawaited(_syncPremiumRoutePreviewState());
    unawaited(_primeRouteStopIcons());
    unawaited(_syncCommunityPlacesSubscription());
  }

  @override
  void didUpdateWidget(covariant VanLiveMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final routeContextChanged =
        oldWidget.routeStops != widget.routeStops ||
        oldWidget.routeStartAnchor != widget.routeStartAnchor ||
        oldWidget.routeEndAnchor != widget.routeEndAnchor ||
        oldWidget.initialSelectedPlaceId != widget.initialSelectedPlaceId;
    final roadRouteChanged =
        _buildRoadRouteSignature(
          routeStops: widget.routeStops,
          routeStartAnchor: widget.routeStartAnchor,
          routeEndAnchor: widget.routeEndAnchor,
        ) !=
        _roadRouteSignature;

    if (!oldWidget.allowPinPlacement && widget.allowPinPlacement) {
      _showPinPlacementHint = true;
    } else if (oldWidget.allowPinPlacement && !widget.allowPinPlacement) {
      _showPinPlacementHint = false;
    }

    if (routeContextChanged) {
      _hasFittedPreferredRoute = false;
      _applyPreferredSelection(force: true);
      _cameraPosition =
          widget.initialCameraPosition ?? _preferredCameraPosition;
      _selectedPin = widget.initialSelectedPin;
      unawaited(_primeRouteStopIcons());

      if (_mapController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_fitVisibleRouteBoundsIfPossible());
        });
      }
    }

    if (roadRouteChanged) {
      unawaited(_refreshRoadRoutePreview());
    }

    if (oldWidget.showCommunityPins != widget.showCommunityPins) {
      _showCommunityPins = widget.showCommunityPins;
      unawaited(_syncCommunityPlacesSubscription());
    }
  }

  @override
  void dispose() {
    VanMatePremiumService.instance.removeListener(_handlePremiumChanged);
    _searchDebounceTimer?.cancel();
    _communityPlacesSubscription?.cancel();
    _autocompleteController.dispose();
    _searchController.dispose();
    _debouncedSearchQuery.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _applyPreferredSelection({bool force = false}) {
    final preferredPlaceId =
        widget.initialSelectedPlaceId ?? _preferredRoutePlaceId;
    if (preferredPlaceId == null) {
      return;
    }

    final matchingPlace = _findPlaceById(preferredPlaceId);
    if (matchingPlace == null) {
      return;
    }

    if (!force && _selectedPlace != null) {
      return;
    }

    _selectedPlace = matchingPlace;
  }

  VanPlace? _findPlaceById(String placeId) {
    for (final place in widget.places) {
      if (place.id == placeId) {
        return place;
      }
    }
    return null;
  }

  String? get _preferredRoutePlaceId {
    for (final stop in widget.routeStops) {
      if (stop.isQueued) {
        return stop.placeId;
      }
    }

    if (widget.routeStops.isNotEmpty) {
      return widget.routeStops.first.placeId;
    }

    return null;
  }

  List<VanPlace> get _filteredPlaces {
    if (widget.routeViewOnly || !_showSavedDrops) {
      return const <VanPlace>[];
    }

    final filtered = widget.places
        .where((place) {
          return _selectedFilter == null || place.placeType == _selectedFilter;
        })
        .toList(growable: false);

    final selectedId = _selectedPlace?.id;
    if (selectedId != null &&
        !filtered.any((place) => place.id == selectedId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedPlace = null;
        });
      });
    }

    return filtered;
  }

  List<VanPlace> get _savedSearchMatches {
    if (widget.routeViewOnly || _debouncedSearchQuery.value.isEmpty) {
      return const <VanPlace>[];
    }

    return _filteredPlaces
        .where((place) => place.matchesQuery(_debouncedSearchQuery.value))
        .toList(growable: false);
  }

  List<VanPlace> get _visiblePinnedPlaces {
    return _filteredPlaces
        .where((place) => place.hasCoordinates)
        .toList(growable: false);
  }

  bool get _communityLayerEnabled {
    return widget.showCommunityPins &&
        (!widget.routeViewOnly || !widget.showBackButton);
  }

  List<VanCommunityPlace> get _visibleCommunityPlaces {
    if (!_communityLayerEnabled || !_showCommunityPins) {
      return const <VanCommunityPlace>[];
    }

    return _communityPlaces
        .where((place) => place.hasExactPin)
        .toList(growable: false);
  }

  List<VanRouteStop> get _visibleRouteStops {
    final filtered = widget.routeStops
        .where((stop) {
          return widget.routeViewOnly ||
              _selectedFilter == null ||
              stop.placeType == _selectedFilter;
        })
        .toList(growable: false);
    return filtered;
  }

  List<VanRouteStop> get _visiblePinnedRouteStops {
    return _visibleRouteStops
        .where((stop) => stop.hasCoordinates)
        .toList(growable: false);
  }

  LatLng? get _routeStartAnchorLatLng {
    final anchor = widget.routeStartAnchor;
    if (!widget.routeViewOnly || anchor?.hasCoordinates != true) {
      return null;
    }

    return LatLng(anchor!.latitude!, anchor.longitude!);
  }

  LatLng? get _routeEndAnchorLatLng {
    final anchor = widget.routeEndAnchor;
    if (!widget.routeViewOnly || anchor?.hasCoordinates != true) {
      return null;
    }

    return LatLng(anchor!.latitude!, anchor.longitude!);
  }

  List<LatLng> get _routePreviewPolylinePoints {
    if (!widget.routeViewOnly) {
      return const <LatLng>[];
    }

    final roadPolylinePoints = _premiumRoutePreviewEnabled
        ? _roadRoutePreview?.polylinePoints
        : null;
    if (roadPolylinePoints != null && roadPolylinePoints.length >= 2) {
      return _dedupeSequentialLatLngs(roadPolylinePoints);
    }

    return const <LatLng>[];
  }

  Future<void> _syncPremiumRoutePreviewState() async {
    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    final premiumEnabled = premiumService.canUseRoadRoutePreview;
    if (_premiumRoutePreviewEnabled != premiumEnabled) {
      setState(() {
        _premiumRoutePreviewEnabled = premiumEnabled;
      });
    }
    if (!premiumEnabled) {
      if (_roadRoutePreview != null || _roadRouteLoading) {
        setState(() {
          _roadRouteRequestId++;
          _roadRoutePreview = null;
          _roadRouteLoading = false;
          _roadRouteSignature = '';
        });
      }
      return;
    }

    if (widget.routeViewOnly) {
      unawaited(_refreshRoadRoutePreview());
    }
  }

  Future<void> _syncCommunityPlacesSubscription() async {
    await _communityPlacesSubscription?.cancel();
    _communityPlacesSubscription = null;

    if (!_communityLayerEnabled) {
      if (!mounted) {
        return;
      }
      setState(() {
        _communityPlaces = const <VanCommunityPlace>[];
        _selectedCommunityPlace = null;
      });
      return;
    }

    _communityPlacesSubscription = VanCommunityPlacesService.instance
        .watchApprovedPlaces()
        .listen(
          _handleCommunityPlacesUpdated,
          onError: (error, stackTrace) {
            debugPrint('[CommunityMap] approved places stream failed: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!mounted) {
              return;
            }
            setState(() {
              _communityPlaces = const <VanCommunityPlace>[];
            });
          },
        );
  }

  void _handleCommunityPlacesUpdated(List<VanCommunityPlace> places) {
    if (!mounted) {
      return;
    }

    final selectedId = _selectedCommunityPlace?.id;
    VanCommunityPlace? matchingSelected;
    if (selectedId != null) {
      for (final place in places) {
        if (place.id == selectedId) {
          matchingSelected = place;
          break;
        }
      }
    }

    setState(() {
      _communityPlaces = places;
      _selectedCommunityPlace = matchingSelected;
    });
  }

  void _handlePremiumChanged() {
    if (!mounted) {
      return;
    }

    unawaited(_syncPremiumRoutePreviewState());
  }

  String _buildRoadRouteSignature({
    required List<VanRouteStop> routeStops,
    VanRouteAnchor? routeStartAnchor,
    VanRouteAnchor? routeEndAnchor,
  }) {
    return buildVanRoadRoutePreviewSignature(
      buildVanRoadRoutePreviewWaypointsFromPieces(
        routeStops: routeStops,
        routeStartAnchor: routeStartAnchor,
        routeEndAnchor: routeEndAnchor,
      ),
    );
  }

  Future<void> _refreshRoadRoutePreview() async {
    if (!widget.routeViewOnly) {
      return;
    }

    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    final premiumEnabled = premiumService.canUseRoadRoutePreview;
    if (_premiumRoutePreviewEnabled != premiumEnabled) {
      setState(() {
        _premiumRoutePreviewEnabled = premiumEnabled;
      });
    }

    if (!premiumEnabled) {
      debugPrint('[RoadPreview] routing API skipped for free user');
      if (_roadRoutePreview != null || _roadRouteLoading) {
        setState(() {
          _roadRoutePreview = null;
          _roadRouteLoading = false;
        });
      }
      return;
    }

    debugPrint('[RoadPreview] routing API allowed for premium user');

    final waypoints = buildVanRoadRoutePreviewWaypointsFromPieces(
      routeStops: _visibleRouteStops,
      routeStartAnchor: widget.routeStartAnchor,
      routeEndAnchor: widget.routeEndAnchor,
    );
    final signature = buildVanRoadRoutePreviewSignature(waypoints);
    if (signature.isEmpty || signature == _roadRouteSignature) {
      return;
    }

    final requestId = ++_roadRouteRequestId;
    _roadRouteSignature = signature;

    if (!mounted) {
      return;
    }

    setState(() {
      _roadRoutePreview = null;
      _roadRouteLoading = waypoints.length >= 2;
      if (waypoints.length < 2) {
        _roadRouteLoading = false;
      }
    });

    if (waypoints.length < 2) {
      return;
    }

    debugPrint(
      '[RoadPreview] route preview calculation started: '
      '${waypoints.length} waypoints',
    );

    try {
      final result = await VanRoadRoutePreviewService.instance
          .calculateRoadPreviewRouteForWaypoints(waypoints: waypoints);
      if (!mounted || requestId != _roadRouteRequestId) {
        return;
      }

      setState(() {
        _roadRoutePreview = result;
      });

      debugPrint(
        '[RoadPreview] route preview calculation success: '
        '${result.polylinePoints.length} polyline points',
      );

      unawaited(_fitVisibleRouteBoundsIfPossible(force: true));
    } catch (error) {
      if (!mounted || requestId != _roadRouteRequestId) {
        return;
      }

      final message = error is VanRoadRoutePreviewException
          ? error.message
          : 'Could not calculate road route preview.';

      setState(() {
        _roadRoutePreview = null;
      });

      debugPrint(
        '[RoadPreview] route calculation failed and fallback used: $message',
      );

      if (_roadRouteErrorSignature != signature) {
        _roadRouteErrorSignature = signature;
        _showRoadRouteMessage('$message Numbered stops are shown below.');
      }
    } finally {
      if (mounted && requestId == _roadRouteRequestId) {
        setState(() {
          _roadRouteLoading = false;
        });
      }
    }
  }

  void _showRoadRouteMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String get _routeViewSubtitle {
    if (_premiumRoutePreviewEnabled) {
      return 'Preview order only. Navigate opens your preferred navigation app.';
    }

    return 'Preview order only. Open route in Google Maps.';
  }

  CameraPosition get _preferredCameraPosition {
    if (_visiblePinnedRouteStops.isNotEmpty) {
      final stop = _preferredPinnedRouteStop;
      return CameraPosition(
        target: LatLng(stop.latitude!, stop.longitude!),
        zoom: 13.9,
      );
    }

    final startAnchor = _routeStartAnchorLatLng;
    if (startAnchor != null) {
      return CameraPosition(target: startAnchor, zoom: 13.9);
    }

    final endAnchor = _routeEndAnchorLatLng;
    if (endAnchor != null) {
      return CameraPosition(target: endAnchor, zoom: 13.9);
    }

    return _defaultCamera;
  }

  VanRouteStop get _preferredPinnedRouteStop {
    for (final stop in _visiblePinnedRouteStops) {
      if (stop.isQueued) {
        return stop;
      }
    }
    return _visiblePinnedRouteStops.first;
  }

  String? get _currentRouteStopId {
    for (final stop in _visibleRouteStops) {
      if (stop.isQueued) {
        return stop.id;
      }
    }
    return null;
  }

  Future<void> _focusPlace(
    VanPlace place, {
    bool clearSearch = true,
    bool moveCamera = true,
  }) async {
    _selectedCommunityPlace = null;
    _collapseFilters();
    FocusManager.instance.primaryFocus?.unfocus();
    if (clearSearch && _searchController.text.isNotEmpty) {
      _searchController.clear();
      _autocompleteController.clearSuggestions(
        onChanged: _refreshAutocompleteState,
        clearSession: true,
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedPlace = place;
      _selectedPin = null;
      _selectedGoogleResult = null;
    });
    widget.onSelectedPinChanged?.call(null);

    if (!place.hasCoordinates) {
      return;
    }

    if (!moveCamera) {
      return;
    }

    final nextCamera = CameraPosition(
      target: LatLng(place.latitude!, place.longitude!),
      zoom: 14.2,
    );
    _logCameraAction(
      'focusPlace',
      'placeId=${place.id} placeName=${place.name}',
    );
    _cameraPosition = nextCamera;
    widget.onCameraPositionChanged?.call(nextCamera);
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(nextCamera),
    );
  }

  Future<void> _focusCommunityPlace(
    VanCommunityPlace place, {
    bool clearSearch = true,
    bool moveCamera = true,
  }) async {
    _selectedPlace = null;
    _collapseFilters();
    FocusManager.instance.primaryFocus?.unfocus();
    if (clearSearch && _searchController.text.isNotEmpty) {
      _searchController.clear();
      _autocompleteController.clearSuggestions(
        onChanged: _refreshAutocompleteState,
        clearSession: true,
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedCommunityPlace = place;
      _selectedPin = null;
      _selectedGoogleResult = null;
    });
    widget.onSelectedPinChanged?.call(null);

    if (!place.hasExactPin) {
      return;
    }

    if (!moveCamera) {
      return;
    }

    final nextCamera = CameraPosition(
      target: LatLng(place.exactLat, place.exactLng),
      zoom: 14.2,
    );
    _logCameraAction(
      'focusCommunityPlace',
      'placeId=${place.id} placeName=${place.placeName}',
    );
    _cameraPosition = nextCamera;
    widget.onCameraPositionChanged?.call(nextCamera);
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(nextCamera),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    if (!_supportsGoogleMapsPlatform()) {
      _showMessage(
        'Live map controls work on supported mobile and web builds.',
      );
      return;
    }

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _showMessage('Location services are switched off on this device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is needed to jump to your position.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final nextCamera = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14.4,
      );
      _logCameraAction('centerOnCurrentLocation', 'requestedByUser=true');
      _cameraPosition = nextCamera;
      widget.onCameraPositionChanged?.call(nextCamera);
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(nextCamera),
      );

      if (!mounted) return;
      setState(() {
        _myLocationEnabled = true;
      });
    } catch (_) {
      _showMessage('Could not read the current location right now.');
    }
  }

  Future<void> _openNavigation(VanPlace place) async {
    await VanMateNavigationService.instance.openNavigationForPlace(
      context,
      place,
    );
  }

  Future<void> _openRouteInGoogleMaps() async {
    final routeUri = _buildRouteUri();
    if (routeUri == null) {
      _showMessage('No route could be opened in Google Maps right now.');
      return;
    }

    final launched = await launchUrl(
      routeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;
    _showMessage('Could not open Google Maps route right now.');
  }

  Uri? _buildRouteUri() {
    return buildVanGoogleMapsDirectionsUri(
      buildVanRoadRoutePreviewWaypointsFromPieces(
        routeStops: widget.routeStops,
        routeStartAnchor: widget.routeStartAnchor,
        routeEndAnchor: widget.routeEndAnchor,
      ),
    );
  }

  void _toggleFilters() {
    if (widget.routeViewOnly) {
      return;
    }
    _dismissPinPlacementHint();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _toggleCommunityPins() {
    if (!_communityLayerEnabled) {
      return;
    }

    _dismissPinPlacementHint();
    setState(() {
      _showCommunityPins = !_showCommunityPins;
      if (!_showCommunityPins) {
        _selectedCommunityPlace = null;
      }
    });
  }

  void _toggleSavedDrops() {
    if (widget.routeViewOnly) {
      return;
    }

    _dismissPinPlacementHint();
    setState(() {
      _showSavedDrops = !_showSavedDrops;
      if (!_showSavedDrops) {
        _selectedPlace = null;
      }
    });
  }

  void _collapseFilters() {
    if (!_showFilters || !mounted) {
      return;
    }

    setState(() {
      _showFilters = false;
    });
  }

  void _handleFilterChanged(VanPlaceType? type) {
    if (widget.routeViewOnly) {
      return;
    }
    _dismissPinPlacementHint();
    setState(() {
      _selectedFilter = type;
    });
  }

  Future<void> _toggleMapType() async {
    _dismissPinPlacementHint();
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
    _logCameraAction('toggleMapType', 'mapType=$_mapType');
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _restoreCameraToCurrentView();
  }

  Future<void> _openCommunityNavigation(VanCommunityPlace place) async {
    if (!place.hasExactPin) {
      _showMessage('This shared pin has no exact location yet.');
      return;
    }

    await VanMateNavigationService.instance.openNavigationForCoordinates(
      context,
      latitude: place.exactLat,
      longitude: place.exactLng,
      label: place.placeName,
    );
  }

  Future<void> _saveCommunityPlace(VanCommunityPlace place) async {
    if (_busyCommunityPlaceId != null) {
      return;
    }

    if (!place.hasExactPin) {
      _showMessage('This shared pin does not have an exact location yet.');
      return;
    }

    setState(() {
      _busyCommunityPlaceId = place.id;
    });

    try {
      await VanCommunityPlacesService.instance.saveToMyDrops(place);
      if (!mounted) {
        return;
      }
      _showMessage('Saved to your drops');
    } catch (error, stackTrace) {
      debugPrint('[CommunityMap] save failed placeId=${place.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      _showMessage('Could not save this shared pin right now.');
    } finally {
      if (mounted) {
        setState(() {
          if (_busyCommunityPlaceId == place.id) {
            _busyCommunityPlaceId = null;
          }
        });
      }
    }
  }

  Future<void> _reportCommunityPlace(VanCommunityPlace place) async {
    if (_busyCommunityPlaceId != null) {
      return;
    }

    setState(() {
      _busyCommunityPlaceId = place.id;
    });

    try {
      await VanCommunityPlacesService.instance.reportPlace(place);
      if (!mounted) {
        return;
      }
      _showMessage('Reported for review');
    } catch (error, stackTrace) {
      debugPrint('[CommunityMap] report failed placeId=${place.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      _showMessage('Could not report this shared pin right now.');
    } finally {
      if (mounted) {
        setState(() {
          if (_busyCommunityPlaceId == place.id) {
            _busyCommunityPlaceId = null;
          }
        });
      }
    }
  }

  Future<void> _restoreCameraToCurrentView() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    _logCameraAction('restoreCameraToCurrentView', 'source=state');
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition),
    );
  }

  void _dismissPinPlacementHint() {
    if (!_showPinPlacementHint || !mounted) {
      return;
    }

    setState(() {
      _showPinPlacementHint = false;
    });
  }

  void _handleMapLongPress(LatLng position) {
    if (!widget.allowPinPlacement || !mounted) {
      return;
    }

    _dismissPinPlacementHint();
    FocusManager.instance.primaryFocus?.unfocus();
    _logCameraAction(
      'handleMapLongPress',
      'lat=${position.latitude} lng=${position.longitude}',
    );
    setState(() {
      _selectedPin = position;
      _selectedPlace = null;
    });
    widget.onSelectedPinChanged?.call(position);
  }

  void _handleSearchChanged(String value) {
    _searchInputCount++;
    debugPrint(
      '[Perf] Live map search onChanged #$_searchInputCount queryLength=${value.trim().length}',
    );
    if (widget.routeViewOnly) {
      return;
    }

    _collapseFilters();
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, _syncSearchState);
  }

  void _syncSearchState() {
    if (!mounted || widget.routeViewOnly) {
      return;
    }

    final query = _searchController.text.trim();
    _debouncedSearchQuery.value = query;

    if (_autocompleteController.supportsAutocomplete) {
      _autocompleteController.handleQueryChanged(
        query,
        originLatitude: _initialSearchOrigin?.latitude,
        originLongitude: _initialSearchOrigin?.longitude,
        onChanged: _refreshAutocompleteState,
      );
    } else {
      _autocompleteController.clearSuggestions(
        onChanged: _refreshAutocompleteState,
        clearSession: true,
      );
    }

    setState(() {});
  }

  void _handleSearchTap() {
    if (widget.routeViewOnly) {
      return;
    }

    _dismissPinPlacementHint();
    _collapseFilters();
  }

  Future<void> _handleSearchSubmitted(String value) async {
    if (widget.routeViewOnly) {
      return;
    }

    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    _searchDebounceTimer?.cancel();
    _debouncedSearchQuery.value = query;
    _collapseFilters();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() {});
    }
    if (!_autocompleteController.supportsAutocomplete) {
      return;
    }

    await _autocompleteController.forceSearch(
      query,
      originLatitude: _initialSearchOrigin?.latitude,
      originLongitude: _initialSearchOrigin?.longitude,
      onChanged: _refreshAutocompleteState,
    );

    if (!mounted) return;
    final errorText = _autocompleteController.errorText;
    if (errorText != null && errorText.isNotEmpty) {
      _showMessage(errorText);
      return;
    }

    if (_autocompleteController.suggestions.isEmpty &&
        _savedSearchMatches.isEmpty) {
      _showMessage('No saved drops or Google places matched that search.');
    }
  }

  void _clearSearch() {
    if (widget.routeViewOnly) {
      return;
    }
    _collapseFilters();
    FocusManager.instance.primaryFocus?.unfocus();
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _debouncedSearchQuery.value = '';
    _autocompleteController.clearSuggestions(
      onChanged: _refreshAutocompleteState,
      clearSession: true,
    );
    if (!mounted) return;
    setState(() {});
  }

  void _refreshAutocompleteState() {
    if (!mounted) return;
    setState(() {});
  }

  LatLng? get _initialSearchOrigin {
    if (widget.routeViewOnly) {
      if (_visiblePinnedRouteStops.isNotEmpty) {
        final stop = _preferredPinnedRouteStop;
        return LatLng(stop.latitude!, stop.longitude!);
      }
      return null;
    }

    final selectedPlace = _selectedPlace;
    if (selectedPlace != null && selectedPlace.hasCoordinates) {
      return LatLng(selectedPlace.latitude!, selectedPlace.longitude!);
    }

    final googleResult = _selectedGoogleResult;
    if (googleResult != null && googleResult.isValid) {
      return LatLng(googleResult.latitude, googleResult.longitude);
    }

    if (_visiblePinnedRouteStops.isNotEmpty) {
      final stop = _preferredPinnedRouteStop;
      return LatLng(stop.latitude!, stop.longitude!);
    }

    if (_visiblePinnedPlaces.isNotEmpty) {
      final place = _visiblePinnedPlaces.first;
      return LatLng(place.latitude!, place.longitude!);
    }

    return null;
  }

  Future<void> _selectGoogleSuggestion(
    PlacesAutocompleteSuggestion suggestion,
  ) async {
    if (widget.routeViewOnly) {
      return;
    }

    _collapseFilters();
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await _autocompleteController.selectSuggestion(
      suggestion,
      onChanged: _refreshAutocompleteState,
    );
    if (!mounted) return;

    if (result == null || !result.isValid) {
      _showMessage(
        _autocompleteController.errorText ??
            'Google place details could not load right now.',
      );
      return;
    }

    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _debouncedSearchQuery.value = '';
    setState(() {
      _selectedPlace = null;
      _selectedPin = null;
      _selectedGoogleResult = result;
    });
    widget.onSelectedPinChanged?.call(null);

    final nextCamera = CameraPosition(
      target: LatLng(result.latitude, result.longitude),
      zoom: 15.0,
    );
    _cameraPosition = nextCamera;
    widget.onCameraPositionChanged?.call(nextCamera);
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(nextCamera),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _primeRouteStopIcons() async {
    final visibleStops = _visiblePinnedRouteStops;
    if (visibleStops.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _routeStopIcons = const <String, BitmapDescriptor>{};
      });
      return;
    }

    final currentRouteStopId = _currentRouteStopId;
    final iconEntries = await Future.wait<MapEntry<String, BitmapDescriptor>>(
      visibleStops.map((stop) async {
        final icon = await buildVanRouteStopMarkerIcon(
          stopNumber: stop.routeOrder + 1,
          status: stop.status,
          isCurrent: stop.id == currentRouteStopId,
        );
        return MapEntry<String, BitmapDescriptor>(stop.id, icon);
      }),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _routeStopIcons = <String, BitmapDescriptor>{
        for (final entry in iconEntries) entry.key: entry.value,
      };
    });
  }

  String _markerCacheSignature() {
    final buffer = StringBuffer()
      ..write(widget.routeViewOnly ? 'rv1' : 'rv0')
      ..write('|f:${_selectedFilter?.name ?? '-'}')
      ..write('|p:${_selectedPlace?.id ?? '-'}')
      ..write('|cp:${_selectedCommunityPlace?.id ?? '-'}')
      ..write('|gp:${_selectedGoogleResult?.placeId ?? '-'}')
      ..write(
        '|pin:${_selectedPin?.latitude.toStringAsFixed(5) ?? '-'}:${_selectedPin?.longitude.toStringAsFixed(5) ?? '-'}',
      )
      ..write(
        '|community:${widget.showCommunityPins ? 1 : 0}:${_showCommunityPins ? 1 : 0}',
      )
      ..write('|loc:${_myLocationEnabled ? 1 : 0}')
      ..write('|icons:');

    for (final entry in _routeStopIcons.entries) {
      buffer
        ..write(entry.key)
        ..write(':')
        ..write(entry.value.hashCode)
        ..write(';');
    }

    buffer.write('|stops:');
    for (final stop in _visiblePinnedRouteStops) {
      buffer
        ..write(stop.id)
        ..write(':')
        ..write(stop.routeOrder)
        ..write(':')
        ..write(stop.latitude)
        ..write(':')
        ..write(stop.longitude)
        ..write(':')
        ..write(stop.status.name)
        ..write(';');
    }

    buffer.write('|places:');
    for (final place in _visiblePinnedPlaces) {
      buffer
        ..write(place.id)
        ..write(':')
        ..write(place.placeType.name)
        ..write(':')
        ..write(place.latitude)
        ..write(':')
        ..write(place.longitude)
        ..write(';');
    }

    buffer.write('|communityPlaces:');
    for (final place in _visibleCommunityPlaces) {
      buffer
        ..write(place.id)
        ..write(':')
        ..write(place.exactLat)
        ..write(':')
        ..write(place.exactLng)
        ..write(':')
        ..write(place.dropType)
        ..write(';');
    }

    return buffer.toString();
  }

  String _polylineCacheSignature() {
    final buffer = StringBuffer()
      ..write(widget.routeViewOnly ? 'rv1' : 'rv0')
      ..write(
        '|start:${_routeStartAnchorLatLng?.latitude.toStringAsFixed(5) ?? '-'}:${_routeStartAnchorLatLng?.longitude.toStringAsFixed(5) ?? '-'}',
      )
      ..write(
        '|end:${_routeEndAnchorLatLng?.latitude.toStringAsFixed(5) ?? '-'}:${_routeEndAnchorLatLng?.longitude.toStringAsFixed(5) ?? '-'}',
      );

    for (final stop in _visiblePinnedRouteStops) {
      buffer
        ..write('|')
        ..write(stop.id)
        ..write(':')
        ..write(stop.latitude)
        ..write(':')
        ..write(stop.longitude);
    }

    return buffer.toString();
  }

  Set<Marker> _buildMarkers() {
    if (!_supportsGoogleMapsPlatform()) {
      return const <Marker>{};
    }

    final signature = _markerCacheSignature();
    if (_cachedMarkersSignature == signature) {
      return _cachedMarkers;
    }

    final markers = <Marker>{};
    final routePlaceIds = <String>{};
    final currentRouteStopId = _currentRouteStopId;

    for (final stop in _visiblePinnedRouteStops) {
      final isCurrentStop = stop.id == currentRouteStopId;
      routePlaceIds.add(stop.placeId);
      markers.add(
        Marker(
          markerId: MarkerId('route_${stop.id}'),
          position: LatLng(stop.latitude!, stop.longitude!),
          infoWindow: InfoWindow(
            title: stop.name,
            snippet: isCurrentStop
                ? 'Stop ${stop.routeOrder + 1} - Next stop'
                : 'Stop ${stop.routeOrder + 1} - ${_routeStatusLabel(stop.status)}',
          ),
          icon:
              _routeStopIcons[stop.id] ??
              fallbackVanRouteStopMarkerIcon(
                status: stop.status,
                isCurrent: isCurrentStop,
              ),
          consumeTapEvents: true,
          zIndexInt: isCurrentStop
              ? 4
              : stop.isQueued
              ? 2
              : 1,
          onTap: () {
            final matchingPlace = _findPlaceById(stop.placeId);
            if (matchingPlace == null) {
              return;
            }
            unawaited(
              _focusPlace(matchingPlace, clearSearch: false, moveCamera: false),
            );
          },
        ),
      );
    }

    final startAnchor = widget.routeStartAnchor;
    final startAnchorLatLng = _routeStartAnchorLatLng;
    if (startAnchor != null && startAnchorLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_start_anchor'),
          position: startAnchorLatLng,
          infoWindow: InfoWindow(
            title: startAnchor.bestLabel,
            snippet: 'Start anchor',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          zIndexInt: 5,
        ),
      );
    }

    final endAnchor = widget.routeEndAnchor;
    final endAnchorLatLng = _routeEndAnchorLatLng;
    if (endAnchor != null && endAnchorLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_end_anchor'),
          position: endAnchorLatLng,
          infoWindow: InfoWindow(
            title: endAnchor.bestLabel,
            snippet: 'End anchor',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          zIndexInt: 4,
        ),
      );
    }

    for (final place in _visiblePinnedPlaces) {
      if (routePlaceIds.contains(place.id)) {
        continue;
      }

      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude!, place.longitude!),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.postcodeArea,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHueForType(place.placeType),
          ),
          consumeTapEvents: true,
          onTap: () {
            unawaited(
              _focusPlace(place, clearSearch: false, moveCamera: false),
            );
          },
        ),
      );
    }

    for (final place in _visibleCommunityPlaces) {
      markers.add(
        Marker(
          markerId: MarkerId('community_${place.id}'),
          position: LatLng(place.exactLat, place.exactLng),
          infoWindow: InfoWindow(
            title: place.placeName,
            snippet: '${place.placeType.label} Shared pin',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          consumeTapEvents: true,
          zIndexInt: 2,
          onTap: () {
            unawaited(
              _focusCommunityPlace(
                place,
                clearSearch: false,
                moveCamera: false,
              ),
            );
          },
        ),
      );
    }

    final googleResult = _selectedGoogleResult;
    if (googleResult != null && googleResult.isValid) {
      markers.add(
        Marker(
          markerId: MarkerId('google_${googleResult.placeId}'),
          position: LatLng(googleResult.latitude, googleResult.longitude),
          infoWindow: InfoWindow(
            title: googleResult.primaryText,
            snippet: googleResult.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 3,
        ),
      );
    }

    final selectedPin = _selectedPin;
    if (widget.allowPinPlacement && selectedPin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_pin'),
          position: selectedPin,
          infoWindow: InfoWindow(
            title: widget.selectedPinMarkerLabel ?? 'Selected pin',
            snippet: 'Adjust this exact pin before saving.',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          zIndexInt: 4,
        ),
      );
    }

    _cachedMarkersSignature = signature;
    _cachedMarkers = Set<Marker>.unmodifiable(markers);
    return _cachedMarkers;
  }

  Set<Polyline> _buildPolylines() {
    if (!_supportsGoogleMapsPlatform() ||
        _routePreviewPolylinePoints.length < 2) {
      return const <Polyline>{};
    }

    final signature = _polylineCacheSignature();
    if (_cachedPolylinesSignature == signature) {
      return _cachedPolylines;
    }

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('van_active_route'),
        points: _routePreviewPolylinePoints,
        width: 5,
        geodesic: true,
        color: const Color(0xFF79A6FF),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    _cachedPolylinesSignature = signature;
    _cachedPolylines = Set<Polyline>.unmodifiable(polylines);
    return _cachedPolylines;
  }

  Future<void> _fitVisibleRouteBoundsIfPossible({bool force = false}) async {
    if (!force && (_hasFittedPreferredRoute || _roadRouteLoading)) {
      return;
    }

    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final boundsPoints = _routePreviewBoundsPoints();
    if (boundsPoints.isEmpty) {
      return;
    }

    if (!force) {
      _hasFittedPreferredRoute = true;
    }

    if (boundsPoints.length == 1) {
      final point = boundsPoints.first;
      _logCameraAction(
        'fitVisibleRouteBoundsIfPossible',
        'force=$force singlePoint=true',
      );
      await controller.animateCamera(CameraUpdate.newLatLngZoom(point, 14.0));
      return;
    }

    final bounds = _routeBoundsFromLatLngs(boundsPoints);
    if (bounds == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    _logCameraAction(
      'fitVisibleRouteBoundsIfPossible',
      'force=$force boundsPoints=${boundsPoints.length}',
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 54));
  }

  void _logCameraAction(String action, String details) {
    final keyboardVisible =
        mounted && MediaQuery.viewInsetsOf(context).bottom > 0;
    final focusActive = FocusManager.instance.primaryFocus?.hasFocus == true;
    debugPrint(
      '[MapCamera] action=$action details=$details focusActive=$focusActive keyboardVisible=$keyboardVisible camera=${_cameraPosition.target.latitude.toStringAsFixed(5)},${_cameraPosition.target.longitude.toStringAsFixed(5)} zoom=${_cameraPosition.zoom.toStringAsFixed(2)}',
    );
  }

  List<LatLng> _routePreviewBoundsPoints() {
    final roadPolylinePoints = _roadRoutePreview?.polylinePoints;
    if (roadPolylinePoints != null && roadPolylinePoints.length >= 2) {
      return _dedupeSequentialLatLngs(roadPolylinePoints);
    }

    if (widget.routeViewOnly) {
      final points = <LatLng>[];
      final startAnchor = _routeStartAnchorLatLng;
      final endAnchor = _routeEndAnchorLatLng;
      if (startAnchor != null) {
        points.add(startAnchor);
      }
      points.addAll(
        _visiblePinnedRouteStops.map(
          (stop) => LatLng(stop.latitude!, stop.longitude!),
        ),
      );
      if (endAnchor != null) {
        points.add(endAnchor);
      }
      return _dedupeSequentialLatLngs(points);
    }

    return _routePreviewPolylinePoints;
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final screenSize = MediaQuery.sizeOf(context);
    const savedResultsOverlayLimit = 6;
    final savedSearchResults = _debouncedSearchQuery.value.isEmpty
        ? const <VanPlace>[]
        : _savedSearchMatches.toList(growable: false);
    final googleSearchResults = _autocompleteController.suggestions.toList(
      growable: false,
    );
    final floatingBottomInset = bottomInset + 16;
    final showPinCard = widget.allowPinPlacement && _selectedPin != null;
    final showSearchOverlay =
        !widget.routeViewOnly && _debouncedSearchQuery.value.isNotEmpty;
    final effectiveShowFilters = _showFilters && !showSearchOverlay;
    final showVisibilityToggles = !widget.routeViewOnly;
    final showCommunityToggle =
        showVisibilityToggles && widget.showCommunityPins;
    const topHeaderInset = 12.0;
    final headerHeight = widget.routeViewOnly ? 51.0 : 48.0;
    final mapControlsTop = topHeaderInset + headerHeight + 10.0;
    final filterPanelTop = mapControlsTop + 50;
    final emptyStateTop = widget.routeViewOnly
        ? mapControlsTop + 56
        : filterPanelTop + (effectiveShowFilters ? 214 : 64);
    final borderRadius = widget.showBackButton ? 0.0 : 28.0;
    final resultsOverlayMaxHeight = math.min(260.0, screenSize.height * 0.33);
    final routeUri = widget.routeViewOnly ? _buildRouteUri() : null;
    final showRouteAction =
        widget.routeViewOnly &&
        !_premiumRoutePreviewEnabled &&
        routeUri != null;
    final showRouteFallbackMessage =
        widget.routeViewOnly &&
        !_roadRouteLoading &&
        _visibleRouteStops.isNotEmpty &&
        _routePreviewPolylinePoints.isEmpty;
    debugPrint(
      '[Perf] Live map panel build #$_buildCount bottomInset=$bottomInset queryLength=${_debouncedSearchQuery.value.length}',
    );

    return Padding(
      padding: widget.padding,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: _VanLiveMapSurface(
                    initialCameraPosition: _cameraPosition,
                    mapType: _mapType,
                    myLocationEnabled: _myLocationEnabled,
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (widget.routeViewOnly) {
                        unawaited(_fitVisibleRouteBoundsIfPossible());
                      }
                    },
                    onCameraMoveStarted: _dismissPinPlacementHint,
                    onCameraMove: (position) {
                      _cameraPosition = position;
                      widget.onCameraPositionChanged?.call(position);
                    },
                    onLongPress: _handleMapLongPress,
                    onTap: (_) {
                      _dismissPinPlacementHint();
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (_selectedPlace == null &&
                          _selectedCommunityPlace == null) {
                        return;
                      }
                      setState(() {
                        _selectedPlace = null;
                        _selectedCommunityPlace = null;
                      });
                    },
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: topHeaderInset,
                  child: RepaintBoundary(
                    child: widget.routeViewOnly
                        ? _VanRouteOnlyMapHeader(
                            title: widget.routeViewTitle ?? 'Route Preview',
                            subtitle: _routeViewSubtitle,
                            showBackButton: widget.showBackButton,
                            onBack: widget.onBack,
                            trailing: showRouteAction
                                ? _VanRouteActionChip(
                                    label: 'Google Maps',
                                    icon: Icons.open_in_new_rounded,
                                    onTap: _openRouteInGoogleMaps,
                                  )
                                : null,
                          )
                        : _VanMapSearchBar(
                            controller: _searchController,
                            showBackButton: widget.showBackButton,
                            onBack: widget.onBack,
                            onTapField: _handleSearchTap,
                            onChanged: _handleSearchChanged,
                            onSubmitted: _handleSearchSubmitted,
                            onClear: _clearSearch,
                          ),
                  ),
                ),
                if (!widget.routeViewOnly || !widget.showBackButton)
                  Positioned(
                    left: 16,
                    top: mapControlsTop,
                    child: RepaintBoundary(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VanMapFiltersButton(
                            activeFilter: _selectedFilter,
                            expanded: effectiveShowFilters,
                            hasActiveState:
                                _selectedFilter != null ||
                                (showVisibilityToggles &&
                                    (!_showSavedDrops ||
                                        (showCommunityToggle &&
                                            !_showCommunityPins))),
                            onTap: _toggleFilters,
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  top: mapControlsTop,
                  child: RepaintBoundary(
                    child: _VanMapToggleButton(
                      mapType: _mapType,
                      onTap: _toggleMapType,
                    ),
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _debouncedSearchQuery,
                  builder: (context, query, _) {
                    final showSearchOverlay =
                        !widget.routeViewOnly && query.isNotEmpty;
                    final effectiveShowFilters =
                        _showFilters && !showSearchOverlay;
                    final showBottomHint =
                        widget.allowPinPlacement &&
                        _showPinPlacementHint &&
                        !showPinCard &&
                        !showSearchOverlay;
                    final showDetailsCard =
                        (!widget.routeViewOnly || !widget.showBackButton) &&
                        !showPinCard &&
                        _showSavedDrops &&
                        _selectedPlace != null &&
                        query.isEmpty;
                    final showCommunityDetailsCard =
                        (!widget.routeViewOnly || !widget.showBackButton) &&
                        !showPinCard &&
                        _showCommunityPins &&
                        _selectedPlace == null &&
                        _selectedCommunityPlace != null &&
                        query.isEmpty;
                    final currentBottomOffset =
                        showDetailsCard ||
                            showCommunityDetailsCard ||
                            showPinCard
                        ? MediaQuery.viewPaddingOf(context).bottom + 188
                        : floatingBottomInset;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!widget.routeViewOnly)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            left: effectiveShowFilters ? 16 : -212,
                            top: filterPanelTop,
                            child: RepaintBoundary(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: effectiveShowFilters ? 1 : 0,
                                child: IgnorePointer(
                                  ignoring: !effectiveShowFilters,
                                  child: _VanMapFilterPanel(
                                    selectedFilter: _selectedFilter,
                                    showVisibilityToggles:
                                        showVisibilityToggles,
                                    showSavedDrops: _showSavedDrops,
                                    showCommunityToggle: showCommunityToggle,
                                    showCommunityDrops: _showCommunityPins,
                                    onSelected: _handleFilterChanged,
                                    onSavedDropsChanged: _toggleSavedDrops,
                                    onCommunityDropsChanged:
                                        _toggleCommunityPins,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 16,
                          right: 74,
                          bottom: floatingBottomInset,
                          child: IgnorePointer(
                            ignoring: !showBottomHint,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              offset: showBottomHint
                                  ? Offset.zero
                                  : const Offset(0, 0.24),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: showBottomHint ? 1 : 0,
                                child: const _VanMapPinPlacementHint(),
                              ),
                            ),
                          ),
                        ),
                        if (widget.showNoResultsEmptyState &&
                            !_roadRouteLoading &&
                            _visiblePinnedPlaces.isEmpty &&
                            _routePreviewPolylinePoints.isEmpty &&
                            query.isEmpty)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: emptyStateTop,
                            child: _VanMapEmptyState(
                              title: widget.routeViewOnly
                                  ? 'No route set for today'
                                  : widget.places.isEmpty &&
                                        widget.routeStops.isEmpty
                                  ? 'No map drops yet'
                                  : 'No pins match this view',
                              message: widget.routeViewOnly
                                  ? 'Build and save a route in Route to see it here.'
                                  : widget.places.isEmpty &&
                                        widget.routeStops.isEmpty
                                  ? 'Save a drop in Places to start showing pins here.'
                                  : 'Clear the current filter or search to show more pins.',
                            ),
                          ),
                        if (_roadRouteLoading && widget.routeViewOnly)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: emptyStateTop,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black.withValues(alpha: 0.50),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: const Text(
                                  'Calculating road route...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (showRouteFallbackMessage)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: emptyStateTop,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.black.withValues(alpha: 0.50),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: const Text(
                                  'Couldn\'t calculate road route yet. Numbered stops are shown below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (showSearchOverlay)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: emptyStateTop,
                            child: RepaintBoundary(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _VanMapResultsOverlay(
                                  savedPlaces: savedSearchResults,
                                  googleSuggestions: googleSearchResults,
                                  query: query,
                                  selectedPlaceId: _selectedPlace?.id,
                                  isSearchingGoogle:
                                      _autocompleteController.isSearching,
                                  googleErrorText:
                                      _autocompleteController.errorText,
                                  showGoogleSection:
                                      _autocompleteController
                                          .supportsAutocomplete &&
                                      query.length >= 2,
                                  compact: false,
                                  maxHeight: resultsOverlayMaxHeight,
                                  hasMoreSavedEntries:
                                      _savedSearchMatches.length >
                                      savedResultsOverlayLimit,
                                  onSavedPlaceTap: (place) {
                                    unawaited(
                                      _focusPlace(place, moveCamera: true),
                                    );
                                  },
                                  onGoogleSuggestionTap:
                                      _selectGoogleSuggestion,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 16,
                          bottom: currentBottomOffset,
                          child: _VanMapCircleButton(
                            icon: Icons.my_location,
                            onTap: _centerOnCurrentLocation,
                          ),
                        ),
                        if (showPinCard)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom:
                                MediaQuery.viewPaddingOf(context).bottom + 14,
                            child: _VanMapSelectedPinCard(
                              selectedPin: _selectedPin!,
                              onUsePin: widget.onUseSelectedPin,
                              actionLabel: widget.selectedPinActionLabel,
                              helperText: widget.selectedPinHelperText,
                            ),
                          ),
                        if (showDetailsCard)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom:
                                MediaQuery.viewPaddingOf(context).bottom + 14,
                            child: _VanMapPlaceDetailsCard(
                              place: _selectedPlace!,
                              onOpenPlace: widget.onOpenPlace == null
                                  ? null
                                  : () => widget.onOpenPlace!(_selectedPlace!),
                              onNavigate: () =>
                                  _openNavigation(_selectedPlace!),
                              onAddToRoute: widget.onAddToRoute == null
                                  ? null
                                  : () => widget.onAddToRoute!(_selectedPlace!),
                            ),
                          ),
                        if (showCommunityDetailsCard)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom:
                                MediaQuery.viewPaddingOf(context).bottom + 14,
                            child: _VanCommunityPlaceDetailsCard(
                              place: _selectedCommunityPlace!,
                              isSaving:
                                  _busyCommunityPlaceId ==
                                  _selectedCommunityPlace!.id,
                              onNavigate: () => _openCommunityNavigation(
                                _selectedCommunityPlace!,
                              ),
                              onSaveToMyDrops: () =>
                                  _saveCommunityPlace(_selectedCommunityPlace!),
                              onReport: () => _reportCommunityPlace(
                                _selectedCommunityPlace!,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VanLiveMapSurface extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final MapType mapType;
  final bool myLocationEnabled;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final MapCreatedCallback? onMapCreated;
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<CameraPosition>? onCameraMove;
  final ValueChanged<LatLng>? onLongPress;
  final ValueChanged<LatLng>? onTap;

  const _VanLiveMapSurface({
    required this.initialCameraPosition,
    required this.mapType,
    required this.myLocationEnabled,
    required this.markers,
    required this.polylines,
    this.onMapCreated,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!_supportsGoogleMapsPlatform()) {
      return Container(
        color: const Color(0xFF0E1726),
        padding: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        child: Text(
          'The live Van Mate map will show on Android, iOS, and web builds. Saved drops and filters are ready for that handoff.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
      );
    }

    final gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    };

    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      markers: markers,
      polylines: polylines,
      mapType: mapType,
      onMapCreated: onMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraMove: onCameraMove,
      onLongPress: onLongPress,
      onTap: onTap,
      gestureRecognizers: gestureRecognizers,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      indoorViewEnabled: false,
      tiltGesturesEnabled: false,
    );
  }
}

class _VanRouteOnlyMapHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;

  const _VanRouteOnlyMapHeader({
    required this.title,
    required this.subtitle,
    required this.showBackButton,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBackButton)
          GestureDetector(
            onTap: onBack,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.42),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        if (showBackButton) const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black.withValues(alpha: 0.42),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _VanRouteActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _VanRouteActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withValues(alpha: 0.42),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _VanMapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback onTapField;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _VanMapSearchBar({
    required this.controller,
    required this.showBackButton,
    required this.onBack,
    required this.onTapField,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.46),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  if (showBackButton)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.search, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.words,
                      textAlignVertical: TextAlignVertical.center,
                      // Keep the map static; the keyboard should overlay the bottom of the screen.
                      scrollPadding: EdgeInsets.zero,
                      onTap: onTapField,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        fontSize: 14.2,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search place or saved drop',
                        hintStyle: TextStyle(
                          fontSize: 13.0,
                          color: Colors.white.withValues(alpha: 0.46),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (hasText)
                    GestureDetector(
                      onTap: onClear,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VanMapFiltersButton extends StatelessWidget {
  final VanPlaceType? activeFilter;
  final bool expanded;
  final bool hasActiveState;
  final VoidCallback onTap;

  const _VanMapFiltersButton({
    required this.activeFilter,
    required this.expanded,
    required this.hasActiveState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = hasActiveState || activeFilter != null;
    final accent = activeFilter?.accent ?? const Color(0xFF4A7DFF);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: hasActiveFilter
                  ? accent.withValues(alpha: 0.24)
                  : Colors.black.withValues(alpha: 0.44),
              border: Border.all(
                color: hasActiveFilter
                    ? accent.withValues(alpha: 0.38)
                    : Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: hasActiveFilter ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_left
                      : Icons.keyboard_arrow_right,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VanMapToggleButton extends StatelessWidget {
  final MapType mapType;
  final VoidCallback onTap;

  const _VanMapToggleButton({required this.mapType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSatellite = mapType == MapType.satellite;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(minWidth: 126),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.black.withValues(alpha: 0.44),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSatellite
                      ? Icons.satellite_alt_outlined
                      : Icons.map_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isSatellite ? 'Satellite' : 'Map',
                      style: const TextStyle(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
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

class _VanMapFilterPanel extends StatelessWidget {
  final VanPlaceType? selectedFilter;
  final bool showVisibilityToggles;
  final bool showSavedDrops;
  final bool showCommunityToggle;
  final bool showCommunityDrops;
  final ValueChanged<VanPlaceType?> onSelected;
  final VoidCallback onSavedDropsChanged;
  final VoidCallback onCommunityDropsChanged;

  const _VanMapFilterPanel({
    required this.selectedFilter,
    required this.showVisibilityToggles,
    required this.showSavedDrops,
    required this.showCommunityToggle,
    required this.showCommunityDrops,
    required this.onSelected,
    required this.onSavedDropsChanged,
    required this.onCommunityDropsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 194,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withValues(alpha: 0.50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(height: 6),
              if (showVisibilityToggles) ...[
                _VanMapVisibilityToggle(
                  label: 'My saved drops',
                  icon: Icons.bookmark_rounded,
                  selected: showSavedDrops,
                  accent: const Color(0xFF4A7DFF),
                  onTap: onSavedDropsChanged,
                ),
                if (showCommunityToggle) ...[
                  const SizedBox(height: 6),
                  _VanMapVisibilityToggle(
                    label: 'Community drops',
                    icon: Icons.groups_rounded,
                    selected: showCommunityDrops,
                    accent: const Color(0xFF35D6C4),
                    onTap: onCommunityDropsChanged,
                  ),
                ],
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Drop type',
                style: TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 6),
              _VanMapFilterOption(
                label: 'All',
                selected: selectedFilter == null,
                accent: const Color(0xFF4A7DFF),
                onTap: () => onSelected(null),
              ),
              for (final type in VanPlaceType.values)
                _VanMapFilterOption(
                  label: _mapFilterLabel(type),
                  selected: selectedFilter == type,
                  accent: type.accent,
                  onTap: () => onSelected(type),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VanMapVisibilityToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _VanMapVisibilityToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: selected
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              child: Icon(
                icon,
                size: 15,
                color: selected ? accent : Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.86),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              size: 28,
              color: selected ? accent : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _VanMapFilterOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _VanMapFilterOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: selected
                ? accent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : Colors.white54,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.86),
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

class _VanMapResultsOverlay extends StatelessWidget {
  final List<VanPlace> savedPlaces;
  final List<PlacesAutocompleteSuggestion> googleSuggestions;
  final String query;
  final String? selectedPlaceId;
  final bool isSearchingGoogle;
  final String? googleErrorText;
  final bool showGoogleSection;
  final bool compact;
  final double maxHeight;
  final bool hasMoreSavedEntries;
  final ValueChanged<VanPlace> onSavedPlaceTap;
  final ValueChanged<PlacesAutocompleteSuggestion> onGoogleSuggestionTap;

  const _VanMapResultsOverlay({
    required this.savedPlaces,
    required this.googleSuggestions,
    required this.query,
    required this.selectedPlaceId,
    required this.isSearchingGoogle,
    required this.googleErrorText,
    required this.showGoogleSection,
    required this.compact,
    required this.maxHeight,
    required this.hasMoreSavedEntries,
    required this.onSavedPlaceTap,
    required this.onGoogleSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleGoogleError = googleErrorText?.trim();
    final hasSavedPlaces = savedPlaces.isNotEmpty;
    final hasGoogleSuggestions = googleSuggestions.isNotEmpty;
    final showEmptyState =
        !hasSavedPlaces &&
        !hasGoogleSuggestions &&
        !isSearchingGoogle &&
        (visibleGoogleError == null || visibleGoogleError.isEmpty);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width - 32, 348),
        maxHeight: maxHeight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.56),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search results',
                      style: TextStyle(
                        fontSize: compact ? 12.1 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Google moves the map. Saved drops open details.',
                      style: TextStyle(
                        fontSize: compact ? 10.7 : 11.0,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (showGoogleSection) ...[
                      _VanMapSearchSectionTitle(
                        label: 'Google places',
                        trailing: isSearchingGoogle
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (visibleGoogleError != null &&
                          visibleGoogleError.isNotEmpty)
                        Text(
                          visibleGoogleError,
                          style: const TextStyle(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFC2BD),
                          ),
                        )
                      else if (!isSearchingGoogle && !hasGoogleSuggestions)
                        Text(
                          'No Google matches yet.',
                          style: TextStyle(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.68),
                          ),
                        )
                      else
                        ...googleSuggestions.map((suggestion) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GestureDetector(
                              onTap: () => onGoogleSuggestionTap(suggestion),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: compact ? 8 : 9,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.10),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      suggestion.primaryText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.6,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (suggestion.secondaryText
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        suggestion.secondaryText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          height: 1.3,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(
                                            alpha: 0.66,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                    ],
                    _VanMapSearchSectionTitle(label: 'Saved drops'),
                    const SizedBox(height: 8),
                    if (showEmptyState)
                      Text(
                        'No saved drops or Google places match "$query".',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      )
                    else if (!hasSavedPlaces)
                      Text(
                        'No saved drops match "$query".',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      )
                    else
                      ...savedPlaces.map((place) {
                        final selected = place.id == selectedPlaceId;
                        final secondaryText =
                            place.bestLocationLabel.trim().isNotEmpty &&
                                place.bestLocationLabel.trim().toLowerCase() !=
                                    place.name.trim().toLowerCase()
                            ? place.bestLocationLabel.trim()
                            : place.postcodeArea.trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => onSavedPlaceTap(place),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: compact ? 8 : 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: selected
                                    ? const Color(
                                        0xFF4A7DFF,
                                      ).withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: selected
                                      ? const Color(
                                          0xFF79A6FF,
                                        ).withValues(alpha: 0.42)
                                      : Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: place.placeType.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.6,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (secondaryText.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            secondaryText,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.0,
                                              height: 1.3,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(
                                                alpha: 0.66,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 17,
                                      color: const Color(
                                        0xFF93B3FF,
                                      ).withValues(alpha: 0.94),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    if (hasMoreSavedEntries)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Keep typing to narrow the saved-drop list.',
                          style: TextStyle(
                            fontSize: compact ? 10.6 : 10.8,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
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
  }
}

class _VanMapSearchSectionTitle extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _VanMapSearchSectionTitle({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.8,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
        const Spacer(),
        ...?trailing == null ? null : <Widget>[trailing!],
      ],
    );
  }
}

class _VanMapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _VanMapCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.46),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.98),
          size: 21,
        ),
      ),
    );
  }
}

class _VanMapPinPlacementHint extends StatelessWidget {
  const _VanMapPinPlacementHint();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withValues(alpha: 0.50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.90),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Long press map to add a drop pin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.90),
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

class _VanMapSelectedPinCard extends StatelessWidget {
  final LatLng selectedPin;
  final VoidCallback? onUsePin;
  final String actionLabel;
  final String? helperText;

  const _VanMapSelectedPinCard({
    required this.selectedPin,
    required this.onUsePin,
    required this.actionLabel,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drop Pin Selected',
            style: TextStyle(
              fontSize: 15.2,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${selectedPin.latitude.toStringAsFixed(5)}, ${selectedPin.longitude.toStringAsFixed(5)}',
            style: TextStyle(
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          if (onUsePin != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText ?? 'Use this pin to open Add Drop.',
              style: TextStyle(
                fontSize: 11.6,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (onUsePin != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _VanMapActionButton(
                label: actionLabel,
                icon: Icons.add_location_alt_outlined,
                filled: true,
                onTap: onUsePin!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanMapButtonRow extends StatelessWidget {
  final Widget leading;
  final Widget trailing;

  const _VanMapButtonRow({required this.leading, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 390 ? 8.0 : 10.0;
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

class _VanMapPlaceDetailsCard extends StatelessWidget {
  final VanPlace place;
  final VoidCallback? onOpenPlace;
  final VoidCallback onNavigate;
  final VoidCallback? onAddToRoute;

  const _VanMapPlaceDetailsCard({
    required this.place,
    required this.onOpenPlace,
    required this.onNavigate,
    required this.onAddToRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.bestLocationLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                        color: place.placeType.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: place.placeType.accent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: place.placeType.accent.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  place.placeType.label,
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (place.deliveryNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                place.deliveryNote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.2,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (onOpenPlace != null)
            _VanMapButtonRow(
              leading: _VanMapActionButton(
                label: 'Open Drop',
                icon: Icons.open_in_new_rounded,
                filled: true,
                onTap: onOpenPlace!,
              ),
              trailing: _VanMapActionButton(
                label: 'Navigate',
                icon: Icons.navigation_outlined,
                onTap: onNavigate,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: _VanMapActionButton(
                label: 'Navigate',
                icon: Icons.navigation_outlined,
                onTap: onNavigate,
              ),
            ),
          if (onAddToRoute != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _VanMapActionButton(
                label: 'Add to Route',
                icon: Icons.route_outlined,
                onTap: onAddToRoute!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VanCommunityPlaceDetailsCard extends StatelessWidget {
  final VanCommunityPlace place;
  final bool isSaving;
  final VoidCallback onNavigate;
  final VoidCallback onSaveToMyDrops;
  final VoidCallback onReport;

  const _VanCommunityPlaceDetailsCard({
    required this.place,
    required this.isSaving,
    required this.onNavigate,
    required this.onSaveToMyDrops,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final noteBlocks = <Widget>[
      if (place.deliveryNote.trim().isNotEmpty)
        _VanMapNoteBlock(title: 'Delivery note', value: place.deliveryNote),
      if (place.accessNote.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        _VanMapNoteBlock(title: 'Access note', value: place.accessNote),
      ],
      if (place.warningNote.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        _VanMapNoteBlock(title: 'Warning note', value: place.warningNote),
      ],
    ];
    final locationText = place.postcodeArea.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.placeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(
                              0xFF35D6C4,
                            ).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(
                                0xFF35D6C4,
                              ).withValues(alpha: 0.30),
                            ),
                          ),
                          child: const Text(
                            'Community',
                            style: TextStyle(
                              fontSize: 11.2,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            place.placeType.label,
                            style: const TextStyle(
                              fontSize: 11.2,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            place.hasExactPin
                                ? 'Exact pin saved'
                                : 'No exact pin',
                            style: TextStyle(
                              fontSize: 11.2,
                              fontWeight: FontWeight.w800,
                              color: place.hasExactPin
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        locationText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w600,
                          color: const Color(
                            0xFF35D6C4,
                          ).withValues(alpha: 0.96),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (noteBlocks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...noteBlocks,
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _VanMapActionButton(
                  label: 'Navigate',
                  icon: Icons.navigation_outlined,
                  filled: true,
                  enabled: place.hasExactPin,
                  onTap: onNavigate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VanMapActionButton(
                  label: isSaving ? 'Saving...' : 'Save to My Drops',
                  icon: Icons.bookmark_add_outlined,
                  enabled: !isSaving && place.hasExactPin,
                  onTap: onSaveToMyDrops,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _VanMapActionButton(
              label: isSaving ? 'Reporting...' : 'Report',
              icon: Icons.flag_outlined,
              enabled: !isSaving,
              onTap: onReport,
            ),
          ),
        ],
      ),
    );
  }
}

class _VanMapNoteBlock extends StatelessWidget {
  final String title;
  final String value;

  const _VanMapNoteBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.1,
              height: 1.34,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanMapActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  const _VanMapActionButton({
    required this.label,
    this.filled = false,
    this.icon,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: filled
              ? const LinearGradient(
                  colors: [Color(0xFF3F67FF), Color(0xFF6D97FF)],
                )
              : null,
          color: filled
              ? null
              : Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: enabled ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanMapEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _VanMapEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined, color: Colors.white70, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

String _mapFilterLabel(VanPlaceType? type) {
  switch (type) {
    case VanPlaceType.shop:
      return 'Shops';
    case VanPlaceType.business:
      return 'Businesses';
    case VanPlaceType.industrialUnit:
      return 'Industrial';
    case VanPlaceType.warehouse:
      return 'Warehouses';
    case VanPlaceType.office:
      return 'Offices';
    case VanPlaceType.other:
      return 'Other';
    case null:
      return 'All';
  }
}

String _routeStatusLabel(VanRouteStopStatus status) {
  switch (status) {
    case VanRouteStopStatus.queued:
      return 'Queued';
    case VanRouteStopStatus.done:
      return 'Done';
    case VanRouteStopStatus.failed:
      return 'Failed';
  }
}

LatLngBounds? _routeBoundsFromLatLngs(List<LatLng> points) {
  if (points.isEmpty) {
    return null;
  }

  double south = points.first.latitude;
  double north = points.first.latitude;
  double west = points.first.longitude;
  double east = points.first.longitude;

  for (final point in points.skip(1)) {
    south = south < point.latitude ? south : point.latitude;
    north = north > point.latitude ? north : point.latitude;
    west = west < point.longitude ? west : point.longitude;
    east = east > point.longitude ? east : point.longitude;
  }

  if (south == north) {
    south -= 0.0045;
    north += 0.0045;
  }

  if (west == east) {
    west -= 0.0045;
    east += 0.0045;
  }

  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}

List<LatLng> _dedupeSequentialLatLngs(Iterable<LatLng> points) {
  final dedupedPoints = <LatLng>[];

  for (final point in points) {
    if (dedupedPoints.isNotEmpty && _sameLatLng(dedupedPoints.last, point)) {
      continue;
    }
    dedupedPoints.add(point);
  }

  return dedupedPoints;
}

bool _sameLatLng(LatLng a, LatLng b) {
  return a.latitude == b.latitude && a.longitude == b.longitude;
}

double _markerHueForType(VanPlaceType type) {
  switch (type) {
    case VanPlaceType.shop:
      return BitmapDescriptor.hueAzure;
    case VanPlaceType.business:
      return 190;
    case VanPlaceType.industrialUnit:
      return BitmapDescriptor.hueOrange;
    case VanPlaceType.warehouse:
      return BitmapDescriptor.hueViolet;
    case VanPlaceType.office:
      return BitmapDescriptor.hueCyan;
    case VanPlaceType.other:
      return BitmapDescriptor.hueRose;
  }
}

bool _supportsGoogleMapsPlatform() {
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}
