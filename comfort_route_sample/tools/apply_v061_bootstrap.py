from pathlib import Path

source_path = Path('comfort_route_sample/tools/apply_v061.py')
source = source_path.read_text()
source = source.replace(
    "poi_methods = r'''  void _scheduleNearbyPoiRefresh",
    'poi_methods = r"""  void _scheduleNearbyPoiRefresh',
    1,
)
source = source.replace(
    "  void _copyLogs() {\n'''\nif insert_anchor",
    '  void _copyLogs() {\n"""\nif insert_anchor',
    1,
)
exec(compile(source, str(source_path), 'exec'))
