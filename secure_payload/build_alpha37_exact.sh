#!/usr/bin/env bash
set -euo pipefail

BASE=/tmp/build_alpha36_exact.sh
RUNTIME=/tmp/build_alpha37_runtime.sh
PATCHER=/tmp/patch_alpha37_crash_ads.py

test -s "$BASE"
test -s "$PATCHER"
cp "$BASE" "$RUNTIME"

python3 - "$RUNTIME" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')

anchor = '(cd "$SOURCE" && patch --batch --forward -p1 < "$PATCH")\n'
if anchor not in text:
    raise SystemExit('alpha36 patch execution anchor missing')
text = text.replace(
    anchor,
    anchor + 'python3 /tmp/patch_alpha37_crash_ads.py "$SOURCE"\n',
    1,
)

# Only update release metadata. Keep alpha36 patcher and patch file paths intact.
text = text.replace('0.2.1-alpha.36', '0.2.1-alpha.37')
text = text.replace('+56', '+57')
text = text.replace('--build-number=56', '--build-number=57')
text = text.replace("versionCode='56'", "versionCode='57'")
text = text.replace('alpha.36-fixed.apk', 'alpha.37-fixed.apk')

report_line = '- Google official test ad unit IDs are used in this validation APK\n'
text = text.replace(
    report_line,
    '- user-provided production banner, rewarded and interstitial unit IDs are embedded\n',
)

manifest_checks = "grep -q 'ca-app-pub-8431674789078471~7810960805' \"$DIST/APK-MANIFEST.txt\"\n"
if manifest_checks not in text:
    raise SystemExit('AdMob app ID verification anchor missing')
text = text.replace(
    manifest_checks,
    manifest_checks + '''unzip -p "$APK" lib/arm64-v8a/libapp.so > /tmp/cineseat-alpha37-libapp.so
strings /tmp/cineseat-alpha37-libapp.so > /tmp/cineseat-alpha37-libapp.strings
grep -q 'ca-app-pub-8431674789078471/1709517483' /tmp/cineseat-alpha37-libapp.strings
grep -q 'ca-app-pub-8431674789078471/4616710575' /tmp/cineseat-alpha37-libapp.strings
grep -q 'ca-app-pub-8431674789078471/6249530627' /tmp/cineseat-alpha37-libapp.strings
if grep -q 'ca-app-pub-3940256099942544/' /tmp/cineseat-alpha37-libapp.strings; then
  echo 'Google test ad unit ID remained in alpha37 production APK' >&2
  exit 1
fi
''',
    1,
)

path.write_text(text, encoding='utf-8')
PY

chmod +x "$RUNTIME"
bash "$RUNTIME"
