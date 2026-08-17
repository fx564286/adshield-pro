enum GuidanceDirection {
  depart,
  arrive,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  forkLeft,
  forkRight,
  roundabout,
  mergeLeft,
  mergeRight,
  unknown,
}

class RouteManeuver {
  const RouteManeuver({
    required this.latitude,
    required this.longitude,
    required this.distanceFromStartMeters,
    required this.stepDistanceMeters,
    required this.durationSeconds,
    required this.type,
    required this.modifier,
    required this.roadName,
    this.exitNumber,
  });

  final double latitude;
  final double longitude;
  final double distanceFromStartMeters;
  final double stepDistanceMeters;
  final double durationSeconds;
  final String type;
  final String modifier;
  final String roadName;
  final int? exitNumber;

  String get stableKey =>
      '${distanceFromStartMeters.toStringAsFixed(1)}|$type|$modifier|$roadName|${exitNumber ?? 0}';
}

class GuidanceTarget {
  const GuidanceTarget({
    required this.index,
    required this.maneuver,
    required this.distanceMeters,
  });

  final int index;
  final RouteManeuver maneuver;
  final double distanceMeters;
}

GuidanceTarget? selectNextGuidance(
  List<RouteManeuver> maneuvers,
  double traveledMeters, {
  double passToleranceMeters = 18,
}) {
  if (maneuvers.isEmpty || !traveledMeters.isFinite) return null;
  final traveled = traveledMeters < 0 ? 0.0 : traveledMeters;

  for (var index = 0; index < maneuvers.length; index++) {
    final maneuver = maneuvers[index];
    final type = maneuver.type.trim().toLowerCase();
    if (type == 'notification') continue;
    if (type == 'depart' && traveled > 12) continue;

    final remaining = maneuver.distanceFromStartMeters - traveled;
    if (remaining >= -passToleranceMeters || type == 'arrive') {
      return GuidanceTarget(
        index: index,
        maneuver: maneuver,
        distanceMeters: remaining < 0 ? 0 : remaining,
      );
    }
  }
  return null;
}

GuidanceDirection guidanceDirection(RouteManeuver maneuver) {
  final type = maneuver.type.trim().toLowerCase();
  final modifier = maneuver.modifier.trim().toLowerCase();
  if (type == 'depart') return GuidanceDirection.depart;
  if (type == 'arrive') return GuidanceDirection.arrive;
  if (type == 'new name' || type == 'continue') {
    return GuidanceDirection.straight;
  }
  if (type == 'roundabout' ||
      type == 'rotary' ||
      type == 'roundabout turn' ||
      type == 'exit roundabout' ||
      type == 'exit rotary') {
    return GuidanceDirection.roundabout;
  }
  if (type == 'fork') {
    if (modifier.contains('left')) return GuidanceDirection.forkLeft;
    if (modifier.contains('right')) return GuidanceDirection.forkRight;
  }
  if (type == 'merge') {
    if (modifier.contains('left')) return GuidanceDirection.mergeLeft;
    if (modifier.contains('right')) return GuidanceDirection.mergeRight;
  }
  if (modifier.contains('uturn') || modifier.contains('u-turn')) {
    return GuidanceDirection.uTurn;
  }
  switch (modifier) {
    case 'sharp left':
      return GuidanceDirection.sharpLeft;
    case 'left':
      return GuidanceDirection.left;
    case 'slight left':
      return GuidanceDirection.slightLeft;
    case 'sharp right':
      return GuidanceDirection.sharpRight;
    case 'right':
      return GuidanceDirection.right;
    case 'slight right':
      return GuidanceDirection.slightRight;
    case 'straight':
      return GuidanceDirection.straight;
  }
  return GuidanceDirection.unknown;
}

String guidanceCoreText(RouteManeuver maneuver) {
  final direction = guidanceDirection(maneuver);
  final road = maneuver.roadName.trim();
  final roadSuffix = road.isEmpty ? '' : ' · $road';
  switch (direction) {
    case GuidanceDirection.depart:
      return '경로를 따라 출발하세요$roadSuffix';
    case GuidanceDirection.arrive:
      return '목적지에 도착합니다';
    case GuidanceDirection.straight:
      return '계속 직진하세요$roadSuffix';
    case GuidanceDirection.slightLeft:
      return '왼쪽 앞 방향으로 진행하세요$roadSuffix';
    case GuidanceDirection.left:
      return '왼쪽으로 도세요$roadSuffix';
    case GuidanceDirection.sharpLeft:
      return '크게 왼쪽으로 도세요$roadSuffix';
    case GuidanceDirection.slightRight:
      return '오른쪽 앞 방향으로 진행하세요$roadSuffix';
    case GuidanceDirection.right:
      return '오른쪽으로 도세요$roadSuffix';
    case GuidanceDirection.sharpRight:
      return '크게 오른쪽으로 도세요$roadSuffix';
    case GuidanceDirection.uTurn:
      return '유턴하세요$roadSuffix';
    case GuidanceDirection.forkLeft:
      return '갈림길에서 왼쪽 길로 진행하세요$roadSuffix';
    case GuidanceDirection.forkRight:
      return '갈림길에서 오른쪽 길로 진행하세요$roadSuffix';
    case GuidanceDirection.roundabout:
      final exit = maneuver.exitNumber;
      return exit == null || exit <= 0
          ? '회전교차로를 따라 진행하세요$roadSuffix'
          : '회전교차로에서 ${exit}번째 출구로 나가세요$roadSuffix';
    case GuidanceDirection.mergeLeft:
      return '왼쪽으로 합류하세요$roadSuffix';
    case GuidanceDirection.mergeRight:
      return '오른쪽으로 합류하세요$roadSuffix';
    case GuidanceDirection.unknown:
      return '경로를 따라 진행하세요$roadSuffix';
  }
}

String formatGuidanceDistance(double meters) {
  if (!meters.isFinite || meters <= 0) return '곧';
  if (meters < 50) {
    final rounded = (meters / 5).round() * 5;
    return '${rounded < 5 ? 5 : rounded}m 앞';
  }
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? 10 : rounded}m 앞';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)}km 앞';
}

String guidanceDisplayText(RouteManeuver maneuver, double distanceMeters) {
  if (guidanceDirection(maneuver) == GuidanceDirection.depart) {
    return guidanceCoreText(maneuver);
  }
  if (guidanceDirection(maneuver) == GuidanceDirection.arrive && distanceMeters <= 18) {
    return guidanceCoreText(maneuver);
  }
  return '${formatGuidanceDistance(distanceMeters)} · ${guidanceCoreText(maneuver)}';
}

String guidanceSpeechText(RouteManeuver maneuver, double distanceMeters) {
  final core = guidanceCoreText(maneuver).replaceAll(' · ', ', ');
  if (guidanceDirection(maneuver) == GuidanceDirection.depart) return core;
  if (guidanceDirection(maneuver) == GuidanceDirection.arrive && distanceMeters <= 18) return core;
  return '${formatGuidanceDistance(distanceMeters).replaceAll(' 앞', ' 앞에서')}, $core';
}

int guidanceSpeechStage(double distanceMeters) {
  if (!distanceMeters.isFinite) return 0;
  if (distanceMeters <= 28) return 2;
  if (distanceMeters <= 95) return 1;
  return 0;
}
