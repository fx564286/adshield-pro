#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build_app')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')

permission = '    <uses-permission android:name="com.google.android.gms.permission.AD_ID" />\n'
if 'com.google.android.gms.permission.AD_ID' not in text:
    marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
    if marker not in text:
        raise SystemExit('Android manifest root marker not found')
    text = text.replace(marker, marker + permission, 1)

if 'com.google.android.gms.ads.APPLICATION_ID' not in text:
    marker = '<application\n'
    index = text.find(marker)
    if index < 0:
        raise SystemExit('Android application marker not found')
    close = text.find('>', index)
    if close < 0:
        raise SystemExit('Android application opening tag is malformed')
    metadata = (
        '\n        <meta-data\n'
        '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
        '            android:value="ca-app-pub-8431674789078471~7810960805" />'
    )
    text = text[: close + 1] + metadata + text[close + 1 :]

manifest.write_text(text, encoding='utf-8')
print('alpha36 AdMob application ID and AD_ID permission applied')
