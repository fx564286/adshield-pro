#!/usr/bin/env bash
set -euo pipefail

BUILD_SCRIPT=/tmp/build_alpha35_base.sh
PATCH30=/tmp/apply_alpha30_auto_seat_design.patch
PATCH31=/tmp/apply_alpha31_unified_picker_probe.patch
PATCH32=/tmp/apply_alpha32_cgv_inline_megabox.patch
PATCH33=/tmp/apply_alpha33_seat_cache_fit_cgv.patch
PATCH34=/tmp/apply_alpha34_cgv_session_capture.patch
PATCH35=/tmp/apply_alpha35_expiry_cgv_legacy.patch

[[ "$(git rev-parse HEAD)" == "612f0604d9b23fbd4ce0da7e1a726f2e9e63326b" ]]
for file in "$BUILD_SCRIPT" "$PATCH30" "$PATCH31" "$PATCH32" "$PATCH33" "$PATCH34" "$PATCH35"; do
  test -s "$file"
done

python3 - <<'PY'
from pathlib import Path

path = Path('/tmp/build_alpha35_base.sh')
source = path.read_text(encoding='utf-8')

preamble = 'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\nDIST='
if preamble not in source:
    raise SystemExit('alpha30 patch preamble missing')
source = source.replace(
    preamble,
    'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\n'
    'PATCH31="/tmp/apply_alpha31_unified_picker_probe.patch"\n'
    'PATCH32="/tmp/apply_alpha32_cgv_inline_megabox.patch"\n'
    'PATCH33="/tmp/apply_alpha33_seat_cache_fit_cgv.patch"\n'
    'PATCH34="/tmp/apply_alpha34_cgv_session_capture.patch"\n'
    'PATCH35="/tmp/apply_alpha35_expiry_cgv_legacy.patch"\nDIST=',
    1,
)

verify = (
    'test -s "$PATCH30"\n'
    "echo 'daf4faadeaf2bcf4dce36ce4d3a7322eeb5b908f8c9b6efb08d5cc48cf050a21  /tmp/apply_alpha30_auto_seat_design.patch' | sha256sum -c -\n"
)
if verify not in source:
    raise SystemExit('alpha30 verification anchor missing')
source = source.replace(
    verify,
    verify
    + 'test -s "$PATCH31"\n'
    + 'test -s "$PATCH32"\n'
    + 'test -s "$PATCH33"\n'
    + 'test -s "$PATCH34"\n'
    + 'test -s "$PATCH35"\n'
    + "echo 'bd81901efc6e07ea30f8d9667a608d0a46d5fcefafc9a0a69e2c4550d9311f03  /tmp/apply_alpha31_unified_picker_probe.patch' | sha256sum -c -\n"
    + "echo '575bacd49ed8187d115c1abe21a0110dd4648247e23d3f811affc08b63d8b84f  /tmp/apply_alpha32_cgv_inline_megabox.patch' | sha256sum -c -\n"
    + "echo '846ebb0285379e1c8a7c03ae1e5042eeb34fee029cd44d738aa1e172fa884fdc  /tmp/apply_alpha33_seat_cache_fit_cgv.patch' | sha256sum -c -\n"
    + "echo '89e323c8100933f1a69778b17d6602ac048bdd4d3b244e02478fa8ad4d3075f2  /tmp/apply_alpha34_cgv_session_capture.patch' | sha256sum -c -\n"
    + "echo '4ceb93306c0b475d5afb80d94db279bf08cdb8ffe8d247aaa458a47a9ceead82  /tmp/apply_alpha35_expiry_cgv_legacy.patch' | sha256sum -c -\n",
    1,
)

patch30 = "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha30_auto_seat_design.patch)\\n' +\n"
if patch30 not in source:
    raise SystemExit('alpha30 patch application anchor missing')
source = source.replace(
    patch30,
    patch30
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha31_unified_picker_probe.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha32_cgv_inline_megabox.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha33_seat_cache_fit_cgv.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha34_cgv_session_capture.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha35_expiry_cgv_legacy.patch)\\n' +\n"
    + "    'grep -q \"_expiryWatchdog\" \"$SOURCE/payload/lib/app_controller.dart\"\\n' +\n"
    + "    'grep -q \"handleAppResumed\" \"$SOURCE/payload/lib/home.dart\"\\n' +\n"
    + "    'grep -q \"QuickResult.aspx\" \"$SOURCE/payload/lib/official_seat_web.dart\"\\n' +\n"
    + "    'grep -q \"selectMatchingShowtime\" \"$SOURCE/payload/lib/cgv_seat_bridge.dart\"\\n' +\n"
    + "    'grep -q \"scnEndDttm\" \"$SOURCE/payload/lib/services.dart\"\\n' +\n",
    1,
)

source = source.replace('0.2.1-alpha.30', '0.2.1-alpha.35')
source = source.replace('version: 0.2.1-alpha.35+50', 'version: 0.2.1-alpha.35+55')
source = source.replace('--build-number=50', '--build-number=55')
source = source.replace("versionCode='50'", "versionCode='55'")
source = source.replace('alpha30-fixed.apk', 'alpha35-fixed.apk')
source = source.replace('run_alpha30_stable', 'run_alpha35_stable')
source = source.replace('build_alpha30_overlay', 'build_alpha35_overlay')
source = source.replace('alpha30 version marker', 'alpha35 version marker')
source = source.replace(
    'fixed alpha27 signing certificate retained for overwrite installation over alpha29',
    'fixed signing certificate retained for overwrite installation over alpha34',
)
path.write_text(source, encoding='utf-8')
PY

chmod +x "$BUILD_SCRIPT"
bash "$BUILD_SCRIPT"
