#!/usr/bin/env bash
set -euo pipefail

BASE=/tmp/build_alpha36_exact.sh
RUNTIME=/tmp/build_alpha39_runtime.sh
SOURCE_PATCHER=/tmp/patch_alpha39_no_ads_source.py
ANDROID_PATCHER=/tmp/patch_alpha39_no_ads_android.py

for file in "$BASE" "$SOURCE_PATCHER" "$ANDROID_PATCHER"; do
  test -s "$file"
done
cp "$BASE" "$RUNTIME"

python3 - "$RUNTIME" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')

source_anchor = '(cd "$SOURCE" && patch --batch --forward -p1 < "$PATCH")\n'
if source_anchor not in text:
    raise SystemExit('alpha36 source patch anchor missing')
text = text.replace(
    source_anchor,
    source_anchor + 'python3 /tmp/patch_alpha39_no_ads_source.py "$SOURCE"\n',
    1,
)

old_ads_contract = """    'ads': [
        'BannerAd(',
        'RewardedAd.load(',
        'InterstitialAd.load(',
    ],
"""
new_ads_contract = """    'ads': [
        'class MonetizationController',
        'bool isAdFree = true;',
        'Future<void> maybeShowInterstitial() async {}',
    ],
"""
if old_ads_contract not in text:
    raise SystemExit('alpha36 advertising source contract anchor missing')
text = text.replace(old_ads_contract, new_ads_contract, 1)

text = text.replace('  google_mobile_ads: ^9.0.0\n', '', 1)
if 'google_mobile_ads:' in text:
    raise SystemExit('google_mobile_ads dependency remained in runtime build script')

android_anchor = 'python3 /tmp/patch_alpha36_android.py "$BUILD"\n'
if android_anchor not in text:
    raise SystemExit('alpha36 Android patch anchor missing')
text = text.replace(
    android_anchor,
    android_anchor + 'python3 /tmp/patch_alpha39_no_ads_android.py "$BUILD"\n',
    1,
)

text = text.replace('0.2.1-alpha.36', '0.2.1-alpha.39')
text = text.replace('+56', '+59')
text = text.replace('--build-number=56', '--build-number=59')
text = text.replace("versionCode='56'", "versionCode='59'")
text = text.replace('alpha.36-fixed.apk', 'alpha.39-fixed.apk')
text = text.replace('alpha.36-unsigned.apk', 'alpha.39-unsigned.apk')
text = text.replace(
    'Cineseat alpha36 CGV direct seats and AdMob validation',
    'Cineseat alpha39 CGV direct seats without advertising SDK',
)

positive_ad_checks = """grep -q 'com.google.android.gms.permission.AD_ID' "$DIST/APK-PERMISSIONS.txt"
grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$DIST/APK-MANIFEST.txt"
grep -q 'ca-app-pub-8431674789078471~7810960805' "$DIST/APK-MANIFEST.txt"
"""
negative_ad_checks = """if grep -q 'com.google.android.gms.permission.AD_ID' "$DIST/APK-PERMISSIONS.txt"; then
  echo 'AD_ID permission remained in alpha39 no-ad APK' >&2
  exit 1
fi
if grep -q 'com.google.android.gms.ads' "$DIST/APK-MANIFEST.txt"; then
  echo 'Google Mobile Ads component remained in alpha39 manifest' >&2
  exit 1
fi
if grep -q 'ca-app-pub-' "$DIST/APK-MANIFEST.txt"; then
  echo 'AdMob identifier remained in alpha39 manifest' >&2
  exit 1
fi
unzip -p "$APK" lib/arm64-v8a/libapp.so > /tmp/cineseat-alpha39-libapp.so
strings /tmp/cineseat-alpha39-libapp.so > /tmp/cineseat-alpha39-libapp.strings
if grep -q 'google_mobile_ads' /tmp/cineseat-alpha39-libapp.strings; then
  echo 'google_mobile_ads Dart package remained in alpha39 AOT snapshot' >&2
  exit 1
fi
if grep -q 'ca-app-pub-' /tmp/cineseat-alpha39-libapp.strings; then
  echo 'AdMob ad unit identifier remained in alpha39 AOT snapshot' >&2
  exit 1
fi
if unzip -l "$APK" | grep -qiE 'google_mobile_ads|MobileAds|AdActivity'; then
  echo 'Google Mobile Ads packaged component remained in alpha39 APK' >&2
  exit 1
fi
"""
if positive_ad_checks not in text:
    raise SystemExit('alpha36 positive AdMob verification block missing')
text = text.replace(positive_ad_checks, negative_ad_checks, 1)

report_pattern = re.compile(
    r'cat > "\$DIST/BUILD_REPORT\.txt" <<\'REPORT\'\n.*?\nREPORT\n',
    re.S,
)
report = '''cat > "$DIST/BUILD_REPORT.txt" <<'REPORT'
Cineseat 0.2.1-alpha.39 build report
- exact alpha35 successfully built source was reconstructed before patching
- alpha36 CGV direct seat API and seat parsing changes are retained
- all Flutter runtime tests passed
- google_mobile_ads is absent from pubspec and the compiled Dart snapshot
- AdMob application metadata and AD_ID permission are absent
- Google Mobile Ads providers, activities and packaged components are absent
- banner, rewarded and interstitial execution paths are replaced by no-op stability shims
- monitoring slots are unrestricted while advertising is isolated
- exact permanent signing identity is retained for overwrite installation
REPORT
'''
text, count = report_pattern.subn(report, text, count=1)
if count != 1:
    raise SystemExit('build report block replacement failed')

path.write_text(text, encoding='utf-8')
PY

chmod +x "$RUNTIME"
bash "$RUNTIME"
