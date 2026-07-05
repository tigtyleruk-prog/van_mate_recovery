import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/pages/jobs_calendar_page.dart';

void main() {
  test('developer cleanup tools stay hidden outside debug builds', () {
    expect(showVanMateDeveloperTools(isDebugMode: false), isFalse);
  });

  test('developer cleanup tools are available in debug builds', () {
    expect(showVanMateDeveloperTools(isDebugMode: true), isTrue);
  });
}
