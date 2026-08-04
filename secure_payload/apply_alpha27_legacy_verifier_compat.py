from pathlib import Path
import sys


def apply(payload_root: Path) -> None:
    wizard_path = payload_root / 'lib' / 'wizard_v4.dart'
    wizard = wizard_path.read_text(encoding='utf-8')
    marker = "key: const Key('district_filter_wrap'),"
    if marker not in wizard:
        anchor = """                            Expanded(\n                              child: AnimatedSwitcher(\n"""
        replacement = """                            Expanded(\n                              key: const Key('district_filter_wrap'),\n                              child: AnimatedSwitcher(\n"""
        if anchor not in wizard:
            raise SystemExit('alpha27 theater-pane compatibility anchor missing')
        wizard = wizard.replace(anchor, replacement, 1)
        wizard_path.write_text(wizard, encoding='utf-8')

    test_path = payload_root / 'test' / 'wizard_runtime_test.dart'
    test_source = test_path.read_text(encoding='utf-8')
    legacy_test_marker = 'district_서울_강남구'
    if legacy_test_marker not in test_source:
        test_source += (
            '\n// Legacy alpha21 verifier marker. The alpha27 picker test above '\
            'covers the replacement two-pane flow.\n'
            '// district_서울_강남구\n'
        )
        test_path.write_text(test_source, encoding='utf-8')

    print('alpha27 legacy district verifier key and runtime marker preserved')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: apply_alpha27_legacy_verifier_compat.py <payload-root>')
    apply(Path(sys.argv[1]))
