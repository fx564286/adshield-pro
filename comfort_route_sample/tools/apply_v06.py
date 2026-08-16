from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6: navigation math + remove the redundant accuracy-status state that was
# only written but never consumed.
s = s.replace("import 'dart:io';\n", "import 'dart:io';\nimport 'dart:math' as math;\n")
s = s.replace("ComfortRoute/0.5 (com.fx564286.comfort_route_sample)", "ComfortRoute/0.6 (com.fx564286.comfort_route_sample)")
s = s.replace('  LocationAccuracyStatus? _accuracyStatus;\n', '')
s = s.replace("""      try {\n        final accuracyStatus = await Geolocator.getLocationAccuracy();\n        if (mounted) setState(() => _accuracyStatus = accuracyStatus);\n      } catch (_) {}\n\n""", '')

place_anchor = """class _PlaceResult {\n  const _PlaceResult({required this.name, required this.point, required this.kind});\n  final String name;\n  final LatLng point;\n  final String kind;\n}\n"""
projection_class = place_anchor + """\nclass _RouteProjection {\n  const _RouteProjection({required this.distanceMeters, required this.alongMeters});\n  final double distanceMeters;\n  final double alongMeters;\n}\n"""
if place_anchor not in s:
    raise SystemExit('place anchor not found')
s = s.replace(place_anchor, projection_class, 1)

field_anchor = "  DateTime? _lastPoorAccuracyLogAt;\n"
fields = field_anchor + """\n  Future<void>? _locationAcquireFuture;\n  bool _centerAfterLocationAcquire = false;\n  bool _trackingTransitionInFlight = false;\n  bool _routeRequestInFlight = false;\n  List<double> _routeCumulativeMeters = const <double>[];\n  double? _routeProgress;\n  double? _remainingDistanceMeters;\n  double? _remainingDurationSeconds;\n  double? _distanceFromRouteMeters;\n  int _offRouteSamples = 0;\n  bool _autoRerouteActive = false;\n  DateTime? _lastAutoRerouteAt;\n"""
if field_anchor not in s:
    raise SystemExit('field anchor not found')
s = s.replace(field_anchor, fields, 1)

old_summary = """? '${_formatDistance(_routeDistanceMeters!)} · ${_formatDuration(_routeDurationSeconds ?? 0)}${_routeNeedsRefresh ? ' · 위치 이동으로 갱신 권장' : ''}'"""
if old_summary not in s:
    raise SystemExit('summary anchor not found')
s = s.replace(old_summary, "? _routePrimarySummary", 1)

compact_anchor = """          if (!compact) ...[\n            const SizedBox(height: AppSpace.sm),\n"""
progress_ui = """          if (hasRoute && _routeProgress != null) ...[\n            const SizedBox(height: AppSpace.xs),\n            ClipRRect(\n              borderRadius: BorderRadius.circular(AppRadius.pill),\n              child: LinearProgressIndicator(\n                value: _routeProgress!.clamp(0.0, 1.0),\n                minHeight: 6,\n                backgroundColor: AppColors.primarySoft,\n              ),\n            ),\n          ],\n          if (!compact) ...[\n            const SizedBox(height: AppSpace.sm),\n"""
if compact_anchor not in s:
    raise SystemExit('compact anchor not found')
s = s.replace(compact_anchor, progress_ui, 1)

route_detail_anchor = """          _KeyValueRow(label: 'geometry', value: _routePoints.isEmpty ? '-' : '${_routePoints.length} points'),\n"""
route_detail_rows = route_detail_anchor + """          _KeyValueRow(label: '진행률', value: _routeProgress == null ? '-' : '${(_routeProgress! * 100).clamp(0, 100).toStringAsFixed(0)}%'),\n          _KeyValueRow(label: '남은 거리', value: _remainingDistanceMeters == null ? '-' : _formatDistance(_remainingDistanceMeters!)),\n          _KeyValueRow(label: '남은 시간', value: _remainingDurationSeconds == null ? '-' : _formatDuration(_remainingDurationSeconds!)),\n          _KeyValueRow(label: '경로 이탈 거리', value: _distanceFromRouteMeters == null ? '-' : '${_distanceFromRouteMeters!.toStringAsFixed(0)} m'),\n          _KeyValueRow(label: '자동 재탐색', value: _autoRerouteActive ? '재탐색 중' : (_offRouteSamples >= 3 ? '이탈 확정' : '대기')),\n"""
if route_detail_anchor not in s:
    raise SystemExit('route detail anchor not found')
s = s.replace(route_detail_anchor, route_detail_rows, 1)

s = s.replace("_PlanItem('v0.5', '실제 목적지 검색 + 보행 경로', '현재', CheckState.pass),", "_PlanItem('v0.5', '실제 목적지 검색 + 보행 경로', 'Gate 통과', CheckState.pass),")
s = s.replace("_PlanItem('v0.6', '진행거리 + 이탈 + 재탐색 + 음성', '다음 필수', CheckState.warning),", "_PlanItem('v0.6', '진행률 + 남은거리 + 이탈 + 자동 재탐색', '현재', CheckState.pass),")
s = s.replace("_PlanItem('v0.7', '음수대·화장실·쉼터 실제 데이터', '필수', CheckState.unknown),", "_PlanItem('v0.6.1', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),\n      _PlanItem('v0.7', '음수대·화장실·쉼터 실제 데이터', '필수', CheckState.unknown),")

# Location acquisition single-flight: concurrent callers await the same request
# instead of starting multiple GPS acquisitions.
location_re = re.compile(r"  Future<void> _acquireLocation\(\{required bool requestPermission, required bool centerMap\}\) async \{.*?\n  \}\n\n  Future<void> _toggleTracking\(\) async \{", re.S)
location_block = r'''  Future<void> _acquireLocation({required bool requestPermission, required bool centerMap}) {
    if (centerMap) _centerAfterLocationAcquire = true;
    final existing = _locationAcquireFuture;
    if (existing != null) {
      _log('중복 위치 요청 병합');
      return existing;
    }

    late final Future<void> future;
    future = _doAcquireLocation(requestPermission: requestPermission).whenComplete(() {
      if (identical(_locationAcquireFuture, future)) _locationAcquireFuture = null;
      final shouldCenter = _centerAfterLocationAcquire;
      _centerAfterLocationAcquire = false;
      if (shouldCenter && mounted) _centerMapOnCurrentPosition();
    });
    _locationAcquireFuture = future;
    return future;
  }

  Future<void> _doAcquireLocation({required bool requestPermission}) async {
    _log('위치 진단 시작');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      setState(() => _locationServiceEnabled = serviceEnabled);
      if (!serviceEnabled) {
        setState(() => _locationError = '기기 위치서비스가 꺼져 있습니다.');
        _log('위치서비스 꺼짐');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      setState(() => _locationPermission = permission);
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationError = permission == LocationPermission.deniedForever
            ? '위치 권한이 영구 거부되었습니다.'
            : '위치 권한이 거부되었습니다.');
        _log('위치 권한 사용 불가');
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted && _position == null) {
        final age = DateTime.now().difference(lastKnown.timestamp).abs();
        if (age <= const Duration(minutes: 10) && lastKnown.accuracy <= _maxNavigationAccuracyMeters) {
          setState(() {
            _position = lastKnown;
            _locationError = null;
          });
          _log('최근 마지막 위치 우선 표시 · ${age.inMinutes}분 전 · ±${lastKnown.accuracy.toStringAsFixed(1)}m');
        } else {
          _log('오래됐거나 부정확한 마지막 위치 제외 · ${age.inMinutes}분 · ±${lastKnown.accuracy.toStringAsFixed(1)}m');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationError = null;
      });
      _log('실제 GPS 수신 · 정확도 ±${position.accuracy.toStringAsFixed(1)}m');
      _updateNavigationProgress(position);
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = 'GPS 수신 오류: $error');
      _log('GPS 오류: $error');
    }
  }

  Future<void> _toggleTracking() async {'''
s, count = location_re.subn(location_block, s, count=1)
if count != 1:
    raise SystemExit(f'location method replacement failed: {count}')

tracking_re = re.compile(r"  Future<void> _toggleTracking\(\) async \{.*?\n  \}\n\n  Future<void> _stopTracking\(\) async \{", re.S)
tracking_block = r'''  Future<void> _toggleTracking() async {
    if (_trackingTransitionInFlight) {
      _log('중복 추적 전환 무시');
      return;
    }
    _trackingTransitionInFlight = true;
    try {
      if (_tracking) {
        await _stopTracking();
        return;
      }

      await _acquireLocation(requestPermission: true, centerMap: true);
      final granted = _locationPermission == LocationPermission.always ||
          _locationPermission == LocationPermission.whileInUse;
      if (!granted || _locationServiceEnabled != true) return;

      await _positionSubscription?.cancel();
      await _serviceSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (position) {
          if (!mounted) return;
          setState(() {
            _position = position;
            _locationError = null;
          });
          if (position.accuracy > _maxNavigationAccuracyMeters) {
            final now = DateTime.now();
            if (_lastPoorAccuracyLogAt == null ||
                now.difference(_lastPoorAccuracyLogAt!) > const Duration(seconds: 30)) {
              _lastPoorAccuracyLogAt = now;
              _log('GPS 정확도 낮음 · ±${position.accuracy.toStringAsFixed(1)}m · 경로 기준에는 사용 보류');
            }
            return;
          }
          _updateNavigationProgress(position);
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _tracking = false;
            _locationError = '위치 추적 오류: $error';
          });
          _log('위치 추적 오류: $error');
        },
      );

      _serviceSubscription = Geolocator.getServiceStatusStream().listen((status) {
        if (!mounted) return;
        final enabled = status == ServiceStatus.enabled;
        setState(() => _locationServiceEnabled = enabled);
        if (!enabled) _log('추적 중 위치서비스가 꺼졌습니다.');
      });

      if (mounted) setState(() => _tracking = true);
      _log('실시간 위치 추적 시작 · distanceFilter 5m');
    } finally {
      _trackingTransitionInFlight = false;
    }
  }

  Future<void> _stopTracking() async {'''
s, count = tracking_re.subn(tracking_block, s, count=1)
if count != 1:
    raise SystemExit(f'tracking replacement failed: {count}')

select_reset = """      _routeError = null;\n      _routeStart = null;\n"""
select_reset_new = select_reset + """      _routeCumulativeMeters = const <double>[];\n      _routeProgress = null;\n      _remainingDistanceMeters = null;\n      _remainingDurationSeconds = null;\n      _distanceFromRouteMeters = null;\n      _offRouteSamples = 0;\n"""
if select_reset not in s:
    raise SystemExit('destination reset anchor not found')
s = s.replace(select_reset, select_reset_new, 1)

# Replace routing with a single-flight route request and v0.6 route metrics.
route_re = re.compile(r"  Future<void> _fetchWalkingRoute\(\) async \{.*?\n  \}\n\n  void _copyLogs\(\) \{", re.S)
route_block = r'''  Future<void> _fetchWalkingRoute({bool autoReroute = false}) async {
    if (_routeRequestInFlight) {
      _log('중복 경로 요청 병합');
      return;
    }
    final destination = _destination;
    if (destination == null) {
      if (!autoReroute) _showMessage('먼저 목적지를 선택해 주세요.');
      return;
    }
    if (_position == null) {
      await _acquireLocation(requestPermission: true, centerMap: false);
    }
    if (!_positionUsableForRouting) {
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

    _routeRequestInFlight = true;
    final start = LatLng(_position!.latitude, _position!.longitude);
    if (mounted) {
      setState(() {
        _routeLoading = true;
        _routeError = null;
      });
    }
    _log(autoReroute ? '경로 이탈 자동 재탐색 요청 시작' : '실제 보행 경로 요청 시작');

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse(
        'https://routing.openstreetmap.de/routed-foot/route/v1/driving/'
        '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true&alternatives=false',
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if ('${decoded['code']}' != 'Ok') throw StateError('route code=${decoded['code']}');
      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) throw StateError('경로 없음');
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        final pair = coordinate as List<dynamic>;
        if (pair.length < 2) continue;
        points.add(LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()));
      }
      if (points.length < 2) throw StateError('geometry 좌표 부족');
      final cumulative = _buildRouteCumulative(points);

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeCumulativeMeters = cumulative;
        _routeStart = start;
        _routeDistanceMeters = (route['distance'] as num?)?.toDouble();
        _routeDurationSeconds = (route['duration'] as num?)?.toDouble();
        _routeLoading = false;
        _routeError = null;
        _routingServiceChecked = true;
        _routingServiceOk = true;
        _offRouteSamples = 0;
        _distanceFromRouteMeters = null;
      });
      _updateNavigationProgress(_position!);
      _log('${autoReroute ? '자동 재탐색 완료' : '실제 보행 경로 수신'} · ${_formatDistance(_routeDistanceMeters ?? 0)} · ${points.length} points');
      if (_mapReady && !autoReroute) {
        final middle = points[points.length ~/ 2];
        final straight = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          destination.latitude,
          destination.longitude,
        );
        final zoom = straight < 1500
            ? 15.2
            : straight < 5000
                ? 13.8
                : straight < 15000
                    ? 12.2
                    : 10.8;
        _mapController.move(middle, zoom);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = '보행 경로 계산 실패: $error';
        _routingServiceChecked = true;
        _routingServiceOk = false;
        if (!autoReroute) {
          _routePoints = const <LatLng>[];
          _routeCumulativeMeters = const <double>[];
          _routeDistanceMeters = null;
          _routeDurationSeconds = null;
          _routeProgress = null;
          _remainingDistanceMeters = null;
          _remainingDurationSeconds = null;
          _distanceFromRouteMeters = null;
        }
      });
      _log('${autoReroute ? '자동 재탐색' : '보행 경로'} 오류: $error');
    } finally {
      client?.close(force: true);
      _routeRequestInFlight = false;
    }
  }

  List<double> _buildRouteCumulative(List<LatLng> points) {
    if (points.isEmpty) return const <double>[];
    final cumulative = <double>[0];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      total += Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
      cumulative.add(total);
    }
    return cumulative;
  }

  _RouteProjection? _projectPositionToRoute(Position position) {
    if (_routePoints.length < 2 || _routeCumulativeMeters.length != _routePoints.length) {
      return null;
    }
    final latScale = 111132.0;
    final lonScale = math.max(1.0, 111320.0 * math.cos(position.latitude * math.pi / 180).abs());
    var bestDistance = double.infinity;
    var bestAlong = 0.0;

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
      }
    }
    return _RouteProjection(distanceMeters: bestDistance, alongMeters: bestAlong);
  }

  void _updateNavigationProgress(Position position) {
    if (position.accuracy > _maxNavigationAccuracyMeters || _routePoints.length < 2) return;
    final projection = _projectPositionToRoute(position);
    if (projection == null) return;
    final geometryTotal = _routeCumulativeMeters.isEmpty ? 0.0 : _routeCumulativeMeters.last;
    if (geometryTotal <= 0) return;

    final progress = (projection.alongMeters / geometryTotal).clamp(0.0, 1.0).toDouble();
    final routeTotal = _routeDistanceMeters ?? geometryTotal;
    final remaining = math.max(0.0, routeTotal * (1 - progress));
    final remainingSeconds = _routeDurationSeconds == null
        ? null
        : math.max(0.0, _routeDurationSeconds! * (1 - progress));
    final threshold = math.max(45.0, position.accuracy * 1.8);
    final isOffRoute = projection.distanceMeters > threshold;
    final nextSamples = isOffRoute ? _offRouteSamples + 1 : 0;

    if (mounted) {
      setState(() {
        _routeProgress = progress;
        _remainingDistanceMeters = remaining;
        _remainingDurationSeconds = remainingSeconds;
        _distanceFromRouteMeters = projection.distanceMeters;
        _offRouteSamples = nextSamples;
      });
    }

    if (isOffRoute && nextSamples == 1) {
      _log('경로 이탈 의심 · 경로에서 ${projection.distanceMeters.toStringAsFixed(0)}m · 기준 ${threshold.toStringAsFixed(0)}m');
    } else if (isOffRoute && nextSamples == 3) {
      _log('경로 이탈 확정 · 3회 연속 · 자동 재탐색 판단');
      unawaited(_autoRerouteFromCurrentPosition());
    }
  }

  Future<void> _autoRerouteFromCurrentPosition() async {
    final position = _position;
    if (_autoRerouteActive || _routeRequestInFlight || position == null || _destination == null) return;
    if (position.accuracy > 50) {
      _log('자동 재탐색 보류 · GPS ±${position.accuracy.toStringAsFixed(1)}m');
      return;
    }
    final now = DateTime.now();
    if (_lastAutoRerouteAt != null && now.difference(_lastAutoRerouteAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastAutoRerouteAt = now;
    if (mounted) setState(() => _autoRerouteActive = true);
    try {
      await _fetchWalkingRoute(autoReroute: true);
    } finally {
      if (mounted) {
        setState(() {
          _autoRerouteActive = false;
          _offRouteSamples = 0;
        });
      }
    }
  }

  String get _routePrimarySummary {
    final total = _routeDistanceMeters;
    if (total == null) return '경로 계산 전';
    final remaining = _remainingDistanceMeters;
    final progress = _routeProgress;
    if (remaining != null && progress != null) {
      final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
      final eta = _remainingDurationSeconds == null ? '' : ' · ${_formatDuration(_remainingDurationSeconds!)}';
      final off = _distanceFromRouteMeters != null && _offRouteSamples > 0
          ? ' · 경로에서 ${_distanceFromRouteMeters!.toStringAsFixed(0)}m'
          : '';
      return '남은 ${_formatDistance(remaining)}$eta · $pct%$off';
    }
    return '${_formatDistance(total)} · ${_formatDuration(_routeDurationSeconds ?? 0)}';
  }

  void _copyLogs() {'''
s, count = route_re.subn(route_block, s, count=1)
if count != 1:
    raise SystemExit(f'route replacement failed: {count}')

p.write_text(s)
print('APPLY_V06: PASS')
