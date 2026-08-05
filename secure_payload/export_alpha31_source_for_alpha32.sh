#!/usr/bin/env bash
set -euo pipefail

BUILD_SCRIPT=/tmp/build_alpha31_export.sh
PATCH30=/tmp/apply_alpha30_auto_seat_design.patch
PATCH31=/tmp/apply_alpha31_unified_picker_probe.patch

[[ "$(git rev-parse HEAD)" == "612f0604d9b23fbd4ce0da7e1a726f2e9e63326b" ]]
test -s "$BUILD_SCRIPT"
test -s "$PATCH30"
test -s "$PATCH31"

python3 - <<'PY'
from pathlib import Path

path = Path('/tmp/build_alpha31_export.sh')
source = path.read_text(encoding='utf-8')

preamble = 'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\nDIST='
if preamble not in source:
    raise SystemExit('patch preamble missing')
source = source.replace(
    preamble,
    'PATCH30="/tmp/apply_alpha30_auto_seat_design.patch"\n'
    'PATCH31="/tmp/apply_alpha31_unified_picker_probe.patch"\nDIST=',
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
    + "echo 'bd81901efc6e07ea30f8d9667a608d0a46d5fcefafc9a0a69e2c4550d9311f03  /tmp/apply_alpha31_unified_picker_probe.patch' | sha256sum -c -\n",
    1,
)

patch30_line = "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha30_auto_seat_design.patch)\\n' +\n"
if patch30_line not in source:
    raise SystemExit('alpha30 patch anchor missing')
source = source.replace(
    patch30_line,
    patch30_line
    + "    '(cd \"$SOURCE/payload\" && patch --batch --forward -p1 < /tmp/apply_alpha31_unified_picker_probe.patch)\\n' +\n",
    1,
)

source = source.replace('0.2.1-alpha.30', '0.2.1-alpha.31')
source = source.replace('run_alpha30_stable', 'run_alpha31_stable')
source = source.replace('build_alpha30_overlay', 'build_alpha31_overlay')

chmod_anchor = 'chmod +x /tmp/run_alpha31_stable.sh\n'
if chmod_anchor not in source:
    raise SystemExit('run chmod anchor missing')
inject = r'''python3 - <<'PYEXPORT'
from pathlib import Path
p = Path('/tmp/run_alpha31_stable.sh')
lines = p.read_text(encoding='utf-8').splitlines(keepends=True)
idx = next(
    i for i, line in enumerate(lines)
    if 'apply_alpha31_unified_picker_probe.patch' in line and 'patch --batch' in line
)
export_lines = [
    "    'rm -rf /tmp/exported_alpha31\\n' +\n",
    "    'mkdir -p /tmp/exported_alpha31\\n' +\n",
    "    'cp -R \\\"$SOURCE/payload/lib\\\" /tmp/exported_alpha31/lib\\n' +\n",
    "    'cp -R \\\"$SOURCE/payload/test\\\" /tmp/exported_alpha31/test\\n' +\n",
    "    'cp \\\"$SOURCE/payload/app_icon.png\\\" /tmp/exported_alpha31/app_icon.png\\n' +\n",
    "    'exit 0\\n' +\n",
]
lines[idx + 1:idx + 1] = export_lines
p.write_text(''.join(lines), encoding='utf-8')
PYEXPORT
'''
source = source.replace(chmod_anchor, chmod_anchor + inject, 1)

run_line = 'bash /tmp/run_alpha31_stable.sh\n'
if run_line not in source:
    raise SystemExit('run execution anchor missing')
source = source.replace(run_line, run_line + 'exit 0\n', 1)
path.write_text(source, encoding='utf-8')
PY

chmod +x "$BUILD_SCRIPT"
bash "$BUILD_SCRIPT"

test -s /tmp/exported_alpha31/lib/wizard_v4.dart
test -s /tmp/exported_alpha31/lib/services.dart
test -s /tmp/exported_alpha31/lib/official_seat_web.dart
grep -q '지역·영화관 통합 선택' /tmp/exported_alpha31/lib/wizard_v4.dart
grep -q 'AutomaticOfficialSeatProbe' /tmp/exported_alpha31/lib/official_seat_web.dart
