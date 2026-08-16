from pathlib import Path

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()
s = s.replace('(_, __)', '(_, _)')
s = s.replace('(context, __)', '(context, _)')
s = s.replace('(_, ___)', '(_, _)')
s = s.replace('(context, ___)', '(context, _)')
p.write_text(s)
print('NORMALIZE_V062_LINTS: PASS')
