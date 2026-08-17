from pathlib import Path

source_path = Path('comfort_route_sample/tools/apply_v066_gps_korean_map.py')
source = source_path.read_text()
source = source.replace(
    "small_action_anchor = 'class _SmallAction extends StatelessWidget {\\n'",
    "small_action_anchor = 'class _CurrentLocationMarker extends StatelessWidget {\\n'",
    1,
)
source = source.replace(
    "raise SystemExit('SmallAction class anchor missing')",
    "raise SystemExit('CurrentLocationMarker class anchor missing')",
    1,
)
exec(compile(source, str(source_path), 'exec'))
