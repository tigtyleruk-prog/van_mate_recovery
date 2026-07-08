import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/models/van_exact_pin_source.dart';
import 'package:van_mate_app/features/van_mate/pages/create_job_request_flow.dart';

void main() {
  test('captured current location shows completed current-location state', () {
    expect(
      isVanCustomerCurrentLocationExactPinCaptured(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
      ),
      isTrue,
    );
    expect(
      vanCustomerCurrentLocationExactPinButtonLabel(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
      ),
      '\u2713 Current location captured',
    );
    expect(
      vanCustomerExactPinHelperText(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
        exactPinSubmitted: false,
      ),
      '\u2713 Current location captured',
    );
  });

  test('confirm button only enables when a valid exact pin exists', () {
    expect(
      hasVanCustomerExactPinSelection(
        exactPinShared: false,
        source: VanExactPinSource.currentLocation,
        latitude: 53.48,
        longitude: -2.24,
      ),
      isFalse,
    );
    expect(
      hasVanCustomerExactPinSelection(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
        latitude: null,
        longitude: -2.24,
      ),
      isFalse,
    );
    expect(
      hasVanCustomerExactPinSelection(
        exactPinShared: true,
        source: null,
        latitude: 53.48,
        longitude: -2.24,
      ),
      isFalse,
    );
    expect(
      hasVanCustomerExactPinSelection(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
        latitude: 53.48,
        longitude: -2.24,
      ),
      isTrue,
    );
    expect(
      canVanCustomerSubmitExactPin(
        requestUnavailable: false,
        hasValidExactPinSelection: false,
        isCapturingCurrentLocation: false,
        isSubmittingExactPin: false,
        exactPinSubmitted: false,
      ),
      isFalse,
    );
    expect(
      canVanCustomerSubmitExactPin(
        requestUnavailable: false,
        hasValidExactPinSelection: true,
        isCapturingCurrentLocation: false,
        isSubmittingExactPin: false,
        exactPinSubmitted: false,
      ),
      isTrue,
    );
    expect(
      canVanCustomerSubmitExactPin(
        requestUnavailable: false,
        hasValidExactPinSelection: true,
        isCapturingCurrentLocation: true,
        isSubmittingExactPin: false,
        exactPinSubmitted: false,
      ),
      isFalse,
    );
  });

  test('submitted exact pin locks selection buttons and relabels confirm', () {
    expect(
      isVanCustomerExactPinSelectionLocked(
        isCapturingCurrentLocation: true,
        isSubmittingExactPin: false,
        exactPinSubmitted: false,
      ),
      isTrue,
    );
    expect(
      isVanCustomerExactPinSelectionLocked(
        isSubmittingExactPin: true,
        exactPinSubmitted: false,
      ),
      isTrue,
    );
    expect(
      isVanCustomerExactPinSelectionLocked(
        isSubmittingExactPin: false,
        exactPinSubmitted: true,
      ),
      isTrue,
    );
    expect(
      vanCustomerExactPinConfirmButtonLabel(
        isSubmittingExactPin: false,
        exactPinSubmitted: true,
      ),
      'Exact location sent \u2713',
    );
    expect(
      vanCustomerExactPinHelperText(
        exactPinShared: true,
        source: VanExactPinSource.currentLocation,
        exactPinSubmitted: true,
      ),
      'Exact location sent. No further changes are needed.',
    );
  });

  test('map selection still allows location changes when needed', () {
    expect(
      isVanCustomerCurrentLocationExactPinCaptured(
        exactPinShared: true,
        source: VanExactPinSource.mapSelection,
      ),
      isFalse,
    );
    expect(
      vanCustomerCurrentLocationExactPinButtonLabel(
        exactPinShared: true,
        source: VanExactPinSource.mapSelection,
      ),
      'I\'m at the exact spot now',
    );
    expect(
      vanCustomerRetakeCurrentLocationExactPinButtonLabel(),
      'Retake current location',
    );
    expect(
      vanCustomerExactPinMapButtonLabel(exactPinShared: true),
      'Choose the spot on a map',
    );
    expect(
      vanCustomerExactPinConfirmButtonLabel(
        isSubmittingExactPin: false,
        exactPinSubmitted: false,
      ),
      'Confirm exact location',
    );
  });
}
