import 'dart:math' as math;

enum RoutePreference { fast, pleasant, weatherAvoid }

class RouteScoreInput {
  const RouteScoreInput({
    required this.distanceMeters,
    required this.durationSeconds,
    this.maneuverCount = 0,
    this.comfortSignalHits = 0,
    this.shelterSignalHits = 0,
    this.sourceIndex = 0,
  });

  final double distanceMeters;
  final double durationSeconds;
  final int maneuverCount;
  final int comfortSignalHits;
  final int shelterSignalHits;
  final int sourceIndex;
}

int chooseRouteIndex(List<RouteScoreInput> routes, RoutePreference preference) {
  if (routes.isEmpty) return -1;
  if (routes.length == 1) return 0;

  double finitePositive(double value) =>
      value.isFinite && value > 0 ? value : double.maxFinite / 4;

  final minDuration = routes
      .map((route) => finitePositive(route.durationSeconds))
      .reduce(math.min);
  final minDistance = routes
      .map((route) => finitePositive(route.distanceMeters))
      .reduce(math.min);
  final minManeuvers = routes
      .map((route) => route.maneuverCount > 0 ? route.maneuverCount.toDouble() : 1.0)
      .reduce(math.min);

  double score(RouteScoreInput route) {
    final durationRatio = finitePositive(route.durationSeconds) / minDuration;
    final distanceRatio = finitePositive(route.distanceMeters) / minDistance;
    final maneuverRatio = (route.maneuverCount > 0 ? route.maneuverCount : 1) / minManeuvers;
    final comfort = math.min(math.max(route.comfortSignalHits, 0), 8) / 8.0;
    final shelter = math.min(math.max(route.shelterSignalHits, 0), 8) / 8.0;

    switch (preference) {
      case RoutePreference.fast:
        return durationRatio * 0.85 + distanceRatio * 0.15;
      case RoutePreference.pleasant:
        return durationRatio * 0.42 +
            distanceRatio * 0.23 +
            maneuverRatio * 0.20 -
            comfort * 0.15;
      case RoutePreference.weatherAvoid:
        // Until verified indoor/covered edges are available, total outdoor
        // exposure distance is the dominant weather-avoidance signal. Nearby
        // shelter-like POIs are only a small secondary hint.
        return durationRatio * 0.32 + distanceRatio * 0.58 - shelter * 0.10;
    }
  }

  var bestIndex = 0;
  var bestScore = score(routes.first);
  for (var index = 1; index < routes.length; index++) {
    final candidateScore = score(routes[index]);
    if (candidateScore < bestScore - 1e-9) {
      bestIndex = index;
      bestScore = candidateScore;
      continue;
    }
    if ((candidateScore - bestScore).abs() <= 1e-9 &&
        routes[index].sourceIndex < routes[bestIndex].sourceIndex) {
      bestIndex = index;
      bestScore = candidateScore;
    }
  }
  return bestIndex;
}
