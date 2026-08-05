# Stop after the fully patched alpha28 Dart source is assembled and copy
# only the files needed for the alpha29 fix into a short-lived artifact.
EXPORT="$ROOT/alpha28_selected_source"
rm -rf "$EXPORT"
mkdir -p "$EXPORT/lib" "$EXPORT/test"
for name in app_controller.dart models.dart home.dart services.dart official_seat_web.dart cgv_seat_bridge.dart wizard_v4.dart; do
  cp "$SOURCE/payload/lib/$name" "$EXPORT/lib/$name"
done
cp "$SOURCE/payload/test/wizard_runtime_test.dart" "$EXPORT/test/wizard_runtime_test.dart"
sha256sum "$EXPORT"/lib/*.dart "$EXPORT"/test/*.dart > "$EXPORT/SHA256SUMS.txt"
printf '%s\n' 'Exact source after alpha22-alpha28 patch chain.' > "$EXPORT/README.txt"
exit 0
