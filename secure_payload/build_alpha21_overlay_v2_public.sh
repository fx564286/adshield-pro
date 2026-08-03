#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
source = Path('secure_payload/build_alpha21_overlay_public.sh')
target = Path('/tmp/build_alpha21_overlay_v2_public.sh')
text = source.read_text(encoding='utf-8')
marker = 'cp "$OVERLAY/overlay/app_icon.png" "$SOURCE/payload/app_icon.png"\n'
addon = r'''

# Replace the alpha.20 home entry points with the exact stable WatchWizard home.
mkdir -p "$OVERLAY/home-addon"
base64 --decode secure_payload/alpha21-home-addon.key.enc.b64 \
  > "$RUNTIME/home-addon.key.enc"
printf '%s  %s\n' \
  'b74cfe750bc1acf847a3e2ff7244f43bf5f23e0fcc1dd8905cc09b31c2337bf8' \
  "$RUNTIME/home-addon.key.enc" | sha256sum -c -
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/home-addon.key.enc" \
  -out "$RUNTIME/home-addon.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
base64 --decode secure_payload/alpha21-home-addon.enc.b64 \
  > "$RUNTIME/home-addon.enc"
printf '%s  %s\n' \
  '9d5e6114be9a77c87fd556755efd02d189ba1547d9518e739e9794ffe42bb6e1' \
  "$RUNTIME/home-addon.enc" | sha256sum -c -
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/home-addon.enc" \
  -out "$RUNTIME/home-addon.tar.xz" \
  -pass file:"$RUNTIME/home-addon.aes.key"
printf '%s  %s\n' \
  '48d87c74c00e3981b946ba93463e2b714852fe6db6b8b49eed96d9e808b94e41' \
  "$RUNTIME/home-addon.tar.xz" | sha256sum -c -
tar -xJf "$RUNTIME/home-addon.tar.xz" -C "$OVERLAY/home-addon"
cp "$OVERLAY/home-addon/addon/lib/home.dart" "$SOURCE/payload/lib/home.dart"
rm -f "$SOURCE/payload/test/alpha20_runtime_test.dart"

# ExpansionTile must paint on its own Material surface. This is a no-op for
# older payloads and applies only when the alpha.23 region accordion exists.
python3 - "$SOURCE/payload" <<'PYFIX'
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'lib/wizard_v4.dart'
source = path.read_text(encoding='utf-8')
old = '''    return Container(
      key: const Key('region_filter_panel'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Theme(
'''
new = '''    return Material(
      key: const Key('region_filter_panel'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
'''
if old in source:
    path.write_text(source.replace(old, new, 1), encoding='utf-8')
    print('region accordion Material surface applied')
PYFIX
'''
if marker not in text:
    raise SystemExit('alpha21 overlay insertion marker missing')
target.write_text(text.replace(marker, marker + addon, 1), encoding='utf-8')
PY

bash /tmp/build_alpha21_overlay_v2_public.sh
