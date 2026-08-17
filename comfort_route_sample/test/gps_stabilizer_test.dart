import 'package:comfort_route_sample/gps_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

GpsSample sample({
  required double lat,
  required double lon,
  required double accuracy,
  double speed = 0,
  int second = 0,
}) {
  return GpsSample(
    latitude: lat,
    longitude: lon,
    accuracyMeters: accuracy,
    speedMps: speed,
    timestamp: DateTime.utc(2026, 8, 17, 3, 0, second),
  );
}

void main() {
  test('rejects a 100m-class one-second teleport with otherwise usable accuracy', () {
    final stabilizer = GpsStabilizer();
    final first = stabilizer.add(sample(lat: 37.500000, lon: 126.750000, accuracy: 12));
    expect(first.accepted, isTrue);

    final jump = stabilizer.add(sample(
      lat: 37.500900,
      lon: 126.750000,
      accuracy: 15,
      second: 1,
    ));
    expect(jump.decision, GpsStabilizerDecision.implausibleJump);
    expect(jump.latitude, closeTo(first.latitude, 1e-10));
    expect(jump.rawDisplacementMeters, greaterThan(90));
  });

  test('does not block plausible fast bicycle motion', () {
    final stabilizer = GpsStabilizer();
    stabilizer.add(sample(lat: 37.500000, lon: 126.750000, accuracy: 10, speed: 14));
    final moving = stabilizer.add(sample(
      lat: 37.500500,
      lon: 126.750000,
      accuracy: 11,
      speed: 14,
      second: 4,
    ));
    expect(moving.accepted, isTrue);
  });

  test('poor 100m sensor fix never becomes a navigation fix', () {
    final stabilizer = GpsStabilizer();
    final result = stabilizer.add(sample(lat: 37.5, lon: 126.75, accuracy: 100));
    expect(result.decision, GpsStabilizerDecision.poorAccuracy);
    expect(result.accepted, isFalse);
  });

  test('stationary jitter is damped rather than copied directly', () {
    final stabilizer = GpsStabilizer();
    final first = stabilizer.add(sample(lat: 37.500000, lon: 126.750000, accuracy: 25));
    final noisy = stabilizer.add(sample(
      lat: 37.500090,
      lon: 126.750000,
      accuracy: 25,
      speed: 0,
      second: 2,
    ));
    expect(noisy.accepted, isTrue);
    expect(noisy.alpha, lessThan(0.5));
    final rawMove = GpsStabilizer.distanceMeters(37.500000, 126.750000, 37.500090, 126.750000);
    final filteredMove = GpsStabilizer.distanceMeters(first.latitude, first.longitude, noisy.latitude, noisy.longitude);
    expect(filteredMove, lessThan(rawMove));
  });

  test('long gaps reset smoothing lag', () {
    final stabilizer = GpsStabilizer();
    stabilizer.add(sample(lat: 37.500000, lon: 126.750000, accuracy: 20));
    final later = stabilizer.add(GpsSample(
      latitude: 37.500100,
      longitude: 126.750100,
      accuracyMeters: 20,
      speedMps: 1.2,
      timestamp: DateTime.utc(2026, 8, 17, 3, 0, 20),
    ));
    expect(later.accepted, isTrue);
    expect(later.alpha, 1);
    expect(later.latitude, closeTo(37.500100, 1e-10));
  });
}
