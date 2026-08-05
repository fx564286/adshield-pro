#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"
DIST="$ROOT/dist"
RUNTIME="$ROOT/secure_runtime"

[[ "$(git rev-parse HEAD)" == "612f0604d9b23fbd4ce0da7e1a726f2e9e63326b" ]]
test -s "$PATCH30"
echo 'daf4faadeaf2bcf4dce36ce4d3a7322eeb5b908f8c9b6efb08d5cc48cf050a21  /tmp/apply_alpha30_auto_seat_design.patch' | sha256sum -c -

cat \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part00 \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part01 \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part02 \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part03a \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part03b \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part04 \
  secure_payload/apply_alpha22_seat_ui_fix.py.gz.b64.part05 \
  | base64 --decode | gzip --decompress \
  > secure_payload/apply_alpha22_seat_ui_fix.py
cat secure_payload/apply_alpha23_ui_cache.py.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > secure_payload/apply_alpha23_ui_cache.py
cat secure_payload/apply_alpha25_alpha19_region_condition.py.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > secure_payload/apply_alpha25_alpha19_region_condition.py
cat secure_payload/apply_alpha26_unified_filters_seat_icon.py.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > secure_payload/apply_alpha26_unified_filters_seat_icon.py
cat secure_payload/apply_alpha27_picker_cgv.py.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > secure_payload/apply_alpha27_picker_cgv.py
cat secure_payload/apply_alpha28_regions_seats.patch.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > /tmp/apply_alpha28_regions_seats.patch
cat secure_payload/apply_alpha29_megabox_picker.patch.gz.b64.part* \
  | base64 --decode | gzip --decompress \
  > /tmp/apply_alpha29_megabox_picker.patch

echo 'ca92226fc2eed9af4d29dd0972291e18e8dfa665aa81c2d71a5c6eda52c87340  /tmp/apply_alpha28_regions_seats.patch' | sha256sum -c -
echo '3e1e699a311513897e21a5f5147cfc0a1d49acdea96ce14a3b5594a6f971017d  /tmp/apply_alpha29_megabox_picker.patch' | sha256sum -c -
python3 -m py_compile secure_payload/apply_alpha22_seat_ui_fix.py
python3 -m py_compile secure_payload/apply_alpha22_booking_helper_fix.py
python3 -m py_compile secure_payload/apply_alpha23_ui_cache.py
python3 -m py_compile secure_payload/apply_alpha25_alpha19_region_condition.py
python3 -m py_compile secure_payload/apply_alpha26_unified_filters_seat_icon.py
python3 -m py_compile secure_payload/apply_alpha26_key_compat.py
python3 -m py_compile secure_payload/apply_alpha27_picker_cgv.py
python3 -m py_compile secure_payload/apply_alpha27_legacy_verifier_compat.py

python3 - <<'PY'
from pathlib import Path

source = Path('secure_payload/build_alpha21_overlay_v2_public.sh')
wrapper = source.read_text(encoding='utf-8')
addon_anchor = 'rm -f "$SOURCE/payload/test/alpha20_runtime_test.dart"\n'
if addon_anchor not in wrapper:
    raise SystemExit('stable addon anchor missing')
wrapper = wrapper.replace(
    addon_anchor,
    addon_anchor +
    'python3 secure_payload/apply_alpha22_seat_ui_fix.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha22_booking_helper_fix.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha23_ui_cache.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha25_alpha19_region_condition.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha26_unified_filters_seat_icon.py "$SOURCE/payload"\n' +
    'printf "\\n// Cineseat 0.2.1-alpha.28\\n" >> "$SOURCE/payload/lib/wizard_v4.dart"\n',
    1,
)
after_polish = "PYFIX\n'''"
if after_polish not in wrapper:
    raise SystemExit('polish anchor missing')
wrapper = wrapper.replace(
    after_polish,
    'PYFIX\n' +
    'python3 secure_payload/apply_alpha26_key_compat.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha27_picker_cgv.py "$SOURCE/payload"\n' +
    'python3 secure_payload/apply_alpha27_legacy_verifier_compat.py "$SOURCE/payload"\n' +
    '(cd "$SOURCE/payload" && patch --batch --forward -p1 < /tmp/apply_alpha28_regions_seats.patch)\n' +
    '(cd "$SOURCE/payload" && patch --batch --forward -p1 < /tmp/apply_alpha29_megabox_picker.patch)\n' +
    '(cd "$SOURCE/payload" && patch --batch --forward -p1 < /tmp/apply_alpha30_auto_seat_design.patch)\n' +
    'grep -q "class AutomaticOfficialSeatProbe" "$SOURCE/payload/lib/official_seat_web.dart"\n' +
    'grep -q "_automaticSeatProbeActive" "$SOURCE/payload/lib/wizard_v4.dart"\n' +
    'grep -q "picker_region_" "$SOURCE/payload/lib/wizard_v4.dart"\n' +
    'printf "\\n// Cineseat 0.2.1-alpha.30\\n" >> "$SOURCE/payload/lib/wizard_v4.dart"\n' +
    "'''",
    1,
)
text_anchor = "text = source.read_text(encoding='utf-8')\n"
if text_anchor not in wrapper:
    raise SystemExit('builder text anchor missing')
wrapper = wrapper.replace(
    text_anchor,
    text_anchor +
    "text = text.replace('0.2.1-alpha.21', '0.2.1-alpha.30')\n" +
    "text = text.replace('version: 0.2.1-alpha.30+41', 'version: 0.2.1-alpha.30+50')\n" +
    "text = text.replace('--build-number=41', '--build-number=50')\n" +
    "text = text.replace(\"versionCode='41'\", \"versionCode='50'\")\n" +
    "text = text.replace('Cineseat 0.2.1-alpha.21 validation build', 'Cineseat 0.2.1-alpha.30 validation build')\n" +
    "text = text.replace(\"if '0.2.1-alpha.21' not in all_dart:\", \"if '0.2.1-alpha.30' not in all_dart:\")\n" +
    "text = text.replace('alpha21 version marker is missing', 'alpha30 version marker is missing')\n" +
    "text = text.replace('  http: ^1.4.0\\n', '  http: ^1.4.0\\n  crypto: ^3.0.7\\n', 1)\n",
    1,
)
wrapper = wrapper.replace(
    '/tmp/build_alpha21_overlay_v2_public.sh',
    '/tmp/build_alpha30_overlay_v2_public.sh',
)
Path('/tmp/run_alpha30_stable.sh').write_text(wrapper, encoding='utf-8')
PY
chmod +x /tmp/run_alpha30_stable.sh

mkdir -p "$RUNTIME"
base64 --decode secure_payload/cineseat-release.aes.key.enc.b64 > "$RUNTIME/cineseat-release.aes.key.enc"
echo '8eb3210c6a037703ae5f29303ba7cc9b051e338434ae261dabb14779111d3909  secure_runtime/cineseat-release.aes.key.enc' | sha256sum -c -
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/cineseat-release.aes.key.enc" \
  -out "$RUNTIME/cineseat-release.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
base64 --decode secure_payload/cineseat-release.p12.enc.b64 > "$RUNTIME/cineseat-release.p12.enc"
echo '9696b12c5690244d8fdadc955cf238b3d90361b984e0ed7ab22a12ed3ad894cf  secure_runtime/cineseat-release.p12.enc' | sha256sum -c -
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/cineseat-release.p12.enc" \
  -out "$RUNTIME/cineseat-release.p12" \
  -pass file:"$RUNTIME/cineseat-release.aes.key"

bash /tmp/run_alpha30_stable.sh

APK="$DIST/cineseat-0.2.1-alpha.30-VALIDATION.apk"
TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
"$TOOLS/apksigner" sign \
  --ks "$RUNTIME/cineseat-release.p12" \
  --ks-type PKCS12 \
  --ks-key-alias cineseat \
  --ks-pass pass:cineseat-fixed-2026 \
  --key-pass pass:cineseat-fixed-2026 \
  --v1-signing-enabled false \
  --v2-signing-enabled true \
  --v3-signing-enabled false \
  --out "$DIST/alpha30-fixed.apk" "$APK"
mv "$DIST/alpha30-fixed.apk" "$APK"
"$TOOLS/zipalign" -c -v 4 "$APK"
"$TOOLS/apksigner" verify --verbose --print-certs "$APK" | tee "$DIST/APK-SIGNATURE.txt"
"$TOOLS/aapt" dump badging "$APK" | tee "$DIST/APK-PACKAGE-INFO.txt"
sha256sum "$APK" | tee "$DIST/SHA256SUMS.txt"

grep -q "package: name='com.fx564286.cinema_seat_alert'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionCode='50'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionName='0.2.1-alpha.30'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q 'f8954ba293629909345ca7a0ae42198bfb0a6b568e1cf5384ecb9c7a3e18edd4' "$DIST/APK-SIGNATURE.txt"
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' "$DIST/APK-SIGNATURE.txt"
test -s "$APK"
unzip -tq "$APK"

cat >> "$DIST/BUILD_REPORT.txt" <<'REPORT'
- CGV and Megabox direct APIs and hidden official non-member WebViews start automatically in parallel
- the first valid exact seat layout appears without opening an official page or pressing an import button
- stale showtime responses are rejected by generation and showtime checks
- Megabox DOM extraction scans additional attributes, ancestors and selectors with extended retries
- theater picker uses full-width cards with horizontal region and district filters instead of a tall fixed rail
- fixed alpha27 signing certificate retained for overwrite installation over alpha29
REPORT

rm -f "$RUNTIME/cineseat-release.aes.key" "$RUNTIME/cineseat-release.p12"
