from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.7: improve effective navigation stability without fabricating a better
# sensor accuracy number. Android stays on Fused Location Provider, receives
# denser high-accuracy samples, rejects implausible jumps, adaptively smooths
# accepted fixes, and only visually snaps the marker to a route at close range.
quality_import = "import 'package:comfort_route_sample/gps_quality.dart';\n"
if quality_import not in s:
    raise SystemExit('gps quality import missing')
s = s.replace(
    quality_import,
    quality_import + "import 'package:comfort_route_sample/gps_stabilizer.dart';\n",
    1,
)
geolocator_import = "import 'package:geolocator/geolocator.dart';\n"
if geolocator_import not in s:
    raise SystemExit('geolocator import missing')
s = s.replace(
    geolocator_import,
    geolocator_import + "import 'package:geolocator_android/geolocator_android.dart';\n",
    1,
)
s = s.replace(
    'ComfortRoute/0.6.6 (com.fx564286.comfort_route_sample)',
    'ComfortRoute/0.6.7 (com.fx564286.comfort_route_sample)',
    1,
)

# Route projection now also carries its nearest geometry point. This is used
# only for the visual marker snap; off-route detection still sees the stabilized
# unsnapped position so the UI cannot hide a genuine route departure.
projection_old = '''class _RouteProjection {
  const _RouteProjection({required this.distanceMeters, required this.alongMeters});
  final double distanceMeters;
  final double alongMeters;
}
'''
projection_new = '''class _RouteProjection {
  const _RouteProjection({
    required this.distanceMeters,
    required this.alongMeters,
    required this.point,
  });
  final double distanceMeters;
  final double alongMeters;
  final LatLng point;
}
'''
if projection_old not in s:
    raise SystemExit('route projection class anchor missing')
s = s.replace(projection_old, projection_new, 1)

state_anchor = '''  int _koreanLabelLayerCount = 0;
'''
state_new = state_anchor + '''  final GpsStabilizer _gpsStabilizer = GpsStabilizer(
    maxNavigationAccuracyMeters: GpsPolicy.navigationMaxMeters,
  );
  LatLng? _stabilizedPosition;
  double? _gpsSmoothingAlpha;
  int _gpsRejectedJumpCount = 0;
'''
if state_anchor not in s:
    raise SystemExit('v066 GPS state anchor missing')
s = s.replace(state_anchor, state_new, 1)

# Explicit Android Fused Location settings. forceLocationManager=false keeps the
# modern FusedLocationProviderClient path instead of the legacy LocationManager.
# A 2m distance filter gives the stabilizer enough samples for walking turns;
# this does not claim 2m sensor accuracy.
s = s.replace(
    '''locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),''',
    '''locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: Duration(seconds: 1),
        ),''',
    1,
)
s = s.replace(
    '''locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),''',
    '''locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          forceLocationManager: false,
          intervalDuration: Duration(seconds: 1),
          timeLimit: Duration(seconds: 20),
        ),''',
    1,
)
s = s.replace(
    '''locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),''',
    '''locationSettings: const AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
          forceLocationManager: false,
          intervalDuration: Duration(seconds: 1),
        ),''',
    1,
)

# Helpers are intentionally separate from Position so filtered coordinates can
# improve navigation/display while the original sensor accuracy remains intact.
refine_anchor = '  Future<Position> _refinePositionIfNeeded(Position initial) async {\n'
helpers = r'''  GpsStabilizedFix _stabilizeGps(Position position) {
    return _gpsStabilizer.add(GpsSample(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMps: position.speed,
      timestamp: position.timestamp,
    ));
  }

  LatLng _navigationPointFor(Position position) =>
      _stabilizedPosition ?? LatLng(position.latitude, position.longitude);

  double? get _rawToStabilizedMeters {
    final raw = _position;
    final filtered = _stabilizedPosition;
    if (raw == null || filtered == null) return null;
    return Geolocator.distanceBetween(
      raw.latitude,
      raw.longitude,
      filtered.latitude,
      filtered.longitude,
    );
  }

  LatLng? get _displayLocationPoint {
    final raw = _position;
    if (raw == null) return null;
    final base = _stabilizedPosition ?? LatLng(raw.latitude, raw.longitude);
    if (_routePoints.length < 2 || _offRouteSamples > 0) return base;
    final projection = _projectPointToRoute(base);
    if (projection == null) return base;
    final snapLimit = math.min(18.0, math.max(7.0, raw.accuracy * 0.6));
    return projection.distanceMeters <= snapLimit ? projection.point : base;
  }

  double? get _displayRouteSnapMeters {
    final raw = _position;
    final base = _stabilizedPosition;
    final display = _displayLocationPoint;
    if (raw == null || base == null || display == null) return null;
    final distance = Geolocator.distanceBetween(
      base.latitude,
      base.longitude,
      display.latitude,
      display.longitude,
    );
    return distance < 0.5 ? 0 : distance;
  }

'''
if refine_anchor not in s:
    raise SystemExit('GPS refine method anchor missing')
s = s.replace(refine_anchor, helpers + refine_anchor, 1)

# A good first fix can still be a one-frame teleport relative to the accepted
# history. Preserve the previous navigation position when the stabilizer rejects it.
acquire_old = r'''      final usablePosition = GpsPolicy.usableForNavigation(position.accuracy);
      final preserveExisting = !usablePosition &&
          _position != null &&
          GpsPolicy.usableForNavigation(_position!.accuracy);
      setState(() {
        _latestRawAccuracyMeters = position.accuracy;
        if (!preserveExisting) _position = position;
        _locationError = null;
      });
      _log('실제 GPS 수신 · ${GpsPolicy.uncertaintyLabel(position.accuracy)}');
      if (usablePosition) {
        _updateNavigationProgress(position);
      } else if (preserveExisting) {
        _log('GPS 재측정값 품질 저하 · 기존 내비 위치 유지');
      } else {
        _log('GPS 안정화 필요 · 45m 초과 샘플은 경로 진행·이탈·음성에 미반영');
      }
'''
acquire_new = r'''      final usablePosition = GpsPolicy.usableForNavigation(position.accuracy);
      final stabilization = usablePosition ? _stabilizeGps(position) : null;
      final jumpRejected = stabilization?.decision == GpsStabilizerDecision.implausibleJump;
      final preserveExisting = (!usablePosition || jumpRejected) &&
          _position != null &&
          GpsPolicy.usableForNavigation(_position!.accuracy);
      setState(() {
        _latestRawAccuracyMeters = position.accuracy;
        if (stabilization?.accepted ?? false) {
          _stabilizedPosition = LatLng(stabilization!.latitude, stabilization.longitude);
          _gpsSmoothingAlpha = stabilization.alpha;
        }
        if (jumpRejected) _gpsRejectedJumpCount++;
        if (!preserveExisting && !jumpRejected) _position = position;
        _locationError = null;
      });
      _log('실제 GPS 수신 · ${GpsPolicy.uncertaintyLabel(position.accuracy)}');
      if (jumpRejected) {
        _log('GPS 순간이동 튐 제거 · ${stabilization!.rawDisplacementMeters.toStringAsFixed(0)}m 점프 무시');
      } else if (usablePosition && (stabilization?.accepted ?? false)) {
        _updateNavigationProgress(position);
      } else if (preserveExisting) {
        _log('GPS 재측정값 품질 저하 · 기존 내비 위치 유지');
      } else {
        _log('GPS 안정화 필요 · 45m 초과 샘플은 경로 진행·이탈·음성에 미반영');
      }
'''
if acquire_old not in s:
    raise SystemExit('v066 manual acquire hardening anchor missing')
s = s.replace(acquire_old, acquire_new, 1)

tracking_old = r'''          setState(() {
            _position = position;
            _locationError = null;
          });
          _updateNavigationProgress(position);
          _syncVectorAnnotations();
'''
tracking_new = r'''          final stabilization = _stabilizeGps(position);
          if (!stabilization.accepted) {
            if (stabilization.decision == GpsStabilizerDecision.implausibleJump) {
              setState(() => _gpsRejectedJumpCount++);
              _log('GPS 순간이동 튐 제거 · ${stabilization.rawDisplacementMeters.toStringAsFixed(0)}m 점프 무시');
            }
            return;
          }
          setState(() {
            _position = position;
            _stabilizedPosition = LatLng(stabilization.latitude, stabilization.longitude);
            _gpsSmoothingAlpha = stabilization.alpha;
            _locationError = null;
          });
          _updateNavigationProgress(position);
          _syncVectorAnnotations();
'''
if tracking_old not in s:
    raise SystemExit('v066 tracking accept anchor missing')
s = s.replace(tracking_old, tracking_new, 1)

# Refactor route projection to accept the stabilized point and expose the
# nearest geometry coordinate for display-only snapping.
project_re = re.compile(
    r"  _RouteProjection\? _projectPositionToRoute\(Position position\) \{.*?\n  \}\n\n  void _updateNavigationProgress",
    re.S,
)
project_new = r'''  _RouteProjection? _projectPointToRoute(LatLng position) {
    if (_routePoints.length < 2 || _routeCumulativeMeters.length != _routePoints.length) {
      return null;
    }
    final latScale = 111132.0;
    final lonScale = math.max(1.0, 111320.0 * math.cos(position.latitude * math.pi / 180).abs());
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    var bestPoint = position;

    for (var i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      final ax = (a.longitude - position.longitude) * lonScale;
      final ay = (a.latitude - position.latitude) * latScale;
      final bx = (b.longitude - position.longitude) * lonScale;
      final by = (b.latitude - position.latitude) * latScale;
      final dx = bx - ax;
      final dy = by - ay;
      final denom = dx * dx + dy * dy;
      final rawT = denom <= 0 ? 0.0 : -((ax * dx) + (ay * dy)) / denom;
      final t = rawT.clamp(0.0, 1.0).toDouble();
      final px = ax + dx * t;
      final py = ay + dy * t;
      final distance = math.sqrt(px * px + py * py);
      if (distance < bestDistance) {
        bestDistance = distance;
        final segmentMeters = _routeCumulativeMeters[i + 1] - _routeCumulativeMeters[i];
        bestAlong = _routeCumulativeMeters[i] + segmentMeters * t;
        bestPoint = LatLng(
          position.latitude + py / latScale,
          position.longitude + px / lonScale,
        );
      }
    }
    return _RouteProjection(
      distanceMeters: bestDistance,
      alongMeters: bestAlong,
      point: bestPoint,
    );
  }

  _RouteProjection? _projectPositionToRoute(Position position) =>
      _projectPointToRoute(_navigationPointFor(position));

  void _updateNavigationProgress'''
s, count = project_re.subn(project_new, s, count=1)
if count != 1:
    raise SystemExit(f'route projection refactor failed: {count}')

# Route requests start from the stabilized point when available. This avoids a
# single raw sideways offset changing the whole route origin.
route_start = '      final start = LatLng(_position!.latitude, _position!.longitude);\n'
route_start_new = '''      final startPosition = _position!;
      final start = _navigationPointFor(startPosition);
'''
if route_start not in s:
    raise SystemExit('route start anchor missing')
s = s.replace(route_start, route_start_new, 1)

# Both renderers and the recenter action use the effective display point. Route
# snapping here is visual only; route progress and reroute logic use the
# stabilized unsnapped point through _projectPositionToRoute.
raster_current = '    final current = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);\n'
if raster_current not in s:
    raise SystemExit('raster current position anchor missing')
s = s.replace(raster_current, '    final current = _displayLocationPoint;\n', 1)

vector_center_old = '''    final p = _position;
    final center = p == null ? _fallbackCenter : LatLng(p.latitude, p.longitude);'''
vector_center_new = '''    final p = _position;
    final displayPoint = _displayLocationPoint;
    final center = displayPoint ?? _fallbackCenter;'''
if vector_center_old not in s:
    raise SystemExit('vector center anchor missing')
s = s.replace(vector_center_old, vector_center_new, 1)
s = s.replace('              zoom: p == null ? 12.5 : 16.0,\n',
              '              zoom: displayPoint == null ? 12.5 : 16.0,\n', 1)

vector_marker_old = r'''        final current = _position;
        if (current != null) {
          await controller.addCircle(
            ml.CircleOptions(
              geometry: ml.LatLng(current.latitude, current.longitude),'''
vector_marker_new = r'''        final current = _displayLocationPoint;
        if (current != null) {
          await controller.addCircle(
            ml.CircleOptions(
              geometry: ml.LatLng(current.latitude, current.longitude),'''
if vector_marker_old not in s:
    raise SystemExit('vector current annotation anchor missing')
s = s.replace(vector_marker_old, vector_marker_new, 1)

center_re = re.compile(
    r"  void _centerMapOnCurrentPosition\(\) \{.*?\n  \}\n\n  Future<void> _selectDestination",
    re.S,
)
center_new = r'''  void _centerMapOnCurrentPosition() {
    final point = _displayLocationPoint;
    if (!_mapReady || point == null) {
      _showMessage('먼저 실제 현재 위치를 받아 주세요.');
      return;
    }
    _moveActiveMap(point, 16.5);
  }

  Future<void> _selectDestination'''
s, count = center_re.subn(center_new, s, count=1)
if count != 1:
    raise SystemExit(f'current-position recenter replacement failed: {count}')

# Explain what the app actually improved: sensor uncertainty is untouched while
# marker/navigation coordinates are stabilized. Never claim the filter changed
# GNSS hardware accuracy.
diag_anchor = "          _KeyValueRow(label: '최근 GPS', value: _latestRawAccuracyMeters == null ? '-' : GpsPolicy.uncertaintyLabel(_latestRawAccuracyMeters!)),\n"
diag_new = diag_anchor + """          _KeyValueRow(label: 'GPS 보정', value: _stabilizedPosition == null ? '대기' : '적응형 평활화 작동 · 튐 $_gpsRejectedJumpCount회 제거'),
          _KeyValueRow(label: '원시→보정 차이', value: _rawToStabilizedMeters == null ? '-' : '${_rawToStabilizedMeters!.toStringAsFixed(1)} m'),
          _KeyValueRow(label: '경로 시각 스냅', value: _displayRouteSnapMeters == null ? '-' : (_displayRouteSnapMeters! <= 0 ? '미사용' : '${_displayRouteSnapMeters!.toStringAsFixed(1)} m · 표시만 보정')),
"""
if diag_anchor not in s:
    raise SystemExit('v066 recent GPS diagnostic anchor missing')
s = s.replace(diag_anchor, diag_new, 1)

# Replace stale v0.6.6 GPS wording in the status detail card if still present.
s = s.replace("_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능' : '정확도 부족 (>80m)')),
",
              "_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능 · 보정 필터 적용' : '안정화 필요 (>45m)')),
")

# More truthful tracking log: 2m is update distance, not accuracy.
s = s.replace(
    "_log('실시간 위치 추적 시작 · 이동 갱신 간격 5m · 내비 허용 오차 45m');",
    "_log('실시간 위치 추적 시작 · Fused 고정밀 · 이동 갱신 조건 2m · 내비 허용 오차 45m · 적응형 보정');",
    1,
)

# Roadmap/status wording.
s = s.replace(
    "_PlanItem('v0.6.5', '실제 회전 지시 + 한국어 음성 안내', '현재', CheckState.pass),",
    "_PlanItem('v0.6.5', '실제 회전 지시 + 한국어 음성 안내', 'Gate 통과', CheckState.pass),\n      _PlanItem('v0.6.7', 'GPS 튐 제거 + 적응형 보정 + 제한적 경로 스냅', '현재', CheckState.pass),",
    1,
)

required = [
    "import 'package:comfort_route_sample/gps_stabilizer.dart';",
    "import 'package:geolocator_android/geolocator_android.dart';",
    'forceLocationManager: false',
    'distanceFilter: 2',
    'GpsStabilizer _gpsStabilizer',
    'GpsStabilizerDecision.implausibleJump',
    'GPS 순간이동 튐 제거',
    'LatLng? get _displayLocationPoint',
    'display only',
    '적응형 평활화 작동',
    'Fused 고정밀 · 이동 갱신 조건 2m',
]
# The source comment uses Korean/English rather than a runtime marker for one
# review contract; validate the actual code marker instead.
required[8] = 'projection.distanceMeters <= snapLimit ? projection.point : base'
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v067 marker: {marker}')

p.write_text(s)
print('APPLY_V067_GPS_STABILIZATION: PASS')
