from pathlib import Path

source_path = Path('comfort_route_sample/tools/apply_v066_gps_korean_map.py')
source = source_path.read_text()
source = source.replace(
    "small_action_anchor = 'class _SmallAction extends StatelessWidget {\\n'",
    "small_action_anchor = 'class _CurrentLocationMarker extends StatelessWidget {\\n'",
    1,
)
source = source.replace(
    "raise SystemExit('SmallAction class anchor missing')",
    "raise SystemExit('CurrentLocationMarker class anchor missing')",
    1,
)
# Keep strict flutter analyze clean after generated-source interpolation.
source = source.replace(
    "'${_koreanLabelLayerCount}개 layer 적용'",
    "'$_koreanLabelLayerCount개 layer 적용'",
    1,
)
exec(compile(source, str(source_path), 'exec'))

# Manual review hardening after the main v0.6.6 transform.
p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# A newly requested poor fix (for example ~100m) must not replace a previously
# accepted navigation-grade fix. Keep it visible in diagnostics via
# _latestRawAccuracyMeters while retaining the good position for the map/route.
old_fix = '''      setState(() {
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
'''
new_fix = '''      final usablePosition = GpsPolicy.usableForNavigation(position.accuracy);
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
if old_fix not in s:
    raise SystemExit('v066 poor-fix preservation anchor missing')
s = s.replace(old_fix, new_fix, 1)

s = s.replace(
    '경로 120m 주변 OSM 신호 · 운영 여부 미검증',
    '현재 불러온 지도 범위 · 경로 120m 주변 OSM 신호 · 운영 여부 미검증',
)

required = [
    'final preserveExisting = !usablePosition',
    'GPS 재측정값 품질 저하 · 기존 내비 위치 유지',
    '현재 불러온 지도 범위 · 경로 120m 주변 OSM 신호 · 운영 여부 미검증',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v066 manual review marker: {marker}')

p.write_text(s)
print('V066_MANUAL_REVIEW_HARDENING: PASS')
