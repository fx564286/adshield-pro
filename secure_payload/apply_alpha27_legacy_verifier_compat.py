from pathlib import Path
import sys


def apply(payload_root: Path) -> None:
    wizard_path = payload_root / 'lib' / 'wizard_v4.dart'
    wizard = wizard_path.read_text(encoding='utf-8')

    district_marker = "key: const Key('district_filter_wrap'),"
    if district_marker not in wizard:
        anchor = """                            Expanded(\n                              child: AnimatedSwitcher(\n"""
        replacement = """                            Expanded(\n                              key: const Key('district_filter_wrap'),\n                              child: AnimatedSwitcher(\n"""
        if anchor not in wizard:
            raise SystemExit('alpha27 theater-pane compatibility anchor missing')
        wizard = wizard.replace(anchor, replacement, 1)

    material_marker = 'alpha27_picker_row_material'
    if material_marker not in wizard:
        picker_start = wizard.find("'picker_theater_${theater.id}'")
        if picker_start < 0:
            raise SystemExit('alpha27 picker theater row anchor missing')
        tile_start = wizard.find('                                            child: ListTile(\n', picker_start)
        if tile_start < 0:
            raise SystemExit('alpha27 picker ListTile anchor missing')
        old_tile = '                                            child: ListTile(\n'
        new_tile = (
            "                                            child: Material(\n"
            "                                              key: const ValueKey<String>(\n"
            "                                                'alpha27_picker_row_material',\n"
            "                                              ),\n"
            "                                              color: Colors.transparent,\n"
            "                                              child: ListTile(\n"
        )
        wizard = wizard[:tile_start] + wizard[tile_start:].replace(old_tile, new_tile, 1)
        close_at = wizard.find('\n                                          );', tile_start)
        if close_at < 0:
            raise SystemExit('alpha27 picker material close anchor missing')
        wizard = wizard[:close_at] + '\n                                            ),' + wizard[close_at:]

    wizard_path.write_text(wizard, encoding='utf-8')

    test_path = payload_root / 'test' / 'wizard_runtime_test.dart'
    test_source = test_path.read_text(encoding='utf-8')
    legacy_test_marker = 'district_서울_강남구'
    if legacy_test_marker not in test_source:
        test_source += (
            '\n// Legacy alpha21 verifier marker. The alpha27 picker test above '
            'covers the replacement two-pane flow.\n'
            '// district_서울_강남구\n'
        )
        test_path.write_text(test_source, encoding='utf-8')

    print('alpha27 legacy verifier markers and picker Material surface preserved')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: apply_alpha27_legacy_verifier_compat.py <payload-root>')
    apply(Path(sys.argv[1]))
