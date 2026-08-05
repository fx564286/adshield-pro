#!/usr/bin/env bash
set -euo pipefail

BASE=/tmp/build_alpha36_exact.sh
RUNTIME=/tmp/build_alpha38_runtime.sh
DART_PATCHER=/tmp/patch_alpha37_crash_ads.py
PRELOAD_PATCHER=/tmp/patch_alpha38_dart_safe.py
NATIVE_PATCHER=/tmp/patch_alpha38_native_ad_safe.py

for file in "$BASE" "$DART_PATCHER" "$PRELOAD_PATCHER" "$NATIVE_PATCHER"; do
  test -s "$file"
done
cp "$BASE" "$RUNTIME"

python3 - "$RUNTIME" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')

source_anchor = '(cd "$SOURCE" && patch --batch --forward -p1 < "$PATCH")\n'
if source_anchor not in text:
    raise SystemExit('alpha36 source patch anchor missing')
text = text.replace(
    source_anchor,
    source_anchor
    + 'python3 /tmp/patch_alpha37_crash_ads.py "$SOURCE"\n'
    + 'python3 /tmp/patch_alpha38_dart_safe.py "$SOURCE"\n',
    1,
)

android_anchor = 'python3 /tmp/patch_alpha36_android.py "$BUILD"\n'
if android_anchor not in text:
    raise SystemExit('alpha36 Android patch anchor missing')
text = text.replace(
    android_anchor,
    android_anchor + 'python3 /tmp/patch_alpha38_native_ad_safe.py "$BUILD"\n',
    1,
)

text = text.replace('0.2.1-alpha.36', '0.2.1-alpha.38')
text = text.replace('+56', '+58')
text = text.replace('--build-number=56', '--build-number=58')
text = text.replace("versionCode='56'", "versionCode='58'")
text = text.replace('alpha.36-fixed.apk', 'alpha.38-fixed.apk')
text = text.replace('alpha36 CGV direct seats and AdMob validation', 'alpha38 crash-safe manual AdMob initialization')

report_line = '- Google official test ad unit IDs are used in this validation APK\n'
text = text.replace(
    report_line,
    '- user-provided production banner, rewarded and interstitial unit IDs are embedded\n'
    '- MobileAdsInitProvider automatic pre-Flutter initialization is removed\n'
    '- Google Mobile Ads is initialized manually after the first visible app frame\n',
)

manifest_checks = "grep -q 'ca-app-pub-8431674789078471~7810960805' \"$DIST/APK-MANIFEST.txt\"\n"
if manifest_checks not in text:
    raise SystemExit('AdMob manifest verification anchor missing')
text = text.replace(
    manifest_checks,
    manifest_checks + '''if grep -q 'com.google.android.gms.ads.MobileAdsInitProvider' "$DIST/APK-MANIFEST.txt"; then
  echo 'MobileAdsInitProvider remained in alpha38 merged manifest' >&2
  exit 1
fi
grep -q 'com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION' "$DIST/APK-MANIFEST.txt"
grep -q 'com.google.android.gms.ads.flag.OPTIMIZE_AD_LOADING' "$DIST/APK-MANIFEST.txt"
unzip -p "$APK" lib/arm64-v8a/libapp.so > /tmp/cineseat-alpha38-libapp.so
strings /tmp/cineseat-alpha38-libapp.so > /tmp/cineseat-alpha38-libapp.strings
grep -q 'ca-app-pub-8431674789078471/1709517483' /tmp/cineseat-alpha38-libapp.strings
grep -q 'ca-app-pub-8431674789078471/4616710575' /tmp/cineseat-alpha38-libapp.strings
grep -q 'ca-app-pub-8431674789078471/6249530627' /tmp/cineseat-alpha38-libapp.strings
if grep -q 'ca-app-pub-3940256099942544/' /tmp/cineseat-alpha38-libapp.strings; then
  echo 'Google test ad unit ID remained in alpha38 production APK' >&2
  exit 1
fi
''',
    1,
)

path.write_text(text, encoding='utf-8')
PY

chmod +x "$RUNTIME"
bash "$RUNTIME"
