#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build_app')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')

root_marker = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
root_with_tools = (
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    xmlns:tools="http://schemas.android.com/tools">'
)
if 'xmlns:tools="http://schemas.android.com/tools"' not in text:
    if root_marker not in text:
        raise SystemExit('Android manifest root marker not found for tools namespace')
    text = text.replace(root_marker, root_with_tools, 1)

application_end = '</application>'
if application_end not in text:
    raise SystemExit('Android application end marker not found')

safe_entries = '''
        <!--
          Google Mobile Ads normally installs this ContentProvider and starts
          before Flutter renders its first frame. On affected devices that
          process-level initialization can terminate the app before Dart can
          apply any delayed or guarded initialization. Remove only the
          automatic provider; MobileAds.initialize() remains available and is
          called manually after the app is visible.
        -->
        <provider
            android:name="com.google.android.gms.ads.MobileAdsInitProvider"
            tools:node="remove" />
        <meta-data
            android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION"
            android:value="false"
            tools:replace="android:value" />
        <meta-data
            android:name="com.google.android.gms.ads.flag.OPTIMIZE_AD_LOADING"
            android:value="false"
            tools:replace="android:value" />
'''

if 'tools:node="remove"' not in text or 'MobileAdsInitProvider' not in text:
    text = text.replace(application_end, safe_entries + '    ' + application_end, 1)

manifest.write_text(text, encoding='utf-8')
print('alpha38 removed pre-Flutter MobileAdsInitProvider auto initialization')
