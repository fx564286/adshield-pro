from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'secure_runtime/source/payload')
path = root / 'lib/wizard_v4.dart'
if not path.exists():
    raise SystemExit(f'wizard source missing: {path}')

text = path.read_text(encoding='utf-8')
usage = '_bookingUrlFor('
declaration = 'String _bookingUrlFor('

if usage in text and declaration not in text:
    anchor = '  Future<void> _openBooking'
    if anchor not in text:
        raise SystemExit('alpha22 booking helper anchor missing')
    method = '''  String _bookingUrlFor(Showtime showtime) {
    final theater = _theater;
    return theater?.chain.bookingUrl ?? CinemaChain.cgv.bookingUrl;
  }

'''
    text = text.replace(anchor, method + anchor, 1)

if declaration not in text:
    raise SystemExit('alpha22 booking URL helper was not restored')

path.write_text(text, encoding='utf-8')
print('alpha22 booking URL helper restored')
