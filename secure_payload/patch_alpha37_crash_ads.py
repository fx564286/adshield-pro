#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/exported_alpha35')
ads = root / 'lib/ads.dart'
home = root / 'lib/home.dart'
settings = root / 'lib/settings_v2.dart'


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)
    if count != 1:
        raise SystemExit(f'{label} replacement failed')
    return updated


ads_text = ads.read_text(encoding='utf-8')

# Replace both configuration classes as a structural block. This avoids any
# dependency on comments or dart-format line wrapping and removes every Google
# sample ad unit from the production AOT snapshot.
ads_text = sub_once(
    ads_text,
    r'class MonetizationConfig \{.*?^\}\n\nclass AdIds \{.*?^\}\n',
    '''class MonetizationConfig {
  static const String adFreeProductId = 'remove_ads_lifetime_2900';
  static const String fallbackPriceLabel = 'Play 등록 후 활성화';
  static const int freeWatchSlots = 3;
}

class AdIds {
  static const String banner =
      'ca-app-pub-8431674789078471/1709517483';
  static const String rewarded =
      'ca-app-pub-8431674789078471/4616710575';
  static const String interstitial =
      'ca-app-pub-8431674789078471/6249530627';
}
''',
    'AdMob configuration block',
)

ads_text = ads_text.replace(
    'await _requestConsent().timeout(const Duration(seconds: 15));',
    'await _requestConsent().timeout(const Duration(seconds: 8));',
)
ads_text = ads_text.replace(
    '.initialize()\n          .timeout(const Duration(seconds: 15));',
    '.initialize()\n          .timeout(const Duration(seconds: 8));',
)

field_anchor = '  bool storeAvailable = false;\n'
if field_anchor not in ads_text:
    raise SystemExit('Monetization availability field anchor missing')
ads_text = ads_text.replace(
    field_anchor,
    field_anchor + '  bool adsAvailable = false;\n',
    1,
)

ads_text = sub_once(
    ads_text,
    r'  Future<void> initialize\(\) async \{.*?(?=  Future<void> refreshProducts\(\) async)',
    '''  Future<void> initialize() async {
    if (_initialized || _initializing || _disposed) return;
    _initializing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      isAdFree = prefs.getBool(_adFreeEntitlementKey) ?? false;
      bonusUntil = await RewardManager().bonusUntil();
      _safeNotify();
      if (!isAdFree) {
        final ready = await AdRuntime.ensureInitialized();
        adsAvailable = ready;
        statusMessage = ready
            ? '광고 SDK가 정상 초기화되었습니다.'
            : '광고를 사용할 수 없어 좌석 기능만 실행합니다.';
        if (ready) {
          unawaited(_rewardedAdService.load());
          unawaited(_interstitialAdService.load());
        }
      }
    } catch (error, stack) {
      adsAvailable = false;
      statusMessage = '광고 초기화에 실패했지만 좌석 감시는 정상적으로 사용할 수 있습니다.';
      debugPrint('Monetization initialization skipped safely: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _initializing = false;
      _initialized = true;
      _safeNotify();
    }
  }

''',
    'Monetization initialize method',
)
ads_text = ads_text.replace(
    "statusMessage = '보상형 테스트 광고를 준비하고 있습니다.';",
    "statusMessage = '보상형 광고를 준비하고 있습니다.';",
)

# Replace the complete banner state. Banner creation is impossible until the
# app has rendered, consent/SDK initialization completed, and the controller
# explicitly marked ads available. Any load error remains local to the banner.
ads_text = sub_once(
    ads_text,
    r'class _AppBannerAdState extends State<AppBannerAd> \{.*?^\}\n\nclass RewardedAdService',
    '''class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.controller.initialized &&
          widget.controller.adsAvailable &&
          AdRuntime.ready &&
          !widget.controller.isAdFree) {
        unawaited(_load());
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerChanged);
      widget.controller.addListener(_controllerChanged);
      _controllerChanged();
    }
  }

  void _controllerChanged() {
    if (!mounted) return;
    if (widget.controller.isAdFree || !widget.controller.adsAvailable) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      setState(() {});
      return;
    }
    if (widget.controller.initialized &&
        AdRuntime.ready &&
        _ad == null &&
        !_loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading ||
        _ad != null ||
        widget.controller.isAdFree ||
        !widget.controller.initialized ||
        !widget.controller.adsAvailable ||
        !AdRuntime.ready) {
      return;
    }
    _loading = true;
    try {
      if (!mounted || !AdRuntime.ready) return;
      late final BannerAd banner;
      banner = BannerAd(
        adUnitId: AdIds.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted || widget.controller.isAdFree) {
              banner.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (_, error) {
            debugPrint('Banner load failed safely: $error');
            banner.dispose();
            if (!mounted) return;
            setState(() {
              if (identical(_ad, banner)) _ad = null;
              _loaded = false;
            });
          },
        ),
      );
      _ad = banner;
      await banner.load().timeout(const Duration(seconds: 12));
    } catch (error, stack) {
      debugPrint('Banner creation skipped safely: $error');
      debugPrintStack(stackTrace: stack);
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (widget.controller.isAdFree ||
        !widget.controller.adsAvailable ||
        !_loaded ||
        ad == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: '하단 배너 광고',
      child: ColoredBox(
        color: const Color(0xFFF8F5F7),
        child: Center(
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}

class RewardedAdService''',
    'App banner state',
)

for test_id in (
    'ca-app-pub-3940256099942544/6300978111',
    'ca-app-pub-3940256099942544/1033173712',
    'ca-app-pub-3940256099942544/5224354917',
    'ca-app-pub-3940256099942544/2934735716',
    'ca-app-pub-3940256099942544/4411468910',
    'ca-app-pub-3940256099942544/1712485313',
):
    ads_text = ads_text.replace(test_id, '')

ads.write_text(ads_text, encoding='utf-8')

home_text = home.read_text(encoding='utf-8')
home_text = home_text.replace(
    'class _AppShellState extends State<AppShell> {',
    'class _AppShellState extends State<AppShell> with WidgetsBindingObserver {',
    1,
)
field_anchor = '  final MonetizationController _monetization = MonetizationController();\n'
if field_anchor not in home_text:
    raise SystemExit('AppShell monetization field anchor missing')
home_text = home_text.replace(
    field_anchor,
    field_anchor + '  Timer? _adStartupTimer;\n',
    1,
)
home_text = sub_once(
    home_text,
    r'  @override\n  void initState\(\) \{.*?(?=  Future<void> _addWatch\(\) async)',
    '''  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleAdInitialization();
    });
  }

  void _scheduleAdInitialization() {
    if (!mounted || _monetization.initialized || _adStartupTimer != null) {
      return;
    }
    _adStartupTimer = Timer(const Duration(seconds: 3), () {
      _adStartupTimer = null;
      if (!mounted) return;
      unawaited(_monetization.initialize());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAdInitialization();
    }
  }

''',
    'AppShell startup lifecycle',
)
home_text = sub_once(
    home_text,
    r'  @override\n  void dispose\(\) \{.*?^  \}\n\n  @override\n  Widget build',
    '''  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adStartupTimer?.cancel();
    _monetization.dispose();
    super.dispose();
  }

  @override
  Widget build''',
    'AppShell dispose method',
)
home_text = home_text.replace(
    '                  if (_tab != 2 && !_monetization.isAdFree)\n'
    '                    AppBannerAd(controller: _monetization),',
    '                  if (_tab != 2 &&\n'
    '                      _monetization.initialized &&\n'
    '                      _monetization.adsAvailable &&\n'
    '                      AdRuntime.ready &&\n'
    '                      !_monetization.isAdFree)\n'
    '                    AppBannerAd(controller: _monetization),',
    1,
)
home.write_text(home_text, encoding='utf-8')

settings_text = settings.read_text(encoding='utf-8')
settings_text = settings_text.replace('Google 테스트 광고', 'Google 광고')
settings_text = settings_text.replace('테스트 광고', '광고')
settings.write_text(settings_text, encoding='utf-8')

required = {
    ads: [
        'ca-app-pub-8431674789078471/1709517483',
        'ca-app-pub-8431674789078471/4616710575',
        'ca-app-pub-8431674789078471/6249530627',
        'bool adsAvailable = false;',
        'banner.load().timeout(const Duration(seconds: 12))',
    ],
    home: [
        'with WidgetsBindingObserver',
        'Timer(const Duration(seconds: 3)',
        '_monetization.adsAvailable',
        'AdRuntime.ready',
    ],
}
for path, tokens in required.items():
    text = path.read_text(encoding='utf-8')
    missing = [token for token in tokens if token not in text]
    if missing:
        raise SystemExit(f'{path.name} alpha37 contract missing: {missing}')

print('alpha37 delayed AdMob startup and production ad unit IDs applied')
