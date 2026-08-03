from pathlib import Path
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build_app')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit(f'Manifest not found: {manifest}')

kotlin_dir = root / 'android/app/src/main/kotlin/com/fx564286/cinema_seat_alert'
for name in ('MainActivity.kt', 'SeatMonitorService.kt', 'BootReceiver.kt'):
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
print('Cineseat Android background components patched')
