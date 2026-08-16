from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.3 design refresh: turn the engineering-heavy prototype into a
# calm, route-first consumer UI that matches the 쾌적길 identity.
colors_re = re.compile(r"class AppColors \{.*?\n\}\n\nclass AppSpace", re.S)
colors = '''class AppColors {
  static const background = Color(0xFFF3F6F0);
  static const surface = Color(0xFFF9FBF7);
  static const surfaceStrong = Color(0xFFFFFFFF);
  static const primary = Color(0xFF72957E);
  static const primaryDeep = Color(0xFF426A55);
  static const primarySoft = Color(0xFFE5EEE6);
  static const text = Color(0xFF26342C);
  static const textMuted = Color(0xFF718078);
  static const shadow = Color(0x160F281B);
  static const pass = Color(0xFF4F7C61);
  static const warn = Color(0xFFC28A46);
  static const fail = Color(0xFFC66C69);
  static const info = Color(0xFF6B8E91);
  static const sun = Color(0xFFF2C77A);
  static const water = Color(0xFF6EA6A3);
}

class AppSpace'''
s, n = colors_re.subn(colors, s, count=1)
if n != 1:
    raise SystemExit('AppColors replacement failed')

s = s.replace("ComfortRoute/0.6.2 (com.fx564286.comfort_route_sample)",
              "ComfortRoute/0.6.3 (com.fx564286.comfort_route_sample)")
s = s.replace("static const _vectorStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';",
              "static const _vectorStyleUrl = 'https://tiles.openfreemap.org/styles/positron';")

# Consumer-facing bottom navigation. Keep technical diagnostics accessible, but
# remove development roadmap terminology from the primary navigation.
s = s.replace(
"""          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: '지도'),
          NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety_rounded), label: '진단'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: '계획'),""",
"""          NavigationDestination(icon: Icon(Icons.alt_route_rounded), selectedIcon: Icon(Icons.route_rounded), label: '길찾기'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield_rounded), label: '상태'),
          NavigationDestination(icon: Icon(Icons.info_outline_rounded), selectedIcon: Icon(Icons.info_rounded), label: '정보'),""",
1)

# Main page: brand -> search -> map -> route card. The engineering status strip
# is deliberately removed from the main journey and remains in the status tab.
map_page_re = re.compile(r"  Widget _buildMapPage\(\) \{.*?\n  \}\n\n  Widget _buildSearchHeader\(\) \{", re.S)
map_page = r'''  Widget _buildMapPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.sm, AppSpace.xs),
          child: Column(
            children: [
              _buildBrandHeader(),
              const SizedBox(height: AppSpace.xs),
              _buildSearchHeader(),
              const SizedBox(height: AppSpace.sm),
              Expanded(child: _buildRealMap()),
              const SizedBox(height: AppSpace.sm),
              _buildMapBottomCard(compact: compact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandHeader() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.primaryDeep, size: 22),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '쾌적길',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 21,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '덜 덥고, 덜 힘든 길',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.surfaceStrong,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: '앱 상태',
              onPressed: () => setState(() => _tabIndex = 1),
              icon: const Icon(Icons.tune_rounded, color: AppColors.primaryDeep, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {'''
s, n = map_page_re.subn(map_page, s, count=1)
if n != 1:
    raise SystemExit('map page replacement failed')

search_re = re.compile(r"  Widget _buildSearchHeader\(\) \{.*?\n  \}\n\n  Widget _buildRuntimeStrip\(\) \{", re.S)
search = r'''  Widget _buildSearchHeader() {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppShadows.soft,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _showDestinationSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.primaryDeep, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _destinationLabel ?? '어디로 갈까요?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _destinationLabel == null ? AppColors.textMuted : AppColors.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_destinationLabel != null)
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        _CircleButton(
          icon: Icons.my_location_rounded,
          tooltip: '내 위치',
          onTap: () => _acquireLocation(requestPermission: true, centerMap: true),
        ),
      ],
    );
  }

  Widget _buildRuntimeStrip() {'''
s, n = search_re.subn(search, s, count=1)
if n != 1:
    raise SystemExit('search header replacement failed')

# Remove the vector/raster developer toggle from the map itself. Raster remains
# as the widget-test/platform fallback internally.
real_map_re = re.compile(r"  Widget _buildRealMap\(\) \{.*?\n  \}\n\n  Widget _buildVectorMap\(\) \{", re.S)
real_map = r'''  Widget _buildRealMap() {
    return _vectorRendererActive ? _buildVectorMap() : _buildRasterMap();
  }

  Widget _buildVectorMap() {'''
s, n = real_map_re.subn(real_map, s, count=1)
if n != 1:
    raise SystemExit('vector wrapper replacement failed')

# Make map copy and attribution feel like a consumer map, not a diagnostics panel.
s = s.replace("label: _vectorStyleReady ? '벡터 지도 · 상가/건물 라벨' : '벡터 스타일 로딩',",
              "label: _vectorStyleReady ? '쾌적 지도' : '지도 준비 중',", 1)
s = s.replace("_log('OpenFreeMap Liberty 벡터 스타일 로드 완료');",
              "_log('OpenFreeMap Positron 벡터 스타일 로드 완료');", 1)
s = s.replace("? (_vectorStyleReady ? 'MapLibre + OpenFreeMap Liberty 벡터 스타일' : '벡터 스타일 로딩 중')",
              "? (_vectorStyleReady ? 'MapLibre + OpenFreeMap Positron' : '벡터 스타일 로딩 중')", 1)

# Route: soft cream halo + deep sage core to stay legible over light vector maps.
route_line_old = '''          await controller.addLine(
            ml.LineOptions(
              geometry: _routePoints
                  .map((point) => ml.LatLng(point.latitude, point.longitude))
                  .toList(growable: false),
              lineColor: '#7C5064',
              lineWidth: 5.0,
              lineOpacity: 0.94,
              lineJoin: 'round',
            ),
          );'''
route_line_new = '''          final vectorGeometry = _routePoints
              .map((point) => ml.LatLng(point.latitude, point.longitude))
              .toList(growable: false);
          await controller.addLine(
            ml.LineOptions(
              geometry: vectorGeometry,
              lineColor: '#FFFDF6',
              lineWidth: 9.0,
              lineOpacity: 0.96,
              lineJoin: 'round',
            ),
          );
          await controller.addLine(
            ml.LineOptions(
              geometry: vectorGeometry,
              lineColor: '#426A55',
              lineWidth: 5.2,
              lineOpacity: 0.96,
              lineJoin: 'round',
            ),
          );'''
if route_line_old not in s:
    raise SystemExit('route line anchor missing')
s = s.replace(route_line_old, route_line_new, 1)
s = s.replace("circleColor: '#7C5064',", "circleColor: '#4F7C61',", 1)
s = s.replace("circleColor: '#B55C66',", "circleColor: '#E7A765',", 1)

# Bottom card is a friendly journey card instead of an engineering state card.
bottom_re = re.compile(r"  Widget _buildMapBottomCard\(\{required bool compact\}\) \{.*?\n  \}\n\n  Widget _buildDiagnosticsPage\(\) \{", re.S)
bottom = r'''  Widget _buildMapBottomCard({required bool compact}) {
    final p = _position;
    final straightMeters = p == null || _destination == null
        ? null
        : Geolocator.distanceBetween(p.latitude, p.longitude, _destination!.latitude, _destination!.longitude);
    final hasRoute = _routeDistanceMeters != null && _routePoints.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compact ? 13 : 15, 16, compact ? 13 : 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(
                  _routeLoading
                      ? Icons.hourglass_top_rounded
                      : (hasRoute ? Icons.directions_walk_rounded : Icons.park_rounded),
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationLabel ?? '조금 돌아가도 편안한 길',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _routeLoading
                          ? '걷기 좋은 경로를 찾고 있어요…'
                          : hasRoute
                              ? _routePrimarySummary
                              : (_routeError ?? (straightMeters == null
                                  ? '목적지를 정하면 현재 위치에서 길을 찾아드려요.'
                                  : '목적지까지 직선 ${_formatDistance(straightMeters)}')),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _routeError == null ? AppColors.textMuted : AppColors.fail,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w650,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRoute)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    '보행',
                    style: TextStyle(color: AppColors.primaryDeep, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          if (hasRoute && _routeProgress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: _routeProgress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.primarySoft,
                color: AppColors.primary,
              ),
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _showDestinationSearch,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(_destination == null ? '목적지 찾기' : '다른 곳 찾기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDeep,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                  ),
                ),
                if (_destination != null) ...[
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _routeLoading ? null : () => _fetchWalkingRoute(),
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: Text(hasRoute ? '다시 찾기' : '길 찾기'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticsPage() {'''
s, n = bottom_re.subn(bottom, s, count=1)
if n != 1:
    raise SystemExit('bottom card replacement failed')

# Status tab wording is user-facing; the existing detailed checks/logs remain
# available for troubleshooting without polluting the navigation screen.
s = s.replace("Text('실행 상태 진단',", "Text('앱 상태',", 1)
s = s.replace("Text('센서·검색·경로를 각각 실제 상태로 확인합니다.',",
              "Text('위치·지도·경로가 잘 연결되어 있는지 확인합니다.',", 1)
# Keep runtime strip used outside the main page so analyzer does not treat it as dead.
diag_anchor = "          const SizedBox(height: AppSpace.md),\n          Expanded(\n            child: ListView("
if diag_anchor in s:
    s = s.replace(diag_anchor,
                  "          const SizedBox(height: AppSpace.sm),\n          _buildRuntimeStrip(),\n          const SizedBox(height: AppSpace.sm),\n          Expanded(\n            child: ListView(",
                  1)

s = s.replace("const Text('개발 게이트',", "const Text('쾌적길 정보',", 1)
s = s.replace("const Text('실기기 로그로 통과한 단계만 다음 단계의 기반으로 사용합니다.',",
              "const Text('쾌적길이 어떤 방향으로 좋아지고 있는지 확인할 수 있어요.',", 1)

# Roadmap label for this visual refresh.
s = s.replace("_PlanItem('v0.6.2', 'MapLibre 벡터 지도 + 상업지도형 라벨', '현재', CheckState.pass),",
              "_PlanItem('v0.6.2', 'MapLibre 벡터 지도 기반', 'Gate 통과', CheckState.pass),", 1)
s = s.replace("_PlanItem('v0.6.3', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),",
              "_PlanItem('v0.6.3', '쾌적길 지도·UI 디자인 전면 정리', '현재', CheckState.pass),\n      _PlanItem('v0.6.4', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),", 1)

# Verify that the main-screen engineering language is no longer in the main path
# and that the new design markers exist.
required = [
    "'덜 덥고, 덜 힘든 길'",
    "'조금 돌아가도 편안한 길'",
    "styles/positron",
    "lineColor: '#426A55'",
    "label: '길찾기'",
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v0.6.3 marker: {marker}')

p.write_text(s)
print('APPLY_V063_PLEASANT_UI: PASS')
