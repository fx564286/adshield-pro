#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
SOURCE=/tmp/exported_alpha35
PATCH=/tmp/apply_alpha36_direct_admob.patch
BUILD="$ROOT/build_app"
DIST="$ROOT/dist"
RUNTIME="$ROOT/secure_runtime"

for file in \
  "$SOURCE/lib/wizard_v4.dart" \
  "$SOURCE/lib/services.dart" \
  "$SOURCE/lib/ads.dart" \
  "$PATCH" \
  /tmp/patch_alpha36_android.py; do
  test -s "$file"
done

echo '680f89dd32f4ee7cb72df8a4d50542042e175b7e3b91f62b92d17e7985708e84  /tmp/apply_alpha36_direct_admob.patch' | sha256sum -c -
(cd "$SOURCE" && patch --batch --forward -p1 < "$PATCH")

python3 - "$SOURCE" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for path in (root / 'lib').glob('*.dart'):
    text = path.read_text(encoding='utf-8')
    text = text.replace('0.2.1-alpha.35', '0.2.1-alpha.36')
    path.write_text(text, encoding='utf-8')

checks = {
    'services': [
        '/cnm/atkt/searchIfSeatDataK',
        '/cnm/atkt/searchIfSeatData',
        '홈페이지를 열지 않고 새로고침으로 다시 시도해 주세요.',
    ],
    'ads': [
        'BannerAd(',
        'RewardedAd.load(',
        'InterstitialAd.load(',
    ],
    'home': ['maybeShowInterstitial()'],
    'wizard': ['CinemaChain.megabox &&'],
}
files = {
    'services': root / 'lib/services.dart',
    'ads': root / 'lib/ads.dart',
    'home': root / 'lib/home.dart',
    'wizard': root / 'lib/wizard_v4.dart',
}
missing = {
    key: [token for token in tokens if token not in files[key].read_text(encoding='utf-8')]
    for key, tokens in checks.items()
    if any(token not in files[key].read_text(encoding='utf-8') for token in tokens)
}
if missing:
    raise SystemExit(f'alpha36 exact source contract failed: {missing}')
print('alpha36 exact source patch verified')
PY

mkdir -p "$RUNTIME/native"
base64 --decode secure_payload/native.key.enc.b64 > "$RUNTIME/native.key.enc"
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/native.key.enc" \
  -out "$RUNTIME/native.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
base64 --decode secure_payload/native.enc.b64 > "$RUNTIME/native.enc"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/native.enc" \
  -out "$RUNTIME/native.tar.gz" \
  -pass file:"$RUNTIME/native.aes.key"
tar -xzf "$RUNTIME/native.tar.gz" -C "$RUNTIME/native"

rm -rf "$BUILD" "$DIST"
mkdir -p "$DIST"
flutter create --platforms=android \
  --org com.fx564286 \
  --project-name cinema_seat_alert "$BUILD"
rm -rf "$BUILD/lib" "$BUILD/test"
cp -R "$SOURCE/lib" "$BUILD/lib"
cp -R "$SOURCE/test" "$BUILD/test"
printf "export 'wizard_v4.dart';\n" > "$BUILD/lib/wizard.dart"

cat > "$BUILD/pubspec.yaml" <<'PUBSPEC'
name: cinema_seat_alert
description: Cineseat alpha36 CGV direct seats and AdMob validation
publish_to: none
version: 0.2.1-alpha.36+56

environment:
  sdk: ">=3.10.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  crypto: ^3.0.7
  cupertino_icons: ^1.0.8
  geolocator: ^14.0.3
  google_mobile_ads: ^9.0.0
  http: ^1.4.0
  shared_preferences: ^2.5.5
  url_launcher: ^6.3.2
  webview_flutter: ^4.14.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
PUBSPEC

KOTLIN_DIR="$BUILD/android/app/src/main/kotlin/com/fx564286/cinema_seat_alert"
mkdir -p "$KOTLIN_DIR"
for name in MainActivity.kt SeatMonitorService.kt BootReceiver.kt; do
  cp "$RUNTIME/native/kotlin/com/fx564286/cinema_seat_alert/$name" "$KOTLIN_DIR/"
done
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' \
  "$BUILD/android/app/build.gradle.kts"
python3 secure_payload/patch_cineseat_android.py "$BUILD"
python3 /tmp/patch_alpha36_android.py "$BUILD"

for dir in "$BUILD"/android/app/src/main/res/mipmap-*; do
  cp "$SOURCE/app_icon.png" "$dir/ic_launcher.png"
done
cat >> "$BUILD/android/gradle.properties" <<'GRADLE'
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G -Dfile.encoding=UTF-8
kotlin.incremental=true
android.useAndroidX=true
GRADLE

cd "$BUILD"
flutter pub get
dart format lib test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter expanded
flutter build apk --release --no-pub \
  --build-name=0.2.1-alpha.36 \
  --build-number=56
cd "$ROOT"

APK="$DIST/cineseat-0.2.1-alpha.36-fixed.apk"
UNSIGNED="$DIST/cineseat-0.2.1-alpha.36-unsigned.apk"
cp "$BUILD/build/app/outputs/flutter-apk/app-release.apk" "$UNSIGNED"
test -s "$UNSIGNED"
unzip -tq "$UNSIGNED"

base64 --decode secure_payload/cineseat-release.aes.key.enc.b64 \
  > "$RUNTIME/cineseat-release.aes.key.enc"
echo '8eb3210c6a037703ae5f29303ba7cc9b051e338434ae261dabb14779111d3909  secure_runtime/cineseat-release.aes.key.enc' | sha256sum -c -
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/cineseat-release.aes.key.enc" \
  -out "$RUNTIME/cineseat-release.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
base64 --decode secure_payload/cineseat-release.p12.enc.b64 \
  > "$RUNTIME/cineseat-release.p12.enc"
echo '9696b12c5690244d8fdadc955cf238b3d90361b984e0ed7ab22a12ed3ad894cf  secure_runtime/cineseat-release.p12.enc' | sha256sum -c -
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/cineseat-release.p12.enc" \
  -out "$RUNTIME/cineseat-release.p12" \
  -pass file:"$RUNTIME/cineseat-release.aes.key"

TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
"$TOOLS/apksigner" sign \
  --ks "$RUNTIME/cineseat-release.p12" \
  --ks-type PKCS12 \
  --ks-key-alias cineseat \
  --ks-pass pass:cineseat-fixed-2026 \
  --key-pass pass:cineseat-fixed-2026 \
  --v1-signing-enabled false \
  --v2-signing-enabled true \
  --v3-signing-enabled false \
  --out "$APK" "$UNSIGNED"
rm -f "$UNSIGNED"

"$TOOLS/zipalign" -c -v 4 "$APK"
"$TOOLS/aapt" dump badging "$APK" | tee "$DIST/APK-PACKAGE-INFO.txt"
"$TOOLS/apksigner" verify --verbose --print-certs "$APK" | tee "$DIST/APK-SIGNATURE.txt"
"$TOOLS/aapt" dump permissions "$APK" | tee "$DIST/APK-PERMISSIONS.txt"
"$TOOLS/aapt" dump xmltree "$APK" AndroidManifest.xml | tee "$DIST/APK-MANIFEST.txt"
sha256sum "$APK" | tee "$DIST/SHA256SUMS.txt"
unzip -tq "$APK"

grep -q 'com.google.android.gms.permission.AD_ID' "$DIST/APK-PERMISSIONS.txt"
grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$DIST/APK-MANIFEST.txt"
grep -q 'ca-app-pub-8431674789078471~7810960805' "$DIST/APK-MANIFEST.txt"
grep -q "package: name='com.fx564286.cinema_seat_alert'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionCode='56'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionName='0.2.1-alpha.36'" "$DIST/APK-PACKAGE-INFO.txt"
grep -qi 'f8954ba293629909345ca7a0ae42198bfb0a6b568e1cf5384ecb9c7a3e18edd4' "$DIST/APK-SIGNATURE.txt"
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' "$DIST/APK-SIGNATURE.txt"

cat > "$DIST/BUILD_REPORT.txt" <<'REPORT'
Cineseat 0.2.1-alpha.36 build report
- exact alpha35 successfully built source was reconstructed before patching
- all Flutter runtime tests passed
- CGV direct API tries searchIfSeatDataK POST/GET then searchIfSeatData GET
- anonymous request is attempted before any optional issued customer number
- CGV seat failure does not automatically start the official homepage or login WebView
- flexible CGV response aliases, duplicate filtering, coordinates and aisle spacing are parsed
- Google Mobile Ads SDK is compiled and initialized independently of seat monitoring
- bottom banner, rewarded slot bonus and every-third-watch interstitial are enabled
- Google official test ad unit IDs are used in this validation APK
- production AdMob application ID is present in AndroidManifest
- exact alpha35 permanent signing identity is retained for overwrite installation
REPORT

rm -f \
  "$RUNTIME/native.aes.key" \
  "$RUNTIME/native.tar.gz" \
  "$RUNTIME/cineseat-release.aes.key" \
  "$RUNTIME/cineseat-release.p12"
