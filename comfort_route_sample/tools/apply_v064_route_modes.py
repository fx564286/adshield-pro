from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.4: real OSRM alternatives, route-preference UI, request race fixes,
# vector fallback hardening, and POI stale-response invalidation.
s = s.replace(
    "import 'package:latlong2/latlong.dart';\n",
    "import 'package:latlong2/latlong.dart';\nimport 'package:comfort_route_sample/route_mode_logic.dart';\n",
    1,
)
s = s.replace(
    'ComfortRoute/0.6.3 (com.fx564286.comfort_route_sample)',
    'ComfortRoute/0.6.4 (com.fx564286.comfort_route_sample)',
)

# Route alternative model lives in the generated app while ranking math remains
# in a separate unit-tested file.
app_anchor = 'class ComfortRouteApp extends StatelessWidget {'
route_model = r'''class _RouteAlternative {
  const _RouteAlternative({
    required this.sourceIndex,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverCount,
    required this.comfortSignalHits,
    required this.shelterSignalHits,
  });

  final int sourceIndex;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final int maneuverCount;
  final int comfortSignalHits;
  final int shelterSignalHits;

  RouteScoreInput get scoreInput => RouteScoreInput(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        maneuverCount: maneuverCount,
        comfortSignalHits: comfortSignalHits,
        shelterSignalHits: shelterSignalHits,
        sourceIndex: sourceIndex,
      );
}

'''
if app_anchor not in s:
    raise SystemExit('ComfortRouteApp anchor missing')
s = s.replace(app_anchor, route_model + app_anchor, 1)

# Additional state after the vector camera field.
field_anchor = '  ml.CameraPosition? _vectorCameraPosition;\n'
fields = field_anchor + r'''
  RoutePreference _routePreference = RoutePreference.pleasant;
  List<_RouteAlternative> _routeAlternatives = const <_RouteAlternative>[];
  int? _selectedAlternativeSourceIndex;
  int _routeRequestGeneration = 0;
  bool _routeRequestQueued = false;
  bool? _queuedRouteAutoReroute;
  Timer? _vectorStartupGuard;
  bool _vectorFallbackUsed = false;
'''
if field_anchor not in s:
    raise SystemExit('vector camera field anchor missing')
s = s.replace(field_anchor, fields, 1)

# v0.6.3 made this final only to satisfy a lint. It must be mutable so a failed
# vector startup can automatically fall back to the raster renderer.
s = s.replace('  final bool _useVectorMap = true;\n', '  bool _useVectorMap = true;\n', 1)

# Cancel startup guard on dispose.
dispose_anchor = '    _poiDebounce?.cancel();\n'
if dispose_anchor not in s:
    raise SystemExit('dispose POI anchor missing')
s = s.replace(dispose_anchor, '    _vectorStartupGuard?.cancel();\n' + dispose_anchor, 1)

# Critical v0.6.2 regression: the blanket camera rewrite accidentally made the
# raster fallback branch call _moveActiveMap recursively.
s = s.replace(
    '    if (_mapReady) _moveActiveMap(point, zoom);\n',
    '    if (_mapReady) _mapController.move(point, zoom);\n',
    1,
)

# Guard vector startup. If the style does not become ready, keep navigation
# usable by falling back to the pure-Flutter map without exposing a dev toggle.
created_old = r'''            onMapCreated: (controller) {
              _vectorMapController = controller;
              _log('MapLibre 벡터 엔진 생성 완료');
            },
            onStyleLoadedCallback: () {
              if (!mounted) return;
              setState(() {
                _vectorStyleReady = true;
                _mapReady = true;
              });
              _log('OpenFreeMap Positron 벡터 스타일 로드 완료');
              _syncVectorAnnotations();
            },'''
created_new = r'''            onMapCreated: (controller) {
              _vectorMapController = controller;
              _vectorStartupGuard?.cancel();
              _vectorStartupGuard = Timer(const Duration(seconds: 9), () {
                if (!mounted || _vectorStyleReady) return;
                setState(() {
                  _useVectorMap = false;
                  _vectorFallbackUsed = true;
                  _mapReady = true;
                });
                _log('벡터 스타일 준비 지연 · 호환 지도 자동 전환');
              });
              _log('MapLibre 벡터 엔진 생성 완료');
            },
            onStyleLoadedCallback: () {
              _vectorStartupGuard?.cancel();
              if (!mounted) return;
              setState(() {
                _vectorStyleReady = true;
                _mapReady = true;
              });
              _log('OpenFreeMap Positron 벡터 스타일 로드 완료');
              _syncVectorAnnotations();
            },'''
if created_old not in s:
    raise SystemExit('vector create/style anchor missing')
s = s.replace(created_old, created_new, 1)

# Invalidate an in-flight POI response when the user zooms out. Otherwise a
# late Overpass response can repopulate labels after the app intentionally hid them.
zoomout_anchor = r'''    if (zoom < 15) {
      if (_nearbyPois.isNotEmpty || _poiError != null || _poiLoading) {'''
zoomout_new = r'''    if (zoom < 15) {
      ++_poiRequestGeneration;
      if (_nearbyPois.isNotEmpty || _poiError != null || _poiLoading) {'''
if zoomout_anchor not in s:
    raise SystemExit('POI zoom-out anchor missing')
s = s.replace(zoomout_anchor, zoomout_new, 1)

# Give parks their own semantic category so they can contribute to the
# preliminary pleasant-route signal instead of falling into generic facilities.
category_anchor = """  String _poiCategory(Map<String, dynamic> tags) {
    final shop = '${tags['shop'] ?? ''}';
    final amenity = '${tags['amenity'] ?? ''}';
"""
category_new = category_anchor + "    final leisure = '${tags['leisure'] ?? ''}';\n"
if category_anchor not in s:
    raise SystemExit('POI category anchor missing')
s = s.replace(category_anchor, category_new, 1)
category_tail = """    if ('${tags['tourism'] ?? ''}' == 'hotel') return '숙박';
    if ('${tags['building'] ?? ''}'.isNotEmpty) return '건물';
"""
category_tail_new = """    if ('${tags['tourism'] ?? ''}' == 'hotel') return '숙박';
    if (leisure == 'park') return '공원';
    if (leisure == 'fitness_centre') return '운동';
    if ('${tags['building'] ?? ''}'.isNotEmpty) return '건물';
"""
if category_tail not in s:
    raise SystemExit('POI category tail missing')
s = s.replace(category_tail, category_tail_new, 1)

# Add the route preference selector directly under destination search.
map_page_anchor = r'''              _buildSearchHeader(),
              const SizedBox(height: AppSpace.sm),
              Expanded(child: _buildRealMap()),'''
map_page_new = r'''              _buildSearchHeader(),
              const SizedBox(height: AppSpace.xs),
              _buildRoutePreferenceSelector(),
              const SizedBox(height: AppSpace.sm),
              Expanded(child: _buildRealMap()),'''
if map_page_anchor not in s:
    raise SystemExit('v0.6.3 map-page anchor missing')
s = s.replace(map_page_anchor, map_page_new, 1)

search_anchor = '  Widget _buildSearchHeader() {\n'
selector_methods = r'''  Widget _buildRoutePreferenceSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(21),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _routePreferenceButton(RoutePreference.fast, Icons.bolt_rounded, '빠른'),
          _routePreferenceButton(RoutePreference.pleasant, Icons.eco_rounded, '쾌적'),
          _routePreferenceButton(RoutePreference.weatherAvoid, Icons.umbrella_rounded, '날씨 회피'),
        ],
      ),
    );
  }

  Widget _routePreferenceButton(RoutePreference preference, IconData icon, String label) {
    final selected = _routePreference == preference;
    return Expanded(
      child: Material(
        color: selected ? AppColors.primaryDeep : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _selectRoutePreference(preference),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.primaryDeep,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

'''
if search_anchor not in s:
    raise SystemExit('search method anchor missing')
s = s.replace(search_anchor, selector_methods + search_anchor, 1)

# Friendly route badge follows the selected preference instead of always saying
# only "walking".
badge_old = r'''                  child: const Text(
                    '보행',
                    style: TextStyle(color: AppColors.primaryDeep, fontSize: 11, fontWeight: FontWeight.w900),
                  ),'''
badge_new = r'''                  child: Text(
                    _routePreferenceBadgeLabel,
                    style: const TextStyle(color: AppColors.primaryDeep, fontSize: 11, fontWeight: FontWeight.w900),
                  ),'''
if badge_old not in s:
    raise SystemExit('route badge anchor missing')
s = s.replace(badge_old, badge_new, 1)

# Explain the actual basis, including when the routing service supplies only one
# candidate. This avoids claiming verified shade/indoor/weather data prematurely.
button_anchor = r'''          if (!compact) ...[
            const SizedBox(height: 11),'''
button_new = r'''          if (hasRoute) ...[
            const SizedBox(height: 8),
            Text(
              _routePreferenceExplanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 11),'''
if button_anchor not in s:
    raise SystemExit('route card action anchor missing')
s = s.replace(button_anchor, button_new, 1)

# Clear candidate state when destination changes.
reset_anchor = r'''      _routeStart = null;
      _routeCumulativeMeters = const <double>[];'''
reset_new = r'''      _routeStart = null;
      _routeAlternatives = const <_RouteAlternative>[];
      _selectedAlternativeSourceIndex = null;
      _routeCumulativeMeters = const <double>[];'''
if reset_anchor not in s:
    raise SystemExit('route destination reset anchor missing')
s = s.replace(reset_anchor, reset_new, 1)

# Draw non-selected candidates subtly in raster mode.
raster_poly_re = re.compile(
    r"    final polylines = <Polyline>\[\];\n    if \(_routePoints\.length >= 2\) \{\n      polylines\.add\(Polyline\(points: _routePoints, strokeWidth: 5, color: AppColors\.primaryDeep\)\);\n    \}",
    re.S,
)
raster_poly = r'''    final polylines = <Polyline>[];
    for (final alternative in _routeAlternatives) {
      if (alternative.sourceIndex == _selectedAlternativeSourceIndex || alternative.points.length < 2) continue;
      polylines.add(Polyline(
        points: alternative.points,
        strokeWidth: 3,
        color: AppColors.primary.withValues(alpha: 0.32),
      ));
    }
    if (_routePoints.length >= 2) {
      polylines.add(Polyline(points: _routePoints, strokeWidth: 5, color: AppColors.primaryDeep));
    }'''
s, count = raster_poly_re.subn(raster_poly, s, count=1)
if count != 1:
    raise SystemExit(f'raster alternative polyline replacement failed: {count}')

# Draw non-selected candidates beneath the selected MapLibre route.
vector_selected = r'''        if (_routePoints.length >= 2) {
          final vectorGeometry = _routePoints
              .map((point) => ml.LatLng(point.latitude, point.longitude))
              .toList(growable: false);'''
vector_new = r'''        for (final alternative in _routeAlternatives) {
          if (alternative.sourceIndex == _selectedAlternativeSourceIndex || alternative.points.length < 2) continue;
          await controller.addLine(
            ml.LineOptions(
              geometry: alternative.points
                  .map((point) => ml.LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              lineColor: '#9BB4A2',
              lineWidth: 3.0,
              lineOpacity: 0.42,
              lineJoin: 'round',
            ),
          );
        }

        if (_routePoints.length >= 2) {
          final vectorGeometry = _routePoints
              .map((point) => ml.LatLng(point.latitude, point.longitude))
              .toList(growable: false);'''
if vector_selected not in s:
    raise SystemExit('vector selected-route anchor missing')
s = s.replace(vector_selected, vector_new, 1)

# Replace the route network method with an alternatives-aware, stale-safe
# implementation. A request arriving during another request invalidates the old
# response and is queued instead of being silently discarded.
route_re = re.compile(
    r"  Future<void> _fetchWalkingRoute\(\{bool autoReroute = false\}\) async \{.*?\n  \}\n\n  List<double> _buildRouteCumulative",
    re.S,
)
route_block = r'''  Future<void> _fetchWalkingRoute({bool autoReroute = false}) async {
    final requestGeneration = ++_routeRequestGeneration;
    if (_routeRequestInFlight) {
      _routeRequestQueued = true;
      _queuedRouteAutoReroute = (_queuedRouteAutoReroute ?? true) && autoReroute;
      _log('새 경로 요청 대기열 병합 · 이전 응답 무효화');
      return;
    }

    _routeRequestInFlight = true;
    HttpClient? client;
    try {
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

      final start = LatLng(_position!.latitude, _position!.longitude);
      if (mounted) {
        setState(() {
          _routeLoading = true;
          _routeError = null;
        });
      }
      _log(autoReroute ? '경로 이탈 자동 재탐색 요청 시작' : '실제 보행 경로 후보 요청 시작');

      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
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
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if ('${decoded['code']}' != 'Ok') throw StateError('route code=${decoded['code']}');
      final routes = decoded['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) throw StateError('경로 없음');

      final alternatives = <_RouteAlternative>[];
      for (var sourceIndex = 0; sourceIndex < routes.length && sourceIndex < 3; sourceIndex++) {
        final route = routes[sourceIndex] as Map<String, dynamic>;
        final geometry = route['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List<dynamic>?;
        if (coordinates == null) continue;
        final points = <LatLng>[];
        for (final coordinate in coordinates) {
          final pair = coordinate as List<dynamic>;
          if (pair.length < 2 || pair[0] is! num || pair[1] is! num) continue;
          points.add(LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()));
        }
        if (points.length < 2) continue;

        var maneuverCount = 0;
        final legs = route['legs'] as List<dynamic>? ?? const <dynamic>[];
        for (final rawLeg in legs) {
          if (rawLeg is! Map<String, dynamic>) continue;
          maneuverCount += (rawLeg['steps'] as List<dynamic>?)?.length ?? 0;
        }
        final distance = (route['distance'] as num?)?.toDouble() ?? _buildRouteCumulative(points).last;
        final duration = (route['duration'] as num?)?.toDouble() ?? 0;
        final comfortSignals = _countRouteSignals(
          points,
          const {'공원', '음수대', '화장실', '편의점', '마트', '카페', '의료'},
        );
        final shelterSignals = _countRouteSignals(
          points,
          const {'건물', '업무', '쇼핑', '주차', '숙박', '마트'},
          maxDistanceMeters: 110,
        );
        final candidate = _RouteAlternative(
          sourceIndex: sourceIndex,
          points: List<LatLng>.unmodifiable(points),
          distanceMeters: distance,
          durationSeconds: duration,
          maneuverCount: maneuverCount,
          comfortSignalHits: comfortSignals,
          shelterSignalHits: shelterSignals,
        );
        final duplicate = alternatives.any((existing) =>
            (existing.distanceMeters - candidate.distanceMeters).abs() < 12 &&
            (existing.durationSeconds - candidate.durationSeconds).abs() < 12);
        if (!duplicate) alternatives.add(candidate);
      }
      if (alternatives.isEmpty) throw StateError('geometry 좌표 부족');

      if (!mounted || requestGeneration != _routeRequestGeneration || !_samePoint(destination, _destination)) {
        _log('오래된 경로 응답 폐기');
        return;
      }
      setState(() {
        _routeAlternatives = List<_RouteAlternative>.unmodifiable(alternatives);
        _routeStart = start;
        _routeLoading = false;
        _routeError = null;
        _routingServiceChecked = true;
        _routingServiceOk = true;
        _offRouteSamples = 0;
        _distanceFromRouteMeters = null;
      });
      _applyRoutePreferenceSelection(fitMap: !autoReroute);
      _log('${autoReroute ? '자동 재탐색' : '실제 보행'} 후보 ${alternatives.length}개 수신 · ${_routePreferenceLogLabel} 적용');
    } catch (error) {
      if (!mounted) return;
      if (requestGeneration != _routeRequestGeneration) {
        _log('무효화된 경로 요청 오류 무시: $error');
        return;
      }
      setState(() {
        _routeLoading = false;
        _routeError = '보행 경로 계산 실패: $error';
        _routingServiceChecked = true;
        _routingServiceOk = false;
        if (!autoReroute) {
          _routePoints = const <LatLng>[];
          _routeAlternatives = const <_RouteAlternative>[];
          _selectedAlternativeSourceIndex = null;
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
      final queued = _routeRequestQueued;
      final queuedAuto = _queuedRouteAutoReroute ?? false;
      _routeRequestQueued = false;
      _queuedRouteAutoReroute = null;
      if (queued && mounted) {
        Future<void>.microtask(() => _fetchWalkingRoute(autoReroute: queuedAuto));
      }
    }
  }

  bool _samePoint(LatLng a, LatLng? b) {
    if (b == null) return false;
    return (a.latitude - b.latitude).abs() < 1e-9 &&
        (a.longitude - b.longitude).abs() < 1e-9;
  }

  int _countRouteSignals(
    List<LatLng> points,
    Set<String> categories, {
    double maxDistanceMeters = 140,
  }) {
    if (points.isEmpty || _nearbyPois.isEmpty) return 0;
    final stride = math.max(1, points.length ~/ 28);
    final samples = <LatLng>[
      for (var i = 0; i < points.length; i += stride) points[i],
      if (points.length > 1) points.last,
    ];
    var hits = 0;
    for (final poi in _nearbyPois) {
      if (!categories.contains(poi.category)) continue;
      var nearRoute = false;
      for (final sample in samples) {
        final distance = Geolocator.distanceBetween(
          sample.latitude,
          sample.longitude,
          poi.point.latitude,
          poi.point.longitude,
        );
        if (distance <= maxDistanceMeters) {
          nearRoute = true;
          break;
        }
      }
      if (nearRoute) hits++;
    }
    return hits;
  }

  void _selectRoutePreference(RoutePreference preference) {
    if (_routePreference == preference) return;
    setState(() => _routePreference = preference);
    _applyRoutePreferenceSelection(fitMap: false);
    _log('경로 기준 변경 · $_routePreferenceLogLabel');
  }

  void _applyRoutePreferenceSelection({required bool fitMap}) {
    if (_routeAlternatives.isEmpty) return;
    final index = chooseRouteIndex(
      _routeAlternatives.map((alternative) => alternative.scoreInput).toList(growable: false),
      _routePreference,
    );
    if (index < 0 || index >= _routeAlternatives.length) return;
    _activateRoute(_routeAlternatives[index], fitMap: fitMap);
  }

  void _activateRoute(_RouteAlternative route, {required bool fitMap}) {
    if (!mounted) return;
    final cumulative = _buildRouteCumulative(route.points);
    setState(() {
      _selectedAlternativeSourceIndex = route.sourceIndex;
      _routePoints = route.points;
      _routeCumulativeMeters = cumulative;
      _routeDistanceMeters = route.distanceMeters;
      _routeDurationSeconds = route.durationSeconds;
      _routeProgress = null;
      _remainingDistanceMeters = null;
      _remainingDurationSeconds = null;
      _distanceFromRouteMeters = null;
      _offRouteSamples = 0;
    });
    final position = _position;
    if (position != null) _updateNavigationProgress(position);
    _syncVectorAnnotations();
    if (fitMap && route.points.isNotEmpty && _routeStart != null && _destination != null) {
      final middle = route.points[route.points.length ~/ 2];
      final straight = Geolocator.distanceBetween(
        _routeStart!.latitude,
        _routeStart!.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );
      final zoom = straight < 1500 ? 15.2 : straight < 5000 ? 13.8 : straight < 15000 ? 12.2 : 10.8;
      _moveActiveMap(middle, zoom);
    }
  }

  String get _routePreferenceBadgeLabel {
    switch (_routePreference) {
      case RoutePreference.fast:
        return '빠른';
      case RoutePreference.pleasant:
        return '쾌적';
      case RoutePreference.weatherAvoid:
        return '날씨 회피';
    }
  }

  String get _routePreferenceLogLabel {
    switch (_routePreference) {
      case RoutePreference.fast:
        return '시간 우선';
      case RoutePreference.pleasant:
        return '단순 이동 + 주변 편의 신호 베타';
      case RoutePreference.weatherAvoid:
        return '외부 노출거리 우선 베타';
    }
  }

  String get _routePreferenceExplanation {
    final count = _routeAlternatives.length;
    if (count <= 1) return '대안 경로가 없어 현재 실제 보행 경로 1개를 사용합니다.';
    switch (_routePreference) {
      case RoutePreference.fast:
        return '실제 보행 후보 $count개 중 예상 이동시간을 가장 우선합니다.';
      case RoutePreference.pleasant:
        return '후보 $count개 중 이동시간·거리·회전 복잡도와 현재 확보된 주변 편의 신호를 함께 보는 베타 기준입니다.';
      case RoutePreference.weatherAvoid:
        return '검증된 실내 통로 연결 전 단계로, 후보 $count개 중 외부 노출거리를 줄이는 짧은 경로를 우선하는 베타 기준입니다.';
    }
  }

  List<double> _buildRouteCumulative'''
s, count = route_re.subn(route_block, s, count=1)
if count != 1:
    raise SystemExit(f'route method replacement failed: {count}')

# Route details expose candidate count and the transparent selection basis.
geometry_row = "          _KeyValueRow(label: 'geometry', value: _routePoints.isEmpty ? '-' : '${_routePoints.length} points'),\n"
if geometry_row in s:
    s = s.replace(
        geometry_row,
        geometry_row
        + "          _KeyValueRow(label: '경로 후보', value: _routeAlternatives.isEmpty ? '-' : '${_routeAlternatives.length}개'),\n"
        + "          _KeyValueRow(label: '선택 기준', value: _routePreferenceLogLabel),\n",
        1,
    )

# Diagnostics should reveal an automatic renderer fallback rather than imply
# MapLibre is healthy when it is not.
diag_vector = """        _vectorRendererActive
            ? (_vectorStyleReady ? 'MapLibre + OpenFreeMap Positron' : '벡터 스타일 로딩 중')
            : 'flutter_map 래스터 호환 모드',"""
if diag_vector in s:
    s = s.replace(
        diag_vector,
        """        _vectorRendererActive
            ? (_vectorStyleReady ? 'MapLibre + OpenFreeMap Positron' : '벡터 스타일 로딩 중')
            : (_vectorFallbackUsed ? '벡터 시작 지연으로 호환 지도 자동 전환' : 'flutter_map 래스터 호환 모드'),""",
        1,
    )

# Final regression contracts for the generated Dart source.
required = [
    "import 'package:comfort_route_sample/route_mode_logic.dart';",
    'alternatives=3',
    '새 경로 요청 대기열 병합',
    '오래된 경로 응답 폐기',
    'Widget _buildRoutePreferenceSelector()',
    '_routeAlternatives',
    '_vectorStartupGuard',
    'if (_mapReady) _mapController.move(point, zoom);',
    '++_poiRequestGeneration;',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v0.6.4 marker: {marker}')
if 'if (_mapReady) _moveActiveMap(point, zoom);' in s:
    raise SystemExit('recursive raster camera fallback still present')

p.write_text(s)
print('APPLY_V064_ROUTE_MODES: PASS')
