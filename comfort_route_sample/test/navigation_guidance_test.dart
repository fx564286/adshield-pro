import 'package:comfort_route_sample/navigation_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

RouteManeuver maneuver({
  required double at,
  String type = 'turn',
  String modifier = 'right',
  String road = '',
  int? exit,
}) {
  return RouteManeuver(
    latitude: 37.5,
    longitude: 126.7,
    distanceFromStartMeters: at,
    stepDistanceMeters: 100,
    durationSeconds: 60,
    type: type,
    modifier: modifier,
    roadName: road,
    exitNumber: exit,
  );
}

void main() {
  test('selects next maneuver from traveled distance', () {
    final maneuvers = [
      maneuver(at: 0, type: 'depart', modifier: 'straight'),
      maneuver(at: 120, modifier: 'left'),
      maneuver(at: 300, modifier: 'right'),
    ];

    final target = selectNextGuidance(maneuvers, 80);
    expect(target, isNotNull);
    expect(target!.index, 1);
    expect(target.distanceMeters, closeTo(40, 0.001));
  });

  test('skips departed instruction after movement begins', () {
    final maneuvers = [
      maneuver(at: 0, type: 'depart', modifier: 'straight'),
      maneuver(at: 100, modifier: 'right'),
    ];
    expect(selectNextGuidance(maneuvers, 20)!.index, 1);
  });

  test('keeps recently passed maneuver within tolerance', () {
    final maneuvers = [maneuver(at: 100, modifier: 'left')];
    final target = selectNextGuidance(maneuvers, 112, passToleranceMeters: 18);
    expect(target, isNotNull);
    expect(target!.distanceMeters, 0);
  });

  test('maps common OSRM modifiers to directions', () {
    expect(guidanceDirection(maneuver(at: 10, modifier: 'sharp left')), GuidanceDirection.sharpLeft);
    expect(guidanceDirection(maneuver(at: 10, modifier: 'slight right')), GuidanceDirection.slightRight);
    expect(guidanceDirection(maneuver(at: 10, type: 'fork', modifier: 'left')), GuidanceDirection.forkLeft);
    expect(guidanceDirection(maneuver(at: 10, type: 'merge', modifier: 'right')), GuidanceDirection.mergeRight);
    expect(guidanceDirection(maneuver(at: 10, modifier: 'uturn')), GuidanceDirection.uTurn);
  });

  test('roundabout exit is included in Korean instruction', () {
    final text = guidanceCoreText(maneuver(at: 200, type: 'roundabout', modifier: 'right', exit: 2));
    expect(text, contains('2번째 출구'));
  });

  test('road name is retained when available', () {
    final text = guidanceCoreText(maneuver(at: 120, modifier: 'left', road: '중동로'));
    expect(text, contains('중동로'));
  });

  test('speech stages trigger approach then near call', () {
    expect(guidanceSpeechStage(150), 0);
    expect(guidanceSpeechStage(90), 1);
    expect(guidanceSpeechStage(25), 2);
  });

  test('guidance distance is human readable', () {
    expect(formatGuidanceDistance(23), '25m 앞');
    expect(formatGuidanceDistance(342), '340m 앞');
    expect(formatGuidanceDistance(1250), '1.3km 앞');
  });

  test('unknown maneuver degrades gracefully', () {
    final m = maneuver(at: 50, type: 'future-new-type', modifier: 'mystery', road: '테스트길');
    expect(guidanceDirection(m), GuidanceDirection.unknown);
    expect(guidanceCoreText(m), contains('경로를 따라'));
  });
}
