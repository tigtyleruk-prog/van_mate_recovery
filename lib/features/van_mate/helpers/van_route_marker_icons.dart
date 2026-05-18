import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/van_route_stop.dart';

final Map<String, Future<BitmapDescriptor>> _routeStopMarkerCache =
    <String, Future<BitmapDescriptor>>{};

Future<BitmapDescriptor> buildVanRouteStopMarkerIcon({
  required int stopNumber,
  required VanRouteStopStatus status,
  required bool isCurrent,
}) {
  final cacheKey = '$stopNumber:${status.storageValue}:$isCurrent';

  return _routeStopMarkerCache.putIfAbsent(cacheKey, () async {
    try {
      final bytes = await _buildVanRouteStopMarkerBytes(
        stopNumber: stopNumber,
        status: status,
        isCurrent: isCurrent,
      );
      final devicePixelRatio = ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first.devicePixelRatio
          : 1.0;

      return BitmapDescriptor.bytes(
        bytes,
        imagePixelRatio: devicePixelRatio,
        width: isCurrent ? 50 : 44,
        height: isCurrent ? 64 : 58,
      );
    } catch (_) {
      return fallbackVanRouteStopMarkerIcon(
        status: status,
        isCurrent: isCurrent,
      );
    }
  });
}

BitmapDescriptor fallbackVanRouteStopMarkerIcon({
  required VanRouteStopStatus status,
  required bool isCurrent,
}) {
  return BitmapDescriptor.defaultMarkerWithHue(
    switch ((status, isCurrent)) {
      (VanRouteStopStatus.done, _) => BitmapDescriptor.hueGreen,
      (VanRouteStopStatus.failed, _) => BitmapDescriptor.hueOrange,
      (VanRouteStopStatus.queued, true) => BitmapDescriptor.hueAzure,
      (VanRouteStopStatus.queued, false) => BitmapDescriptor.hueBlue,
    },
  );
}

Future<Uint8List> _buildVanRouteStopMarkerBytes({
  required int stopNumber,
  required VanRouteStopStatus status,
  required bool isCurrent,
}) async {
  const canvasWidth = 132.0;
  const canvasHeight = 168.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final headRadius = isCurrent ? 31.0 : 28.0;
  final headCenter = Offset(canvasWidth / 2, isCurrent ? 48 : 50);
  final point = Offset(canvasWidth / 2, canvasHeight - 16);
  final tailWidth = headRadius * 1.06;
  final fillColor = switch ((status, isCurrent)) {
    (VanRouteStopStatus.done, _) => const Color(0xFF36B984),
    (VanRouteStopStatus.failed, _) => const Color(0xFFE37A58),
    (VanRouteStopStatus.queued, true) => const Color(0xFF79A6FF),
    (VanRouteStopStatus.queued, false) => const Color(0xFF4573F2),
  };

  final tailPath = Path()
    ..moveTo(headCenter.dx - tailWidth / 2, headCenter.dy + headRadius * 0.54)
    ..quadraticBezierTo(
      headCenter.dx - 20,
      canvasHeight - 58,
      point.dx,
      point.dy,
    )
    ..quadraticBezierTo(
      headCenter.dx + 20,
      canvasHeight - 58,
      headCenter.dx + tailWidth / 2,
      headCenter.dy + headRadius * 0.54,
    )
    ..close();

  if (isCurrent) {
    canvas.drawCircle(
      headCenter,
      headRadius + 10,
      Paint()..color = const Color(0xFF9EBEFF).withValues(alpha: 0.26),
    );
  }

  canvas.save();
  canvas.translate(0, 5);
  final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.20);
  canvas.drawPath(tailPath, shadowPaint);
  canvas.drawCircle(headCenter, headRadius, shadowPaint);
  canvas.restore();

  final fillPaint = Paint()..color = fillColor;
  final strokePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.94)
    ..style = PaintingStyle.stroke
    ..strokeWidth = isCurrent ? 5.5 : 4.5;

  canvas.drawPath(tailPath, fillPaint);
  canvas.drawCircle(headCenter, headRadius, fillPaint);
  canvas.drawPath(tailPath, strokePaint);
  canvas.drawCircle(headCenter, headRadius, strokePaint);

  final numberText = '$stopNumber';
  final numberPainter = TextPainter(
    text: TextSpan(
      text: numberText,
      style: TextStyle(
        fontSize: numberText.length >= 2 ? (isCurrent ? 30 : 28) : 34,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  numberPainter.paint(
    canvas,
    Offset(
      headCenter.dx - numberPainter.width / 2,
      headCenter.dy - numberPainter.height / 2 - 1,
    ),
  );

  if (isCurrent) {
    const accentLabel = 'NEXT';
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: accentLabel,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Color(0xFF0B1B35),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelPadding = const EdgeInsets.symmetric(horizontal: 9, vertical: 5);
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        headCenter.dx - (labelPainter.width / 2) - labelPadding.horizontal / 2,
        12,
        labelPainter.width + labelPadding.horizontal,
        labelPainter.height + labelPadding.vertical,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(labelRect, Paint()..color = const Color(0xFFF1F5FF));
    labelPainter.paint(
      canvas,
      Offset(
        labelRect.left + (labelRect.width - labelPainter.width) / 2,
        labelRect.top + (labelRect.height - labelPainter.height) / 2,
      ),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    canvasWidth.toInt(),
    canvasHeight.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Could not encode Van Mate route marker.');
  }

  return byteData.buffer.asUint8List();
}
