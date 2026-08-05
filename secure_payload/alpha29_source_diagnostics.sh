# Stop after the fully patched Dart source is assembled and expose only
# narrow, non-secret code excerpts as GitHub Actions annotations.
python3 - "$SOURCE/payload" <<'PYDIAG'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
queries = {
    'WATCH_EXPIRY': re.compile(r'endAt|endTime|showEnd|expired|expiry|removeWhere|deleteWatch|cleanup|prune', re.I),
    'WATCH_STORAGE': re.compile(r'SharedPreferences|saveWatches|loadWatches|BackgroundMonitor|syncWatches', re.I),
    'CGV_FLOW': re.compile(r'CGV|cgv|WebView|login|member|non.?member|seat|ticket', re.I),
}

matches = {name: [] for name in queries}
for path in sorted((root / 'lib').rglob('*.dart')):
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    for index, line in enumerate(lines):
        for name, pattern in queries.items():
            if pattern.search(line):
                start = max(0, index - 4)
                end = min(len(lines), index + 7)
                excerpt = '\n'.join(f'{i + 1}: {lines[i]}' for i in range(start, end))
                matches[name].append((path.relative_to(root).as_posix(), index + 1, excerpt))


def escape_annotation(value: str) -> str:
    return (value.replace('%', '%25')
                 .replace('\r', '%0D')
                 .replace('\n', '%0A'))

limits = {'WATCH_EXPIRY': 8, 'WATCH_STORAGE': 5, 'CGV_FLOW': 12}
for name, entries in matches.items():
    seen = set()
    emitted = 0
    for path, line_no, excerpt in entries:
        key = (path, excerpt)
        if key in seen:
            continue
        seen.add(key)
        message = escape_annotation(excerpt[:5500])
        print(f'::warning file={path},line={line_no},title={name}::{message}')
        emitted += 1
        if emitted >= limits[name]:
            break
    print(f'::notice title={name}_COUNT::{len(entries)} raw matches; {emitted} excerpts emitted')
PYDIAG
exit 0
