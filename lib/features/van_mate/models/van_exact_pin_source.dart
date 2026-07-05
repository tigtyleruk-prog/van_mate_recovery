enum VanExactPinSource { currentLocation, mapSelection }

String? vanExactPinSourceToStorage(VanExactPinSource? source) {
  switch (source) {
    case VanExactPinSource.currentLocation:
      return 'currentLocationConfirmed';
    case VanExactPinSource.mapSelection:
      return 'mapAdjusted';
    case null:
      return null;
  }
}

VanExactPinSource? vanExactPinSourceFromStorage(String? value) {
  switch (value?.trim()) {
    case 'currentLocation':
    case 'currentLocationConfirmed':
      return VanExactPinSource.currentLocation;
    case 'mapSelection':
    case 'mapAdjusted':
    case 'chosenOnMap':
      return VanExactPinSource.mapSelection;
  }
  return null;
}

extension VanExactPinSourceText on VanExactPinSource {
  String get customerStatusLabel {
    switch (this) {
      case VanExactPinSource.currentLocation:
        return 'Exact pin shared';
      case VanExactPinSource.mapSelection:
        return 'Exact pin chosen on map';
    }
  }

  String get customerHelperText {
    switch (this) {
      case VanExactPinSource.currentLocation:
        return 'You confirmed this is the exact place the driver needs to go.';
      case VanExactPinSource.mapSelection:
        return 'The driver will receive the selected pickup/drop-off point.';
    }
  }

  String get driverSourceText {
    switch (this) {
      case VanExactPinSource.currentLocation:
        return 'Customer confirmed they were at the pickup/drop-off point.';
      case VanExactPinSource.mapSelection:
        return 'Customer selected the pickup/drop-off point on a map.';
    }
  }

  String get submitSummaryText {
    switch (this) {
      case VanExactPinSource.currentLocation:
        return 'Exact pin: shared - customer confirmed they are at the location.';
      case VanExactPinSource.mapSelection:
        return 'Exact pin: chosen on map.';
    }
  }
}
