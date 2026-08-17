from pathlib import Path

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# AndroidSettings is re-exported by geolocator 14.x. Keep geolocator_android
# pinned in pubspec for implementation reproducibility, but do not import its
# library redundantly in app code. Its constructors are not const in 5.0.3.
s = s.replace("import 'package:geolocator_android/geolocator_android.dart';\n", '', 1)
s = s.replace('const AndroidSettings(', 'AndroidSettings(')
s = s.replace(
    '    final p = _position;\n    final displayPoint = _displayLocationPoint;\n    final center = displayPoint ?? _fallbackCenter;\n',
    '    final displayPoint = _displayLocationPoint;\n    final center = displayPoint ?? _fallbackCenter;\n',
    1,
)

# Keep the smoothing coefficient observable so QA can distinguish heavy
# stationary damping from fast-motion tracking and strict analyzer sees the
# state as intentionally used.
diag_old = "          _KeyValueRow(label: '내비 카메라', value: !_tracking ? '대기' : (_lastNavigationCameraZoom == null ? '추적 시작' : '자동 추적 · zoom ${_lastNavigationCameraZoom!.toStringAsFixed(1)}')),\n"
diag_new = """          _KeyValueRow(label: '평활 계수', value: _gpsSmoothingAlpha == null ? '-' : _gpsSmoothingAlpha!.toStringAsFixed(2)),
          _KeyValueRow(label: '내비 카메라', value: !_tracking ? '대기' : (_lastNavigationCameraZoom == null ? '추적 시작' : '자동 추적 · zoom ${_lastNavigationCameraZoom!.toStringAsFixed(1)}')),
"""
if diag_old not in s:
    raise SystemExit('v067 camera diagnostic anchor missing')
s = s.replace(diag_old, diag_new, 1)

# Nominatim public service must not be used as per-keystroke autocomplete. Keep
# the request explicitly user-triggered, but once that search completes update
# the map immediately to the top result. The user can still pick another result
# before route selection, so we avoid silently routing to the wrong place.
search_old = '''              final found = await _searchPlaces(controller.text);
              if (!sheetContext.mounted) return;
              setSheetState(() => results = found);
'''
search_new = '''              final found = await _searchPlaces(controller.text);
              if (!sheetContext.mounted) return;
              setSheetState(() => results = found);
              if (found.isNotEmpty) {
                _moveActiveMap(found.first.point, 16.8);
                _log('검색 결과 지도 즉시 미리보기 · ${found.first.name}');
              }
'''
if search_old not in s:
    raise SystemExit('destination search result update anchor missing')
s = s.replace(search_old, search_new, 1)

# Ensure the helper copy no longer implies the user must press a second
# confirmation button after a result is chosen.
s = s.replace(
    '검색 버튼을 눌렀을 때만 실제 장소 검색을 실행합니다.',
    '검색하면 첫 결과를 지도에 바로 보여드리고, 결과를 누르면 즉시 경로를 계산합니다.',
    1,
)

required = [
    'AndroidSettings(',
    'forceLocationManager: false',
    "_KeyValueRow(label: '평활 계수'",
    '_moveActiveMap(found.first.point, 16.8);',
    '검색 결과 지도 즉시 미리보기',
    '결과를 누르면 즉시 경로를 계산합니다.',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v067 review fix marker: {marker}')

p.write_text(s)
print('FIX_V067_REVIEW_FINDINGS: PASS')
