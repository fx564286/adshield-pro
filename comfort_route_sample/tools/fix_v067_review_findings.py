from pathlib import Path

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# AndroidSettings is re-exported by geolocator 14.x. Keep geolocator_android
# pinned in pubspec for implementation reproducibility, but do not import its
# library redundantly in app code. Its constructors are not const in 5.0.3.
s = s.replace("import 'package:geolocator_android/geolocator_android.dart';\n", '', 1)
s = s.replace('const AndroidSettings(', 'AndroidSettings(')
s = s.replace(
    '    final p = _position;\n    final displayPoint = _displayLocationPoint;\n    final center = displayPoint ?? _fallbackCenter;\n',
    '    final displayPoint = _displayLocationPoint;\n    final center = displayPoint ?? _fallbackCenter;\n',
    1,
)

# Destination selection is a navigation intent, unlike a later route-mode
# refresh. Keep an explicit one-shot flag so only this flow can automatically
# start live tracking after a valid route is actually received.
state_anchor = '  double? _lastNavigationCameraZoom;\n'
state_new = state_anchor + '  bool _autoStartGuidanceOnNextRoute = false;\n'
if state_anchor not in s:
    raise SystemExit('v067 nav camera state anchor missing')
s = s.replace(state_anchor, state_new, 1)

select_anchor = '''    _syncVectorAnnotations();
    _moveActiveMap(point, 17.2);
    await _fetchWalkingRoute();
'''
select_new = '''    _syncVectorAnnotations();
    _moveActiveMap(point, 17.2);
    _autoStartGuidanceOnNextRoute = true;
    await _fetchWalkingRoute();
'''
if select_anchor not in s:
    raise SystemExit('v067 immediate destination routing anchor missing')
s = s.replace(select_anchor, select_new, 1)

# Do not key this insertion to user-visible logging; earlier lint normalization
# legitimately changes interpolation syntax. Route selection itself is the
# stable semantic anchor.
route_success_anchor = '      _applyRoutePreferenceSelection(fitMap: !autoReroute);\n'
route_success_new = route_success_anchor + '''      if (!autoReroute && _autoStartGuidanceOnNextRoute) {
        _autoStartGuidanceOnNextRoute = false;
        if (!_tracking) {
          Future<void>.microtask(() async {
            if (!mounted || _tracking) return;
            await _toggleTracking();
          });
        }
      }
'''
if route_success_anchor not in s:
    raise SystemExit('route selection auto-guidance anchor missing')
s = s.replace(route_success_anchor, route_success_new, 1)

# Keep the smoothing coefficient observable so QA can distinguish heavy
# stationary damping from fast-motion tracking and strict analyzer sees the
# state as intentionally used.
diag_old = "          _KeyValueRow(label: '내비 카메라', value: !_tracking ? '대기' : (_lastNavigationCameraZoom == null ? '추적 시작' : '자동 추적 · zoom ${_lastNavigationCameraZoom!.toStringAsFixed(1)}')),\n"
diag_new = """          _KeyValueRow(label: '평활 계수', value: _gpsSmoothingAlpha == null ? '-' : _gpsSmoothingAlpha!.toStringAsFixed(2)),
          _KeyValueRow(label: '내비 카메라', value: !_tracking ? '대기' : (_lastNavigationCameraZoom == null ? '추적 시작' : '자동 추적 · zoom ${_lastNavigationCameraZoom!.toStringAsFixed(1)}')),
"""
if diag_old not in s:
    raise SystemExit('v067 camera diagnostic anchor missing')
s = s.replace(diag_old, diag_new, 1)

# Nominatim public service must not be used as per-keystroke autocomplete. Keep
# the request explicitly user-triggered, but once that search completes update
# the map immediately to the top result. The user can still pick another result
# before route selection, so we avoid silently routing to the wrong place.
search_old = '''              final found = await _searchPlaces(controller.text);
              if (!sheetContext.mounted) return;
              setSheetState(() => results = found);
'''
search_new = '''              final found = await _searchPlaces(controller.text);
              if (!sheetContext.mounted) return;
              setSheetState(() => results = found);
              if (found.isNotEmpty) {
                _moveActiveMap(found.first.point, 16.8);
                _log('검색 결과 지도 즉시 미리보기 · ${found.first.name}');
              }
'''
if search_old not in s:
    raise SystemExit('destination search result update anchor missing')
s = s.replace(search_old, search_new, 1)

# Ensure the helper copy no longer implies the user must press a second
# confirmation button after a result is chosen.
s = s.replace(
    '검색 버튼을 눌렀을 때만 실제 장소 검색을 실행합니다.',
    '검색하면 첫 결과를 지도에 바로 보여드리고, 결과를 누르면 즉시 경로를 계산합니다.',
    1,
)

# At high navigation zoom, centering the camera directly on the blue dot wastes
# half the viewport behind the user. Move the camera target 18-60m ahead along
# the route geometry while keeping navigation/off-route calculations on the
# stabilized unsnapped coordinate.
camera_anchor = '  void _updateNavigationCamera(Position position) {\n'
lookahead_method = r'''  LatLng? _routePointAtAlongMeters(double alongMeters) {
    if (_routePoints.isEmpty || _routeCumulativeMeters.length != _routePoints.length) return null;
    final total = _routeCumulativeMeters.last;
    if (total <= 0) return _routePoints.first;
    final target = alongMeters.clamp(0.0, total).toDouble();
    for (var i = 0; i < _routePoints.length - 1; i++) {
      final start = _routeCumulativeMeters[i];
      final end = _routeCumulativeMeters[i + 1];
      if (target > end && i < _routePoints.length - 2) continue;
      final span = end - start;
      final t = span <= 0 ? 0.0 : ((target - start) / span).clamp(0.0, 1.0).toDouble();
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    return _routePoints.last;
  }

'''
if camera_anchor not in s:
    raise SystemExit('navigation camera method anchor missing')
s = s.replace(camera_anchor, lookahead_method + camera_anchor, 1)

camera_point_old = '''    final point = _displayLocationPoint ?? _navigationPointFor(position);
    final validHeading = position.heading.isFinite &&
'''
camera_point_new = '''    final basePoint = _displayLocationPoint ?? _navigationPointFor(position);
    var point = basePoint;
    if (_offRouteSamples == 0) {
      final routeProjection = _projectPointToRoute(_navigationPointFor(position));
      if (routeProjection != null) {
        final lookAheadMeters = nextDistance != null && nextDistance <= 35
            ? math.min(18.0, nextDistance)
            : speed >= 6.0
                ? 60.0
                : speed >= 2.8
                    ? 48.0
                    : 34.0;
        point = _routePointAtAlongMeters(routeProjection.alongMeters + lookAheadMeters) ?? basePoint;
      }
    }
    final validHeading = position.heading.isFinite &&
'''
if camera_point_old not in s:
    raise SystemExit('navigation camera target anchor missing')
s = s.replace(camera_point_old, camera_point_new, 1)

required = [
    'AndroidSettings(',
    'forceLocationManager: false',
    "_KeyValueRow(label: '평활 계수'",
    '_moveActiveMap(found.first.point, 16.8);',
    '검색 결과 지도 즉시 미리보기',
    '결과를 누르면 즉시 경로를 계산합니다.',
    '_autoStartGuidanceOnNextRoute = true;',
    'Future<void>.microtask(() async',
    'LatLng? _routePointAtAlongMeters(double alongMeters)',
    'routeProjection.alongMeters + lookAheadMeters',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v067 review fix marker: {marker}')

p.write_text(s)
print('FIX_V067_REVIEW_FINDINGS: PASS')
