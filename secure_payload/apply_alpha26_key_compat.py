from pathlib import Path
import re
import sys


def apply(payload_root: Path) -> None:
    path = payload_root / 'lib' / 'wizard_v4.dart'
    source = path.read_text(encoding='utf-8')
    replacements = {
        "Key('unified_region_filter_panel')": "Key('region_filter_panel')",
        "Key('unified_region_filter_toggle')": "Key('region_filter_toggle')",
        "Key('unified_region_filter_wrap')": "Key('region_filter_wrap')",
        "Key('unified_region_$region')": "Key('region_$region')",
        "Key('unified_district_filter_wrap')": "Key('district_filter_wrap')",
        "Key('unified_district_${_regionFilter}_$district')": "Key('district_${_regionFilter}_$district')",
    }
    changed = 0
    for old, new in replacements.items():
        if old in source:
            source = source.replace(old, new)
            changed += 1
    if changed != len(replacements):
        raise SystemExit(
            f'alpha26 compatibility key replacement incomplete: '
            f'{changed}/{len(replacements)}'
        )

    handler_pattern = re.compile(
        r"onSelected:\s*\(_\)\s*=>\s*"
        r"setState\(\(\)\s*=>\s*_districtFilter\s*=\s*district\),"
    )
    handler_replacement = (
        "onSelected: (_) {\n"
        "                      setState(() => _districtFilter = district);\n"
        "                      _regionExpansionController.collapse();\n"
        "                    },"
    )
    source, handler_count = handler_pattern.subn(
        handler_replacement,
        source,
        count=1,
    )
    if handler_count != 1:
        raise SystemExit(
            f'alpha26 district collapse handler replacement incomplete: '
            f'{handler_count}/1'
        )

    path.write_text(source, encoding='utf-8')
    print('alpha26 legacy region keys and district auto-collapse preserved')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: apply_alpha26_key_compat.py <payload-root>')
    apply(Path(sys.argv[1]))
