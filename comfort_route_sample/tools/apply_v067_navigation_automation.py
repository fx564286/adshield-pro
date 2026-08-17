from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.7 UX/nav automation: destination selection immediately drives map + GPS
# + routing, camera intents survive vector-style startup, and live guidance uses
# a close dynamic follow zoom instead of leaving the whole-route overview on screen.
state_anchor = '''  int _gpsRejectedJumpCount = 0;
'''
state_new = state_anchor + '''  LatLng? _pendingCameraPoint;
  double? _pendingCameraZoom;
  double? _pendingCameraBearing;
  DateTime? _lastNavigationCameraAt;
  double? _lastNavigationCameraZoom;
'''
if state_anchor not in s:
    raise SystemExit('v067 GPS state anchor missing')
s = s.replace(state_anchor, state_new, 1)

# Replace the renderer camera bridge. Calls made while MapLibre is still loading
# are queued rather than silently discarded. Bearing is applied only by the
# vector renderer; raster compatibility mode still gets the same zoom/center.
move_re = re.compile(
    r"  void _moveActiveMap\(LatLng point, double zoom\) \{.*?\n  \}\n\n  Widget _buildRasterMap",
    re.S,
)
move_new = r'''  void _moveActiveMap(LatLng point, double zoom, {double? bearing}) {
    if (_vectorRendererActive) {
      final controller = _vectorMapController;
      if (_vectorStyleReady && controller != null) {
        final currentBearing = _vectorCameraPosition?.bearing ?? 0.0;
        controller.animateCamera(
          ml.CameraUpdate.newCameraPosition(
            ml.CameraPosition(
              target: ml.LatLng(point.latitude, point.longitude),
              zoom: zoom,
              bearing: bearing ?? currentBearing,
              tilt: _tracking ? 34.0 : 0.0,
            ),
          ),
          duration: const Duration(milliseconds: 520),
        );
        return;
      }
      _pendingCameraPoint = point;
      _pendingCameraZoom = zoom;
      _pendingCameraBearing = bearing;
      return;
    }
    if (_mapReady) {
      _mapController.move(point, zoom);
      return;
    }
    _pendingCameraPoint = point;
    _pendingCameraZoom = zoom;
    _pendingCameraBearing = bearing;
  }

  void _flushPendingMapCamera() {
    final point = _pendingCameraPoint;
    final zoom = _pendingCameraZoom;
    if (point == null || zoom == null) return;
    final bearing = _pendingCameraBearing;
    _pendingCameraPoint = null;
    _pendingCameraZoom = null;
    _pendingCameraBearing = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveActiveMap(point, zoom, bearing: bearing);
    });
  }

  Widget _buildRasterMap'''
s, count = move_re.subn(move_new, s, count=1)
if count != 1:
    raise SystemExit(f'active-map camera replacement failed: {count}')

# Flush camera intents as soon as either renderer actually becomes usable.
style_anchor = '''              _log('OpenFreeMap Positron 벡터 스타일 로드 완료');
              unawaited(_applyKoreanMapLabels());
              _syncVectorAnnotations();
'''
style_new = style_anchor + '              _flushPendingMapCamera();\n'
if style_anchor not in s:
    raise SystemExit('vector style callback camera anchor missing')
s = s.replace(style_anchor, style_new, 1)

raster_ready = '''                _log('지도 엔진 준비 완료');
'''
if raster_ready not in s:
    raise SystemExit('raster ready log anchor missing')
s = s.replace(raster_ready, raster_ready + '                _flushPendingMapCamera();\n', 1)

# Destination selection is now a single flow: map moves immediately and route
# fetch always runs. _fetchWalkingRoute itself acquires location when needed,
# removing the previous extra current-location/confirm step.
select_tail = '''    _log('목적지 지정 · $label · ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
    _syncVectorAnnotations();
    if (_position != null) await _fetchWalkingRoute();
'''
select_tail_new = '''    _log('목적지 지정 · $label · ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
    _syncVectorAnnotations();
    _moveActiveMap(point, 17.2);
    await _fetchWalkingRoute();
'''
if select_tail not in s:
    raise SystemExit('destination auto-route tail missing')
s = s.replace(select_tail, select_tail_new, 1)

# The search result itself is the confirmation. Do not issue a second direct
# raster camera call after _selectDestination; that method now owns all camera
# and route work for both vector and compatibility renderers.
result_old = '''                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _selectDestination(place.point, place.name);
                                    if (_mapReady) _moveActiveMap(place.point, 16);
                                  },'''
result_new = '''                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    unawaited(_selectDestination(place.point, place.name));
                                  },'''
if result_old in s:
    s = s.replace(result_old, result_new, 1)
else:
    # Older generated source may still contain the raw flutter_map call.
    result_raw = result_old.replace('_moveActiveMap(place.point, 16)', '_mapController.move(place.point, 16)')
    if result_raw not in s:
        raise SystemExit('search result immediate-select anchor missing')
    s = s.replace(result_raw, result_new, 1)

# Dynamic close-follow camera for live guidance. It is throttled to avoid camera
# animation storms. Near a turn/arrival it reaches ~18.9; during faster cycling
# it backs out slightly to preserve forward context.
guidance_anchor = '  void _updateGuidanceForAlongMeters(double alongMeters, {required bool allowVoice}) {\n'
camera_method = r'''  void _updateNavigationCamera(Position position) {
    if (!_tracking || _routePoints.length < 2 || !GpsPolicy.usableForNavigation(position.accuracy)) return;
    final now = DateTime.now();
    final nextDistance = _distanceToNextManeuverMeters;
    final speed = position.speed.isFinite && position.speed > 0 ? position.speed : 0.0;

    double zoom;
    if (_offRouteSamples > 0) {
      zoom = 17.1;
    } else if (nextDistance != null && nextDistance <= 35) {
      zoom = 18.9;
    } else if (nextDistance != null && nextDistance <= 120) {
      zoom = 18.6;
    } else if (nextDistance != null && nextDistance <= 300) {
      zoom = 18.25;
    } else if (speed >= 6.0) {
      zoom = 17.55;
    } else if (speed >= 2.8) {
      zoom = 17.9;
    } else {
      zoom = 18.2;
    }

    final sinceLast = _lastNavigationCameraAt == null
        ? const Duration(days: 1)
        : now.difference(_lastNavigationCameraAt!);
    final zoomDelta = _lastNavigationCameraZoom == null
        ? double.infinity
        : (zoom - _lastNavigationCameraZoom!).abs();
    if (sinceLast < const Duration(milliseconds: 850) && zoomDelta < 0.28) return;

    final point = _displayLocationPoint ?? _navigationPointFor(position);
    final validHeading = position.heading.isFinite &&
        position.heading >= 0 &&
        position.heading <= 360 &&
        speed >= 0.7;
    _lastNavigationCameraAt = now;
    _lastNavigationCameraZoom = zoom;
    _moveActiveMap(point, zoom, bearing: validHeading ? position.heading : null);
  }

'''
if guidance_anchor not in s:
    raise SystemExit('guidance method anchor missing')
s = s.replace(guidance_anchor, camera_method + guidance_anchor, 1)

progress_anchor = '''    _updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);
'''
progress_new = progress_anchor + '    _updateNavigationCamera(position);\n'
if progress_anchor not in s:
    raise SystemExit('guidance progress hook missing')
s = s.replace(progress_anchor, progress_new, 1)

# Enter guidance camera immediately when live tracking starts rather than waiting
# for the next several metres of movement.
tracking_start = '''      unawaited(_refreshTtsStatus());
      _log('실시간 위치 추적 시작 · Fused 고정밀 · 이동 갱신 조건 2m · 내비 허용 오차 45m · 적응형 보정');
'''
tracking_start_new = '''      unawaited(_refreshTtsStatus());
      final currentForCamera = _position;
      if (currentForCamera != null) _updateNavigationCamera(currentForCamera);
      _log('실시간 위치 추적 시작 · Fused 고정밀 · 이동 갱신 조건 2m · 내비 허용 오차 45m · 적응형 보정');
'''
if tracking_start not in s:
    raise SystemExit('v067 tracking start camera anchor missing')
s = s.replace(tracking_start, tracking_start_new, 1)

# Do not let the whole-route preview zoom overwrite live close guidance after a
# reroute or destination change while tracking.
fit_anchor = '''    if (fitMap && route.points.isNotEmpty && _routeStart != null && _destination != null) {
'''
fit_new = '''    if (fitMap && !_tracking && route.points.isNotEmpty && _routeStart != null && _destination != null) {
'''
if fit_anchor not in s:
    raise SystemExit('route overview fit anchor missing')
s = s.replace(fit_anchor, fit_new, 1)

# Diagnostics make camera automation visible when QAing a physical device.
diag_anchor = "          _KeyValueRow(label: '경로 시각 스냅', value: _displayRouteSnapMeters == null ? '-' : (_displayRouteSnapMeters! <= 0 ? '미사용' : '${_displayRouteSnapMeters!.toStringAsFixed(1)} m · 표시만 보정')),\n"
diag_new = diag_anchor + """          _KeyValueRow(label: '내비 카메라', value: !_tracking ? '대기' : (_lastNavigationCameraZoom == null ? '추적 시작' : '자동 추적 · zoom ${_lastNavigationCameraZoom!.toStringAsFixed(1)}')),
"""
if diag_anchor not in s:
    raise SystemExit('route snap diagnostic anchor missing')
s = s.replace(diag_anchor, diag_new, 1)

required = [
    'void _flushPendingMapCamera()',
    '_pendingCameraPoint = point;',
    '_moveActiveMap(point, 17.2);',
    'await _fetchWalkingRoute();',
    'void _updateNavigationCamera(Position position)',
    'zoom = 18.9;',
    '_updateNavigationCamera(position);',
    'if (fitMap && !_tracking',
    '자동 추적 · zoom',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing navigation automation marker: {marker}')

p.write_text(s)
print('APPLY_V067_NAVIGATION_AUTOMATION: PASS')
