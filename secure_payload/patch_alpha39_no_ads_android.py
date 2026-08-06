#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')

text = re.sub(
    r'\s*<uses-permission\s+android:name="com\.google\.android\.gms\.permission\.AD_ID"\s*/>\s*',
    '\n',
    text,
)
text = re.sub(
    r'\s*<meta-data\s+android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"\s+android:value="[^"]+"\s*/>\s*',
    '\n',
    text,
)

for forbidden in (
    'com.google.android.gms.permission.AD_ID',
    'com.google.android.gms.ads.APPLICATION_ID',
    'ca-app-pub-',
):
    if forbidden in text:
        raise SystemExit(f'alpha39 Android manifest still contains {forbidden}')

manifest.write_text(text, encoding='utf-8')
print('alpha39 AdMob manifest metadata and AD_ID permission removed')
