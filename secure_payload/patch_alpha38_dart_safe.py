#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/exported_alpha35')
path = root / 'lib/ads.dart'
text = path.read_text(encoding='utf-8')
preload = '''        if (ready) {
          unawaited(_rewardedAdService.load());
          unawaited(_interstitialAdService.load());
        }
'''
if preload not in text:
    raise SystemExit('alpha38 ad preload block missing')
text = text.replace(preload, '', 1)
path.write_text(text, encoding='utf-8')
print('alpha38 removed rewarded and interstitial startup preload')
