from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

s = s.replace('ComfortRoute/0.6 (com.fx564286.comfort_route_sample)', 'ComfortRoute/0.6.1 (com.fx564286.comfort_route_sample)')

projection_anchor = '''class _RouteProjection {\n  const _RouteProjection({required this.distanceMeters, required this.alongMeters});\n  final double distanceMeters;\n  final double alongMeters;\n}\n'''
poi_class = projection_anchor + '''\nclass _NearbyPoi {\n  const _NearbyPoi({\n    required this.name,\n    required this.point,\n    required this.category,\n    required this.priority,\n  });\n\n  final String name;\n  final LatLng point;\n  final String category;\n  final int priority;\n}\n'''
if projection_anchor not in s:
    raise SystemExit('route projection anchor not found')
s = s.replace(projection_anchor, poi_class, 1)

field_anchor = '  DateTime? _lastAutoRerouteAt;\n'
poi_fields = field_anchor + '''\n  Timer? _poiDebounce;\n  final Map<String, List<_NearbyPoi>> _poiCache = <String, List<_NearbyPoi>>{};\n  List<_NearbyPoi> _nearbyPois = const <_NearbyPoi>[];\n  bool _poiLoading = false;\n  String? _poiError;\n  double _mapZoom = 12.5;\n  int _poiRequestGeneration = 0;\n'''
if field_anchor not in s:
    raise SystemExit('field anchor not found')
s = s.replace(field_anchor, poi_fields, 1)

s = s.replace('''  void dispose() {\n    _positionSubscription?.cancel();''', '''  void dispose() {\n    _poiDebounce?.cancel();\n    _positionSubscription?.cancel();''', 1)

route_pill = '''          _StatusPill(label: '실제 보행 경로', state: routeState),\n          const SizedBox(width: 6),\n          const _StatusPill(label: '쾌적도 후속', state: CheckState.unavailable),'''
poi_pill = '''          _StatusPill(label: '실제 보행 경로', state: routeState),\n          const SizedBox(width: 6),\n          _StatusPill(\n            label: _mapZoom < 15\n                ? '확대하면 주변 상가'\n                : (_poiLoading ? '주변 상가 불러오는 중' : '주변 상가 ${_nearbyPois.length}곳'),\n            state: _mapZoom < 15\n                ? CheckState.unknown\n                : (_poiLoading ? CheckState.running : (_poiError == null ? CheckState.pass : CheckState.warning)),\n          ),\n          const SizedBox(width: 6),\n          const _StatusPill(label: '쾌적도 후속', state: CheckState.unavailable),'''
if route_pill not in s:
    raise SystemExit('route pill anchor not found')
s = s.replace(route_pill, poi_pill, 1)

markers_anchor = '''    final markers = <Marker>[];\n'''
poi_marker_block = '''    final poiMarkers = _nearbyPois.map((poi) {\n      final dense = _mapZoom >= 17;\n      return Marker(\n        point: poi.point,\n        width: dense ? 150 : 126,\n        height: 38,\n        child: GestureDetector(\n          behavior: HitTestBehavior.opaque,\n          onTap: () => _showPoiDetail(poi),\n          child: Container(\n            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),\n            decoration: BoxDecoration(\n              color: AppColors.surfaceStrong.withValues(alpha: 0.94),\n              borderRadius: BorderRadius.circular(AppRadius.pill),\n              boxShadow: AppShadows.soft,\n            ),\n            child: Row(\n              mainAxisSize: MainAxisSize.min,\n              children: [\n                Icon(_poiIcon(poi.category), size: 15, color: AppColors.primaryDeep),\n                const SizedBox(width: 5),\n                Flexible(\n                  child: Text(\n                    poi.name,\n                    maxLines: 1,\n                    overflow: TextOverflow.ellipsis,\n                    style: const TextStyle(\n                      color: AppColors.text,\n                      fontSize: 11,\n                      fontWeight: FontWeight.w800,\n                    ),\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      );\n    }).toList(growable: false);\n\n    final markers = <Marker>[];\n'''
if markers_anchor not in s:
    raise SystemExit('markers anchor not found')
s = s.replace(markers_anchor, poi_marker_block, 1)

children_anchor = '''              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),\n              if (markers.isNotEmpty) MarkerLayer(markers: markers),'''
children_new = '''              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),\n              if (poiMarkers.isNotEmpty) MarkerLayer(markers: poiMarkers),\n              if (markers.isNotEmpty) MarkerLayer(markers: markers),'''
if children_anchor not in s:
    raise SystemExit('map children anchor not found')
s = s.replace(children_anchor, children_new, 1)

position_anchor = '''              onMapReady: () {\n                if (!mounted) return;\n                setState(() => _mapReady = true);\n                _log('지도 엔진 준비 완료');\n              },\n              onTap: (_, point) => _selectDestination(point, '지도 선택 지점'),'''
position_new = '''              onMapReady: () {\n                if (!mounted) return;\n                setState(() => _mapReady = true);\n                _log('지도 엔진 준비 완료');\n              },\n              onPositionChanged: (camera, hasGesture) {\n                _mapZoom = camera.zoom;\n                _scheduleNearbyPoiRefresh(camera.center, camera.zoom);\n              },\n              onTap: (_, point) => _selectDestination(point, '지도 선택 지점'),'''
if position_anchor not in s:
    raise SystemExit('map options anchor not found')
s = s.replace(position_anchor, position_new, 1)

plan_old = "      _PlanItem('v0.6.1', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),"
plan_new = "      _PlanItem('v0.6.1', '확대 시 주변 상가·시설 고밀도 표시', '현재', CheckState.pass),\n      _PlanItem('v0.6.2', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),"
if plan_old in s:
    s = s.replace(plan_old, plan_new, 1)

check_anchor = '''      DiagnosticCheck(\n        '실제 보행 경로','''
# Add an extra diagnostic immediately before comfort features by replacing their line.
comfort_check = "      const DiagnosticCheck('쾌적도·건물 통과', '일반 내비 Gate 이후 연결합니다.', CheckState.unavailable),"
poi_check = '''      DiagnosticCheck(\n        '주변 상가·시설',\n        _mapZoom < 15\n            ? '지도를 줌 15 이상 확대하면 현재 화면 주변 POI를 불러옵니다.'\n            : (_poiLoading\n                ? '주변 POI 조회 중'\n                : (_poiError == null\n                    ? '${_nearbyPois.length}개 라벨 표시 · 확대할수록 밀도 증가'\n                    : 'POI 조회 일부 실패 · 기본 지도와 캐시 유지')),\n        _mapZoom < 15\n            ? CheckState.unknown\n            : (_poiLoading ? CheckState.running : (_poiError == null ? CheckState.pass : CheckState.warning)),\n      ),\n      const DiagnosticCheck('쾌적도·건물 통과', '일반 내비 Gate 이후 연결합니다.', CheckState.unavailable),'''
if comfort_check not in s:
    raise SystemExit('diagnostic comfort anchor not found')
s = s.replace(comfort_check, poi_check, 1)

insert_anchor = '''  void _copyLogs() {\n'''
poi_methods = r'''  void _scheduleNearbyPoiRefresh(LatLng center, double zoom) {
    _mapZoom = zoom;
    _poiDebounce?.cancel();

    if (zoom < 15) {
      if (_nearbyPois.isNotEmpty || _poiError != null || _poiLoading) {
        if (mounted) {
          setState(() {
            _nearbyPois = const <_NearbyPoi>[];
            _poiLoading = false;
            _poiError = null;
          });
        }
      }
      return;
    }

    _poiDebounce = Timer(const Duration(milliseconds: 850), () {
      _fetchNearbyPois(center, zoom);
    });
  }

  String _poiCacheKey(LatLng center, double zoom) {
    final grid = zoom >= 18 ? 0.002 : zoom >= 17 ? 0.003 : zoom >= 16 ? 0.005 : 0.009;
    final latCell = (center.latitude / grid).round();
    final lonCell = (center.longitude / grid).round();
    return '${zoom.floor()}:$latCell:$lonCell';
  }

  Future<void> _fetchNearbyPois(LatLng center, double zoom) async {
    if (zoom < 15) return;
    final key = _poiCacheKey(center, zoom);
    final cached = _poiCache[key];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _nearbyPois = cached;
        _poiLoading = false;
        _poiError = null;
      });
      return;
    }

    final generation = ++_poiRequestGeneration;
    if (mounted) {
      setState(() {
        _poiLoading = true;
        _poiError = null;
      });
    }

    final radius = zoom >= 18 ? 450 : zoom >= 17 ? 700 : zoom >= 16 ? 1050 : 1500;
    final extras = zoom >= 17.5
        ? '''nwr["building"]["name"](around:$radius,${center.latitude},${center.longitude});
             nwr["office"]["name"](around:$radius,${center.latitude},${center.longitude});'''
        : '';
    final query = '''[out:json][timeout:8];
      (
        nwr["shop"]["name"](around:$radius,${center.latitude},${center.longitude});
        nwr["amenity"~"restaurant|cafe|fast_food|pharmacy|bank|atm|hospital|clinic|doctors|dentist|fuel|parking|toilets|drinking_water|marketplace"]["name"](around:$radius,${center.latitude},${center.longitude});
        nwr["tourism"~"hotel|museum|attraction"]["name"](around:$radius,${center.latitude},${center.longitude});
        nwr["leisure"~"fitness_centre|park"]["name"](around:$radius,${center.latitude},${center.longitude});
        $extras
      );
      out center tags;''';

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(Uri.parse('https://overpass-api.de/api/interpreter'));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      request.write('data=${Uri.encodeQueryComponent(query)}');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final elements = decoded['elements'] as List<dynamic>? ?? const <dynamic>[];
      final candidates = <_NearbyPoi>[];

      for (final raw in elements) {
        final element = raw as Map<String, dynamic>;
        final tagsRaw = element['tags'];
        if (tagsRaw is! Map) continue;
        final tags = <String, dynamic>{};
        tagsRaw.forEach((key, value) => tags['$key'] = value);
        final name = '${tags['name:ko'] ?? tags['name'] ?? tags['brand'] ?? ''}'.trim();
        if (name.isEmpty) continue;

        double? lat;
        double? lon;
        if (element['lat'] is num && element['lon'] is num) {
          lat = (element['lat'] as num).toDouble();
          lon = (element['lon'] as num).toDouble();
        } else if (element['center'] is Map) {
          final centerMap = element['center'] as Map;
          if (centerMap['lat'] is num && centerMap['lon'] is num) {
            lat = (centerMap['lat'] as num).toDouble();
            lon = (centerMap['lon'] as num).toDouble();
          }
        }
        if (lat == null || lon == null) continue;

        final priority = _poiPriority(tags);
        if (zoom < 15.8 && priority > 0) continue;
        if (zoom < 16.8 && priority > 1) continue;
        if (zoom < 17.5 && priority > 2) continue;

        candidates.add(_NearbyPoi(
          name: name,
          point: LatLng(lat, lon),
          category: _poiCategory(tags),
          priority: priority,
        ));
      }

      candidates.sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        final da = Geolocator.distanceBetween(center.latitude, center.longitude, a.point.latitude, a.point.longitude);
        final db = Geolocator.distanceBetween(center.latitude, center.longitude, b.point.latitude, b.point.longitude);
        return da.compareTo(db);
      });

      final spacing = zoom >= 18 ? 16.0 : zoom >= 17 ? 28.0 : zoom >= 16 ? 45.0 : 75.0;
      final limit = zoom >= 18 ? 60 : zoom >= 17 ? 44 : zoom >= 16 ? 28 : 14;
      final selected = <_NearbyPoi>[];
      for (final poi in candidates) {
        final overlaps = selected.any((kept) => Geolocator.distanceBetween(
              kept.point.latitude,
              kept.point.longitude,
              poi.point.latitude,
              poi.point.longitude,
            ) < spacing);
        if (overlaps) continue;
        selected.add(poi);
        if (selected.length >= limit) break;
      }

      _poiCache[key] = selected;
      if (!mounted || generation != _poiRequestGeneration) return;
      setState(() {
        _nearbyPois = selected;
        _poiLoading = false;
        _poiError = null;
      });
      _log('주변 상가·시설 표시 · 줌 ${zoom.toStringAsFixed(1)} · ${selected.length}곳');
    } catch (error) {
      if (!mounted || generation != _poiRequestGeneration) return;
      setState(() {
        _poiLoading = false;
        _poiError = '$error';
      });
      _log('주변 POI 조회 오류: $error');
    } finally {
      client?.close(force: true);
    }
  }

  int _poiPriority(Map<String, dynamic> tags) {
    final shop = '${tags['shop'] ?? ''}';
    final amenity = '${tags['amenity'] ?? ''}';
    final tourism = '${tags['tourism'] ?? ''}';
    if (shop == 'convenience' || shop == 'supermarket' || shop == 'mall' || shop == 'department_store') return 0;
    if (amenity == 'hospital' || amenity == 'pharmacy' || amenity == 'fuel' || amenity == 'parking') return 0;
    if (amenity == 'restaurant' || amenity == 'cafe' || amenity == 'fast_food' || amenity == 'bank' || amenity == 'atm') return 1;
    if (amenity == 'toilets' || amenity == 'drinking_water' || amenity == 'clinic' || tourism == 'hotel') return 1;
    if (shop.isNotEmpty || tourism.isNotEmpty || '${tags['leisure'] ?? ''}'.isNotEmpty) return 2;
    return 3;
  }

  String _poiCategory(Map<String, dynamic> tags) {
    final shop = '${tags['shop'] ?? ''}';
    final amenity = '${tags['amenity'] ?? ''}';
    if (shop == 'convenience') return '편의점';
    if (shop == 'supermarket') return '마트';
    if (shop == 'mall' || shop == 'department_store') return '쇼핑';
    if (amenity == 'restaurant') return '음식점';
    if (amenity == 'cafe') return '카페';
    if (amenity == 'fast_food') return '패스트푸드';
    if (amenity == 'pharmacy') return '약국';
    if (amenity == 'hospital' || amenity == 'clinic' || amenity == 'doctors' || amenity == 'dentist') return '의료';
    if (amenity == 'bank' || amenity == 'atm') return '금융';
    if (amenity == 'parking') return '주차';
    if (amenity == 'fuel') return '주유';
    if (amenity == 'toilets') return '화장실';
    if (amenity == 'drinking_water') return '음수대';
    if ('${tags['tourism'] ?? ''}' == 'hotel') return '숙박';
    if ('${tags['building'] ?? ''}'.isNotEmpty) return '건물';
    if ('${tags['office'] ?? ''}'.isNotEmpty) return '업무';
    return shop.isNotEmpty ? '상점' : '시설';
  }

  IconData _poiIcon(String category) {
    switch (category) {
      case '편의점':
      case '마트':
      case '쇼핑':
      case '상점':
        return Icons.storefront_rounded;
      case '음식점':
      case '패스트푸드':
        return Icons.restaurant_rounded;
      case '카페':
        return Icons.local_cafe_rounded;
      case '약국':
      case '의료':
        return Icons.local_hospital_rounded;
      case '금융':
        return Icons.account_balance_rounded;
      case '주차':
        return Icons.local_parking_rounded;
      case '주유':
        return Icons.local_gas_station_rounded;
      case '화장실':
        return Icons.wc_rounded;
      case '음수대':
        return Icons.water_drop_rounded;
      case '숙박':
        return Icons.hotel_rounded;
      case '건물':
      case '업무':
        return Icons.apartment_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  void _showPoiDetail(_NearbyPoi poi) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: Icon(_poiIcon(poi.category), color: AppColors.primaryDeep),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(poi.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(poi.category, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                '${poi.point.latitude.toStringAsFixed(6)}, ${poi.point.longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _selectDestination(poi.point, poi.name);
                    if (_mapReady) _mapController.move(poi.point, 17);
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('이곳을 목적지로'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyLogs() {
'''
if insert_anchor not in s:
    raise SystemExit('copy logs anchor not found')
s = s.replace(insert_anchor, poi_methods, 1)

p.write_text(s)
print('APPLY_V061: PASS')
