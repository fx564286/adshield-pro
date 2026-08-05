#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/exported_alpha35')
ads = root / 'lib/ads.dart'
home = root / 'lib/home.dart'
settings = root / 'lib/settings_v2.dart'

ads_text = ads.read_text(encoding='utf-8')

ad_ids_pattern = re.compile(r'class AdIds \{.*?\n\}\n\n/// 동의 확인', re.S)
ad_ids_replacement = '''class AdIds {
  static const String banner =
      'ca-app-pub-8431674789078471/1709517483';
  static const String rewarded =
      'ca-app-pub-8431674789078471/4616710575';
  static const String interstitial =
      'ca-app-pub-8431674789078471/6249530627';
}

/// 동의 확인'''
ads_text, count = ad_ids_pattern.subn(ad_ids_replacement, ads_text, count=1)
if count != 1:
    raise SystemExit('AdIds class replacement failed')

ads_text = ads_text.replace(
    'await _requestConsent().timeout(const Duration(seconds: 15));',
    "await _requestConsent().timeout(const Duration(seconds: 8));",
    1,
)
ads_text = ads_text.replace(
    ".initialize()\n          .timeout(const Duration(seconds: 15));",
    ".initialize()\n          .timeout(const Duration(seconds: 8));",
    1,
)

ads_text = ads_text.replace(
    '  bool _disposed = false;\n\n  bool storeAvailable = false;',
    '  bool _disposed = false;\n\n  bool storeAvailable = false;\n  bool adsAvailable = false;',
    1,
)
ads_text = ads_text.replace(
    "        statusMessage = ready\n            ? 'Google 테스트 광고 SDK가 정상 초기화되었습니다.'\n            : '광고 동의 또는 네트워크 상태를 확인해 주세요.';",
    "        adsAvailable = ready;\n        statusMessage = ready\n            ? '광고 SDK가 정상 초기화되었습니다.'\n            : '광고를 사용할 수 없어 좌석 기능만 실행합니다.';",
    1,
)
ads_text = ads_text.replace(
    "    } catch (error, stack) {\n      statusMessage = '광고 초기화에 실패했지만 좌석 감시는 정상적으로 사용할 수 있습니다.';",
    "    } catch (error, stack) {\n      adsAvailable = false;\n      statusMessage = '광고 초기화에 실패했지만 좌석 감시는 정상적으로 사용할 수 있습니다.';",
    1,
)
ads_text = ads_text.replace(
    "    statusMessage = '보상형 테스트 광고를 준비하고 있습니다.';",
    "    statusMessage = '보상형 광고를 준비하고 있습니다.';",
    1,
)
ads_text = ads_text.replace("label: '하단 테스트 배너 광고'", "label: '하단 배너 광고'", 1)

old_init = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.controller.isAdFree) unawaited(_load());
    });'''
new_init = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.controller.initialized &&
          widget.controller.adsAvailable &&
          AdRuntime.ready &&
          !widget.controller.isAdFree) {
        unawaited(_load());
      }
    });'''
if old_init not in ads_text:
    raise SystemExit('banner init anchor missing')
ads_text = ads_text.replace(old_init, new_init, 1)

ads_text = ads_text.replace(
    "    } else if (_ad == null && !_loading) {\n      unawaited(_load());\n    }",
    "    } else if (widget.controller.initialized &&\n        widget.controller.adsAvailable &&\n        AdRuntime.ready &&\n        _ad == null &&\n        !_loading) {\n      unawaited(_load());\n    }",
    1,
)
ads_text = ads_text.replace(
    "    if (_loading || _ad != null || widget.controller.isAdFree) return;",
    "    if (_loading ||\n        _ad != null ||\n        widget.controller.isAdFree ||\n        !widget.controller.initialized ||\n        !widget.controller.adsAvailable ||\n        !AdRuntime.ready) {\n      return;\n    }",
    1,
)
ads_text = ads_text.replace(
    "      if (!await AdRuntime.ensureInitialized() || !mounted) return;",
    "      if (!mounted || !AdRuntime.ready) return;",
    1,
)
ads_text = ads_text.replace(
    '      await banner.load();',
    '      await banner.load().timeout(const Duration(seconds: 12));',
    1,
)

# Keep production builds free of accidental Google test unit IDs.
for test_id in (
    'ca-app-pub-3940256099942544/6300978111',
    'ca-app-pub-3940256099942544/1033173712',
    'ca-app-pub-3940256099942544/5224354917',
):
    ads_text = ads_text.replace(test_id, '')

ads.write_text(ads_text, encoding='utf-8')

home_text = home.read_text(encoding='utf-8')
home_text = home_text.replace(
    'class _AppShellState extends State<AppShell> {',
    'class _AppShellState extends State<AppShell> with WidgetsBindingObserver {',
    1,
)
home_text = home_text.replace(
    '  final MonetizationController _monetization = MonetizationController();\n  int _tab = 0;',
    '  final MonetizationController _monetization = MonetizationController();\n  Timer? _adStartupTimer;\n  int _tab = 0;',
    1,
)
old_home_init = '''  @override
  void initState() {
    super.initState();
    unawaited(_monetization.initialize());
  }
'''
new_home_init = '''  @override
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
'''
if old_home_init not in home_text:
    raise SystemExit('AppShell initState anchor missing')
home_text = home_text.replace(old_home_init, new_home_init, 1)
home_text = home_text.replace(
    '''  @override
  void dispose() {
    _monetization.dispose();
    super.dispose();
  }''',
    '''  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adStartupTimer?.cancel();
    _monetization.dispose();
    super.dispose();
  }''',
    1,
)
home_text = home_text.replace(
    '                  if (_tab != 2 && !_monetization.isAdFree)\n                    AppBannerAd(controller: _monetization),',
    '                  if (_tab != 2 &&\n                      _monetization.initialized &&\n                      _monetization.adsAvailable &&\n                      AdRuntime.ready &&\n                      !_monetization.isAdFree)\n                    AppBannerAd(controller: _monetization),',
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
