from pathlib import Path
import base64
import re
import shutil
import subprocess
import sys
import tarfile

repo_root = Path.cwd()
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build_app')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit(f'Manifest not found: {manifest}')

kotlin_dir = root / 'android/app/src/main/kotlin/com/fx564286/cinema_seat_alert'
kotlin_dir.mkdir(parents=True, exist_ok=True)
required_native = ('MainActivity.kt', 'SeatMonitorService.kt', 'BootReceiver.kt')

if any(not (kotlin_dir / name).exists() for name in required_native):
    payload_dir = repo_root / 'secure_payload'
    runtime_dir = repo_root / 'secure_runtime/native_restore'
    private_key = repo_root / 'secure_runtime/private.pem'
    encrypted_payload = payload_dir / 'native.enc.b64'
    encrypted_key = payload_dir / 'native.key.enc.b64'
    for path in (private_key, encrypted_payload, encrypted_key):
        if not path.exists() or path.stat().st_size == 0:
            raise SystemExit(f'Encrypted native prerequisite missing: {path}')

    if runtime_dir.exists():
        shutil.rmtree(runtime_dir)
    runtime_dir.mkdir(parents=True, exist_ok=True)
    key_enc = runtime_dir / 'native.key.enc'
    aes_key = runtime_dir / 'native.aes.key'
    payload_enc = runtime_dir / 'native.enc'
    archive = runtime_dir / 'native.tar.gz'
    extract_dir = runtime_dir / 'extracted'
    extract_dir.mkdir(parents=True, exist_ok=True)

    key_enc.write_bytes(base64.b64decode(encrypted_key.read_text(encoding='utf-8')))
    payload_enc.write_bytes(base64.b64decode(encrypted_payload.read_text(encoding='utf-8')))
    subprocess.run(
        [
            'openssl', 'pkeyutl', '-decrypt',
            '-inkey', str(private_key),
            '-in', str(key_enc),
            '-out', str(aes_key),
            '-pkeyopt', 'rsa_padding_mode:oaep',
            '-pkeyopt', 'rsa_oaep_md:sha256',
        ],
        check=True,
    )
    subprocess.run(
        [
            'openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000',
            '-in', str(payload_enc),
            '-out', str(archive),
            '-pass', f'file:{aes_key}',
        ],
        check=True,
    )
    with tarfile.open(archive, 'r:gz') as package:
        package.extractall(extract_dir)
    native_source = extract_dir / 'kotlin/com/fx564286/cinema_seat_alert'
    for name in required_native:
        source = native_source / name
        if not source.exists() or source.stat().st_size == 0:
            raise SystemExit(f'Decrypted Android source missing: {source}')
        shutil.copy2(source, kotlin_dir / name)
    shutil.rmtree(runtime_dir)

for name in required_native:
    path = kotlin_dir / name
    if not path.exists() or path.stat().st_size == 0:
        raise SystemExit(f'Required Android source missing: {path}')

text = manifest.read_text(encoding='utf-8')
text = text.replace('android:label="cinema_seat_alert"', 'android:label="시네시트"')

permissions = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
]
for permission in permissions:
    text = re.sub(
        rf'\s*<uses-permission\s+android:name="{re.escape(permission)}"\s*/>',
        '',
        text,
    )

manifest_open = re.search(r'<manifest\b[^>]*>', text)
if manifest_open is None:
    raise SystemExit('Manifest opening tag not found')
permission_xml = ''.join(
    f'\n    <uses-permission android:name="{permission}" />'
    for permission in permissions
)
text = text[:manifest_open.end()] + permission_xml + text[manifest_open.end():]

text = re.sub(
    r'\s*<service\b[^>]*android:name="(?:\.|com\.fx564286\.cinema_seat_alert\.)SeatMonitorService"[\s\S]*?</service>',
    '',
    text,
)
text = re.sub(
    r'\s*<receiver\b[^>]*android:name="(?:\.|com\.fx564286\.cinema_seat_alert\.)BootReceiver"[\s\S]*?</receiver>',
    '',
    text,
)
components = '''
        <service
            android:name=".SeatMonitorService"
            android:enabled="true"
            android:exported="false"
            android:stopWithTask="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="User-selected cinema seat availability monitoring with a persistent notification" />
        </service>
        <receiver
            android:name=".BootReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.LOCKED_BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
'''
if '</application>' not in text:
    raise SystemExit('Application closing tag not found')
text = text.replace('</application>', components + '    </application>', 1)
manifest.write_text(text, encoding='utf-8')

final = manifest.read_text(encoding='utf-8')
required_tokens = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.WAKE_LOCK',
    'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    '.SeatMonitorService',
    '.BootReceiver',
    'android.intent.action.BOOT_COMPLETED',
]
missing = [token for token in required_tokens if token not in final]
if missing:
    raise SystemExit(f'Android manifest patch incomplete: {missing}')
print('Cineseat encrypted native sources and background components patched')
