from pathlib import Path

p = Path('/tmp/comfort_route_build/lib/main.dart')
s = p.read_text()

# v0.6.5: use OSRM step maneuvers for real turn-by-turn guidance and bridge
# Korean Android TextToSpeech through a small MethodChannel.
route_import = "import 'package:comfort_route_sample/route_mode_logic.dart';\n"
if route_import not in s:
    raise SystemExit('route mode import missing')
s = s.replace(
    route_import,
    route_import + "import 'package:comfort_route_sample/navigation_guidance.dart';\n",
    1,
)
s = s.replace(
    'ComfortRoute/0.6.4 (com.fx564286.comfort_route_sample)',
    'ComfortRoute/0.6.5 (com.fx564286.comfort_route_sample)',
    1,
)

# Each alternative owns its maneuver list so switching route preference cannot
# accidentally keep instructions from the previously selected geometry.
ctor_anchor = '''    required this.comfortSignalHits,
    required this.shelterSignalHits,
  });'''
ctor_new = '''    required this.comfortSignalHits,
    required this.shelterSignalHits,
    required this.maneuvers,
  });'''
if ctor_anchor not in s:
    raise SystemExit('route alternative constructor anchor missing')
s = s.replace(ctor_anchor, ctor_new, 1)

field_anchor = '''  final int comfortSignalHits;
  final int shelterSignalHits;

  RouteScoreInput get scoreInput'''
field_new = '''  final int comfortSignalHits;
  final int shelterSignalHits;
  final List<RouteManeuver> maneuvers;

  RouteScoreInput get scoreInput'''
if field_anchor not in s:
    raise SystemExit('route alternative field anchor missing')
s = s.replace(field_anchor, field_new, 1)

state_anchor = '''  bool _vectorFallbackUsed = false;
'''
state_new = state_anchor + '''  static const MethodChannel _ttsChannel = MethodChannel('comfort_route/navigation_tts');
  List<RouteManeuver> _routeManeuvers = const <RouteManeuver>[];
  int? _activeManeuverIndex;
  double? _distanceToNextManeuverMeters;
  bool _voiceGuidanceEnabled = true;
  bool _ttsReady = false;
  String? _lastSpokenManeuverKey;
  int _lastSpokenSpeechStage = 0;
'''
if state_anchor not in s:
    raise SystemExit('v064 state anchor missing')
s = s.replace(state_anchor, state_new, 1)

# Put the active instruction between map and journey card. It remains compact
# and disappears entirely when route steps are unavailable.
map_anchor = '''              Expanded(child: _buildRealMap()),
              const SizedBox(height: AppSpace.sm),
              _buildMapBottomCard(compact: compact),'''
map_new = '''              Expanded(child: _buildRealMap()),
              if (_activeManeuverIndex != null) ...[
                const SizedBox(height: AppSpace.xs),
                _buildGuidanceBanner(),
              ],
              const SizedBox(height: AppSpace.sm),
              _buildMapBottomCard(compact: compact),'''
if map_anchor not in s:
    raise SystemExit('map guidance insertion anchor missing')
s = s.replace(map_anchor, map_new, 1)

search_anchor = '  Widget _buildSearchHeader() {\n'
guidance_methods = r'''  RouteManeuver? get _activeManeuver {
    final index = _activeManeuverIndex;
    if (index == null || index < 0 || index >= _routeManeuvers.length) return null;
    return _routeManeuvers[index];
  }

  Widget _buildGuidanceBanner() {
    final maneuver = _activeManeuver;
    final distance = _distanceToNextManeuverMeters;
    if (maneuver == null || distance == null) return const SizedBox.shrink();
    final direction = guidanceDirection(maneuver);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 9, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(_guidanceIcon(direction), color: AppColors.primaryDeep, size: 23),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guidanceDisplayText(maneuver, distance),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _tracking ? '실시간 안내 중' : '추적을 시작하면 회전 음성 안내가 재생됩니다.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w650,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _voiceGuidanceEnabled ? '음성 안내 끄기' : '음성 안내 켜기',
            onPressed: _toggleVoiceGuidance,
            icon: Icon(
              _voiceGuidanceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _voiceGuidanceEnabled ? AppColors.primaryDeep : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _guidanceIcon(GuidanceDirection direction) {
    switch (direction) {
      case GuidanceDirection.depart:
        return Icons.navigation_rounded;
      case GuidanceDirection.arrive:
        return Icons.flag_rounded;
      case GuidanceDirection.straight:
        return Icons.arrow_upward_rounded;
      case GuidanceDirection.slightLeft:
      case GuidanceDirection.left:
      case GuidanceDirection.sharpLeft:
        return Icons.arrow_back_rounded;
      case GuidanceDirection.slightRight:
      case GuidanceDirection.right:
      case GuidanceDirection.sharpRight:
        return Icons.arrow_forward_rounded;
      case GuidanceDirection.uTurn:
      case GuidanceDirection.roundabout:
        return Icons.sync_rounded;
      case GuidanceDirection.forkLeft:
      case GuidanceDirection.forkRight:
        return Icons.call_split_rounded;
      case GuidanceDirection.mergeLeft:
      case GuidanceDirection.mergeRight:
        return Icons.merge_type_rounded;
      case GuidanceDirection.unknown:
        return Icons.alt_route_rounded;
    }
  }

  Future<void> _toggleVoiceGuidance() async {
    final enabled = !_voiceGuidanceEnabled;
    if (mounted) setState(() => _voiceGuidanceEnabled = enabled);
    if (!enabled) {
      try {
        if (!_isWidgetTest) await _ttsChannel.invokeMethod<bool>('stop');
      } catch (error) {
        _log('음성 안내 중지 오류: $error');
      }
      _log('회전 음성 안내 끔');
      return;
    }
    _lastSpokenManeuverKey = null;
    _lastSpokenSpeechStage = 0;
    await _refreshTtsStatus();
    _log(_ttsReady ? '회전 음성 안내 켬 · 한국어 TTS 준비' : '회전 음성 안내 켬 · TTS 준비 대기');
  }

  Future<void> _refreshTtsStatus() async {
    if (_isWidgetTest) return;
    try {
      final ready = await _ttsChannel.invokeMethod<bool>('status') ?? false;
      if (mounted && ready != _ttsReady) setState(() => _ttsReady = ready);
    } catch (error) {
      if (mounted && _ttsReady) setState(() => _ttsReady = false);
      _log('TTS 상태 확인 오류: $error');
    }
  }

  void _updateGuidanceForAlongMeters(double alongMeters, {required bool allowVoice}) {
    final target = selectNextGuidance(_routeManeuvers, alongMeters);
    if (target == null) {
      if (_activeManeuverIndex != null && mounted) {
        setState(() {
          _activeManeuverIndex = null;
          _distanceToNextManeuverMeters = null;
        });
      }
      return;
    }

    final changed = _activeManeuverIndex != target.index;
    final distanceChanged = _distanceToNextManeuverMeters == null ||
        (_distanceToNextManeuverMeters! - target.distanceMeters).abs() >= 2;
    if ((changed || distanceChanged) && mounted) {
      setState(() {
        _activeManeuverIndex = target.index;
        _distanceToNextManeuverMeters = target.distanceMeters;
      });
    }
    if (changed) {
      _lastSpokenManeuverKey = null;
      _lastSpokenSpeechStage = 0;
    }

    if (!allowVoice || !_tracking || !_voiceGuidanceEnabled) return;
    final passedBy = alongMeters - target.maneuver.distanceFromStartMeters;
    if (passedBy > 4) return;
    final stage = guidanceSpeechStage(target.distanceMeters);
    if (stage <= 0) return;
    unawaited(_speakGuidance(target.maneuver, target.distanceMeters, stage));
  }

  Future<void> _speakGuidance(RouteManeuver maneuver, double distanceMeters, int stage) async {
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
if search_anchor not in s:
    raise SystemExit('search method anchor missing')
s = s.replace(search_anchor, guidance_methods + search_anchor, 1)

# Parse OSRM RouteStep / StepManeuver into immutable guidance data. The running
# step-distance sum becomes each maneuver's distance from route start.
step_anchor = '''        var maneuverCount = 0;
        final legs = route['legs'] as List<dynamic>? ?? const <dynamic>[];
        for (final rawLeg in legs) {
          if (rawLeg is! Map<String, dynamic>) continue;
          maneuverCount += (rawLeg['steps'] as List<dynamic>?)?.length ?? 0;
        }
'''
step_new = '''        var maneuverCount = 0;
        var maneuverDistance = 0.0;
        final maneuvers = <RouteManeuver>[];
        final legs = route['legs'] as List<dynamic>? ?? const <dynamic>[];
        for (final rawLeg in legs) {
          if (rawLeg is! Map<String, dynamic>) continue;
          final steps = rawLeg['steps'] as List<dynamic>? ?? const <dynamic>[];
          maneuverCount += steps.length;
          for (final rawStep in steps) {
            if (rawStep is! Map<String, dynamic>) continue;
            final stepDistance = (rawStep['distance'] as num?)?.toDouble() ?? 0.0;
            final stepDuration = (rawStep['duration'] as num?)?.toDouble() ?? 0.0;
            final rawManeuver = rawStep['maneuver'];
            if (rawManeuver is Map<String, dynamic>) {
              final rawLocation = rawManeuver['location'];
              if (rawLocation is List && rawLocation.length >= 2 &&
                  rawLocation[0] is num && rawLocation[1] is num) {
                maneuvers.add(RouteManeuver(
                  latitude: (rawLocation[1] as num).toDouble(),
                  longitude: (rawLocation[0] as num).toDouble(),
                  distanceFromStartMeters: maneuverDistance,
                  stepDistanceMeters: stepDistance,
                  durationSeconds: stepDuration,
                  type: '${rawManeuver['type'] ?? 'turn'}',
                  modifier: '${rawManeuver['modifier'] ?? ''}',
                  roadName: '${rawStep['name'] ?? ''}',
                  exitNumber: rawManeuver['exit'] is num ? (rawManeuver['exit'] as num).toInt() : null,
                ));
              }
            }
            maneuverDistance += stepDistance;
          }
        }
'''
if step_anchor not in s:
    raise SystemExit('OSRM step parse anchor missing')
s = s.replace(step_anchor, step_new, 1)

candidate_anchor = '''          comfortSignalHits: comfortSignals,
          shelterSignalHits: shelterSignals,
        );'''
candidate_new = '''          comfortSignalHits: comfortSignals,
          shelterSignalHits: shelterSignals,
          maneuvers: List<RouteManeuver>.unmodifiable(maneuvers),
        );'''
if candidate_anchor not in s:
    raise SystemExit('route candidate maneuver anchor missing')
s = s.replace(candidate_anchor, candidate_new, 1)

# Switching alternatives must switch its instruction list atomically with route
# geometry and reset voice-stage state.
activate_anchor = '''      _routeDistanceMeters = route.distanceMeters;
      _routeDurationSeconds = route.durationSeconds;
      _routeProgress = null;'''
activate_new = '''      _routeDistanceMeters = route.distanceMeters;
      _routeDurationSeconds = route.durationSeconds;
      _routeManeuvers = route.maneuvers;
      _activeManeuverIndex = null;
      _distanceToNextManeuverMeters = null;
      _lastSpokenManeuverKey = null;
      _lastSpokenSpeechStage = 0;
      _routeProgress = null;'''
if activate_anchor not in s:
    raise SystemExit('route activation guidance anchor missing')
s = s.replace(activate_anchor, activate_new, 1)

# Both destination-change and route-error clears must also clear instructions.
reset_marker = '''      _selectedAlternativeSourceIndex = null;
'''
reset_count = s.count(reset_marker)
if reset_count < 2:
    raise SystemExit(f'expected >=2 route reset markers, found {reset_count}')
reset_replacement = reset_marker + '''      _routeManeuvers = const <RouteManeuver>[];
      _activeManeuverIndex = null;
      _distanceToNextManeuverMeters = null;
      _lastSpokenManeuverKey = null;
      _lastSpokenSpeechStage = 0;
'''
s = s.replace(reset_marker, reset_replacement, 2)

# Navigation progress already rejects low-accuracy GPS before reaching this hook.
progress_anchor = '''    if (isOffRoute && nextSamples == 1) {
'''
progress_new = '''    _updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);

    if (isOffRoute && nextSamples == 1) {
'''
if progress_anchor not in s:
    raise SystemExit('navigation progress hook missing')
s = s.replace(progress_anchor, progress_new, 1)

# Warm up TTS only when the user starts live tracking, and stop speech when
# tracking ends. This avoids startup work for users who only browse routes.
tracking_start = "      _log('실시간 위치 추적 시작 · distanceFilter 5m');\n"
if tracking_start not in s:
    raise SystemExit('tracking start log missing')
s = s.replace(
    tracking_start,
    "      unawaited(_refreshTtsStatus());\n" + tracking_start,
    1,
)
tracking_stop = "    _log('실시간 위치 추적 중지');\n"
if tracking_stop not in s:
    raise SystemExit('tracking stop log missing')
s = s.replace(
    tracking_stop,
    "    if (!_isWidgetTest) unawaited(_ttsChannel.invokeMethod<bool>('stop').catchError((_) => false));\n" + tracking_stop,
    1,
)

# Diagnostics expose whether step instructions and Android TTS are actually
# available instead of merely showing a generic navigation PASS.
diag_anchor = "          _KeyValueRow(label: '자동 재탐색', value: _autoRerouteActive ? '재탐색 중' : (_offRouteSamples >= 3 ? '이탈 확정' : '대기')),\n"
diag_new = diag_anchor + """          _KeyValueRow(label: '회전 안내', value: _routeManeuvers.isEmpty ? '-' : '${_routeManeuvers.length}개 step'),
          _KeyValueRow(label: '다음 안내', value: _activeManeuver == null || _distanceToNextManeuverMeters == null ? '-' : guidanceDisplayText(_activeManeuver!, _distanceToNextManeuverMeters!)),
          _KeyValueRow(label: '음성 안내', value: !_voiceGuidanceEnabled ? '꺼짐' : (_ttsReady ? '한국어 TTS 준비' : 'TTS 준비 대기')),
"""
if diag_anchor not in s:
    raise SystemExit('route detail diagnostics anchor missing')
s = s.replace(diag_anchor, diag_new, 1)

# Update consumer roadmap wording if the prior item is still present.
s = s.replace("_PlanItem('v0.6.3', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),",
              "_PlanItem('v0.6.5', '실제 회전 지시 + 한국어 음성 안내', '현재', CheckState.pass),")
s = s.replace("_PlanItem('v0.6.4', '회전 지시 + 음성 안내', '다음 필수', CheckState.warning),",
              "_PlanItem('v0.6.5', '실제 회전 지시 + 한국어 음성 안내', '현재', CheckState.pass),")

required = [
    "import 'package:comfort_route_sample/navigation_guidance.dart';",
    "MethodChannel('comfort_route/navigation_tts')",
    'List<RouteManeuver> _routeManeuvers',
    'Widget _buildGuidanceBanner()',
    "final rawManeuver = rawStep['maneuver'];",
    'distanceFromStartMeters: maneuverDistance',
    'maneuvers: List<RouteManeuver>.unmodifiable(maneuvers)',
    '_updateGuidanceForAlongMeters(projection.alongMeters, allowVoice: !isOffRoute);',
    'unawaited(_refreshTtsStatus());',
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'missing v065 marker: {marker}')

p.write_text(s)
print('APPLY_V065_GUIDANCE: PASS')
