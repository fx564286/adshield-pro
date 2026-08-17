# Comfort Route / 쾌적길 review instructions

When reviewing changes under `comfort_route_sample/`, prioritize correctness and user-visible reliability over style nits.

Review specifically for:
- duplicate async work and race conditions in GPS acquisition, tracking start/stop, route requests, POI requests, MapLibre annotation sync, and TTS calls;
- stale async responses overwriting newer destination/route selections;
- incorrect route progress, remaining-distance, off-route, reroute, or next-maneuver calculations;
- route alternatives accidentally sharing geometry or maneuver state;
- OSRM step parsing errors, especially longitude/latitude ordering and cumulative maneuver distance;
- repeated, late, or misleading voice prompts after a maneuver has already been passed;
- voice prompts firing while off-route, GPS accuracy is poor, tracking is stopped, or voice guidance is disabled;
- TextToSpeech lifecycle leaks, calls after activity destruction, and platform-channel failures that crash Flutter;
- GPS accuracy handling and false reroutes caused by noisy positions;
- null/mounted/dispose lifecycle errors, platform-view issues, and callbacks firing after disposal;
- network timeout/error paths that leave loading flags stuck;
- map camera/annotation desynchronization between vector and fallback renderers;
- responsive UI overflow or inaccessible actions on 360x800 and larger phones;
- misleading UX: never label a heuristic or fallback as verified comfort/weather data;
- excessive use of public OSM/Nominatim/Overpass infrastructure; preserve debounce/cache/rate-limit behavior;
- signing/version/package regressions in the Android build workflow.

For route-mode work, require graceful fallback when the routing server returns fewer alternatives than requested. Do not assume three alternatives always exist.

For turn-by-turn work, unknown future OSRM maneuver types must degrade gracefully instead of throwing. Voice guidance must remain optional and navigation must continue if Android TTS is unavailable.
