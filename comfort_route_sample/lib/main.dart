import 'dart:async';
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
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];
}

enum CheckState { unknown, running, pass, warning, fail, unavailable }

class DiagnosticCheck {
  const DiagnosticCheck(this.title, this.detail, this.state);

  final String title;
  final String detail;
  final CheckState state;
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
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
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
  static const _userAgent = 'ComfortRoute/0.4 (com.fx564286.comfort_route_sample)';

  final MapController _mapController = MapController();
  final List<String> _logs = <String>[];

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
  LatLng? _destination;
  bool _tracking = false;
  String? _locationError;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _serviceSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            _buildMapPage(),
            _buildDiagnosticsPage(),
            _buildPlanPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety_rounded),
            label: '진단',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: '계획',
          ),
        ],
      ),
    );
  }

  Widget _buildMapPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.xs,
          ),
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
              onTap: _showDestinationGuide,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.primaryDeep),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '어디로 갈까요?',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.touch_app_rounded, color: AppColors.textMuted),
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
    final gpsState = _position != null
        ? CheckState.pass
        : _locationError != null
            ? CheckState.fail
            : CheckState.unknown;
    final mapState = _mapReady ? CheckState.pass : CheckState.running;
    const routeState = CheckState.unavailable;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatusPill(label: '실제 지도', state: mapState),
          const SizedBox(width: 6),
          _StatusPill(label: '실제 GPS', state: gpsState),
          const SizedBox(width: 6),
          const _StatusPill(label: '보행 경로 미연결', state: routeState),
          const SizedBox(width: 6),
          const _StatusPill(label: '쾌적도 후속', state: CheckState.unavailable),
        ],
      ),
    );
  }

  Widget _buildRealMap() {
    final current = _position == null
        ? null
        : LatLng(_position!.latitude, _position!.longitude);

    final polylines = <Polyline>[];
    if (current != null && _destination != null) {
      polylines.add(
        Polyline(
          points: [current, _destination!],
          strokeWidth: 4,
          color: AppColors.primary.withValues(alpha: 0.72),
        ),
      );
    }

    final markers = <Marker>[];
    if (current != null) {
      markers.add(
        Marker(
          point: current,
          width: 48,
          height: 48,
          child: const _CurrentLocationMarker(),
        ),
      );
    }
    if (_destination != null) {
      markers.add(
        Marker(
          point: _destination!,
          width: 48,
          height: 54,
          alignment: Alignment.topCenter,
          child: const _DestinationMarker(),
        ),
      );
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
              onTap: (_, point) {
                setState(() => _destination = point);
                _log(
                  '목적지 지정 ${point.latitude.toStringAsFixed(6)}, '
                  '${point.longitude.toStringAsFixed(6)}',
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.fx564286.comfort_route_sample',
                maxNativeZoom: 19,
              ),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
                backgroundColor: Color(0xCCFFFFFF),
              ),
            ],
          ),
          Positioned(
            left: AppSpace.sm,
            top: AppSpace.sm,
            child: _MapBadge(
              icon: Icons.public_rounded,
              label: 'OpenStreetMap 실제 타일',
              state: _networkChecked
                  ? (_networkOk ? CheckState.pass : CheckState.fail)
                  : CheckState.unknown,
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
    final current = _position;
    final destination = _destination;
    final straightMeters = current == null || destination == null
        ? null
        : Geolocator.distanceBetween(
            current.latitude,
            current.longitude,
            destination.latitude,
            destination.longitude,
          );

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
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.navigation_rounded, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination == null ? '지도에서 목적지를 눌러주세요' : '목적지 선택됨',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      straightMeters == null
                          ? '현재 위치를 확인하면 실제 거리 기준을 계산합니다.'
                          : '직선거리 ${_formatDistance(straightMeters)} · 실제 보행 경로는 아직 미연결',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
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
                    icon: Icons.gps_fixed_rounded,
                    label: current == null ? 'GPS 확인' : 'GPS 갱신',
                    onTap: () => _acquireLocation(
                      requestPermission: true,
                      centerMap: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.xs),
                Expanded(
                  child: _SmallAction(
                    icon: Icons.fact_check_rounded,
                    label: '전체 진단',
                    onTap: () {
                      setState(() => _tabIndex = 1);
                      _runDiagnostics();
                    },
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '실행 상태 진단',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '“켜짐”과 “실제 동작”을 분리해서 확인합니다.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                ...checks.map(
                  (check) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: _DiagnosticRow(check: check),
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                _buildGpsDetailCard(),
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
          const Text(
            'GPS 세부 정보',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpace.sm),
          _KeyValueRow(
            label: '위치서비스',
            value: _locationServiceEnabled == null
                ? '확인 전'
                : (_locationServiceEnabled! ? '켜짐' : '꺼짐'),
          ),
          _KeyValueRow(
            label: '권한',
            value: _permissionText(_locationPermission),
          ),
          _KeyValueRow(
            label: '정확도 권한',
            value: _accuracyStatus == null
                ? '확인 전'
                : (_accuracyStatus == LocationAccuracyStatus.precise ? '정밀' : '대략적'),
          ),
          _KeyValueRow(
            label: '좌표',
            value: p == null
                ? '아직 없음'
                : '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}',
          ),
          _KeyValueRow(
            label: 'GPS 정확도',
            value: p == null ? '-' : '±${p.accuracy.toStringAsFixed(1)} m',
          ),
          _KeyValueRow(
            label: '속도',
            value: p == null ? '-' : '${(p.speed * 3.6).toStringAsFixed(1)} km/h',
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _acquireLocation(
                  requestPermission: true,
                  centerMap: true,
                ),
                icon: const Icon(Icons.gps_fixed_rounded),
                label: const Text('현재 위치 다시 받기'),
              ),
              OutlinedButton.icon(
                onPressed: Geolocator.openLocationSettings,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('위치 설정'),
              ),
              OutlinedButton.icon(
                onPressed: Geolocator.openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('앱 권한 설정'),
              ),
            ],
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
              const Expanded(
                child: Text(
                  '진단 로그',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _logs.isEmpty ? null : _copyLogs,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('복사'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          if (_logs.isEmpty)
            const Text(
              '아직 실행 로그가 없습니다. 전체 진단을 실행해 주세요.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            ..._logs.reversed.take(12).map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPlanPage() {
    const items = [
      _PlanItem('v0.4', '실제 지도 + GPS + 진단', '진행/검증', CheckState.pass),
      _PlanItem('v0.5', '실제 보행 경로 API + 목적지 검색', '다음 필수', CheckState.warning),
      _PlanItem('v0.6', '경로 이탈 + 재탐색 + 음성 안내', '필수', CheckState.unknown),
      _PlanItem('v0.7', '음수대·화장실·쉼터 실제 데이터', '필수', CheckState.unknown),
      _PlanItem('v0.8', '검증된 건물 통과 edge', '핵심 차별화', CheckState.unknown),
      _PlanItem('후순위', '시간대별 그늘·날씨·좌우 보도', 'SHOULD', CheckState.unavailable),
      _PlanItem('제외', 'AR·3D·SNS·자동차 내비', 'NOT NOW', CheckState.unavailable),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.sm,
        AppSpace.md,
        AppSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '개발 게이트',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '앞 단계가 정상 동작하지 않으면 다음 기능을 덧붙이지 않습니다.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    final permissionGranted = _locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse;

    return [
      const DiagnosticCheck(
        '앱 런타임',
        '화면이 렌더링되고 앱 프로세스가 동작 중입니다.',
        CheckState.pass,
      ),
      DiagnosticCheck(
        '지도 엔진',
        _mapReady ? 'flutter_map 엔진 초기화 완료' : '지도 초기화 대기 중',
        _mapReady ? CheckState.pass : CheckState.running,
      ),
      DiagnosticCheck(
        'OSM 지도 네트워크',
        !_networkChecked
            ? '아직 실제 타일 서버 연결을 검사하지 않았습니다.'
            : (_networkOk
                ? 'HTTP ${_networkStatusCode ?? 200} · 실제 지도 서버 응답 확인'
                : '지도 서버 연결 실패${_networkStatusCode == null ? '' : ' · HTTP $_networkStatusCode'}'),
        !_networkChecked
            ? CheckState.unknown
            : (_networkOk ? CheckState.pass : CheckState.fail),
      ),
      DiagnosticCheck(
        '위치 서비스',
        _locationServiceEnabled == null
            ? '아직 기기 위치서비스 상태를 확인하지 않았습니다.'
            : (_locationServiceEnabled! ? '기기 위치서비스 켜짐' : '기기 위치서비스 꺼짐'),
        _locationServiceEnabled == null
            ? CheckState.unknown
            : (_locationServiceEnabled! ? CheckState.pass : CheckState.fail),
      ),
      DiagnosticCheck(
        '위치 권한',
        _locationPermission == null
            ? '아직 앱 위치권한 상태를 확인하지 않았습니다.'
            : _permissionText(_locationPermission),
        _locationPermission == null
            ? CheckState.unknown
            : (permissionGranted
                ? CheckState.pass
                : (_locationPermission == LocationPermission.deniedForever
                    ? CheckState.fail
                    : CheckState.warning)),
      ),
      DiagnosticCheck(
        '실제 GPS 좌표',
        _position == null
            ? (_locationError ?? '아직 실제 좌표를 수신하지 않았습니다.')
            : '정확도 ±${_position!.accuracy.toStringAsFixed(1)}m · '
                '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
        _position == null
            ? (_locationError == null ? CheckState.unknown : CheckState.fail)
            : CheckState.pass,
      ),
      DiagnosticCheck(
        '실시간 위치 추적',
        _tracking ? '5m 이상 이동 시 위치 스트림 갱신 중' : '현재 중지 상태',
        _tracking ? CheckState.pass : CheckState.unknown,
      ),
      const DiagnosticCheck(
        '실제 보행 경로 API',
        '아직 연결하지 않았습니다. 직선 연결선을 실제 경로로 표시하지 않습니다.',
        CheckState.unavailable,
      ),
      const DiagnosticCheck(
        '쾌적도·건물 통과',
        '일반 내비 Gate 통과 이후 연결할 기능입니다.',
        CheckState.unavailable,
      ),
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
      final request = await client.getUrl(
        Uri.parse('https://tile.openstreetmap.org/0/0/0.png'),
      );
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

  Future<void> _acquireLocation({
    required bool requestPermission,
    required bool centerMap,
  }) async {
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

      if (permission == LocationPermission.denied) {
        setState(() => _locationError = '위치 권한이 거부되었습니다.');
        _log('위치 권한 거부');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = '위치 권한이 영구 거부되었습니다. 앱 설정에서 허용해 주세요.');
        _log('위치 권한 영구 거부');
        return;
      }

      try {
        final accuracyStatus = await Geolocator.getLocationAccuracy();
        if (mounted) setState(() => _accuracyStatus = accuracyStatus);
      } catch (_) {
        // 위치 정확도 상태 조회 실패는 좌표 획득 자체를 막지 않습니다.
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted && _position == null) {
        setState(() {
          _position = lastKnown;
          _locationError = null;
        });
        _log('마지막 알려진 위치 우선 표시');
        if (centerMap) _centerMapOnCurrentPosition();
      }

      final settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        timeLimit: const Duration(seconds: 20),
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
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
    final granted = _locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse;
    if (!granted || _locationServiceEnabled != true) return;

    await _positionSubscription?.cancel();
    await _serviceSubscription?.cancel();

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _position = position;
          _tracking = true;
          _locationError = null;
        });
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

  void _showDestinationGuide() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'v0.4 목적지 지정',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              '현재 버전은 지도 위 원하는 지점을 직접 눌러 목적지를 지정합니다. '
              '목적지 검색과 실제 보행 경로 API는 다음 Gate에서 연결합니다.',
              style: TextStyle(
                color: AppColors.textMuted,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('지도에서 선택하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    _showMessage('진단 로그를 복사했습니다.');
  }

  void _log(String message) {
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    if (!mounted) return;
    setState(() {
      _logs.add('[$stamp] $message');
      if (_logs.length > 100) _logs.removeAt(0);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.state});

  final String label;
  final CheckState state;

  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
          child: SizedBox(
            width: 50,
            height: 50,
            child: Icon(icon, color: AppColors.primaryDeep),
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryDeep),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
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
        decoration: BoxDecoration(
          color: AppColors.info,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 5),
          boxShadow: AppShadows.soft,
        ),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on_rounded,
      color: AppColors.primaryDeep,
      size: 46,
      shadows: [Shadow(color: AppColors.shadow, blurRadius: 8)],
    );
  }
}

class _DiagnosticSummary extends StatelessWidget {
  const _DiagnosticSummary({required this.checks});

  final List<DiagnosticCheck> checks;

  @override
  Widget build(BuildContext context) {
    final pass = checks.where((e) => e.state == CheckState.pass).length;
    final fail = checks.where((e) => e.state == CheckState.fail).length;
    final pending = checks.where((e) =>
        e.state == CheckState.unknown ||
        e.state == CheckState.running ||
        e.state == CheckState.warning).length;

    return _CardShell(
      child: Row(
        children: [
          _SummaryMetric(label: '정상', value: '$pass', tone: AppColors.pass),
          _SummaryMetric(label: '문제', value: '$fail', tone: AppColors.fail),
          _SummaryMetric(label: '확인 필요', value: '$pending', tone: AppColors.warn),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: tone),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.check});

  final DiagnosticCheck check;

  @override
  Widget build(BuildContext context) {
    final tone = _stateTone(check.state);
    return _CardShell(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(_stateIcon(check.state), size: 19, color: tone),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  check.detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              item.version,
              style: TextStyle(color: tone, fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            item.tag,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
