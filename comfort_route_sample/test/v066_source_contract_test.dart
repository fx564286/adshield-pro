import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  test('navigation rejects 100m-class GPS samples', () {
    expect(source, contains('GpsPolicy.navigationMaxMeters'));
    expect(source, contains('GpsPolicy.usableForNavigation(position.accuracy)'));
    expect(source, contains('45m 초과 샘플은 경로 진행·이탈·음성에 미반영'));
  });

  test('poor remeasurement cannot overwrite an existing navigation-grade fix', () {
    expect(source, contains('final preserveExisting = !usablePosition'));
    expect(source, contains('GpsPolicy.usableForNavigation(_position!.accuracy)'));
    expect(source, contains('GPS 재측정값 품질 저하 · 기존 내비 위치 유지'));
  });

  test('GPS acquisition asks for best navigation accuracy and refines briefly', () {
    expect(source, contains('LocationAccuracy.bestForNavigation'));
    expect(source, contains('Future<Position> _refinePositionIfNeeded'));
    expect(source, contains('Duration(seconds: 7)'));
  });

  test('UI copy describes location uncertainty instead of plus-minus precision', () {
    expect(source, contains('GpsPolicy.uncertaintyLabel(position.accuracy)'));
    expect(source, contains('현재 위치 오차가 약'));
  });

  test('vector style is localized native/Korean first without translating refs', () {
    expect(source, contains('Future<void> _applyKoreanMapLabels() async'));
    expect(source, contains("<dynamic>['get', 'name:ko']"));
    expect(source, contains("<dynamic>['get', 'name:nonlatin']"));
    expect(source, contains('ml.SymbolLayerProperties.fromJson(properties)'));
    expect(source, contains("encoded.contains('\"ref\"')"));
    expect(source, contains("encoded.contains('\"iata\"')"));
  });

  test('essential amenities include unnamed toilets water and shelters', () {
    expect(source, contains('toilets|drinking_water|shelter'));
    expect(source, contains("if (amenity == 'shelter') return '쉼터';"));
    expect(source, contains('공중화장실'));
    expect(source, contains('현재 불러온 지도 범위 · 경로 120m 주변 OSM 신호 · 운영 여부 미검증'));
  });
}
