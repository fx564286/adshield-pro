import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String activity;
  late String manifest;

  setUpAll(() {
    source = File('lib/main.dart').readAsStringSync();
    activity = File('android/app/src/main/kotlin/com/fx564286/comfort_route_sample/MainActivity.kt')
        .readAsStringSync();
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('OSRM route steps are parsed into immutable maneuver data', () {
    expect(source, contains("final rawManeuver = rawStep['maneuver'];"));
    expect(source, contains('distanceFromStartMeters: maneuverDistance'));
    expect(source, contains('maneuvers: List<RouteManeuver>.unmodifiable(maneuvers)'));
  });

  test('selected route atomically owns selected maneuver list', () {
    expect(source, contains('_routeManeuvers = route.maneuvers;'));
    expect(source, contains('_lastSpokenManeuverKey = null;'));
  });

  test('guidance only hooks after normal route progress filtering', () {
    expect(
      source,
      contains('_updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);'),
    );
    expect(source, contains('position.accuracy > _maxNavigationAccuracyMeters'));
  });

  test('voice guidance uses a dedicated platform channel and can be disabled', () {
    expect(source, contains("MethodChannel('comfort_route/navigation_tts')"));
    expect(source, contains('_voiceGuidanceEnabled'));
    expect(source, contains("invokeMethod<bool>('stop')"));
  });

  test('Android bridge releases TTS resources', () {
    expect(activity, contains('TextToSpeech'));
    expect(activity, contains('textToSpeech?.shutdown()'));
    expect(activity, contains('Locale.KOREAN'));
  });

  test('Android manifest declares TTS service query for Android 11+', () {
    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
  });
}
