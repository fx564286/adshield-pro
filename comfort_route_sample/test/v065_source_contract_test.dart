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
    expect(source, contains('final guidanceGeneration = ++_guidanceRouteGeneration;'));
  });

  test('guidance uses OSRM route-distance scale after GPS filtering', () {
    expect(source, contains('position.accuracy > _maxNavigationAccuracyMeters'));
    expect(source, contains('final traveledRouteMeters = routeTotal * progress;'));
    expect(
      source,
      contains('_updateGuidanceForAlongMeters(traveledRouteMeters, allowVoice: !isOffRoute);'),
    );
  });

  test('voice guidance serializes speech and rejects stale route calls', () {
    expect(source, contains('bool _ttsSpeakInFlight = false;'));
    expect(source, contains('int _guidanceRouteGeneration = 0;'));
    expect(source, contains('if (_ttsSpeakInFlight) return;'));
    expect(source, contains('generation != _guidanceRouteGeneration'));
    expect(source, contains('Future<void> _restartGuidanceForActivatedRoute'));
    expect(source, contains('Future<void> _stopTtsSilently() async'));
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
