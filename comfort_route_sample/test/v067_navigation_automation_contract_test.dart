import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  test('destination selection immediately moves map and computes route', () {
    expect(source, contains('_moveActiveMap(point, 17.2);'));
    expect(source, contains('await _fetchWalkingRoute();'));
    expect(source, isNot(contains('if (_position != null) await _fetchWalkingRoute();')));
  });

  test('explicit search updates the map immediately without auto-routing wrong top result', () {
    expect(source, contains('_moveActiveMap(found.first.point, 16.8);'));
    expect(source, contains('검색 결과 지도 즉시 미리보기'));
    expect(source, contains('unawaited(_selectDestination(place.point, place.name));'));
  });

  test('camera commands survive vector style startup', () {
    expect(source, contains('LatLng? _pendingCameraPoint'));
    expect(source, contains('void _flushPendingMapCamera()'));
    expect(source, contains('_pendingCameraPoint = point;'));
  });

  test('live guidance uses close dynamic zoom and does not get overwritten by overview', () {
    expect(source, contains('void _updateNavigationCamera(Position position)'));
    expect(source, contains('zoom = 18.9;'));
    expect(source, contains('zoom = 18.6;'));
    expect(source, contains('zoom = 18.2;'));
    expect(source, contains('if (fitMap && !_tracking'));
  });

  test('off-route state widens view and display snap stays outside route logic', () {
    expect(source, contains('if (_offRouteSamples > 0)'));
    expect(source, contains('zoom = 17.1;'));
    expect(source, contains('_projectPointToRoute(_navigationPointFor(position))'));
  });
}
