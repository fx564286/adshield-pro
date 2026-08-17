from pathlib import Path

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# Review finding 1: OSRM maneuver distances are accumulated from RouteStep
# distances, while projection.alongMeters is geometry length. Use the same
# route-distance scale as the maneuvers to avoid drift on long routes.
old_progress = '''    _updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);
'''
new_progress = '''    final traveledRouteMeters = routeTotal * progress;
    _updateGuidanceForAlongMeters(traveledRouteMeters, allowVoice: !isOffRoute);
'''
if old_progress not in s:
    raise SystemExit('guidance progress scale anchor missing')
s = s.replace(old_progress, new_progress, 1)

# Review finding 2: repeated GPS samples can enter the async TTS call before the
# previous call records its spoken stage. Serialize TTS speech requests.
field_anchor = '''  String? _lastSpokenManeuverKey;
  int _lastSpokenSpeechStage = 0;
'''
field_new = field_anchor + '''  bool _ttsSpeakInFlight = false;
'''
if field_anchor not in s:
    raise SystemExit('tts in-flight field anchor missing')
s = s.replace(field_anchor, field_new, 1)

# Use a Future<void> helper so dart:async unawaited receives the correct type.
old_tracking_stop = "    if (!_isWidgetTest) unawaited(_ttsChannel.invokeMethod<bool>('stop').catchError((_) => false));\n"
new_tracking_stop = "    if (!_isWidgetTest) unawaited(_stopTtsSilently());\n"
if old_tracking_stop not in s:
    raise SystemExit('tracking TTS stop anchor missing')
s = s.replace(old_tracking_stop, new_tracking_stop, 1)

old_speak = r'''  Future<void> _speakGuidance(RouteManeuver maneuver, double distanceMeters, int stage) async {
    final key = maneuver.stableKey;
    if (_lastSpokenManeuverKey == key && stage <= _lastSpokenSpeechStage) return;
    if (!_ttsReady) {
      await _refreshTtsStatus();
      if (!_ttsReady) return;
    }
    if (!_tracking || !_voiceGuidanceEnabled || _isWidgetTest) return;
    final text = guidanceSpeechText(maneuver, distanceMeters);
    try {
      final ok = await _ttsChannel.invokeMethod<bool>('speak', <String, Object?>{'text': text}) ?? false;
      if (!ok) return;
      _lastSpokenManeuverKey = key;
      _lastSpokenSpeechStage = stage;
      _log('음성 안내 · $text');
    } catch (error) {
      if (mounted) setState(() => _ttsReady = false);
      _log('음성 안내 오류: $error');
    }
  }
'''
new_speak = r'''  Future<void> _stopTtsSilently() async {
    if (_isWidgetTest) return;
    try {
      await _ttsChannel.invokeMethod<bool>('stop');
    } catch (_) {}
  }

  Future<void> _speakGuidance(RouteManeuver maneuver, double distanceMeters, int stage) async {
    final key = maneuver.stableKey;
    if (_ttsSpeakInFlight) return;
    if (_lastSpokenManeuverKey == key && stage <= _lastSpokenSpeechStage) return;
    _ttsSpeakInFlight = true;
    try {
      if (!_ttsReady) {
        await _refreshTtsStatus();
        if (!_ttsReady) return;
      }
      if (!_tracking || !_voiceGuidanceEnabled || _isWidgetTest) return;
      if (_activeManeuver?.stableKey != key) return;
      final text = guidanceSpeechText(maneuver, distanceMeters);
      final ok = await _ttsChannel.invokeMethod<bool>('speak', <String, Object?>{'text': text}) ?? false;
      if (!ok) return;
      if (_activeManeuver?.stableKey != key || !_tracking || !_voiceGuidanceEnabled) {
        await _stopTtsSilently();
        return;
      }
      _lastSpokenManeuverKey = key;
      _lastSpokenSpeechStage = stage;
      _log('음성 안내 · $text');
    } catch (error) {
      if (mounted) setState(() => _ttsReady = false);
      _log('음성 안내 오류: $error');
    } finally {
      _ttsSpeakInFlight = false;
    }
  }
'''
if old_speak not in s:
    raise SystemExit('speak method anchor missing')
s = s.replace(old_speak, new_speak, 1)

# Review finding 3: switching alternatives can leave an already-playing old
# instruction audible. Stop platform speech immediately after route activation.
activate_tail = '''    });
    final position = _position;
    if (position != null) _updateNavigationProgress(position);
'''
activate_tail_new = '''    });
    if (!_isWidgetTest) unawaited(_stopTtsSilently());
    final position = _position;
    if (position != null) _updateNavigationProgress(position);
'''
if activate_tail not in s:
    raise SystemExit('route activation tail anchor missing')
s = s.replace(activate_tail, activate_tail_new, 1)

required = [
    'final traveledRouteMeters = routeTotal * progress;',
    'bool _ttsSpeakInFlight = false;',
    'Future<void> _stopTtsSilently() async',
    'if (_activeManeuver?.stableKey != key) return;',
    'if (!_isWidgetTest) unawaited(_stopTtsSilently());',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v065 review fix marker: {marker}')

p.write_text(s)
print('FIX_V065_REVIEW_FINDINGS: PASS')
