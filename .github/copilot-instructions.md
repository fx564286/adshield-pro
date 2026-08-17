# Comfort Route / 쾌적길 review instructions

When reviewing changes under `comfort_route_sample/`, prioritize correctness and user-visible reliability over style nits.

Review specifically for:
- duplicate async work and race conditions in GPS acquisition, tracking start/stop, route requests, POI requests, and MapLibre annotation sync;
- stale async responses overwriting newer destination/route selections;
- incorrect route progress, remaining-distance, off-route, and reroute calculations;
- route alternatives accidentally sharing or overwriting mutable state;
- GPS accuracy handling and false reroutes caused by noisy positions;
- null/mounted/dispose lifecycle errors, platform-view issues, and callbacks firing after disposal;
- network timeout/error paths that leave loading flags stuck;
- map camera/annotation desynchronization between vector and fallback renderers;
- responsive UI overflow or inaccessible actions on 360x800 and larger phones;
- misleading UX: never label a heuristic or fallback as verified comfort/weather data;
- excessive use of public OSM/Nominatim/Overpass infrastructure; preserve debounce/cache/rate-limit behavior;
- signing/version/package regressions in the Android build workflow.

For route-mode work, require graceful fallback when the routing server returns fewer alternatives than requested. Do not assume three alternatives always exist.
