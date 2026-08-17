enum GpsQuality { good, fair, usable, poor }

class GpsPolicy {
  const GpsPolicy._();

  static const double preferredMeters = 20;
  static const double fairMeters = 30;
  static const double navigationMaxMeters = 45;

  static GpsQuality quality(double accuracyMeters) {
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) return GpsQuality.poor;
    if (accuracyMeters <= preferredMeters) return GpsQuality.good;
    if (accuracyMeters <= fairMeters) return GpsQuality.fair;
    if (accuracyMeters <= navigationMaxMeters) return GpsQuality.usable;
    return GpsQuality.poor;
  }

  static bool usableForNavigation(double accuracyMeters) =>
      quality(accuracyMeters) != GpsQuality.poor;

  static String qualityLabel(double accuracyMeters) {
    switch (quality(accuracyMeters)) {
      case GpsQuality.good:
        return '좋음';
      case GpsQuality.fair:
        return '보통';
      case GpsQuality.usable:
        return '사용 가능';
      case GpsQuality.poor:
        return '안정화 필요';
    }
  }

  static String uncertaintyLabel(double accuracyMeters) {
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) return '위치 정확도 확인 중';
    return '위치 오차 약 ${accuracyMeters.toStringAsFixed(0)}m · ${qualityLabel(accuracyMeters)}';
  }
}
