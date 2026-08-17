from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.6: stricter GPS quality handling, Korean-first vector labels, and
# first route-adjacent essential amenity summary without pretending OSM data is verified.
nav_import = "import 'package:comfort_route_sample/navigation_guidance.dart';\n"
if nav_import not in s:
    raise SystemExit('navigation guidance import missing')
s = s.replace(
    nav_import,
    nav_import + "import 'package:comfort_route_sample/gps_quality.dart';\n",
    1,
)
s = s.replace(
    'ComfortRoute/0.6.5 (com.fx564286.comfort_route_sample)',
    'ComfortRoute/0.6.6 (com.fx564286.comfort_route_sample)',
    1,
)
s = s.replace(
    'static const _maxNavigationAccuracyMeters = 80.0;',
    'static const _maxNavigationAccuracyMeters = GpsPolicy.navigationMaxMeters;',
    1,
)

state_anchor = '  DateTime? _lastPoorAccuracyLogAt;\n'
state_extra = state_anchor + '''  LocationAccuracyStatus? _accuracyStatus;\n  double? _latestRawAccuracyMeters;\n  bool _koreanLabelsApplied = false;\n  int _koreanLabelLayerCount = 0;\n'''
if state_anchor not in s:
    raise SystemExit('location state anchor missing')
s = s.replace(state_anchor, state_extra, 1)

# Replace acquisition with best-for-navigation + short best-sample refinement.
acquire_re = re.compile(
    r"  Future<void> _doAcquireLocation\(\{required bool requestPermission\}\) async \{.*?\n  \}\n\n  Future<void> _toggleTracking\(\) async \{",
    re.S,
)
acquire_block = r'''  Future<Position> _refinePositionIfNeeded(Position initial) async {
    if (initial.accuracy.isFinite &&
        initial.accuracy > 0 &&
        initial.accuracy <= GpsPolicy.preferredMeters) {
      return initial;
    }

    var best = initial;
    final completer = Completer<void>();
    StreamSubscription<Position>? subscription;
    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen(
        (candidate) {
          if (!candidate.accuracy.isFinite || candidate.accuracy <= 0) return;
          if (mounted) setState(() => _latestRawAccuracyMeters = candidate.accuracy);
          if (!best.accuracy.isFinite || candidate.accuracy < best.accuracy) best = candidate;
          if (best.accuracy <= GpsPolicy.preferredMeters && !completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future.timeout(const Duration(seconds: 7));
    } on TimeoutException {
      // Keep the best sample collected during the bounded refinement window.
    } finally {
      await subscription?.cancel();
    }
    if (best.accuracy < initial.accuracy) {
      _log('GPS 정밀도 개선 · ${GpsPolicy.uncertaintyLabel(initial.accuracy)} → ${GpsPolicy.uncertaintyLabel(best.accuracy)}');
    }
    return best;
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

      try {
        final status = await Geolocator.getLocationAccuracy();
        if (mounted) setState(() => _accuracyStatus = status);
        if (status == LocationAccuracyStatus.reduced) {
          _log('휴대폰이 대략적인 위치만 허용 중 · 정확한 위치 권한 권장');
        }
      } catch (error) {
        _log('위치 정확도 권한 상태 확인 생략: $error');
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted && _position == null) {
        final age = DateTime.now().difference(lastKnown.timestamp).abs();
        if (age <= const Duration(minutes: 5) &&
            GpsPolicy.usableForNavigation(lastKnown.accuracy)) {
          setState(() {
            _position = lastKnown;
            _latestRawAccuracyMeters = lastKnown.accuracy;
            _locationError = null;
          });
          _log('최근 위치 우선 표시 · ${age.inMinutes}분 전 · ${GpsPolicy.uncertaintyLabel(lastKnown.accuracy)}');
        } else {
          _log('최근 위치 제외 · ${age.inMinutes}분 전 · ${GpsPolicy.uncertaintyLabel(lastKnown.accuracy)}');
        }
      }

      var position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() => _latestRawAccuracyMeters = position.accuracy);
      position = await _refinePositionIfNeeded(position);
      if (!mounted) return;
      setState(() {
        _position = position;
        _latestRawAccuracyMeters = position.accuracy;
        _locationError = null;
      });
      _log('실제 GPS 수신 · ${GpsPolicy.uncertaintyLabel(position.accuracy)}');
      if (GpsPolicy.usableForNavigation(position.accuracy)) {
        _updateNavigationProgress(position);
      } else {
        _log('GPS 안정화 필요 · 45m 초과 샘플은 경로 진행·이탈·음성에 미반영');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = 'GPS 수신 오류: $error');
      _log('GPS 오류: $error');
    }
  }

  Future<void> _toggleTracking() async {'''
s, count = acquire_re.subn(acquire_block, s, count=1)
if count != 1:
    raise SystemExit(f'GPS acquisition replacement failed: {count}')

# Replace live tracking so poor samples do not overwrite a previously usable navigation fix.
tracking_re = re.compile(
    r"  Future<void> _toggleTracking\(\) async \{.*?\n  \}\n\n  Future<void> _stopTracking\(\) async \{",
    re.S,
)
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
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(
        (position) {
          if (!mounted) return;
          setState(() => _latestRawAccuracyMeters = position.accuracy);
          if (!GpsPolicy.usableForNavigation(position.accuracy)) {
            final now = DateTime.now();
            if (_lastPoorAccuracyLogAt == null ||
                now.difference(_lastPoorAccuracyLogAt!) > const Duration(seconds: 20)) {
              _lastPoorAccuracyLogAt = now;
              _log('${GpsPolicy.uncertaintyLabel(position.accuracy)} · 내비 반영 보류');
            }
            return;
          }
          setState(() {
            _position = position;
            _locationError = null;
          });
          _updateNavigationProgress(position);
          _syncVectorAnnotations();
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
      unawaited(_refreshTtsStatus());
      _log('실시간 위치 추적 시작 · 이동 갱신 간격 5m · 내비 허용 오차 45m');
    } finally {
      _trackingTransitionInFlight = false;
    }
  }

  Future<void> _stopTracking() async {'''
s, count = tracking_re.subn(tracking_block, s, count=1)
if count != 1:
    raise SystemExit(f'GPS tracking replacement failed: {count}')

# Any remaining route-start copy must use uncertainty wording and the new ceiling.
s = s.replace(
    "'GPS 정확도가 ±${accuracy.toStringAsFixed(0)}m입니다. 80m 이하에서 경로를 계산해 주세요.'",
    "'현재 위치 오차가 약 ${accuracy.toStringAsFixed(0)}m입니다. 45m 이하로 안정화되면 경로를 계산합니다.'",
)

# Korean/native-first labels. Preserve full existing symbol layer properties and
# only replace name-centric text fields; leave refs, elevation, housenumbers and IATA intact.
style_callback_anchor = "              _log('OpenFreeMap Positron 벡터 스타일 로드 완료');\n              _syncVectorAnnotations();\n"
style_callback_new = "              _log('OpenFreeMap Positron 벡터 스타일 로드 완료');\n              unawaited(_applyKoreanMapLabels());\n              _syncVectorAnnotations();\n"
if style_callback_anchor not in s:
    raise SystemExit('vector style loaded callback anchor missing')
s = s.replace(style_callback_anchor, style_callback_new, 1)

sync_anchor = '  Future<void> _syncVectorAnnotations() async {\n'
localization_method = r'''  Future<void> _applyKoreanMapLabels() async {
    final controller = _vectorMapController;
    if (!_vectorRendererActive || !_vectorStyleReady || controller == null) return;
    try {
      final rawStyle = await controller.getStyle();
      if (rawStyle == null || rawStyle.isEmpty) return;
      final decoded = jsonDecode(rawStyle);
      if (decoded is! Map<String, dynamic>) return;
      final layers = decoded['layers'];
      if (layers is! List) return;

      const koreanFirst = <dynamic>[
        'coalesce',
        <dynamic>['get', 'name:ko'],
        <dynamic>['get', 'name:nonlatin'],
        <dynamic>['get', 'name'],
        <dynamic>['get', 'name:latin'],
        <dynamic>['get', 'name_en'],
        <dynamic>['get', 'name:en'],
      ];
      var changed = 0;
      for (final rawLayer in layers) {
        if (rawLayer is! Map) continue;
        final layer = <String, dynamic>{};
        rawLayer.forEach((key, value) => layer['$key'] = value);
        if (layer['type'] != 'symbol') continue;
        final id = '${layer['id'] ?? ''}';
        if (id.isEmpty) continue;
        final layoutRaw = layer['layout'];
        if (layoutRaw is! Map) continue;
        final layout = <String, dynamic>{};
        layoutRaw.forEach((key, value) => layout['$key'] = value);
        final textField = layout['text-field'];
        if (textField == null) continue;
        final encoded = jsonEncode(textField);
        final hasName = encoded.contains('"name"') ||
            encoded.contains('"name:') ||
            encoded.contains('"name_');
        if (!hasName) continue;
        final special = encoded.contains('"ele"') ||
            encoded.contains('"ele_ft"') ||
            encoded.contains('"iata"') ||
            encoded.contains('"housenumber"') ||
            encoded.contains('"height"') ||
            encoded.contains('"ref"');
        if (special) continue;

        final properties = <String, dynamic>{};
        final paintRaw = layer['paint'];
        if (paintRaw is Map) paintRaw.forEach((key, value) => properties['$key'] = value);
        properties.addAll(layout);
        properties['text-field'] = koreanFirst;
        await controller.setLayerProperties(id, ml.SymbolLayerProperties.fromJson(properties));
        changed++;
      }
      if (!mounted) return;
      setState(() {
        _koreanLabelsApplied = true;
        _koreanLabelLayerCount = changed;
      });
      _log('한국어 우선 지도 라벨 적용 · $changed개 layer');
    } catch (error) {
      _log('한국어 지도 라벨 적용 일부 실패 · 기존 지도 유지: $error');
    }
  }

'''
if sync_anchor not in s:
    raise SystemExit('vector sync anchor missing')
s = s.replace(sync_anchor, localization_method + sync_anchor, 1)

# Make the map badge explicit about localization after the style patch finishes.
s = s.replace(
    "label: _vectorStyleReady ? '쾌적 지도' : '지도 준비 중',",
    "label: _vectorStyleReady ? (_koreanLabelsApplied ? '쾌적 지도 · 한국어 우선' : '쾌적 지도') : '지도 준비 중',",
    1,
)

# Essential OSM amenities: fetch toilets/water/shelters even when unnamed, then
# use a Korean fallback label. These are explicitly unverified OSM signals.
old_amenity_query = '        nwr["amenity"~"restaurant|cafe|fast_food|pharmacy|bank|atm|hospital|clinic|doctors|dentist|fuel|parking|toilets|drinking_water|marketplace"]["name"](around:$radius,${center.latitude},${center.longitude});\n'
new_amenity_query = '        nwr["amenity"~"restaurant|cafe|fast_food|pharmacy|bank|atm|hospital|clinic|doctors|dentist|fuel|parking|marketplace"]["name"](around:$radius,${center.latitude},${center.longitude});\n        nwr["amenity"~"toilets|drinking_water|shelter"](around:$radius,${center.latitude},${center.longitude});\n'
if old_amenity_query not in s:
    raise SystemExit('Overpass amenity query anchor missing')
s = s.replace(old_amenity_query, new_amenity_query, 1)

name_anchor = "        final name = '${tags['name:ko'] ?? tags['name'] ?? tags['brand'] ?? ''}'.trim();\n        if (name.isEmpty) continue;\n"
name_new = "        final category = _poiCategory(tags);\n        final rawName = '${tags['name:ko'] ?? tags['name'] ?? tags['brand'] ?? ''}'.trim();\n        final name = rawName.isNotEmpty ? rawName : _essentialPoiFallbackName(category);\n        if (name.isEmpty) continue;\n"
if name_anchor not in s:
    raise SystemExit('POI name anchor missing')
s = s.replace(name_anchor, name_new, 1)
s = s.replace('          category: _poiCategory(tags),\n', '          category: category,\n', 1)

category_anchor = "    if (amenity == 'drinking_water') return '음수대';\n"
category_new = category_anchor + "    if (amenity == 'shelter') return '쉼터';\n"
if category_anchor not in s:
    raise SystemExit('POI category drinking water anchor missing')
s = s.replace(category_anchor, category_new, 1)

priority_anchor = "    if (amenity == 'toilets' || amenity == 'drinking_water' || amenity == 'clinic' || tourism == 'hotel') return 1;\n"
priority_new = "    if (amenity == 'toilets' || amenity == 'drinking_water' || amenity == 'shelter' || amenity == 'clinic' || tourism == 'hotel') return 1;\n"
if priority_anchor not in s:
    raise SystemExit('POI priority anchor missing')
s = s.replace(priority_anchor, priority_new, 1)

copy_logs_anchor = '  void _copyLogs() {\n'
amenity_helpers = r'''  String _essentialPoiFallbackName(String category) {
    switch (category) {
      case '화장실':
        return '공중화장실';
      case '음수대':
        return '음수대';
      case '쉼터':
        return '쉼터';
      default:
        return '';
    }
  }

  int get _routeWaterCount =>
      _countRouteSignals(_routePoints, const {'음수대'}, maxDistanceMeters: 120);
  int get _routeToiletCount =>
      _countRouteSignals(_routePoints, const {'화장실'}, maxDistanceMeters: 120);
  int get _routeShelterCount =>
      _countRouteSignals(_routePoints, const {'쉼터'}, maxDistanceMeters: 120);

  Widget _buildEssentialAmenitySummary() {
    final water = _routeWaterCount;
    final toilets = _routeToiletCount;
    final shelters = _routeShelterCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _AppMetricPill(icon: Icons.water_drop_rounded, label: '음수 $water'),
            _AppMetricPill(icon: Icons.wc_rounded, label: '화장실 $toilets'),
            _AppMetricPill(icon: Icons.chair_alt_rounded, label: '쉼터 $shelters'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '경로 120m 주변 OSM 신호 · 운영 여부 미검증',
          style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

'''
if copy_logs_anchor not in s:
    raise SystemExit('copy logs method anchor missing')
s = s.replace(copy_logs_anchor, amenity_helpers + copy_logs_anchor, 1)

# Reuse a tiny pill local to this generated source; insert before _SmallAction.
small_action_anchor = 'class _SmallAction extends StatelessWidget {\n'
metric_class = r'''class _AppMetricPill extends StatelessWidget {
  const _AppMetricPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDeep),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.primaryDeep, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

'''
if small_action_anchor not in s:
    raise SystemExit('SmallAction class anchor missing')
s = s.replace(small_action_anchor, metric_class + small_action_anchor, 1)

# Route card: show essential amenity counts when the nearby cache has data.
route_explanation_anchor = '''          if (!compact) ...[
            const SizedBox(height: 11),'''
route_explanation_new = '''          if (hasRoute && _nearbyPois.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildEssentialAmenitySummary(),
          ],
          if (!compact) ...[
            const SizedBox(height: 11),'''
if route_explanation_anchor not in s:
    raise SystemExit('route card amenity insertion anchor missing')
s = s.replace(route_explanation_anchor, route_explanation_new, 1)

# Diagnostics: make reduced/precise permission and raw-vs-accepted accuracy visible.
diag_row_anchor = "          _KeyValueRow(label: '회전 안내', value: _routeManeuvers.isEmpty ? '-' : '${_routeManeuvers.length}개 step'),\n"
diag_rows = """          _KeyValueRow(label: '위치 권한 정밀도', value: _accuracyStatus == LocationAccuracyStatus.reduced ? '대략적인 위치' : (_accuracyStatus == LocationAccuracyStatus.precise ? '정확한 위치' : '-')),
          _KeyValueRow(label: '최근 GPS', value: _latestRawAccuracyMeters == null ? '-' : GpsPolicy.uncertaintyLabel(_latestRawAccuracyMeters!)),
          _KeyValueRow(label: '한국어 지도 라벨', value: _koreanLabelsApplied ? '${_koreanLabelLayerCount}개 layer 적용' : '적용 대기'),
""" + diag_row_anchor
if diag_row_anchor not in s:
    raise SystemExit('diagnostics v065 anchor missing')
s = s.replace(diag_row_anchor, diag_rows, 1)

# Clean up old plus-minus phrasing that remains in logs/UX from earlier transforms.
s = s.replace("'GPS 정확도 낮음 · ±${position.accuracy.toStringAsFixed(1)}m · 경로 기준에는 사용 보류'",
              "'${GpsPolicy.uncertaintyLabel(position.accuracy)} · 경로 기준에는 사용 보류'")
s = s.replace("'실제 GPS 수신 · 정확도 ±${position.accuracy.toStringAsFixed(1)}m'",
              "'실제 GPS 수신 · ${GpsPolicy.uncertaintyLabel(position.accuracy)}'")

required = [
    "import 'package:comfort_route_sample/gps_quality.dart';",
    'LocationAccuracy.bestForNavigation',
    'GpsPolicy.navigationMaxMeters',
    'GPS 안정화 필요 · 45m 초과 샘플은 경로 진행·이탈·음성에 미반영',
    'Future<void> _applyKoreanMapLabels() async',
    "<dynamic>['get', 'name:ko']",
    "<dynamic>['get', 'name:nonlatin']",
    'ml.SymbolLayerProperties.fromJson(properties)',
    "nwr[\"amenity\"~\"toilets|drinking_water|shelter\"]",
    "if (amenity == 'shelter') return '쉼터';",
    '경로 120m 주변 OSM 신호 · 운영 여부 미검증',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v066 marker: {marker}')

p.write_text(s)
print('APPLY_V066_GPS_KOREAN_MAP: PASS')
