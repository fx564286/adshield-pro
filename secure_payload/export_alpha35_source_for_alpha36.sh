#!/usr/bin/env bash
set -euo pipefail

EXPORT_SCRIPT=/tmp/export_alpha35_runtime.sh
cp /tmp/build_alpha35_expiry_cgv_legacy.sh "$EXPORT_SCRIPT"

python3 - "$EXPORT_SCRIPT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding='utf-8')
anchor = '''chmod +x "$BUILD_SCRIPT"
bash "$BUILD_SCRIPT"
'''
if anchor not in source:
    raise SystemExit('alpha35 final execution anchor missing')

replacement = r"""python3 - <<'PYEXPORT'
from pathlib import Path

path = Path('/tmp/build_alpha35_base.sh')
text = path.read_text(encoding='utf-8')
chmod_anchor = 'chmod +x /tmp/run_alpha35_stable.sh\n'
if chmod_anchor not in text:
    raise SystemExit('alpha35 run chmod anchor missing')

inject = r'''python3 - <<'PYSOURCE'
from pathlib import Path

p = Path('/tmp/run_alpha35_stable.sh')
lines = p.read_text(encoding='utf-8').splitlines(keepends=True)
idx = next(
    i for i, line in enumerate(lines)
    if line.strip() == "text = source.read_text(encoding='utf-8')"
)
export_code = [
    "text = text.replace(\n",
    "    '# Restore the encrypted foreground monitor and boot receiver.\\n',\n",
    "    'rm -rf /tmp/exported_alpha35\\n'\n",
    "    'mkdir -p /tmp/exported_alpha35\\n'\n",
    "    'cp -R \\\"$SOURCE/payload/lib\\\" /tmp/exported_alpha35/lib\\n'\n",
    "    'cp -R \\\"$SOURCE/payload/test\\\" /tmp/exported_alpha35/test\\n'\n",
    "    'cp \\\"$SOURCE/payload/app_icon.png\\\" /tmp/exported_alpha35/app_icon.png\\n'\n",
    "    'exit 0\\n\\n'\n",
    "    '# Restore the encrypted foreground monitor and boot receiver.\\n',\n",
    "    1,\n",
    ")\n",
]
lines[idx + 1:idx + 1] = export_code
p.write_text(''.join(lines), encoding='utf-8')
PYSOURCE
'''
text = text.replace(chmod_anchor, chmod_anchor + inject, 1)
run_line = 'bash /tmp/run_alpha35_stable.sh\n'
if run_line not in text:
    raise SystemExit('alpha35 run execution anchor missing')
text = text.replace(run_line, run_line + 'exit 0\n', 1)
path.write_text(text, encoding='utf-8')
PYEXPORT

chmod +x "$BUILD_SCRIPT"
bash "$BUILD_SCRIPT"
"""
source = source.replace(anchor, replacement, 1)
path.write_text(source, encoding='utf-8')
PY

chmod +x "$EXPORT_SCRIPT"
bash "$EXPORT_SCRIPT"

test -s /tmp/exported_alpha35/lib/wizard_v4.dart
test -s /tmp/exported_alpha35/lib/services.dart
test -s /tmp/exported_alpha35/lib/official_seat_web.dart
test -s /tmp/exported_alpha35/lib/cgv_seat_bridge.dart
test -s /tmp/exported_alpha35/lib/app_controller.dart
test -s /tmp/exported_alpha35/lib/home.dart
grep -q '0.2.1-alpha.35' /tmp/exported_alpha35/lib/wizard_v4.dart
grep -q 'QuickResult.aspx' /tmp/exported_alpha35/lib/official_seat_web.dart
grep -q '_expiryWatchdog' /tmp/exported_alpha35/lib/app_controller.dart
