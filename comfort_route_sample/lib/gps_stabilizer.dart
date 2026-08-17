import 'dart:math' as math;

enum GpsStabilizerDecision { accepted, poorAccuracy, implausibleJump }

class GpsSample {
  const GpsSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedMps,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedMps;
  final DateTime timestamp;
}

class GpsStabilizedFix {
  const GpsStabilizedFix({
    required this.latitude,
    required this.longitude,
    required this.sensorAccuracyMeters,
    required this.alpha,
    required this.decision,
    required this.rawDisplacementMeters,
  });

  final double latitude;
  final double longitude;

  /// This remains the sensor-reported uncertainty. Filtering must never pretend
  /// that the GNSS hardware itself became more accurate than it reported.
  final double sensorAccuracyMeters;
  final double alpha;
  final GpsStabilizerDecision decision;
  final double rawDisplacementMeters;

  bool get accepted => decision == GpsStabilizerDecision.accepted;
}

class GpsStabilizer {
  GpsStabilizer({this.maxNavigationAccuracyMeters = 45});

  final double maxNavigationAccuracyMeters;
  GpsSample? _lastAcceptedRaw;
  GpsStabilizedFix? _lastOutput;

  GpsStabilizedFix? get lastOutput => _lastOutput;

  void reset() {
    _lastAcceptedRaw = null;
    _lastOutput = null;
  }

  GpsStabilizedFix add(GpsSample sample) {
    if (!_validSample(sample) || sample.accuracyMeters > maxNavigationAccuracyMeters) {
      return GpsStabilizedFix(
        latitude: _lastOutput?.latitude ?? sample.latitude,
        longitude: _lastOutput?.longitude ?? sample.longitude,
        sensorAccuracyMeters: sample.accuracyMeters,
        alpha: 0,
        decision: GpsStabilizerDecision.poorAccuracy,
        rawDisplacementMeters: 0,
      );
    }

    final previousRaw = _lastAcceptedRaw;
    final previousOutput = _lastOutput;
    if (previousRaw == null || previousOutput == null) {
      final first = GpsStabilizedFix(
        latitude: sample.latitude,
        longitude: sample.longitude,
        sensorAccuracyMeters: sample.accuracyMeters,
        alpha: 1,
        decision: GpsStabilizerDecision.accepted,
        rawDisplacementMeters: 0,
      );
      _lastAcceptedRaw = sample;
      _lastOutput = first;
      return first;
    }

    final dtSeconds = math.max(
      0.2,
      sample.timestamp.difference(previousRaw.timestamp).inMilliseconds.abs() / 1000,
    );
    final rawDisplacement = distanceMeters(
      previousRaw.latitude,
      previousRaw.longitude,
      sample.latitude,
      sample.longitude,
    );
    final statedSpeed = math.max(
      0,
      math.max(_cleanSpeed(previousRaw.speedMps), _cleanSpeed(sample.speedMps)),
    );

    // Short-window teleport rejection. The allowance scales with both reported
    // uncertainty and actual motion, so a bicycle remains valid while a 50-100m
    // one-second GNSS jump from a pedestrian is rejected.
    if (dtSeconds < 15) {
      final uncertaintyAllowance = math.min(
        50.0,
        (previousRaw.accuracyMeters + sample.accuracyMeters) * 0.65,
      );
      final distanceAllowance = math.max(
        45.0,
        uncertaintyAllowance + (statedSpeed + 4.0) * dtSeconds + 10.0,
      );
      final impliedSpeed = rawDisplacement / dtSeconds;
      final speedCeiling = math.max(11.0, statedSpeed + 7.0);
      if (rawDisplacement > distanceAllowance && impliedSpeed > speedCeiling) {
        return GpsStabilizedFix(
          latitude: previousOutput.latitude,
          longitude: previousOutput.longitude,
          sensorAccuracyMeters: sample.accuracyMeters,
          alpha: 0,
          decision: GpsStabilizerDecision.implausibleJump,
          rawDisplacementMeters: rawDisplacement,
        );
      }
    }

    final outputDisplacement = distanceMeters(
      previousOutput.latitude,
      previousOutput.longitude,
      sample.latitude,
      sample.longitude,
    );
    final impliedOutputSpeed = outputDisplacement / dtSeconds;

    // When Android reports almost no physical speed and the coordinate movement
    // sits comfortably inside the combined uncertainty envelope, treat it as
    // stationary GNSS jitter rather than deriving a false walking/cycling speed
    // from the noisy coordinates themselves.
    final withinUncertainty = outputDisplacement <= math.max(
      6.0,
      (previousRaw.accuracyMeters + sample.accuracyMeters) * 0.55,
    );
    final motionSpeed = statedSpeed < 0.5 && withinUncertainty
        ? 0.0
        : math.max(statedSpeed, impliedOutputSpeed);

    double alpha;
    if (dtSeconds > 10) {
      // After a long gap, avoid dragging the marker toward stale history.
      alpha = 1;
    } else if (sample.accuracyMeters <= 8) {
      alpha = 0.82;
    } else if (motionSpeed >= 7) {
      alpha = 0.78;
    } else if (motionSpeed >= 2.2) {
      alpha = 0.62;
    } else if (motionSpeed >= 0.7) {
      alpha = 0.46;
    } else {
      alpha = 0.22;
    }

    final accuracyFactor = (28 / sample.accuracyMeters).clamp(0.45, 1.0);
    alpha *= accuracyFactor;
    if (!withinUncertainty && outputDisplacement > math.max(10, sample.accuracyMeters * 0.8)) {
      alpha += 0.12;
    }
    alpha = alpha.clamp(0.14, 0.88);

    final latitude = previousOutput.latitude + (sample.latitude - previousOutput.latitude) * alpha;
    final longitude = _interpolateLongitude(previousOutput.longitude, sample.longitude, alpha);
    final result = GpsStabilizedFix(
      latitude: latitude,
      longitude: longitude,
      sensorAccuracyMeters: sample.accuracyMeters,
      alpha: alpha,
      decision: GpsStabilizerDecision.accepted,
      rawDisplacementMeters: rawDisplacement,
    );
    _lastAcceptedRaw = sample;
    _lastOutput = result;
    return result;
  }

  static bool _validSample(GpsSample sample) =>
      sample.latitude.isFinite &&
      sample.longitude.isFinite &&
      sample.latitude >= -90 &&
      sample.latitude <= 90 &&
      sample.longitude >= -180 &&
      sample.longitude <= 180 &&
      sample.accuracyMeters.isFinite &&
      sample.accuracyMeters > 0;

  static double _cleanSpeed(double value) {
    if (!value.isFinite || value < 0) return 0;
    return value.clamp(0, 55).toDouble();
  }

  static double _interpolateLongitude(double from, double to, double alpha) {
    var delta = to - from;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    var value = from + delta * alpha;
    if (value > 180) value -= 360;
    if (value < -180) value += 360;
    return value;
  }

  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371008.8;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
