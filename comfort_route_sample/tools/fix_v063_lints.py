from pathlib import Path
import re

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

s = s.replace('  bool _useVectorMap = true;\n', '  final bool _useVectorMap = true;\n', 1)
s = s.replace(
    '            borderRadius: BorderRadius.circular(22),\n            boxShadow: AppShadows.soft,\n',
    '            borderRadius: BorderRadius.circular(22),\n',
    1,
)
s = s.replace('FontWeight.w650', 'FontWeight.w600')

small_action_re = re.compile(
    r'\nclass _SmallAction extends StatelessWidget \{.*?\n\}\n\nclass _CurrentLocationMarker',
    re.S,
)
s, count = small_action_re.subn('\nclass _CurrentLocationMarker', s, count=1)
if count != 1:
    raise SystemExit('unused _SmallAction removal failed')

p.write_text(s)
print('FIX_V063_LINTS: PASS')
