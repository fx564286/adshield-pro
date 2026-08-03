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

edit_card_marker = "const ValueKey('edit_schedule_button')"
if edit_card_marker not in text:
    seat_anchor = '''        const SizedBox(height: 16),
        if (_loadingSeats)
'''
    if seat_anchor not in text:
        raise SystemExit('alpha22 edit card insertion anchor missing')
    edit_card = '''        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '감시 일정 수정',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '좌석 조건은 유지한 채 날짜·상영시간 또는 영화관을 다시 선택할 수 있습니다.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const ValueKey('edit_schedule_button'),
                        onPressed: _openScheduleEditor,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text(
                          '일정 변경',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const ValueKey('edit_theater_button'),
                        onPressed: _openTheaterEditor,
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text(
                          '영화관 변경',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingSeats)
'''
    text = text.replace(seat_anchor, edit_card, 1)

required = [
    'String _bookingUrlFor(Theater theater, Showtime showtime)',
    '_bookingUrlFor(theater, showtime)',
    "const ValueKey('edit_schedule_button')",
    "const ValueKey('edit_theater_button')",
    'onPressed: _openScheduleEditor',
    'onPressed: _openTheaterEditor',
]
missing = [token for token in required if token not in text]
if missing:
    raise SystemExit(f'alpha22 helper/card repair incomplete: {missing}')

path.write_text(text, encoding='utf-8')
print('alpha22 booking helper and consistent edit card restored')
