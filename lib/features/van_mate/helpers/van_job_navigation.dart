import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/van_live_pin_request.dart';
import '../pages/driver_customer_reply_mock_page.dart';

Future<void> openVanJobNavigation(
  BuildContext context,
  DriverCustomerReplyMockData job,
) async {
  final exactPin = _jobExactPin(job);
  if (exactPin != null) {
    await openVanGoogleMapsAtCoordinates(
      context,
      latitude: exactPin.latitude,
      longitude: exactPin.longitude,
    );
    return;
  }

  final query = _jobSearchQuery(job);
  if (query == null) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No address or exact pin saved yet.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || launched) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open Google Maps just now.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

LatLng? _jobExactPin(DriverCustomerReplyMockData job) {
  final latitude = job.exactPinLatitude;
  final longitude = job.exactPinLongitude;
  if (latitude == null || longitude == null) {
    return null;
  }
  return LatLng(latitude, longitude);
}

String? _jobSearchQuery(DriverCustomerReplyMockData job) {
  final parts = <String>[
    job.address.trim(),
    job.postcode.trim(),
  ].where((value) => value.isNotEmpty).toList(growable: false);

  if (parts.isEmpty) {
    return null;
  }

  return parts.join(', ');
}
