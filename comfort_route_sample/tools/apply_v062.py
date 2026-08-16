from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.2: keep the existing latlong2 route/navigation model, but add MapLibre
# as the default renderer with OpenFreeMap vector styles. Raster remains a
# user-selectable fallback so navigation/GPS can be validated independently.
s = s.replace("import 'package:latlong2/latlong.dart';\n", "import 'package:latlong2/latlong.dart';\nimport 'package:maplibre_gl/maplibre_gl.dart' as ml;\n")
s = s.replace('ComfortRoute/0.6.1 (com.fx564286.comfort_route_sample)', 'ComfortRoute/0.6.2 (com.fx564286.comfort_route_sample)')

# Vector map state.
field_anchor = '  int _poiRequestGeneration = 0;\n'
fields = field_anchor + '''\n  static const _vectorStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';\n  bool _useVectorMap = true;\n  bool _vectorStyleReady = false;\n  bool _vectorSyncRunning = false;\n  bool _vectorSyncQueued = false;\n  ml.MapLibreMapController? _vectorMapController;\n  ml.CameraPosition? _vectorCameraPosition;\n'''
if field_anchor not in s:
    raise SystemExit('v061 field anchor not found')
s = s.replace(field_anchor, fields, 1)

# Dispose vector controller too.
dispose_anchor = '    _mapController.dispose();\n'
if dispose_anchor not in s:
    raise SystemExit('dispose anchor not found')
s = s.replace(dispose_anchor, '    _vectorMapController?.dispose();\n    _mapController.dispose();\n', 1)

# Widget tests use the pure-Flutter raster renderer because platform views are
# not available in flutter_test. Real Android builds default to vector.
build_map_anchor = '  Widget _buildRealMap() {\n'
if build_map_anchor not in s:
    raise SystemExit('buildRealMap anchor not found')
s = s.replace(build_map_anchor, '  Widget _buildRasterMap() {\n', 1)

insert_before_raster = '  Widget _buildRasterMap() {\n'
vector_block = r'''  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

  bool get _vectorRendererActive => _useVectorMap && !_isWidgetTest;

  Widget _buildRealMap() {
    return Stack(
      children: [
        Positioned.fill(
          child: _vectorRendererActive ? _buildVectorMap() : _buildRasterMap(),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Material(
            color: AppColors.surfaceStrong.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: _isWidgetTest
                  ? null
                  : () {
                      setState(() => _useVectorMap = !_useVectorMap);
                      _log(_useVectorMap ? '벡터 지도 엔진 선택' : '호환 지도 엔진 선택');
                      if (_useVectorMap) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _syncVectorAnnotations());
                      }
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _vectorRendererActive ? Icons.layers_rounded : Icons.map_outlined,
                      size: 16,
                      color: AppColors.primaryDeep,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _vectorRendererActive ? '벡터' : '호환',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVectorMap() {
    final p = _position;
    final center = p == null ? _fallbackCenter : LatLng(p.latitude, p.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          ml.MapLibreMap(
            styleString: _vectorStyleUrl,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(center.latitude, center.longitude),
              zoom: p == null ? 12.5 : 16.0,
            ),
            trackCameraPosition: true,
            featureTapsTriggersMapClick: true,
            compassEnabled: true,
            logoEnabled: false,
            foregroundLoadColor: AppColors.background,
            onMapCreated: (controller) {
              _vectorMapController = controller;
              _log('MapLibre 벡터 엔진 생성 완료');
            },
            onStyleLoadedCallback: () {
              if (!mounted) return;
              setState(() {
                _vectorStyleReady = true;
                _mapReady = true;
              });
              _log('OpenFreeMap Liberty 벡터 스타일 로드 완료');
              _syncVectorAnnotations();
            },
            onCameraMove: (camera) {
              _vectorCameraPosition = camera;
              _mapZoom = camera.zoom;
            },
            onCameraIdle: () {
              final camera = _vectorCameraPosition ?? _vectorMapController?.cameraPosition;
              if (camera == null) return;
              _mapZoom = camera.zoom;
              _scheduleNearbyPoiRefresh(
                LatLng(camera.target.latitude, camera.target.longitude),
                camera.zoom,
              );
              if (mounted) setState(() {});
            },
            onMapClick: (_, coordinate) {
              _selectDestination(
                LatLng(coordinate.latitude, coordinate.longitude),
                '지도 선택 지점',
              );
            },
          ),
          Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            child: _MapBadge(
              icon: Icons.layers_rounded,
              label: _vectorStyleReady ? '벡터 지도 · 상가/건물 라벨' : '벡터 스타일 로딩',
              state: _vectorStyleReady ? CheckState.pass : CheckState.running,
            ),
          ),
          Positioned(
            left: 8,
            bottom: 4,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 230),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceStrong.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'OpenFreeMap © OpenMapTiles · © OpenStreetMap contributors',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8.5, color: AppColors.textMuted),
              ),
            ),
          ),
          Positioned(
            right: AppSpace.sm,
            bottom: 34,
            child: Column(
              children: [
                _CircleButton(
                  icon: _tracking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  tooltip: _tracking ? '위치 추적 중지' : '실시간 위치 추적',
                  onTap: _toggleTracking,
                ),
                const SizedBox(height: AppSpace.xs),
                _CircleButton(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: '현재 위치로 이동',
                  onTap: _centerMapOnCurrentPosition,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncVectorAnnotations() async {
    final controller = _vectorMapController;
    if (!_vectorRendererActive || !_vectorStyleReady || controller == null) return;
    if (_vectorSyncRunning) {
      _vectorSyncQueued = true;
      return;
    }
    _vectorSyncRunning = true;
    try {
      do {
        _vectorSyncQueued = false;
        await controller.clearLines();
        await controller.clearCircles();

        if (_routePoints.length >= 2) {
          await controller.addLine(
            ml.LineOptions(
              geometry: _routePoints
                  .map((point) => ml.LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              lineColor: '#7C5064',
              lineWidth: 5.0,
              lineOpacity: 0.94,
              lineJoin: 'round',
            ),
          );
        }

        final current = _position;
        if (current != null) {
          await controller.addCircle(
            ml.CircleOptions(
              geometry: ml.LatLng(current.latitude, current.longitude),
              circleRadius: 8,
              circleColor: '#7C5064',
              circleStrokeWidth: 3,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }

        final destination = _destination;
        if (destination != null) {
          await controller.addCircle(
            ml.CircleOptions(
              geometry: ml.LatLng(destination.latitude, destination.longitude),
              circleRadius: 9,
              circleColor: '#B55C66',
              circleStrokeWidth: 3,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }
      } while (_vectorSyncQueued);
    } catch (error) {
      _log('벡터 지도 주석 동기화 오류: $error');
    } finally {
      _vectorSyncRunning = false;
    }
  }

  void _moveActiveMap(LatLng point, double zoom) {
    if (_vectorRendererActive && _vectorStyleReady && _vectorMapController != null) {
      _vectorMapController!.animateCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: ml.LatLng(point.latitude, point.longitude),
            zoom: zoom,
          ),
        ),
        duration: const Duration(milliseconds: 420),
      );
      return;
    }
    if (_mapReady) _mapController.move(point, zoom);
  }

'''
if insert_before_raster not in s:
    raise SystemExit('raster insertion anchor missing')
s = s.replace(insert_before_raster, vector_block + insert_before_raster, 1)

# Camera moves now route through the active renderer.
s = re.sub(r'_mapController\.move\(([^;]+)\);', r'_moveActiveMap(\1);', s)

# Sync vector annotations after GPS, tracking, destination and route changes.
# These replacements are intentionally placed on stable log anchors.
s = s.replace("      _log('실제 GPS 수신 · 정확도 ±${position.accuracy.toStringAsFixed(1)}m');\n      _updateNavigationProgress(position);",
              "      _log('실제 GPS 수신 · 정확도 ±${position.accuracy.toStringAsFixed(1)}m');\n      _updateNavigationProgress(position);\n      _syncVectorAnnotations();", 1)

tracking_anchor = "          _updateNavigationProgress(position);\n        },"
if tracking_anchor in s:
    s = s.replace(tracking_anchor, "          _updateNavigationProgress(position);\n          _syncVectorAnnotations();\n        },", 1)

select_anchor = "    _log('목적지 지정 · $label · ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');\n"
if select_anchor not in s:
    raise SystemExit('destination log anchor missing')
s = s.replace(select_anchor, select_anchor + '    _syncVectorAnnotations();\n', 1)

route_log_anchor = "      _log(autoReroute ? '자동 재탐색 완료 · ${_formatDistance(_routeDistanceMeters ?? 0)}' : '실제 보행 경로 수신 · ${_formatDistance(_routeDistanceMeters ?? 0)} · ${points.length} points');\n"
if route_log_anchor in s:
    s = s.replace(route_log_anchor, route_log_anchor + '      _syncVectorAnnotations();\n', 1)
else:
    # Fallback for slightly different v0.6 route-log wording.
    fallback = "      _log('실제 보행 경로 수신 · ${_formatDistance(_routeDistanceMeters ?? 0)} · ${points.length} points');\n"
    if fallback in s:
        s = s.replace(fallback, fallback + '      _syncVectorAnnotations();\n', 1)

# Runtime strip indicates actual renderer.
strip_anchor = "_StatusPill(label: '실제 지도', state: _mapReady ? CheckState.pass : CheckState.running),"
if strip_anchor in s:
    s = s.replace(strip_anchor,
                  "_StatusPill(label: _vectorRendererActive ? '벡터 지도' : '호환 지도', state: _mapReady ? CheckState.pass : CheckState.running),",
                  1)

# Add renderer status to diagnostics before OSM network entry.
diag_anchor = "      DiagnosticCheck(\n        'OSM 지도 네트워크',"
vector_diag = """      DiagnosticCheck(
        '지도 렌더러',
        _vectorRendererActive
            ? (_vectorStyleReady ? 'MapLibre + OpenFreeMap Liberty 벡터 스타일' : '벡터 스타일 로딩 중')
            : 'flutter_map 래스터 호환 모드',
        _vectorRendererActive
            ? (_vectorStyleReady ? CheckState.pass : CheckState.running)
            : CheckState.warning,
      ),
      DiagnosticCheck(
        'OSM 지도 네트워크',"""
if diag_anchor not in s:
    raise SystemExit('diagnostic renderer anchor missing')
s = s.replace(diag_anchor, vector_diag, 1)

# Roadmap: vector engine now current; voice guidance is next.
s = s.replace("_PlanItem('v0.6.1', '확대 시 주변 상가·시설 고밀도 표시', '현재', CheckState.pass),",
              "_PlanItem('v0.6.1', '확대 시 주변 상가·시설 고밀도 표시', 'Gate 통과', CheckState.pass),")
s = s.replace("_PlanItem('v0.6.2', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),",
              "_PlanItem('v0.6.2', 'MapLibre 벡터 지도 + 상업지도형 라벨', '현재', CheckState.pass),\n      _PlanItem('v0.6.3', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),")

# Validate critical markers.
required = [
    "import 'package:maplibre_gl/maplibre_gl.dart' as ml;",
    'Widget _buildVectorMap()',
    '_vectorStyleUrl',
    'OpenFreeMap Liberty 벡터 스타일 로드 완료',
    'Future<void> _syncVectorAnnotations()',
    'void _moveActiveMap(',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing transformed marker: {marker}')

p.write_text(s)
print('APPLY_V062: PASS')
