from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# Review finding: when MapLibre times out, the raster FlutterMap is only mounted
# on the next frame. Do not advertise map readiness before its onMapReady fires.
old_fallback = '''                setState(() {
                  _useVectorMap = false;
                  _vectorFallbackUsed = true;
                  _mapReady = true;
                });'''
new_fallback = '''                setState(() {
                  _useVectorMap = false;
                  _vectorFallbackUsed = true;
                  _mapReady = false;
                });'''
if old_fallback not in s:
    raise SystemExit('vector fallback readiness anchor missing')
s = s.replace(old_fallback, new_fallback, 1)

# Review finding: if a newer destination/route request arrived while waiting for
# GPS, abort this stale request before spending another public routing call.
route_accuracy_anchor = '''      if (!_positionUsableForRouting) {
        final accuracy = _position?.accuracy;
        if (!autoReroute) {
          _showMessage(accuracy == null
              ? '현재 위치를 먼저 받아 주세요.'
              : 'GPS 정확도가 ±${accuracy.toStringAsFixed(0)}m입니다. 80m 이하에서 경로를 계산해 주세요.');
        } else {
          _log('자동 재탐색 보류 · GPS 정확도 부족');
        }
        return;
      }

      final start = LatLng(_position!.latitude, _position!.longitude);'''
route_accuracy_new = '''      if (!_positionUsableForRouting) {
        final accuracy = _position?.accuracy;
        if (!autoReroute) {
          _showMessage(accuracy == null
              ? '현재 위치를 먼저 받아 주세요.'
              : 'GPS 정확도가 ±${accuracy.toStringAsFixed(0)}m입니다. 80m 이하에서 경로를 계산해 주세요.');
        } else {
          _log('자동 재탐색 보류 · GPS 정확도 부족');
        }
        return;
      }
      if (requestGeneration != _routeRequestGeneration || !_samePoint(destination, _destination)) {
        _log('GPS 대기 중 무효화된 경로 요청 중단');
        return;
      }

      final start = LatLng(_position!.latitude, _position!.longitude);'''
if route_accuracy_anchor not in s:
    raise SystemExit('route accuracy/stale anchor missing')
s = s.replace(route_accuracy_anchor, route_accuracy_new, 1)

# Review finding: requesting numeric alternatives is valid OSRM syntax, but a
# public backend can still reject or disable alternatives. Retry once with a
# normal single-route request so the previously-working navigation path does not
# regress just because alternatives are unavailable.
route_http_anchor = '''      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true&alternatives=3',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;'''
route_http_new = '''      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

      Future<({int statusCode, String body})> requestRoutes(String alternatives) async {
        final uri = Uri.parse(
          'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
          '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=$alternatives',
        );
        final request = await client!.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        final response = await request.close().timeout(const Duration(seconds: 15));
        final body = await response.transform(utf8.decoder).join();
        return (statusCode: response.statusCode, body: body);
      }

      var routeResponse = await requestRoutes('3');
      if (routeResponse.statusCode < 200 || routeResponse.statusCode >= 300) {
        _log('대안 경로 요청 HTTP ${routeResponse.statusCode} · 단일 경로로 재시도');
        routeResponse = await requestRoutes('false');
      }
      if (routeResponse.statusCode < 200 || routeResponse.statusCode >= 300) {
        throw HttpException('HTTP ${routeResponse.statusCode}');
      }
      final decoded = jsonDecode(routeResponse.body) as Map<String, dynamic>;'''
if route_http_anchor not in s:
    raise SystemExit('route HTTP alternatives anchor missing')
s = s.replace(route_http_anchor, route_http_new, 1)

# Dart lint: only strip braces around bare identifiers. Property/index/expression
# interpolations retain braces.
s = re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}', r'$\1', s)

required = [
    '_mapReady = false;',
    'GPS 대기 중 무효화된 경로 요청 중단',
    '대안 경로 요청 HTTP',
    "routeResponse = await requestRoutes('false');",
    'if (_mapReady) _mapController.move(point, zoom);',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing review fix marker: {marker}')

p.write_text(s)
print('FIX_V064_REVIEW_FINDINGS: PASS')
