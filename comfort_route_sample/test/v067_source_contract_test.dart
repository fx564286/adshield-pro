import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  test('Android location stays on Fused provider with denser navigation samples', () {
    expect(source, contains('AndroidSettings('));
    expect(source, contains('forceLocationManager: false'));
    expect(source, contains('distanceFilter: 2'));
    expect(source, contains('intervalDuration: Duration(seconds: 1)'));
    expect(source, isNot(contains("import 'package:geolocator_android/geolocator_android.dart';")));
  });

  test('navigation uses adaptive stabilized coordinates and rejects teleport jumps', () {
    expect(source, contains('GpsStabilizer _gpsStabilizer'));
    expect(source, contains('GpsStabilizerDecision.implausibleJump'));
    expect(source, contains('GPS 순간이동 튐 제거'));
    expect(source, contains('_projectPointToRoute(_navigationPointFor(position))'));
  });

  test('route snapping changes display only and not off-route input', () {
    expect(source, contains('LatLng? get _displayLocationPoint'));
    expect(source, contains('projection.distanceMeters <= snapLimit ? projection.point : base'));
    expect(source, contains('_projectPositionToRoute(Position position) =>'));
    expect(source, contains('_projectPointToRoute(_navigationPointFor(position))'));
    expect(source, contains('표시만 보정'));
  });

  test('diagnostics never claim filtering changed GNSS sensor accuracy', () {
    expect(source, contains("_KeyValueRow(label: '최근 GPS'"));
    expect(source, contains("_KeyValueRow(label: 'GPS 보정'"));
    expect(source, contains("_KeyValueRow(label: '원시→보정 차이'"));
    expect(source, isNot(contains('보정 정확도 ±')));
  });
}
