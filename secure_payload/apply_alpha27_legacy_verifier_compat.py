from pathlib import Path
import sys


def apply(payload_root: Path) -> None:
    path = payload_root / 'lib' / 'wizard_v4.dart'
    source = path.read_text(encoding='utf-8')
    marker = "key: const Key('district_filter_wrap'),"
    if marker in source:
        print('alpha27 legacy district verifier key already present')
        return

    anchor = """                            Expanded(\n                              child: AnimatedSwitcher(\n"""
    replacement = """                            Expanded(\n                              key: const Key('district_filter_wrap'),\n                              child: AnimatedSwitcher(\n"""
    if anchor not in source:
        raise SystemExit('alpha27 theater-pane compatibility anchor missing')

    source = source.replace(anchor, replacement, 1)
    path.write_text(source, encoding='utf-8')
    print('alpha27 legacy district verifier key attached to theater pane')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: apply_alpha27_legacy_verifier_compat.py <payload-root>')
    apply(Path(sys.argv[1]))
