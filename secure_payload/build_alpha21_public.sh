#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
RUNTIME="$ROOT/secure_runtime"
SOURCE="$RUNTIME/source"
DELTA="$RUNTIME/delta"
NATIVE="$RUNTIME/native"
BUILD="$ROOT/build_app"
DIST="$ROOT/dist"

cleanup() {
  rm -rf "$SOURCE" "$DELTA" "$NATIVE" "$BUILD"
  rm -f "$RUNTIME"/*.aes.key "$RUNTIME"/*.key.enc \
    "$RUNTIME"/*.enc "$RUNTIME"/*.tar.gz "$RUNTIME"/*.tar.xz
}
trap cleanup EXIT

mkdir -p "$SOURCE" "$DELTA" "$NATIVE" "$DIST"
test -s "$RUNTIME/private.pem"

# Decrypt the last stable alpha.19 source archive.
base64 --decode secure_payload/key.enc.b64 > "$RUNTIME/source.key.enc"
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/source.key.enc" \
  -out "$RUNTIME/source.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
cat secure_payload/source.enc.b64.part* | base64 --decode > "$RUNTIME/source.enc"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/source.enc" \
  -out "$RUNTIME/source.tar.gz" \
  -pass file:"$RUNTIME/source.aes.key"
tar -xzf "$RUNTIME/source.tar.gz" -C "$SOURCE"
test -s "$SOURCE/payload/lib/wizard_v4.dart"
test -s "$SOURCE/payload/test/wizard_runtime_test.dart"

# Reassemble and validate the encrypted alpha.21 delta.
base64 --decode secure_payload/alpha21-delta.key.enc.b64 \
  > "$RUNTIME/delta.key.enc"
printf '%s  %s\n' \
  '29ec18b89fc2da145533c997df6d1fba14b5284c11b0b060d2e062e9f0c31a26' \
  "$RUNTIME/delta.key.enc" | sha256sum -c -
openssl pkeyutl -decrypt \
  -inkey "$RUNTIME/private.pem" \
  -in "$RUNTIME/delta.key.enc" \
  -out "$RUNTIME/delta.aes.key" \
  -pkeyopt rsa_padding_mode:oaep \
  -pkeyopt rsa_oaep_md:sha256
cat secure_payload/alpha21-delta.enc.b64.part* \
  | base64 --decode > "$RUNTIME/delta.enc"
printf '%s  %s\n' \
  '8553476b7fe8c7073e86b6cf042713122526aff2050ead8e10a3662a7b0b1442' \
  "$RUNTIME/delta.enc" | sha256sum -c -
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$RUNTIME/delta.enc" \
  -out "$RUNTIME/delta.tar.xz" \
  -pass file:"$RUNTIME/delta.aes.key"
tar -xJf "$RUNTIME/delta.tar.xz" -C "$DELTA"

cd "$SOURCE/payload"
patch -p1 < "$DELTA/delta/alpha21.diff"
cp "$DELTA/delta/app_icon.png" app_icon.png
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
root = Path('secure_runtime/source/payload')
wizard = (root / 'lib/wizard_v4.dart').read_text(encoding='utf-8')
controller = (root / 'lib/app_controller.dart').read_text(encoding='utf-8')
home = (root / 'lib/home.dart').read_text(encoding='utf-8')
required = [
    'class WatchWizard',
    'this.initialItem',
    "String _districtFilter = '전체';",
    "Key('region_filter_panel')",
    "Key('district_filter_wrap')",
    "'서울'",
    "'강남구'",
]
missing = [token for token in required if token not in wizard]
if missing:
    raise SystemExit(f'alpha21 wizard verification failed: {missing}')
if 'BackgroundMonitor.syncWatches(items)' not in controller:
    raise SystemExit('stable BackgroundMonitor synchronization is missing')
if 'WatchWizard(' not in home:
    raise SystemExit('stable WatchWizard entry is missing')
all_dart = '\n'.join(
    path.read_text(encoding='utf-8') for path in (root / 'lib').rglob('*.dart')
)
if "'기타'" in all_dart or "return '기타'" in all_dart:
    raise SystemExit('user-visible 기타 region remains')
if 'class NewWatchWizard' in all_dart or 'class EditWatchWizard' in all_dart:
    raise SystemExit('broken alpha20 split watch flow remains')
print('alpha21 stable watch and district region source verified')
PY

# Decrypt the Android foreground monitor and boot receiver.
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
tar -xzf "$RUNTIME/native.tar.gz" -C "$NATIVE"
for name in MainActivity.kt SeatMonitorService.kt BootReceiver.kt; do
  test -s "$NATIVE/kotlin/com/fx564286/cinema_seat_alert/$name"
done

rm -rf "$BUILD" "$DIST"
mkdir -p "$DIST"
flutter create --platforms=android \
  --org com.fx564286 \
  --project-name cinema_seat_alert "$BUILD"
rm -rf "$BUILD/lib" "$BUILD/test"
cp -R "$SOURCE/payload/lib" "$BUILD/lib"
cp -R "$SOURCE/payload/test" "$BUILD/test"
printf "export 'wizard_v4.dart';\n" > "$BUILD/lib/wizard.dart"

cat > "$BUILD/pubspec.yaml" <<'PUBSPEC'
name: cinema_seat_alert
description: Cineseat alpha21 stable seat watch and district regions
publish_to: none
version: 0.2.1-alpha.21+41

environment:
  sdk: ">=3.10.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  geolocator: ^14.0.3
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
cp "$NATIVE/kotlin/com/fx564286/cinema_seat_alert/MainActivity.kt" "$KOTLIN_DIR/"
cp "$NATIVE/kotlin/com/fx564286/cinema_seat_alert/SeatMonitorService.kt" "$KOTLIN_DIR/"
cp "$NATIVE/kotlin/com/fx564286/cinema_seat_alert/BootReceiver.kt" "$KOTLIN_DIR/"
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' \
  "$BUILD/android/app/build.gradle.kts"
python3 secure_payload/patch_cineseat_android.py "$BUILD"
for dir in "$BUILD"/android/app/src/main/res/mipmap-*; do
  cp "$SOURCE/payload/app_icon.png" "$dir/ic_launcher.png"
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
flutter test test/wizard_runtime_test.dart --reporter expanded
flutter build apk --release --no-pub \
  --build-name=0.2.1-alpha.21 \
  --build-number=41
cd "$ROOT"

APK="$DIST/cineseat-0.2.1-alpha.21-VALIDATION.apk"
cp "$BUILD/build/app/outputs/flutter-apk/app-release.apk" "$APK"
TOOLS="$(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
test -s "$APK"
unzip -t "$APK"
"$TOOLS/zipalign" -c -v 4 "$APK"
"$TOOLS/apksigner" verify --verbose --print-certs "$APK" | tee "$DIST/APK-SIGNATURE.txt"
"$TOOLS/aapt" dump badging "$APK" | tee "$DIST/APK-PACKAGE-INFO.txt"
"$TOOLS/aapt" dump permissions "$APK" | tee "$DIST/APK-PERMISSIONS.txt"
"$TOOLS/aapt" dump xmltree "$APK" AndroidManifest.xml | tee "$DIST/APK-MANIFEST.txt"
grep -q "package: name='com.fx564286.cinema_seat_alert'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionCode='41'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q "versionName='0.2.1-alpha.21'" "$DIST/APK-PACKAGE-INFO.txt"
grep -q 'android.permission.POST_NOTIFICATIONS' "$DIST/APK-PERMISSIONS.txt"
grep -q 'android.permission.WAKE_LOCK' "$DIST/APK-PERMISSIONS.txt"
grep -q 'android.permission.FOREGROUND_SERVICE_SPECIAL_USE' "$DIST/APK-PERMISSIONS.txt"
grep -q 'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS' "$DIST/APK-PERMISSIONS.txt"
grep -q 'android.permission.RECEIVE_BOOT_COMPLETED' "$DIST/APK-PERMISSIONS.txt"
grep -q 'SeatMonitorService' "$DIST/APK-MANIFEST.txt"
grep -q 'BootReceiver' "$DIST/APK-MANIFEST.txt"
cp "$TOOLS/lib/apksigner.jar" "$DIST/apksigner.jar"
cp "$TOOLS/zipalign" "$DIST/zipalign"
chmod +x "$DIST/zipalign"
sha256sum "$APK" | tee "$DIST/SHA256SUMS.txt"
cat > "$DIST/BUILD_REPORT.txt" <<'REPORT'
Cineseat 0.2.1-alpha.21 validation build
- stable alpha.19 WatchWizard create/edit/save flow restored
- broken alpha.20 split watch flow absent
- province and city/county/district region selector
- no user-visible 기타 region
- dedicated cinema seat launcher icon
- foreground seat monitor and boot recovery included
REPORT
