#!/usr/bin/env bash
set -euo pipefail

BUILD_SCRIPT=/tmp/build_alpha33_export.sh
PATCH30=/tmp/apply_alpha30_auto_seat_design.patch
PATCH31=/tmp/apply_alpha31_unified_picker_probe.patch
PATCH32=/tmp/apply_alpha32_cgv_inline_megabox.patch
PATCH33=/tmp/apply_alpha33_seat_cache_fit_cgv.patch

[[ "$(git rev-parse HEAD)" == "612f0604d9b23fbd4ce0da7e1a726f2e9e63326b" ]]
test -s "$BUILD_SCRIPT"
test -s "$PATCH30"
test -s "$PATCH31"
test -s "$PATCH32"
test -s "$PATCH33"

python3 - <<'PY'
from pathlib import Path

path = Path('/tmp/build_alpha33_export.sh')
source = path.read_text(encoding='utf-8')

preamble = 'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\nDIST='
if preamble not in source:
    raise SystemExit('patch preamble missing')
source = source.replace(
    preamble,
    'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\n'
    'PATCH31="/tmp/apply_alpha31_unified_picker_probe.patch"\n'
    'PATCH32="/tmp/apply_alpha32_cgv_inline_megabox.patch"\n'
    'PATCH33="/tmp/apply_alpha33_seat_cache_fit_cgv.patch"\nDIST=',
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
    + "echo 'bd81901efc6e07ea30f8d9667a608d0a46d5fcefafc9a0a69e2c4550d9311f03  /tmp/apply_alpha31_unified_picker_probe.patch' | sha256sum -c -\n"
    + "echo '575bacd49ed8187d115c1abe21a0110dd4648247e23d3f811affc08b63d8b84f  /tmp/apply_alpha32_cgv_inline_megabox.patch' | sha256sum -c -\n"
    + "echo '846ebb0285379e1c8a7c03ae1e5042eeb34fee029cd44d738aa1e172fa884fdc  /tmp/apply_alpha33_seat_cache_fit_cgv.patch' | sha256sum -c -\n",
    1,
)

patch30_line = "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha30_auto_seat_design.patch)\\n' +\n"
if patch30_line not in source:
    raise SystemExit('alpha30 patch anchor missing')
source = source.replace(
    patch30_line,
    patch30_line
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha31_unified_picker_probe.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha32_cgv_inline_megabox.patch)\\n' +\n"
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha33_seat_cache_fit_cgv.patch)\\n' +\n",
    1,
)

source = source.replace('0.2.1-alpha.30', '0.2.1-alpha.33')
source = source.replace('run_alpha30_stable', 'run_alpha33_stable')
source = source.replace('build_alpha30_overlay', 'build_alpha33_overlay')

chmod_anchor = 'chmod +x /tmp/run_alpha33_stable.sh\n'
if chmod_anchor not in source:
    raise SystemExit('run chmod anchor missing')
inject = r'''python3 - <<'PYEXPORT'
from pathlib import Path
p = Path('/tmp/run_alpha33_stable.sh')
lines = p.read_text(encoding='utf-8').splitlines(keepends=True)
idx = next(
    i for i, line in enumerate(lines)
    if line.strip() == "text = source.read_text(encoding='utf-8')"
)
export_code = [
    "text = text.replace(\n",
    "    '# Restore the encrypted foreground monitor and boot receiver.\\n',\n",
    "    'rm -rf /tmp/exported_alpha33\\n'\n",
    "    'mkdir -p /tmp/exported_alpha33\\n'\n",
    "    'cp -R \\\"$SOURCE/payload/lib\\\" /tmp/exported_alpha33/lib\\n'\n",
    "    'cp -R \\\"$SOURCE/payload/test\\\" /tmp/exported_alpha33/test\\n'\n",
    "    'cp \\\"$SOURCE/payload/app_icon.png\\\" /tmp/exported_alpha33/app_icon.png\\n'\n",
    "    'exit 0\\n\\n'\n",
    "    '# Restore the encrypted foreground monitor and boot receiver.\\n',\n",
    "    1,\n",
    ")\n",
]
lines[idx + 1:idx + 1] = export_code
p.write_text(''.join(lines), encoding='utf-8')
PYEXPORT
'''
source = source.replace(chmod_anchor, chmod_anchor + inject, 1)

run_line = 'bash /tmp/run_alpha33_stable.sh\n'
if run_line not in source:
    raise SystemExit('run execution anchor missing')
source = source.replace(run_line, run_line + 'exit 0\n', 1)
path.write_text(source, encoding='utf-8')
PY

chmod +x "$BUILD_SCRIPT"
bash "$BUILD_SCRIPT"

test -s /tmp/exported_alpha33/lib/wizard_v4.dart
test -s /tmp/exported_alpha33/lib/services.dart
test -s /tmp/exported_alpha33/lib/official_seat_web.dart
test -s /tmp/exported_alpha33/lib/cgv_seat_bridge.dart
grep -q 'exact_seat_viewport' /tmp/exported_alpha33/lib/wizard_v4.dart
grep -q 'nmbrAtktFlag' /tmp/exported_alpha33/lib/official_seat_web.dart
