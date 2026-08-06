#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

root = Path(sys.argv[1])
ads = root / 'lib/ads.dart'
settings = root / 'lib/settings_v2.dart'

ads.write_text(
    '''import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Alpha39 stability build: no advertising package is linked or initialized.
class MonetizationConfig {
  static const String adFreeProductId = 'disabled_alpha39';
  static const String fallbackPriceLabel = '비활성';
  static const int freeWatchSlots = 1 << 20;
}

class AdIds {
  static const String banner = '';
  static const String rewarded = '';
  static const String interstitial = '';
}

class AdRuntime {
  static bool get ready => false;
  static Object? lastError;

  static Future<bool> ensureInitialized() async => false;
  static Future<void> showPrivacyOptions() async {}
}

class RewardManager {
  Future<DateTime?> bonusUntil() async => null;
  Future<DateTime?> grantBonus() async => null;
}

class MonetizationController extends ChangeNotifier {
  bool _initialized = false;
  bool _disposed = false;

  bool storeAvailable = false;
  bool purchasePending = true;
  bool restorePending = true;
  bool rewardPending = false;
  bool isAdFree = true;
  bool adsAvailable = false;
  Object? adFreeProduct;
  DateTime? bonusUntil;
  String? statusMessage = '광고 SDK를 완전히 제거한 안정성 확인 빌드입니다.';

  bool get initialized => _initialized;
  bool get bonusActive => false;
  String get priceLabel => MonetizationConfig.fallbackPriceLabel;
  int get watchLimit => MonetizationConfig.freeWatchSlots;
  String get watchLimitLabel => '무제한';

  bool canCreateWatch(int currentCount) => true;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    isAdFree = true;
    adsAvailable = false;
    statusMessage = '광고 SDK를 완전히 제거한 안정성 확인 빌드입니다.';
    _safeNotify();
  }

  Future<void> refreshProducts() async {
    statusMessage = '현재 빌드에서는 광고와 결제 기능을 사용하지 않습니다.';
    _safeNotify();
  }

  Future<bool> buyAdFree() async {
    statusMessage = '광고 SDK 제거 빌드이므로 별도 구매가 필요하지 않습니다.';
    _safeNotify();
    return false;
  }

  Future<void> restorePurchases() async {
    statusMessage = '광고 SDK 제거 빌드에서는 구매 복원을 사용하지 않습니다.';
    _safeNotify();
  }

  Future<bool> showRewardedBonus() async {
    statusMessage = '광고 기능이 분리되어 감시 슬롯은 제한 없이 사용할 수 있습니다.';
    _safeNotify();
    return false;
  }

  Future<void> maybeShowInterstitial() async {}

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppBannerAd extends StatelessWidget {
  const AppBannerAd({super.key, required this.controller});

  final MonetizationController controller;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class RewardedAdService {
  Future<void> load() async {}
  Future<bool> show() async => false;
  void dispose() {}
}

class InterstitialAdService {
  Future<void> load() async {}
  Future<void> show() async {}
  void dispose() {}
}
''',
    encoding='utf-8',
)

text = settings.read_text(encoding='utf-8')
replacements = {
    '알림, 감시 동작, 광고와 구매 내역을 관리합니다.': '알림과 감시 동작을 관리합니다.',
    "const _SectionLabel(title: '광고 및 이용권')": "const _SectionLabel(title: '안정성 확인')",
    "title: '알파 테스트 광고'": "title: '광고 SDK 완전 제거'",
    "subtitle: '현재 APK는 Google 공식 테스트 광고만 사용하며 실제 수익은 발생하지 않습니다.'": "subtitle: '반복된 시작 충돌을 분리하기 위해 이 APK에는 광고 라이브러리와 광고 권한이 포함되지 않습니다.'",
    "subtitle: '0.2.1-alpha.6 · 실제 좌석표 및 광고 최소화'": "subtitle: '0.2.1-alpha.39 · 광고 SDK 제거 안정성 확인'",
}
for old, new in replacements.items():
    text = text.replace(old, new)
settings.write_text(text, encoding='utf-8')

source = ads.read_text(encoding='utf-8')
required = [
    'class MonetizationController',
    'bool isAdFree = true;',
    'bool adsAvailable = false;',
    'Future<void> maybeShowInterstitial() async {}',
    'class AppBannerAd',
]
missing = [token for token in required if token not in source]
if missing:
    raise SystemExit(f'alpha39 no-ad source contract missing: {missing}')

for forbidden in (
    'google_mobile_ads',
    'BannerAd(',
    'RewardedAd.load(',
    'InterstitialAd.load(',
    'MobileAds.instance',
    'ca-app-pub-',
):
    if forbidden in source:
        raise SystemExit(f'alpha39 forbidden ad token remained in ads.dart: {forbidden}')

print('alpha39 advertising runtime replaced with no-op stability shim')
