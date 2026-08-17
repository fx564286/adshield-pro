import 'package:comfort_route_sample/route_mode_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty route list returns -1', () {
    expect(chooseRouteIndex(const [], RoutePreference.fast), -1);
  });

  test('single route is used for every preference', () {
    const routes = [
      RouteScoreInput(distanceMeters: 1200, durationSeconds: 900),
    ];
    for (final preference in RoutePreference.values) {
      expect(chooseRouteIndex(routes, preference), 0);
    }
  });

  test('fast preference favors lower travel time', () {
    const routes = [
      RouteScoreInput(distanceMeters: 1300, durationSeconds: 760, sourceIndex: 0),
      RouteScoreInput(distanceMeters: 1100, durationSeconds: 820, sourceIndex: 1),
    ];
    expect(chooseRouteIndex(routes, RoutePreference.fast), 0);
  });

  test('pleasant preference may accept a small detour for comfort signals', () {
    const routes = [
      RouteScoreInput(distanceMeters: 1200, durationSeconds: 760, sourceIndex: 0),
      RouteScoreInput(
        distanceMeters: 1240,
        durationSeconds: 785,
        comfortSignalHits: 8,
        sourceIndex: 1,
      ),
    ];
    expect(chooseRouteIndex(routes, RoutePreference.pleasant), 1);
  });

  test('weather avoidance may accept a small detour for shelter signals', () {
    const routes = [
      RouteScoreInput(distanceMeters: 1200, durationSeconds: 760, sourceIndex: 0),
      RouteScoreInput(
        distanceMeters: 1260,
        durationSeconds: 800,
        shelterSignalHits: 8,
        sourceIndex: 1,
      ),
    ];
    expect(chooseRouteIndex(routes, RoutePreference.weatherAvoid), 1);
  });

  test('invalid durations do not win ranking', () {
    const routes = [
      RouteScoreInput(distanceMeters: 1000, durationSeconds: 0, sourceIndex: 0),
      RouteScoreInput(distanceMeters: 1200, durationSeconds: 800, sourceIndex: 1),
    ];
    expect(chooseRouteIndex(routes, RoutePreference.fast), 1);
  });
}
