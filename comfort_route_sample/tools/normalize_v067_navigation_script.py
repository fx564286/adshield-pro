from pathlib import Path

p = Path('comfort_route_sample/tools/apply_v067_navigation_automation.py')
s = p.read_text()

old = "progress_anchor = '''    _updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);\n'''"
new = "progress_anchor = '''    _updateGuidanceForAlongMeters(traveledRouteMeters, allowVoice: !isOffRoute);\n'''"
if old not in s:
    raise SystemExit('v067 navigation progress generator anchor missing')
s = s.replace(old, new, 1)
p.write_text(s)
compile(s, str(p), 'exec')
print('NORMALIZE_V067_NAVIGATION_SCRIPT: PASS')
