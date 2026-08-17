from pathlib import Path

p = Path('comfort_route_sample/tools/apply_v067_gps_stabilization.py')
s = p.read_text()

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
p.write_text(s)
compile(s, str(p), 'exec')
print('NORMALIZE_V067_SCRIPT: PASS')
