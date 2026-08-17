from pathlib import Path

# Fix a generated-source replacement string that intentionally contains a Dart
# newline escape. Keep the repository-side generator compilable before running it.
gps = Path('comfort_route_sample/tools/apply_v067_gps_stabilization.py')
s = gps.read_text()

bad = '''s = s.replace("_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능' : '정확도 부족 (>80m)')),
",
              "_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능 · 보정 필터 적용' : '안정화 필요 (>45m)')),
")'''

good = '''s = s.replace(
    "_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능' : '정확도 부족 (>80m)')),\\n",
    "_KeyValueRow(label: '경로용 판정', value: p == null ? '-' : (_positionUsableForRouting ? '사용 가능 · 보정 필터 적용' : '안정화 필요 (>45m)')),\\n",
)'''

if bad not in s:
    raise SystemExit('v067 broken route-quality replacement anchor missing')
s = s.replace(bad, good, 1)
gps.write_text(s)
compile(s, str(gps), 'exec')

# v0.6.5 review hardening changed guidance progress from raw geometry metres to
# route-scaled travelled metres. Point the v0.6.7 camera hook at that final form.
nav = Path('comfort_route_sample/tools/apply_v067_navigation_automation.py')
n = nav.read_text()
old = "progress_anchor = '''    _updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);\n'''"
new = "progress_anchor = '''    _updateGuidanceForAlongMeters(traveledRouteMeters, allowVoice: !isOffRoute);\n'''"
if old not in n:
    raise SystemExit('v067 navigation progress generator anchor missing')
n = n.replace(old, new, 1)
nav.write_text(n)
compile(n, str(nav), 'exec')

print('NORMALIZE_V067_SCRIPT: PASS')
