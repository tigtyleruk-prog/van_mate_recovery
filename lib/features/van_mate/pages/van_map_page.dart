import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_route_marker_icons.dart';
import '../models/van_place.dart';
import '../models/van_route.dart';
import '../models/van_route_stop.dart';
import '../services/van_premium_service.dart';
import '../services/van_route_preview_service.dart';
import '../widgets/van_live_map_panel.dart';

class VanMapPageResult {
  const VanMapPageResult({
    required this.cameraPosition,
    this.selectedPin,
    this.useSelectedPin = false,
  });

  final CameraPosition cameraPosition;
  final LatLng? selectedPin;
  final bool useSelectedPin;
}

class VanMapTabPage extends StatelessWidget {
  const VanMapTabPage({
    super.key,
    required this.places,
    required this.cameraPosition,
    required this.selectedPin,
    required this.activeRoute,
    required this.onOpenFullScreenMap,
  });

  final List<VanPlace> places;
  final CameraPosition? cameraPosition;
  final LatLng? selectedPin;
  final VanRoute? activeRoute;
  final VoidCallback onOpenFullScreenMap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final routeStops = activeRoute?.stops ?? const <VanRouteStop>[];
    final routeStartAnchor = activeRoute?.startAnchor;
    final routeEndAnchor = activeRoute?.endAnchor;
    final routePreviewMode = activeRoute != null;

    return Stack(
      key: const ValueKey('map_tab'),
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: VanLiveMapPanel(
            places: List<VanPlace>.from(places),
            routeStops: routeStops,
            routeStartAnchor: routeStartAnchor,
            routeEndAnchor: routeEndAnchor,
            initialCameraPosition: cameraPosition,
            initialSelectedPin: selectedPin,
            allowPinPlacement: !routePreviewMode,
            showCommunityPins: true,
            routeViewOnly: routePreviewMode,
            padding: EdgeInsets.zero,
            showNoResultsEmptyState: false,
          ),
        ),
        Positioned(
          right: 16,
          bottom: bottomInset + 110,
          child: _VanMapOpenFullButton(onTap: onOpenFullScreenMap),
        ),
      ],
    );
  }
}

class _VanMapOpenFullButton extends StatelessWidget {
  final VoidCallback onTap;

  const _VanMapOpenFullButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withValues(alpha: 0.44),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: const Icon(
              Icons.open_in_full_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class VanMapPage extends StatelessWidget {
  final List<VanPlace> places;
  final VanRoute? activeRoute;
  final CameraPosition? initialCameraPosition;
  final LatLng? initialSelectedPin;
  final String selectedPinActionLabel;
  final String? selectedPinMarkerLabel;
  final String? selectedPinHelperText;
  final bool routeViewOnly;
  final String? routeViewTitle;
  final bool showCommunityPins;

  const VanMapPage({
    super.key,
    required this.places,
    this.activeRoute,
    this.initialCameraPosition,
    this.initialSelectedPin,
    this.selectedPinActionLabel = 'Continue to Details',
    this.selectedPinMarkerLabel,
    this.selectedPinHelperText,
    this.routeViewOnly = false,
    this.routeViewTitle,
    this.showCommunityPins = false,
  });

  @override
  Widget build(BuildContext context) {
    final routeStops = activeRoute?.stops ?? const <VanRouteStop>[];
    final routeStartAnchor = activeRoute?.startAnchor;
    final routeEndAnchor = activeRoute?.endAnchor;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.30)),
          SafeArea(
            child: _VanMapPageBody(
              places: places,
              routeStops: routeStops,
              routeStartAnchor: routeStartAnchor,
              routeEndAnchor: routeEndAnchor,
              initialSelectedPlaceId: activeRoute?.currentJob?.placeId,
              initialCameraPosition: initialCameraPosition,
              initialSelectedPin: initialSelectedPin,
              selectedPinActionLabel: selectedPinActionLabel,
              selectedPinMarkerLabel: selectedPinMarkerLabel,
              selectedPinHelperText: selectedPinHelperText,
              routeViewOnly: routeViewOnly,
              routeViewTitle: routeViewTitle,
              showCommunityPins: showCommunityPins,
            ),
          ),
        ],
      ),
    );
  }
}

class _VanMapPageBody extends StatefulWidget {
  const _VanMapPageBody({
    required this.places,
    required this.routeStops,
    required this.routeStartAnchor,
    required this.routeEndAnchor,
    required this.initialSelectedPlaceId,
    required this.initialCameraPosition,
    required this.initialSelectedPin,
    required this.selectedPinActionLabel,
    required this.selectedPinMarkerLabel,
    required this.selectedPinHelperText,
    required this.routeViewOnly,
    required this.routeViewTitle,
    required this.showCommunityPins,
  });

  final List<VanPlace> places;
  final List<VanRouteStop> routeStops;
  final VanRouteAnchor? routeStartAnchor;
  final VanRouteAnchor? routeEndAnchor;
  final String? initialSelectedPlaceId;
  final CameraPosition? initialCameraPosition;
  final LatLng? initialSelectedPin;
  final String selectedPinActionLabel;
  final String? selectedPinMarkerLabel;
  final String? selectedPinHelperText;
  final bool routeViewOnly;
  final String? routeViewTitle;
  final bool showCommunityPins;

  @override
  State<_VanMapPageBody> createState() => _VanMapPageBodyState();
}

class _VanMapPageBodyState extends State<_VanMapPageBody> {
  late CameraPosition _cameraPosition;
  LatLng? _selectedPin;

  @override
  void initState() {
    super.initState();
    _cameraPosition = widget.initialCameraPosition ?? _fallbackCameraPosition();
    _selectedPin = widget.initialSelectedPin;
  }

  void _useSelectedPin() {
    Navigator.of(context).pop(
      VanMapPageResult(
        cameraPosition: _cameraPosition,
        selectedPin: _selectedPin,
        useSelectedPin: true,
      ),
    );
  }

  CameraPosition _fallbackCameraPosition() {
    if (!widget.routeViewOnly) {
      return const CameraPosition(target: LatLng(54.4, -3.0), zoom: 5.9);
    }

    for (final stop in widget.routeStops) {
      if (stop.hasCoordinates) {
        return CameraPosition(
          target: LatLng(stop.latitude!, stop.longitude!),
          zoom: 13.9,
        );
      }
    }

    final startAnchor = widget.routeStartAnchor;
    if (startAnchor?.hasCoordinates == true) {
      return CameraPosition(
        target: LatLng(startAnchor!.latitude!, startAnchor.longitude!),
        zoom: 13.9,
      );
    }

    final endAnchor = widget.routeEndAnchor;
    if (endAnchor?.hasCoordinates == true) {
      return CameraPosition(
        target: LatLng(endAnchor!.latitude!, endAnchor.longitude!),
        zoom: 13.9,
      );
    }

    return const CameraPosition(target: LatLng(54.4, -3.0), zoom: 5.9);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<VanMapPageResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(
          VanMapPageResult(
            cameraPosition: _cameraPosition,
            selectedPin: _selectedPin,
          ),
        );
      },
      child: VanLiveMapPanel(
        places: widget.places,
        routeStops: widget.routeStops,
        routeStartAnchor: widget.routeStartAnchor,
        routeEndAnchor: widget.routeEndAnchor,
        initialSelectedPlaceId: widget.initialSelectedPlaceId,
        initialCameraPosition: _cameraPosition,
        initialSelectedPin: _selectedPin,
        routeViewOnly: widget.routeViewOnly,
        routeViewTitle: widget.routeViewTitle,
        allowPinPlacement: !widget.routeViewOnly,
        selectedPinMarkerLabel: widget.selectedPinMarkerLabel,
        selectedPinHelperText: widget.selectedPinHelperText,
        showBackButton: true,
        showCommunityPins: widget.showCommunityPins,
        onBack: () {
          Navigator.of(context).pop(
            VanMapPageResult(
              cameraPosition: _cameraPosition,
              selectedPin: _selectedPin,
            ),
          );
        },
        onCameraPositionChanged: (position) {
          _cameraPosition = position;
        },
        onSelectedPinChanged: (pin) {
          if (_selectedPin == pin) {
            return;
          }

          setState(() {
            _selectedPin = pin;
          });
        },
        onUseSelectedPin: widget.routeViewOnly || _selectedPin == null
            ? null
            : _useSelectedPin,
        selectedPinActionLabel: widget.selectedPinActionLabel,
        showNoResultsEmptyState: false,
      ),
    );
  }
}

class VanMapPreviewCard extends StatelessWidget {
  final List<VanPlace> places;
  final List<VanRouteStop> routeStops;
  final CameraPosition? cameraPosition;
  final LatLng? selectedPin;
  final VoidCallback onTap;

  const VanMapPreviewCard({
    super.key,
    required this.places,
    required this.routeStops,
    required this.cameraPosition,
    required this.selectedPin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewCamera = cameraPosition ?? _fallbackPreviewCamera();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: _VanSavedPlacesMapPreview(
                      places: places,
                      routeStops: routeStops,
                      cameraPosition: previewCamera,
                      selectedPin: selectedPin,
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
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.46),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF4A7DFF).withValues(alpha: 0.20),
                        border: Border.all(
                          color: const Color(
                            0xFF79A6FF,
                          ).withValues(alpha: 0.32),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_full_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Open Full Map',
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _VanSavedPlacePreviewCaption(
                      placeCount: places
                          .where((place) => place.hasCoordinates)
                          .length,
                      hasSelectedPin: selectedPin != null,
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

  CameraPosition _fallbackPreviewCamera() {
    for (final stop in routeStops) {
      if (stop.hasCoordinates) {
        return CameraPosition(
          target: LatLng(stop.latitude!, stop.longitude!),
          zoom: 12.8,
        );
      }
    }

    for (final place in places) {
      if (place.hasCoordinates) {
        return CameraPosition(
          target: LatLng(place.latitude!, place.longitude!),
          zoom: 12.8,
        );
      }
    }

    return const CameraPosition(target: LatLng(54.4, -3.0), zoom: 5.9);
  }
}

class _VanSavedPlacesMapPreview extends StatefulWidget {
  const _VanSavedPlacesMapPreview({
    required this.places,
    required this.routeStops,
    required this.cameraPosition,
    required this.selectedPin,
  });

  final List<VanPlace> places;
  final List<VanRouteStop> routeStops;
  final CameraPosition cameraPosition;
  final LatLng? selectedPin;

  @override
  State<_VanSavedPlacesMapPreview> createState() =>
      _VanSavedPlacesMapPreviewState();
}

class _VanSavedPlacesMapPreviewState extends State<_VanSavedPlacesMapPreview> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsVanMapPlatform()) {
      return const _VanMiniMapEmptyState(
        title: 'Map preview unavailable here',
        message: 'The Van Mate map preview works on Android, iOS, and web.',
      );
    }

    return GoogleMap(
      initialCameraPosition: widget.cameraPosition,
      markers: _previewPlaceMarkers(
        places: widget.places,
        routeStops: widget.routeStops,
        selectedPin: widget.selectedPin,
      ),
      polylines: _previewPolylines(widget.routeStops),
      onMapCreated: (controller) {
        _mapController = controller;
        unawaited(_fitPreviewBounds());
      },
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      indoorViewEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
    );
  }

  Future<void> _fitPreviewBounds() async {
    final controller = _mapController;
    if (controller == null || widget.routeStops.isEmpty) {
      return;
    }

    final pinnedStops = widget.routeStops
        .where((stop) => stop.hasCoordinates)
        .toList(growable: false);
    if (pinnedStops.isEmpty) {
      return;
    }

    if (pinnedStops.length == 1) {
      final stop = pinnedStops.first;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(stop.latitude!, stop.longitude!),
          13.2,
        ),
      );
      return;
    }

    final bounds = _routeBounds(pinnedStops);
    if (bounds == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 36));
  }
}

// ignore: unused_element
class _VanMapPreviewCaption extends StatelessWidget {
  const _VanMapPreviewCaption({
    required this.placeCount,
    required this.routeCount,
    required this.hasSelectedPin,
  });

  final int placeCount;
  final int routeCount;
  final bool hasSelectedPin;

  @override
  Widget build(BuildContext context) {
    final subtitle = hasSelectedPin
        ? 'Selected pin ready. Tap to continue in full-screen.'
        : 'Tap to search, browse saved drops, and long press to place a pin.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Saved pins: $placeCount  •  Route stops: $routeCount',
            style: const TextStyle(
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanSavedPlacePreviewCaption extends StatelessWidget {
  const _VanSavedPlacePreviewCaption({
    required this.placeCount,
    required this.hasSelectedPin,
  });

  final int placeCount;
  final bool hasSelectedPin;

  @override
  Widget build(BuildContext context) {
    final subtitle = hasSelectedPin
        ? 'Selected pin ready. Tap to continue in full-screen.'
        : 'Tap saved pins to view drops, or long press in full-screen to place a new drop pin.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.46),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Saved drop pins: $placeCount',
            style: const TextStyle(
              fontSize: 12.6,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class VanRouteMiniMapCard extends StatelessWidget {
  final VanRoute? route;
  final bool showActionChips;
  final bool interactiveMap;

  const VanRouteMiniMapCard({
    super.key,
    required this.route,
    this.showActionChips = true,
    this.interactiveMap = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: VanMatePremiumService.instance,
      builder: (context, _) {
        final premiumEnabled =
            VanMatePremiumService.instance.canUseRoadRoutePreview;
        final previewPoints = _orderedRoutePreviewPoints(route);
        final previewWaypoints = buildVanRoadRoutePreviewWaypoints(route);
        final currentJob = route?.currentJob;
        final emptyState = route == null
            ? const _VanMiniMapEmptyState(
                title: 'No route set for today',
                message:
                    'Save a route in Route to preview the stop order here.',
              )
            : previewWaypoints.length < 2 && previewPoints.isEmpty
            ? const _VanMiniMapEmptyState(
                title: 'No mapped route points yet',
                message:
                    'Add saved coordinates for Start, End, or route stops to show the route here.',
              )
            : null;

        final previewSubtitle = emptyState == null
            ? 'Preview order shown.'
            : 'Preview order shown.';

        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        height: 200,
                        child:
                            emptyState ??
                            (interactiveMap
                                ? _VanMiniRouteMapPreview(
                                    route: route,
                                    currentJobId: currentJob?.id,
                                    interactiveMap: interactiveMap,
                                  )
                                : IgnorePointer(
                                    child: _VanMiniRouteMapPreview(
                                      route: route,
                                      currentJobId: currentJob?.id,
                                      interactiveMap: interactiveMap,
                                    ),
                                  )),
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (showActionChips)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackFooter = constraints.maxWidth < 340;
                          final previewLabel = Text(
                            previewSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.68),
                            ),
                          );
                          final fullMapChip = showActionChips
                              ? IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: const Color(
                                        0xFF4A7DFF,
                                      ).withValues(alpha: 0.18),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4A7DFF,
                                        ).withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_full_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Full Map',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null;
                          final openRouteChip =
                              showActionChips &&
                                  !premiumEnabled &&
                                  previewWaypoints.isNotEmpty
                              ? GestureDetector(
                                  onTap: () =>
                                      _openRouteInGoogleMaps(context, route),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: const Color(
                                        0xFF1D2B4D,
                                      ).withValues(alpha: 0.92),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4A7DFF,
                                        ).withValues(alpha: 0.26),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_new_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Google Maps',
                                          style: TextStyle(
                                            fontSize: 11.2,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null;

                          if (stackFooter) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                previewLabel,
                                if (openRouteChip != null) ...[
                                  const SizedBox(height: 6),
                                  openRouteChip,
                                ],
                                if (fullMapChip != null) ...[
                                  const SizedBox(height: 6),
                                  fullMapChip,
                                ],
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: previewLabel),
                              if (openRouteChip != null) ...[
                                const SizedBox(width: 8),
                                openRouteChip,
                              ],
                              if (fullMapChip != null) ...[
                                const SizedBox(width: 8),
                                fullMapChip,
                              ],
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VanMiniRouteMapPreview extends StatefulWidget {
  final VanRoute? route;
  final String? currentJobId;
  final bool interactiveMap;

  const _VanMiniRouteMapPreview({
    required this.route,
    required this.currentJobId,
    required this.interactiveMap,
  });

  @override
  State<_VanMiniRouteMapPreview> createState() =>
      _VanMiniRouteMapPreviewState();
}

class _VanMiniRouteMapPreviewState extends State<_VanMiniRouteMapPreview> {
  static const LatLng _fallbackCameraTarget = LatLng(54.4, -3.0);

  GoogleMapController? _mapController;
  Map<String, BitmapDescriptor> _stopMarkerIcons =
      const <String, BitmapDescriptor>{};
  VanRoadRoutePreviewResult? _roadRoutePreview;
  List<VanRouteStop> _roadRouteStops = const <VanRouteStop>[];
  bool _roadRouteLoading = false;
  String _roadRouteSignature = '';
  int _roadRouteRequestId = 0;
  String? _roadRouteErrorMessage;
  String _cameraFitSignature = '';
  bool _hasAutoFittedCamera = false;
  bool _userMovedCamera = false;
  bool _isAutoFittingCamera = false;

  @override
  void initState() {
    super.initState();
    VanMatePremiumService.instance.addListener(_handlePremiumChanged);
    unawaited(_primeStopMarkerIcons());
    unawaited(_refreshRoadRoutePreview());
    _cameraFitSignature = _previewSignatureForRoute(widget.route);
  }

  @override
  void didUpdateWidget(covariant _VanMiniRouteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextSignature = buildVanRoadRoutePreviewSignature(
      buildVanFreeRoutePreviewWaypointsForRoute(widget.route),
    );
    if (nextSignature != _roadRouteSignature) {
      unawaited(_refreshRoadRoutePreview());
      unawaited(_primeStopMarkerIcons());
    }

    final nextCameraSignature = _previewSignatureForRoute(widget.route);
    if (nextCameraSignature != _cameraFitSignature) {
      _cameraFitSignature = nextCameraSignature;
      _hasAutoFittedCamera = false;
      _userMovedCamera = false;
      if (_mapController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          unawaited(
            _fitPreviewBounds(_orderedRoutePreviewPoints(widget.route)),
          );
        });
      }
    }

    if (oldWidget.currentJobId != widget.currentJobId) {
      unawaited(_primeStopMarkerIcons());
    }
  }

  @override
  void dispose() {
    VanMatePremiumService.instance.removeListener(_handlePremiumChanged);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsVanMapPlatform()) {
      return const _VanMiniMapEmptyState(
        title: 'Map preview unavailable here',
        message:
            'The mini route map will show on Android, iOS, and web builds.',
      );
    }

    final previewStops = _roadRouteStops.isNotEmpty
        ? _roadRouteStops
        : buildVanFreeRoutePreviewStopsForRoute(widget.route);
    final premiumEnabled =
        VanMatePremiumService.instance.canUseRoadRoutePreview;
    final previewPoints = _previewRoutePoints(
      previewStops,
      resolvedPoints: _roadRoutePreview?.resolvedPoints,
    );
    final roadPolylinePoints = premiumEnabled
        ? _roadRoutePreview?.polylinePoints
        : null;
    final hasRoadPolyline =
        roadPolylinePoints != null && roadPolylinePoints.length >= 2;
    final initialPoint = previewPoints.isNotEmpty
        ? _preferredPreviewPoint(previewPoints, widget.currentJobId)
        : _VanRoutePreviewPoint(
            id: 'fallback_camera',
            position: _fallbackCameraTarget,
            title: 'Route preview',
            subtitle: 'Waiting for route points',
            type: _VanRoutePreviewPointType.stop,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialPoint.position,
            zoom: 12.4,
          ),
          markers: _previewRouteMarkers(
            previewPoints: previewPoints,
            currentJobId: widget.currentJobId,
            stopIcons: _stopMarkerIcons,
          ),
          polylines: _previewRoutePolylines(
            previewPoints,
            roadPolylinePoints: hasRoadPolyline ? roadPolylinePoints : null,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            unawaited(_fitPreviewBounds(previewPoints));
          },
          onCameraMoveStarted: _handleCameraMoveStarted,
          gestureRecognizers: widget.interactiveMap
              ? <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => ScaleGestureRecognizer(),
                  ),
                }
              : const <Factory<OneSequenceGestureRecognizer>>{},
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          indoorViewEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: widget.interactiveMap,
          scrollGesturesEnabled: widget.interactiveMap,
        ),
        if (premiumEnabled && widget.interactiveMap)
          Positioned(
            right: 10,
            bottom: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(_refreshRoadRoutePreview(force: true)),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black.withValues(alpha: 0.52),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Refresh route',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_roadRouteLoading)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.52),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Text(
                  'Calculating road route...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _primeStopMarkerIcons() async {
    final previewPoints = _previewRoutePoints(
      _roadRouteStops.isNotEmpty
          ? _roadRouteStops
          : buildVanFreeRoutePreviewStopsForRoute(widget.route),
      resolvedPoints: _roadRoutePreview?.resolvedPoints,
    );
    final stopPoints = previewPoints
        .where((point) => point.stop != null)
        .toList(growable: false);
    final iconEntries = <MapEntry<String, BitmapDescriptor>>[];
    for (var index = 0; index < stopPoints.length; index++) {
      final stop = stopPoints[index].stop!;
      final icon = await buildVanRouteStopMarkerIcon(
        stopNumber: index + 1,
        status: stop.status,
        isCurrent: stop.id == widget.currentJobId,
      );
      iconEntries.add(MapEntry<String, BitmapDescriptor>(stop.id, icon));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _stopMarkerIcons = <String, BitmapDescriptor>{
        for (final entry in iconEntries) entry.key: entry.value,
      };
    });
  }

  Future<void> _refreshRoadRoutePreview({bool force = false}) async {
    final premiumEnabled =
        VanMatePremiumService.instance.canUseRoadRoutePreview;
    final waypoints = buildVanFreeRoutePreviewWaypointsForRoute(widget.route);
    final signature = buildVanRoadRoutePreviewSignature(waypoints);
    if (!premiumEnabled) {
      if (!mounted) {
        return;
      }

      setState(() {
        _roadRouteStops = const <VanRouteStop>[];
        _roadRoutePreview = null;
        _roadRouteLoading = false;
        _roadRouteSignature = '';
        _roadRouteErrorMessage = null;
      });
      return;
    }

    if (signature.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _roadRouteStops = const <VanRouteStop>[];
        _roadRoutePreview = null;
        _roadRouteLoading = false;
        _roadRouteSignature = '';
        _roadRouteErrorMessage = null;
      });
      return;
    }

    if (!force && signature == _roadRouteSignature) {
      if (_roadRoutePreview != null || _roadRouteErrorMessage != null) {
        return;
      }
    }

    final requestId = ++_roadRouteRequestId;
    _roadRouteSignature = signature;
    final previewStops = buildVanFreeRoutePreviewStopsForRoute(widget.route);

    if (!mounted) {
      return;
    }

    setState(() {
      _roadRouteStops = previewStops;
      _roadRoutePreview = null;
      _roadRouteErrorMessage = null;
      _roadRouteLoading = waypoints.length >= 2;
    });

    if (waypoints.length < 2) {
      if (!mounted || requestId != _roadRouteRequestId) {
        return;
      }

      setState(() {
        _roadRouteLoading = false;
        _roadRouteErrorMessage = null;
      });
      return;
    }

    debugPrint(
      '[RoadPreview] route preview calculation started: '
      '${waypoints.length} waypoints',
    );

    try {
      final result = await VanRoadRoutePreviewService.instance
          .calculateRoadPreviewRouteForWaypoints(
            waypoints: waypoints,
            force: force,
          );
      if (!mounted || requestId != _roadRouteRequestId) {
        return;
      }

      setState(() {
        _roadRoutePreview = result;
        _roadRouteErrorMessage = null;
      });

      if (!_userMovedCamera) {
        unawaited(
          _fitPreviewBounds(
            _previewRoutePoints(
              previewStops,
              resolvedPoints: result.resolvedPoints,
            ),
            force: true,
          ),
        );
      }

      debugPrint(
        '[RoadPreview] route preview calculation success: '
        '${result.polylinePoints.length} polyline points',
      );
    } catch (error) {
      if (!mounted || requestId != _roadRouteRequestId) {
        return;
      }

      final message = error is VanRoadRoutePreviewException
          ? error.message
          : 'Could not calculate road route preview.';

      setState(() {
        _roadRoutePreview = null;
        _roadRouteErrorMessage = null;
      });

      debugPrint(
        '[RoadPreview] route calculation failed and fallback used: $message',
      );
    } finally {
      if (mounted && requestId == _roadRouteRequestId) {
        setState(() {
          _roadRouteLoading = false;
        });
      }
    }
  }

  Future<void> _fitPreviewBounds(
    List<_VanRoutePreviewPoint> previewPoints, {
    bool force = false,
  }) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final boundsPoints = _previewPolylinePoints(previewPoints);
    if (boundsPoints.isEmpty) {
      return;
    }

    if (!force && (_hasAutoFittedCamera || _userMovedCamera)) {
      return;
    }

    if (boundsPoints.length == 1) {
      final point = boundsPoints.first;
      _isAutoFittingCamera = true;
      try {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(point, 13.4));
      } finally {
        _isAutoFittingCamera = false;
      }
      _hasAutoFittedCamera = true;
      return;
    }

    final bounds = _routeBoundsFromLatLngs(boundsPoints);
    if (bounds == null) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    _isAutoFittingCamera = true;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 36));
    } finally {
      _isAutoFittingCamera = false;
    }
    _hasAutoFittedCamera = true;
  }

  List<_VanRoutePreviewPoint> _previewRoutePoints(
    List<VanRouteStop> previewStops, {
    List<LatLng>? resolvedPoints,
  }) {
    final points = <_VanRoutePreviewPoint>[];

    for (var index = 0; index < previewStops.length; index++) {
      final stop = previewStops[index];
      final resolvedPosition =
          resolvedPoints != null && index < resolvedPoints.length
          ? resolvedPoints[index]
          : stop.hasCoordinates
          ? LatLng(stop.latitude!, stop.longitude!)
          : null;
      if (resolvedPosition == null) {
        continue;
      }

      points.add(
        _VanRoutePreviewPoint(
          id: 'free_preview_${stop.id}',
          position: resolvedPosition,
          title: stop.name,
          subtitle:
              'Stop ${stop.routeOrder + 1} - ${_routeStatusLabel(stop.status)}',
          type: _VanRoutePreviewPointType.stop,
          stop: stop,
        ),
      );
    }

    return points;
  }

  List<LatLng> _previewPolylinePoints(
    List<_VanRoutePreviewPoint> previewPoints,
  ) {
    return _dedupeSequentialLatLngs(
      previewPoints.map((point) => point.position),
    );
  }

  String _previewSignatureForRoute(VanRoute? route) {
    return buildVanRoadRoutePreviewSignature(
      buildVanRoadRoutePreviewWaypoints(route),
    );
  }

  void _handleCameraMoveStarted() {
    if (!mounted || _isAutoFittingCamera) {
      return;
    }

    if (_userMovedCamera) {
      return;
    }

    setState(() {
      _userMovedCamera = true;
    });
  }

  void _handlePremiumChanged() {
    if (!mounted) {
      return;
    }

    unawaited(_refreshRoadRoutePreview(force: true));
  }
}

class _VanMiniMapEmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _VanMiniMapEmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1728),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.4,
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

enum _VanRoutePreviewPointType { start, stop, end }

class _VanRoutePreviewPoint {
  const _VanRoutePreviewPoint({
    required this.id,
    required this.position,
    required this.title,
    required this.subtitle,
    required this.type,
    this.stop,
  });

  final String id;
  final LatLng position;
  final String title;
  final String subtitle;
  final _VanRoutePreviewPointType type;
  final VanRouteStop? stop;
}

List<_VanRoutePreviewPoint> _orderedRoutePreviewPoints(VanRoute? route) {
  if (route == null) {
    return const <_VanRoutePreviewPoint>[];
  }

  final previewPoints = <_VanRoutePreviewPoint>[];
  final startAnchor = route.startAnchor;
  final endAnchor = route.endAnchor;

  if (startAnchor?.hasCoordinates == true) {
    previewPoints.add(
      _VanRoutePreviewPoint(
        id: 'route_start_anchor',
        position: LatLng(startAnchor!.latitude!, startAnchor.longitude!),
        title: startAnchor.bestLabel,
        subtitle: 'Start anchor',
        type: _VanRoutePreviewPointType.start,
      ),
    );
  }

  final orderedStops = route.remainingStops
      .where((stop) => stop.hasCoordinates)
      .toList(growable: false);

  for (var index = 0; index < orderedStops.length; index++) {
    final stop = orderedStops[index];
    previewPoints.add(
      _VanRoutePreviewPoint(
        id: 'preview_${stop.id}',
        position: LatLng(stop.latitude!, stop.longitude!),
        title: stop.name,
        subtitle: 'Stop ${index + 1} - ${_routeStatusLabel(stop.status)}',
        type: _VanRoutePreviewPointType.stop,
        stop: stop,
      ),
    );
  }

  if (endAnchor?.hasCoordinates == true) {
    previewPoints.add(
      _VanRoutePreviewPoint(
        id: 'route_end_anchor',
        position: LatLng(endAnchor!.latitude!, endAnchor.longitude!),
        title: endAnchor.bestLabel,
        subtitle: 'End anchor',
        type: _VanRoutePreviewPointType.end,
      ),
    );
  }

  return previewPoints;
}

_VanRoutePreviewPoint _preferredPreviewPoint(
  List<_VanRoutePreviewPoint> previewPoints,
  String? currentJobId,
) {
  if (currentJobId != null) {
    for (final point in previewPoints) {
      if (point.stop?.id == currentJobId) {
        return point;
      }
    }
  }

  return previewPoints.first;
}

Set<Marker> _previewRouteMarkers({
  required List<_VanRoutePreviewPoint> previewPoints,
  required String? currentJobId,
  required Map<String, BitmapDescriptor> stopIcons,
}) {
  return previewPoints.map((point) {
    final stop = point.stop;
    final markerIcon = switch (point.type) {
      _VanRoutePreviewPointType.start => BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueViolet,
      ),
      _VanRoutePreviewPointType.end => BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      ),
      _VanRoutePreviewPointType.stop =>
        stopIcons[stop!.id] ??
            fallbackVanRouteStopMarkerIcon(
              status: stop.status,
              isCurrent: stop.id == currentJobId,
            ),
    };
    final zIndex = switch (point.type) {
      _VanRoutePreviewPointType.start => 5,
      _VanRoutePreviewPointType.stop => stop?.id == currentJobId ? 4 : 2,
      _VanRoutePreviewPointType.end => 4,
    };

    return Marker(
      markerId: MarkerId(point.id),
      position: point.position,
      infoWindow: InfoWindow(title: point.title, snippet: point.subtitle),
      icon: markerIcon,
      zIndexInt: zIndex,
    );
  }).toSet();
}

Set<Polyline> _previewRoutePolylines(
  List<_VanRoutePreviewPoint> previewPoints, {
  List<LatLng>? roadPolylinePoints,
}) {
  final orderedPoints =
      roadPolylinePoints != null && roadPolylinePoints.length >= 2
      ? _dedupeSequentialLatLngs(roadPolylinePoints)
      : const <LatLng>[];

  if (orderedPoints.length < 2) {
    return const <Polyline>{};
  }

  return <Polyline>{
    Polyline(
      polylineId: const PolylineId('route_preview_with_anchors'),
      points: orderedPoints,
      width: 5,
      geodesic: true,
      color: const Color(0xFF79A6FF),
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
    ),
  };
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

Set<Polyline> _previewPolylines(List<VanRouteStop> routeStops) {
  return const <Polyline>{};
}

Future<void> _openRouteInGoogleMaps(
  BuildContext context,
  VanRoute? route,
) async {
  final result = buildVanGoogleMapsDirectionsResultForRemainingRoute(route);
  final uri = result.uri ?? buildVanGoogleMapsDirectionsUriForRoute(route);
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No route could be opened in Google Maps right now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (result.isTruncated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Google Maps may only show part of large routes. Use Navigate next stop for the full route.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || launched) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open Google Maps route right now.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Set<Marker> _previewPlaceMarkers({
  required List<VanPlace> places,
  required List<VanRouteStop> routeStops,
  required LatLng? selectedPin,
}) {
  final markers = <Marker>{};
  final routePlaceIds = <String>{};

  for (final stop in routeStops) {
    if (!stop.hasCoordinates) {
      continue;
    }

    routePlaceIds.add(stop.placeId);
    markers.add(
      Marker(
        markerId: MarkerId('preview_route_${stop.id}'),
        position: LatLng(stop.latitude!, stop.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _routeMarkerHue(stop, currentJobId: null),
        ),
      ),
    );
  }

  for (final place in places) {
    if (!place.hasCoordinates || routePlaceIds.contains(place.id)) {
      continue;
    }

    markers.add(
      Marker(
        markerId: MarkerId('preview_place_${place.id}'),
        position: LatLng(place.latitude!, place.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _previewPlaceHue(place.placeType),
        ),
      ),
    );
  }

  if (selectedPin != null) {
    markers.add(
      Marker(
        markerId: const MarkerId('preview_selected_pin'),
        position: selectedPin,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  return markers;
}

LatLngBounds? _routeBounds(List<VanRouteStop> routeStops) {
  if (routeStops.isEmpty) {
    return null;
  }

  double south = routeStops.first.latitude!;
  double north = routeStops.first.latitude!;
  double west = routeStops.first.longitude!;
  double east = routeStops.first.longitude!;

  for (final stop in routeStops.skip(1)) {
    south = south < stop.latitude! ? south : stop.latitude!;
    north = north > stop.latitude! ? north : stop.latitude!;
    west = west < stop.longitude! ? west : stop.longitude!;
    east = east > stop.longitude! ? east : stop.longitude!;
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

double _routeMarkerHue(VanRouteStop stop, {String? currentJobId}) {
  if (stop.id == currentJobId) {
    return BitmapDescriptor.hueAzure;
  }

  switch (stop.status) {
    case VanRouteStopStatus.queued:
      return BitmapDescriptor.hueBlue;
    case VanRouteStopStatus.done:
      return BitmapDescriptor.hueGreen;
    case VanRouteStopStatus.failed:
      return BitmapDescriptor.hueRed;
  }
}

double _previewPlaceHue(VanPlaceType type) {
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

bool _supportsVanMapPlatform() {
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
