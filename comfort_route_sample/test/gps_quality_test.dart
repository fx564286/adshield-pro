import 'package:comfort_route_sample/gps_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('5m is good navigation accuracy', () {
    expect(GpsPolicy.quality(5), GpsQuality.good);
    expect(GpsPolicy.usableForNavigation(5), isTrue);
  });

  test('45m is the navigation ceiling', () {
    expect(GpsPolicy.usableForNavigation(45), isTrue);
    expect(GpsPolicy.usableForNavigation(45.1), isFalse);
  });

  test('100m is explicitly rejected for navigation', () {
    expect(GpsPolicy.quality(100), GpsQuality.poor);
    expect(GpsPolicy.usableForNavigation(100), isFalse);
    expect(GpsPolicy.uncertaintyLabel(100), contains('안정화 필요'));
  });

  test('accuracy copy describes uncertainty rather than symmetric plus-minus', () {
    final label = GpsPolicy.uncertaintyLabel(18.4);
    expect(label, contains('오차 약 18m'));
    expect(label, isNot(contains('±')));
  });
}
