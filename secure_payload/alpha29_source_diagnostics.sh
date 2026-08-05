# Stop after the fully patched Dart source is assembled and expose only
# focused, non-secret excerpts through three GitHub Actions annotations.
python3 - "$SOURCE/payload" "$ROOT/secure_runtime" <<'PYDIAG'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
files = sorted((root / 'lib').rglob('*.dart'))


def numbered(lines, start, end):
    return '\n'.join(f'{i + 1}: {lines[i]}' for i in range(start, end))


def collect(title, patterns, before=10, after=55, max_blocks=16, max_chars=46000):
    blocks = []
    seen = set()
    total = 0
    for path in files:
        lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
        for index, line in enumerate(lines):
            if not any(pattern.search(line) for pattern in patterns):
                continue
            start = max(0, index - before)
            end = min(len(lines), index + after)
            signature = (path.as_posix(), start, end)
            if signature in seen:
                continue
            seen.add(signature)
            text = f'===== {path.relative_to(root).as_posix()} @ {index + 1} =====\n' + numbered(lines, start, end)
            if total + len(text) > max_chars and blocks:
                break
            blocks.append(text)
            total += len(text)
            if len(blocks) >= max_blocks:
                break
        if len(blocks) >= max_blocks or total >= max_chars:
            break
    return f'{title}\n\n' + '\n\n'.join(blocks)


def escape(value):
    return (value.replace('%', '%25')
                 .replace('\r', '%0D')
                 .replace('\n', '%0A'))

expiry = collect(
    'WATCH EXPIRY AND LIFECYCLE',
    [
        re.compile(r'void\s+_scheduleExpiryCleanup|Future<.*>\s+_removeExpired|removeExpired|pruneExpired', re.I),
        re.compile(r'bool\s+get\s+isExpired|DateTime\s+get\s+(endAt|endsAt)|endDateTime', re.I),
        re.compile(r'class\s+WatchItem\b|WatchItem\.(fromJson|fromMap)|Map<String, dynamic>\s+toJson', re.I),
        re.compile(r'didChangeAppLifecycleState|AppLifecycleState\.resumed', re.I),
    ],
    before=14,
    after=80,
    max_blocks=14,
    max_chars=44000,
)

storage = collect(
    'WATCH STORAGE AND BACKGROUND SYNC',
    [
        re.compile(r'class\s+WatchStore\b|Future<.*>\s+(load|save)\(', re.I),
        re.compile(r'_scheduleExpiryCleanup|BackgroundMonitor\.syncWatches|SharedPreferences', re.I),
    ],
    before=10,
    after=55,
    max_blocks=10,
    max_chars=30000,
)

cgv = collect(
    'CGV SEAT LOADING FLOW',
    [
        re.compile(r'class\s+.*Cgv|Future<.*>\s+_?[A-Za-z0-9_]*Cgv|_loadCgv|fetchCgv|cgvSeat', re.I),
        re.compile(r'https?://[^\s\"\']*cgv|cgv\.co\.kr|m\.cgv\.co\.kr|mticket\.cgv\.co\.kr', re.I),
        re.compile(r'WebViewController|NavigationDelegate|onPageFinished|onNavigationRequest|login', re.I),
        re.compile(r'non.?member|비회원|seatMap|seatLayout|availableSeat', re.I),
    ],
    before=16,
    after=95,
    max_blocks=18,
    max_chars=50000,
)

reports = {
    'WATCH_EXPIRY_DETAIL': expiry,
    'WATCH_STORAGE_DETAIL': storage,
    'CGV_FLOW_DETAIL': cgv,
}
for title, content in reports.items():
    (out / f'{title.lower()}.txt').write_text(content, encoding='utf-8')
    print(f'::warning file=.github,line=1,title={title}::{escape(content)}')
print('focused diagnostic excerpts emitted')
PYDIAG
exit 0
