from pathlib import Path
import re
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'secure_runtime/source/payload')
path = root / 'lib/wizard_v4.dart'
if not path.exists():
    raise SystemExit(f'wizard source missing: {path}')

text = path.read_text(encoding='utf-8')
anchor = '  Future<void> _openBooking'
method = '''  String _bookingUrlFor(Theater theater, Showtime showtime) {
    return theater.chain.bookingUrl;
  }

'''

text, replaced = re.subn(
    r'  String _bookingUrlFor\([^)]*\) \{.*?\n  \}\n\n',
    method,
    text,
    count=1,
    flags=re.S,
)

if replaced == 0:
    if anchor not in text:
        raise SystemExit('alpha22 booking helper anchor missing')
    text = text.replace(anchor, method + anchor, 1)

if 'String _bookingUrlFor(Theater theater, Showtime showtime)' not in text:
    raise SystemExit('alpha22 booking URL helper signature was not restored')
if '_bookingUrlFor(theater, showtime)' not in text:
    raise SystemExit('alpha22 booking URL call signature mismatch')

path.write_text(text, encoding='utf-8')
print('alpha22 booking URL helper restored with theater and showtime')
