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

# Dart lint: only strip braces around bare identifiers. Property/index/expression
# interpolations retain braces.
s = re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}', r'$\1', s)

required = [
    '_mapReady = false;',
    'GPS 대기 중 무효화된 경로 요청 중단',
    'if (_mapReady) _mapController.move(point, zoom);',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing review fix marker: {marker}')

p.write_text(s)
print('FIX_V064_REVIEW_FINDINGS: PASS')
