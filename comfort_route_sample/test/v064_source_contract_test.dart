import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
  });

  test('raster camera fallback is not recursively calling itself', () {
    expect(source, contains('if (_mapReady) _mapController.move(point, zoom);'));
    expect(source, isNot(contains('if (_mapReady) _moveActiveMap(point, zoom);')));
  });

  test('route requests ask for alternatives and protect against stale responses', () {
    expect(source, contains('alternatives=3'));
    expect(source, contains('_routeRequestQueued = true'));
    expect(source, contains('오래된 경로 응답 폐기'));
  });

  test('zooming out invalidates pending POI responses', () {
    expect(source, contains('++_poiRequestGeneration;'));
  });

  test('vector startup has an automatic compatibility fallback', () {
    expect(source, contains("_log('벡터 스타일 준비 지연 · 호환 지도 자동 전환')"));
    expect(source, contains('_vectorStartupGuard = Timer'));
  });
}
