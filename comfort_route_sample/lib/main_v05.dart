import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const ComfortRouteApp());

class AppColors {
  static const background = Color(0xFFF8F5F7);
  static const surface = Color(0xFFFFFCFD);
  static const surfaceStrong = Colors.white;
  static const primary = Color(0xFFA86F88);
  static const primaryDeep = Color(0xFF7C5064);
  static const primarySoft = Color(0xFFF3E5EB);
  static const text = Color(0xFF2E2930);
  static const textMuted = Color(0xFF756D73);
  static const shadow = Color(0x140F0810);
  static const pass = Color(0xFF4F886A);
  static const warn = Color(0xFFA9793D);
  static const fail = Color(0xFFB55C66);
  static const info = Color(0xFF5D7893);
}

class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

class AppRadius {
  static const control = 18.0;
  static const card = 26.0;
  static const sheet = 30.0;
  static const pill = 999.0;
}

class AppShadows {
  static const soft = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 22, offset: Offset(0, 8)),
  ];
}

enum CheckState { unknown, running, pass, warning, fail, unavailable }

class DiagnosticCheck {
  const DiagnosticCheck(this.title, this.detail, this.state);
  final String title;
  final String detail;
  final CheckState state;
}

class _PlaceResult {
  const _PlaceResult({required this.name, required this.point, required this.kind});
  final String name;
  final LatLng point;
  final String kind;
}

class ComfortRouteApp extends StatelessWidget {
  const ComfortRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '쾌적길',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        fontFamilyFallback: const ['sans-serif'],
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.surfaceStrong,
          elevation: 0,
          indicatorColor: AppColors.primarySoft,
          height: 68,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide.none,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _fallbackCenter = LatLng(37.5665, 126.9780);
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgent = 'ComfortRoute/0.5 (com.fx564286.comfort_route_sample)';
  static const _maxNavigationAccuracyMeters = 80.0;

  final MapController _mapController = MapController();
  final List<String> _logs = <String>[];
  final Map<String, List<_PlaceResult>> _searchCache = <String, List<_PlaceResult>>{};

  int _tabIndex = 0;
  bool _mapReady = false;
  bool _diagnosticRunning = false;
  bool _networkChecked = false;
  bool _networkOk = false;
  int? _networkStatusCode;

  bool? _locationServiceEnabled;
  LocationPermission? _locationPermission;
  LocationAccuracyStatus? _accuracyStatus;
  Position? _position;
  bool _tracking = false;
  String? _locationError;

  LatLng? _destination;
  String? _destinationLabel;
  List<LatLng> _routePoints = const <LatLng>[];
  LatLng? _routeStart;
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _routeLoading = false;
  String? _routeError;
  bool _routingServiceChecked = false;
  bool _routingServiceOk = false;
  bool _searchServiceChecked = false;
  bool _searchServiceOk = false;
  DateTime? _lastSearchRequestAt;
  DateTime? _lastPoorAccuracyLogAt;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _serviceSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  bool get _positionUsableForRouting =>
      _position != null && _position!.accuracy.isFinite && _position!.accuracy <= _maxNavigationAccuracyMeters;

  bool get _routeNeedsRefresh {
    if (_position == null || _routeStart == null || _routePoints.isEmpty) return false;
    final moved = Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      _routeStart!.latitude,
      _routeStart!.longitude,
    );
    return moved > 50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: [_buildMapPage(), _buildDiagnosticsPage(), _buildPlanPage()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: '지도'),
          NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety_rounded), label: '진단'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: '계획'),
        ],
      ),
    );
  }

  Widget _buildMapPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.xs),
          child: Column(
            children: [
              _buildSearchHeader(),
              const SizedBox(height: AppSpace.xs),
              _buildRuntimeStrip(),
              const SizedBox(height: AppSpace.xs),
              Expanded(child: _buildRealMap()),
              const SizedBox(height: AppSpace.xs),
              _buildMapBottomCard(compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.control),
              onTap: _showDestinationSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primaryDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _destinationLabel ?? '어디로 갈까요?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _destinationLabel == null ? AppColors.textMuted : AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        _CircleButton(
          icon: Icons.my_location_rounded,
          tooltip: '실제 현재 위치 확인',
          onTap: () => _acquireLocation(requestPermission: true, centerMap: true),
        ),
      ],
    );
  }

  Widget _buildRuntimeStrip() {
    final gpsState = _position == null
        ? (_locationError == null ? CheckState.unknown : CheckState.fail)
        : (_positionUsableForRouting ? CheckState.pass : CheckState.warning);
    final routeState = _routeLoading
        ? CheckState.running
        : (_routePoints.isNotEmpty
            ? CheckState.pass
            : (_routeError == null ? CheckState.unknown : CheckState.fail));
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatusPill(label: '실제 지도', state: _mapReady ? CheckState.pass : CheckState.running),
          const SizedBox(width: 6),
          _StatusPill(label: '실제 GPS', state: gpsState),
          const SizedBox(width: 6),
          _StatusPill(label: '목적지 검색', state: _searchServiceChecked ? (_searchServiceOk ? CheckState.pass : CheckState.fail) : CheckState.unknown),
          const SizedBox(width: 6),
          _StatusPill(label: '실제 보행 경로', state: routeState),
          const SizedBox(width: 6),
          const _StatusPill(label: '쾌적도 후속', state: CheckState.unavailable),
        ],
      ),
    );
  }

  Widget _buildRealMap() {
    final current = _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
    final polylines = <Polyline>[];
    if (_routePoints.length >= 2) {
      polylines.add(Polyline(points: _routePoints, strokeWidth: 5, color: AppColors.primaryDeep));
    }

    final markers = <Marker>[];
    if (current != null) {
      markers.add(Marker(point: current, width: 48, height: 48, child: const _CurrentLocationMarker()));
    }
    if (_destination != null) {
      markers.add(Marker(
        point: _destination!,
        width: 48,
        height: 54,
        alignment: Alignment.topCenter,
        child: const _DestinationMarker(),
      ));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: current ?? _fallbackCenter,
              initialZoom: current == null ? 12.5 : 16,
              minZoom: 3,
              maxZoom: 19,
              onMapReady: () {
                if (!mounted) return;
                setState(() => _mapReady = true);
                _log('지도 엔진 준비 완료');
              },
              onTap: (_, point) => _selectDestination(point, '지도 선택 지점'),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.fx564286.comfort_route_sample',
                maxNativeZoom: 19,
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),
          const Positioned(left: 8, bottom: 4, child: _MapAttribution()),
          Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            child: _MapBadge(
              icon: _routePoints.isNotEmpty ? Icons.directions_walk_rounded : Icons.public_rounded,
              label: _routePoints.isNotEmpty ? 'OSM 보행 경로' : 'OpenStreetMap',
              state: _routePoints.isNotEmpty ? CheckState.pass : (_networkChecked ? (_networkOk ? CheckState.pass : CheckState.fail) : CheckState.unknown),
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

  Widget _buildMapBottomCard({required bool compact}) {
    final p = _position;
    final straightMeters = p == null || _destination == null
        ? null
        : Geolocator.distanceBetween(p.latitude, p.longitude, _destination!.latitude, _destination!.longitude);
    final hasRoute = _routeDistanceMeters != null && _routePoints.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
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
                child: Icon(
                  _routeLoading ? Icons.hourglass_top_rounded : (hasRoute ? Icons.directions_walk_rounded : Icons.navigation_rounded),
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationLabel ?? '목적지를 검색하거나 지도에서 눌러주세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _routeLoading
                          ? '실제 보행 경로 계산 중…'
                          : hasRoute
                              ? '${_formatDistance(_routeDistanceMeters!)} · ${_formatDuration(_routeDurationSeconds ?? 0)}${_routeNeedsRefresh ? ' · 위치 이동으로 갱신 권장' : ''}'
                              : (_routeError ?? (straightMeters == null
                                  ? 'GPS와 목적지가 준비되면 실제 보행 경로를 계산합니다.'
                                  : '직선 ${_formatDistance(straightMeters)} · 경로 계산 전 참고값')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _routeError == null ? AppColors.textMuted : AppColors.fail,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: _SmallAction(
                    icon: Icons.search_rounded,
                    label: '목적지 검색',
                    onTap: _showDestinationSearch,
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: _SmallAction(
                    icon: Icons.refresh_rounded,
                    label: hasRoute ? '경로 갱신' : '경로 계산',
                    onTap: _destination == null ? _showDestinationSearch : () => _fetchWalkingRoute(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticsPage() {
    final checks = _diagnosticChecks;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('실행 상태 진단', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.text)),
                    SizedBox(height: 3),
                    Text('센서·검색·경로를 각각 실제 상태로 확인합니다.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _CircleButton(
                icon: _diagnosticRunning ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                tooltip: '전체 재검사',
                onTap: _diagnosticRunning ? null : _runDiagnostics,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: ListView(
              children: [
                _DiagnosticSummary(checks: checks),
                const SizedBox(height: AppSpace.sm),
                ...checks.map((check) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: _DiagnosticRow(check: check),
                    )),
                const SizedBox(height: AppSpace.xs),
                _buildGpsDetailCard(),
                const SizedBox(height: AppSpace.sm),
                _buildRouteDetailCard(),
                const SizedBox(height: AppSpace.sm),
                _buildLogCard(),
                const SizedBox(height: AppSpace.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsDetailCard() {
    final p = _position;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GPS 세부 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpace.sm),
          _KeyValueRow(label: '위치서비스', value: _locationServiceEnabled == null ? '확인 전' : (_locationServiceEnabled! ? '켜짐' : '꺼짐')),
          _KeyValueRow(label: '권한', value: _permissionText(_locationPermission)),
          _KeyValueRow(label: '좌표', value: p == null ? '아직 없음' : '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}'),
          _KeyValueRow(label: 'GPS 정확도', value: p == null ? '-' : '±${p.accuracy.toStringAsFixed(1)} m'),
          _KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능' : '정확도 부족 (>80m)')),
          _KeyValueRow(label: '속도', value: p == null ? '-' : '${(p.speed * 3.6).toStringAsFixed(1)} km/h'),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _acquireLocation(requestPermission: true, centerMap: true),
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('현재 위치 다시 받기'),
              ),
              OutlinedButton.icon(onPressed: Geolocator.openLocationSettings, icon: const Icon(Icons.location_on_outlined), label: const Text('위치 설정')),
              OutlinedButton.icon(onPressed: Geolocator.openAppSettings, icon: const Icon(Icons.settings_outlined), label: const Text('앱 권한 설정')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetailCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('v0.5 실제 경로', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpace.sm),
          _KeyValueRow(label: '목적지 검색', value: !_searchServiceChecked ? '미사용' : (_searchServiceOk ? '정상' : '실패')),
          _KeyValueRow(label: '보행 라우팅', value: !_routingServiceChecked ? '미사용' : (_routingServiceOk ? '정상' : '실패')),
          _KeyValueRow(label: '경로 거리', value: _routeDistanceMeters == null ? '-' : _formatDistance(_routeDistanceMeters!)),
          _KeyValueRow(label: '예상 시간', value: _routeDurationSeconds == null ? '-' : _formatDuration(_routeDurationSeconds!)),
          _KeyValueRow(label: 'geometry', value: _routePoints.isEmpty ? '-' : '${_routePoints.length} points'),
          if (_routeNeedsRefresh)
            const Padding(
              padding: EdgeInsets.only(top: AppSpace.xs),
              child: Text('현재 위치가 경로 계산 시작점에서 50m 이상 이동했습니다. 경로 갱신을 권장합니다.', style: TextStyle(color: AppColors.warn, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildLogCard() {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('진단 로그', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: _logs.isEmpty ? null : _copyLogs, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('복사')),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          if (_logs.isEmpty)
            const Text('아직 실행 로그가 없습니다.', style: TextStyle(color: AppColors.textMuted))
          else
            ..._logs.reversed.take(16).map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: AppColors.textMuted)),
                )),
        ],
      ),
    );
  }

  Widget _buildPlanPage() {
    const items = [
      _PlanItem('v0.4', '실제 지도 + GPS + 진단', 'Gate 통과', CheckState.pass),
      _PlanItem('v0.5', '실제 목적지 검색 + 보행 경로', '현재', CheckState.pass),
      _PlanItem('v0.6', '진행거리 + 이탈 + 재탐색 + 음성', '다음 필수', CheckState.warning),
      _PlanItem('v0.7', '음수대·화장실·쉼터 실제 데이터', '필수', CheckState.unknown),
      _PlanItem('v0.8', '검증된 건물 통과 edge', '핵심 차별화', CheckState.unknown),
      _PlanItem('후순위', '시간대별 그늘·날씨·좌우 보도', 'SHOULD', CheckState.unavailable),
      _PlanItem('제외', 'AR·3D·SNS·자동차 내비', 'NOT NOW', CheckState.unavailable),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('개발 게이트', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('실기기 로그로 통과한 단계만 다음 단계의 기반으로 사용합니다.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xs),
              itemBuilder: (_, index) => _PlanRow(item: items[index]),
            ),
          ),
        ],
      ),
    );
  }

  List<DiagnosticCheck> get _diagnosticChecks {
    final permissionGranted = _locationPermission == LocationPermission.always || _locationPermission == LocationPermission.whileInUse;
    return [
      const DiagnosticCheck('앱 런타임', '화면과 앱 프로세스가 동작 중입니다.', CheckState.pass),
      DiagnosticCheck('지도 엔진', _mapReady ? 'flutter_map 초기화 완료' : '지도 초기화 대기 중', _mapReady ? CheckState.pass : CheckState.running),
      DiagnosticCheck(
        'OSM 지도 네트워크',
        !_networkChecked ? '아직 검사 전' : (_networkOk ? 'HTTP ${_networkStatusCode ?? 200} · 실제 타일 서버 응답' : '지도 서버 연결 실패'),
        !_networkChecked ? CheckState.unknown : (_networkOk ? CheckState.pass : CheckState.fail),
      ),
      DiagnosticCheck(
        '위치 서비스',
        _locationServiceEnabled == null ? '확인 전' : (_locationServiceEnabled! ? '기기 위치서비스 켜짐' : '기기 위치서비스 꺼짐'),
        _locationServiceEnabled == null ? CheckState.unknown : (_locationServiceEnabled! ? CheckState.pass : CheckState.fail),
      ),
      DiagnosticCheck(
        '위치 권한',
        _locationPermission == null ? '확인 전' : _permissionText(_locationPermission),
        _locationPermission == null ? CheckState.unknown : (permissionGranted ? CheckState.pass : CheckState.warning),
      ),
      DiagnosticCheck(
        '실제 GPS 좌표',
        _position == null ? (_locationError ?? '아직 수신 전') : '정확도 ±${_position!.accuracy.toStringAsFixed(1)}m · ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
        _position == null ? (_locationError == null ? CheckState.unknown : CheckState.fail) : (_positionUsableForRouting ? CheckState.pass : CheckState.warning),
      ),
      DiagnosticCheck('실시간 위치 추적', _tracking ? '5m distanceFilter 위치 스트림 갱신 중' : '현재 중지', _tracking ? CheckState.pass : CheckState.unknown),
      DiagnosticCheck(
        '목적지 검색',
        !_searchServiceChecked ? '검색을 실행하면 실제 서버 응답을 판정합니다.' : (_searchServiceOk ? '실제 장소 검색 응답 확인' : '장소 검색 실패'),
        !_searchServiceChecked ? CheckState.unknown : (_searchServiceOk ? CheckState.pass : CheckState.fail),
      ),
      DiagnosticCheck(
        '실제 보행 경로',
        _routeLoading ? '경로 계산 중' : (!_routingServiceChecked ? '목적지를 선택하면 실제 보행 경로를 계산합니다.' : (_routingServiceOk ? '${_routePoints.length}개 좌표의 실제 도로 geometry 수신' : (_routeError ?? '경로 계산 실패'))),
        _routeLoading ? CheckState.running : (!_routingServiceChecked ? CheckState.unknown : (_routingServiceOk ? CheckState.pass : CheckState.fail)),
      ),
      const DiagnosticCheck('쾌적도·건물 통과', '일반 내비 Gate 이후 연결합니다.', CheckState.unavailable),
    ];
  }

  Future<void> _runDiagnostics() async {
    if (_diagnosticRunning) return;
    setState(() => _diagnosticRunning = true);
    _log('전체 진단 시작');
    await _probeMapNetwork();
    await _acquireLocation(requestPermission: true, centerMap: false);
    if (!mounted) return;
    setState(() => _diagnosticRunning = false);
    _log('전체 진단 종료');
  }

  Future<void> _probeMapNetwork() async {
    _log('OSM 네트워크 검사 시작');
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse('https://tile.openstreetmap.org/0/0/0.png'));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close().timeout(const Duration(seconds: 10));
      final code = response.statusCode;
      await response.drain<void>();
      if (!mounted) return;
      setState(() {
        _networkChecked = true;
        _networkStatusCode = code;
        _networkOk = code >= 200 && code < 300;
      });
      _log('OSM 네트워크 응답 HTTP $code');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _networkChecked = true;
        _networkOk = false;
        _networkStatusCode = null;
      });
      _log('OSM 네트워크 오류: $error');
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> _acquireLocation({required bool requestPermission, required bool centerMap}) async {
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
      if (permission == LocationPermission.denied && requestPermission) permission = await Geolocator.requestPermission();
      if (!mounted) return;
      setState(() => _locationPermission = permission);
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _locationError = permission == LocationPermission.deniedForever ? '위치 권한이 영구 거부되었습니다.' : '위치 권한이 거부되었습니다.');
        _log('위치 권한 사용 불가');
        return;
      }

      try {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (mounted) setState(() => _accuracyStatus = accuracyStatus);
      } catch (_) {}

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted && _position == null) {
        final age = DateTime.now().difference(lastKnown.timestamp).abs();
        if (age <= const Duration(minutes: 10) && lastKnown.accuracy <= 100) {
          setState(() {
            _position = lastKnown;
            _locationError = null;
          });
          _log('최근 마지막 위치 우선 표시 · ${age.inMinutes}분 전 · ±${lastKnown.accuracy.toStringAsFixed(1)}m');
          if (centerMap) _centerMapOnCurrentPosition();
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
      if (centerMap) _centerMapOnCurrentPosition();
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = 'GPS 수신 오류: $error');
      _log('GPS 오류: $error');
    }
  }

  Future<void> _toggleTracking() async {
    if (_tracking) {
      await _stopTracking();
      return;
    }
    await _acquireLocation(requestPermission: true, centerMap: true);
    final granted = _locationPermission == LocationPermission.always || _locationPermission == LocationPermission.whileInUse;
    if (!granted || _locationServiceEnabled != true) return;

    await _positionSubscription?.cancel();
    await _serviceSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _position = position;
          _tracking = true;
          _locationError = null;
        });
        if (position.accuracy > _maxNavigationAccuracyMeters) {
          final now = DateTime.now();
          if (_lastPoorAccuracyLogAt == null || now.difference(_lastPoorAccuracyLogAt!) > const Duration(seconds: 30)) {
            _lastPoorAccuracyLogAt = now;
            _log('GPS 정확도 낮음 · ±${position.accuracy.toStringAsFixed(1)}m · 경로 기준에는 사용 보류');
          }
        }
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
    setState(() => _tracking = true);
    _log('실시간 위치 추적 시작 · distanceFilter 5m');
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    await _serviceSubscription?.cancel();
    _positionSubscription = null;
    _serviceSubscription = null;
    if (mounted) setState(() => _tracking = false);
    _log('실시간 위치 추적 중지');
  }

  void _centerMapOnCurrentPosition() {
    final p = _position;
    if (!_mapReady || p == null) {
      _showMessage('먼저 실제 현재 위치를 받아 주세요.');
      return;
    }
    _mapController.move(LatLng(p.latitude, p.longitude), 16.5);
  }

  Future<void> _selectDestination(LatLng point, String label) async {
    if (!mounted) return;
    setState(() {
      _destination = point;
      _destinationLabel = label;
      _routePoints = const <LatLng>[];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      _routeError = null;
      _routeStart = null;
    });
    _log('목적지 지정 · $label · ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}');
    if (_position != null) await _fetchWalkingRoute();
  }

  Future<List<_PlaceResult>> _searchPlaces(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) throw const FormatException('두 글자 이상 입력해 주세요.');
    final cacheKey = query.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) {
      _log('목적지 검색 캐시 사용 · "$query"');
      return cached;
    }

    final last = _lastSearchRequestAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < const Duration(milliseconds: 1100)) {
        await Future<void>.delayed(const Duration(milliseconds: 1100) - elapsed);
      }
    }
    _lastSearchRequestAt = DateTime.now();

    HttpClient? client;
    try {
      _log('실제 목적지 검색 · "$query"');
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '6',
        'countrycodes': 'kr',
        'addressdetails': '1',
      });
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'ko-KR,ko;q=0.9,en;q=0.7');
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body) as List<dynamic>;
      final results = <_PlaceResult>[];
      for (final item in decoded) {
        final map = item as Map<String, dynamic>;
        final lat = double.tryParse('${map['lat'] ?? ''}');
        final lon = double.tryParse('${map['lon'] ?? ''}');
        if (lat == null || lon == null) continue;
        results.add(_PlaceResult(
          name: '${map['display_name'] ?? query}',
          point: LatLng(lat, lon),
          kind: '${map['type'] ?? map['class'] ?? 'place'}',
        ));
      }
      _searchCache[cacheKey] = results;
      if (mounted) {
        setState(() {
          _searchServiceChecked = true;
          _searchServiceOk = true;
        });
      }
      _log('목적지 검색 응답 · ${results.length}건');
      return results;
    } catch (error) {
      if (mounted) {
        setState(() {
          _searchServiceChecked = true;
          _searchServiceOk = false;
        });
      }
      _log('목적지 검색 오류: $error');
      rethrow;
    } finally {
      client?.close(force: true);
    }
  }

  void _showDestinationSearch() {
    final controller = TextEditingController();
    List<_PlaceResult> results = const <_PlaceResult>[];
    bool loading = false;
    String? errorText;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> search() async {
            if (loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
            });
            try {
              final found = await _searchPlaces(controller.text);
              if (!sheetContext.mounted) return;
              setSheetState(() => results = found);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() => errorText = error is FormatException ? error.message : '검색 서버에 연결하지 못했습니다.');
            } finally {
              if (sheetContext.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 22),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('목적지 검색', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('검색 버튼을 눌렀을 때만 실제 장소 검색을 실행합니다.', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => search(),
                          decoration: const InputDecoration(hintText: '장소·주소 입력', prefixIcon: Icon(Icons.search_rounded)),
                        ),
                      ),
                      const SizedBox(width: AppSpace.xs),
                      FilledButton(
                        onPressed: loading ? null : search,
                        style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
                        child: loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('검색'),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(errorText!, style: const TextStyle(color: AppColors.fail, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: AppSpace.sm),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text('검색 결과가 여기에 표시됩니다.\n지도에서 직접 목적지를 눌러도 됩니다.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, height: 1.5)),
                          )
                        : ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              final place = results[index];
                              return Material(
                                color: AppColors.surfaceStrong,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadius.control),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _selectDestination(place.point, place.name);
                                    if (_mapReady) _mapController.move(place.point, 16);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.place_outlined, color: AppColors.primaryDeep),
                                        const SizedBox(width: AppSpace.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 2),
                                              Text(place.kind, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Text('검색 데이터 © OpenStreetMap contributors · Nominatim', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _fetchWalkingRoute() async {
    final destination = _destination;
    if (destination == null) {
      _showMessage('먼저 목적지를 선택해 주세요.');
      return;
    }
    if (_position == null) {
      await _acquireLocation(requestPermission: true, centerMap: false);
    }
    if (!_positionUsableForRouting) {
      final accuracy = _position?.accuracy;
      _showMessage(accuracy == null ? '현재 위치를 먼저 받아 주세요.' : 'GPS 정확도가 ±${accuracy.toStringAsFixed(0)}m입니다. 80m 이하에서 경로를 계산해 주세요.');
      return;
    }

    final start = LatLng(_position!.latitude, _position!.longitude);
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });
    _log('실제 보행 경로 요청 시작');

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
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('HTTP ${response.statusCode}');
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

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeStart = start;
        _routeDistanceMeters = (route['distance'] as num?)?.toDouble();
        _routeDurationSeconds = (route['duration'] as num?)?.toDouble();
        _routeLoading = false;
        _routeError = null;
        _routingServiceChecked = true;
        _routingServiceOk = true;
      });
      _log('실제 보행 경로 수신 · ${_formatDistance(_routeDistanceMeters ?? 0)} · ${points.length} points');
      if (_mapReady) {
        final middle = points[points.length ~/ 2];
        final straight = Geolocator.distanceBetween(start.latitude, start.longitude, destination.latitude, destination.longitude);
        final zoom = straight < 1500 ? 15.2 : straight < 5000 ? 13.8 : straight < 15000 ? 12.2 : 10.8;
        _mapController.move(middle, zoom);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _routeError = '보행 경로 계산 실패: $error';
        _routingServiceChecked = true;
        _routingServiceOk = false;
        _routePoints = const <LatLng>[];
        _routeDistanceMeters = null;
        _routeDurationSeconds = null;
      });
      _log('보행 경로 오류: $error');
    } finally {
      client?.close(force: true);
    }
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    _showMessage('진단 로그를 복사했습니다.');
  }

  void _log(String message) {
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    if (!mounted) return;
    setState(() {
      _logs.add('[$stamp] $message');
      if (_logs.length > 120) _logs.removeAt(0);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDistance(double meters) => meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(2)} km';

  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes분';
    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    return remain == 0 ? '$hours시간' : '$hours시간 $remain분';
  }

  static String _permissionText(LocationPermission? permission) {
    switch (permission) {
      case LocationPermission.always:
        return '항상 허용';
      case LocationPermission.whileInUse:
        return '앱 사용 중 허용';
      case LocationPermission.denied:
        return '거부됨';
      case LocationPermission.deniedForever:
        return '영구 거부됨';
      case LocationPermission.unableToDetermine:
        return '확인 불가';
      case null:
        return '확인 전';
    }
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
      child: const Text('© OpenStreetMap contributors', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.state});
  final String label;
  final CheckState state;
  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: tone, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label, required this.state});
  final IconData icon;
  final String label;
  final CheckState state;
  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppRadius.pill), boxShadow: AppShadows.soft),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: tone),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceStrong,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 50, height: 50, child: Icon(icon, color: AppColors.primaryDeep)),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: AppColors.primaryDeep),
            const SizedBox(width: 7),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w800))),
          ]),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: AppColors.info, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5), boxShadow: AppShadows.soft),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();
  @override
  Widget build(BuildContext context) => const Icon(Icons.location_on_rounded, color: AppColors.primaryDeep, size: 46, shadows: [Shadow(color: AppColors.shadow, blurRadius: 8)]);
}

class _DiagnosticSummary extends StatelessWidget {
  const _DiagnosticSummary({required this.checks});
  final List<DiagnosticCheck> checks;
  @override
  Widget build(BuildContext context) {
    final pass = checks.where((e) => e.state == CheckState.pass).length;
    final fail = checks.where((e) => e.state == CheckState.fail).length;
    final pending = checks.where((e) => e.state == CheckState.unknown || e.state == CheckState.running || e.state == CheckState.warning).length;
    return _CardShell(
      child: Row(children: [
        _SummaryMetric(label: '정상', value: '$pass', tone: AppColors.pass),
        _SummaryMetric(label: '문제', value: '$fail', tone: AppColors.fail),
        _SummaryMetric(label: '확인 필요', value: '$pending', tone: AppColors.warn),
      ]),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final Color tone;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: tone)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.check});
  final DiagnosticCheck check;
  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(check.state);
    return _CardShell(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: tone.withValues(alpha: 0.11), shape: BoxShape.circle), child: Icon(_stateIcon(check.state), size: 19, color: tone)),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(check.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(check.detail, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: AppColors.surfaceStrong, borderRadius: BorderRadius.circular(AppRadius.card), boxShadow: AppShadows.soft),
        child: child,
      );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _PlanItem {
  const _PlanItem(this.version, this.title, this.tag, this.state);
  final String version;
  final String title;
  final String tag;
  final CheckState state;
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item});
  final _PlanItem item;
  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(item.state);
    return _CardShell(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(color: tone.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(item.version, style: TextStyle(color: tone, fontWeight: FontWeight.w900, fontSize: 11.5)),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: AppSpace.xs),
        Text(item.tag, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Color _stateTone(CheckState state) {
  switch (state) {
    case CheckState.pass:
      return AppColors.pass;
    case CheckState.warning:
      return AppColors.warn;
    case CheckState.fail:
      return AppColors.fail;
    case CheckState.running:
      return AppColors.info;
    case CheckState.unavailable:
      return AppColors.textMuted;
    case CheckState.unknown:
      return AppColors.info;
  }
}

IconData _stateIcon(CheckState state) {
  switch (state) {
    case CheckState.pass:
      return Icons.check_rounded;
    case CheckState.warning:
      return Icons.priority_high_rounded;
    case CheckState.fail:
      return Icons.close_rounded;
    case CheckState.running:
      return Icons.sync_rounded;
    case CheckState.unavailable:
      return Icons.remove_rounded;
    case CheckState.unknown:
      return Icons.question_mark_rounded;
  }
}
