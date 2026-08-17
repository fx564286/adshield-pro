# Comfort Route / 쾌적길 review instructions

When reviewing changes under `comfort_route_sample/`, prioritize correctness and user-visible reliability over style nits.

Review specifically for:
- duplicate async work and race conditions in GPS acquisition/refinement, tracking start/stop, route requests, POI requests, MapLibre annotation/style sync, and TTS calls;
- stale async responses overwriting newer destination/route selections;
- incorrect route progress, remaining-distance, off-route, reroute, or next-maneuver calculations;
- route alternatives accidentally sharing geometry or maneuver state;
- OSRM step parsing errors, especially longitude/latitude ordering and cumulative maneuver distance;
- repeated, late, or misleading voice prompts after a maneuver has already been passed;
- voice prompts firing while off-route, GPS accuracy is poor, tracking is stopped, or voice guidance is disabled;
- TextToSpeech lifecycle leaks, calls after activity destruction, and platform-channel failures that crash Flutter;
- GPS quality semantics: distanceFilter is not accuracy, >45m fixes must not drive route progress/off-route/voice, and a worse raw fix must not overwrite a usable navigation fix;
- reduced/approximate location permission and whether user-facing diagnostics explain it without claiming impossible precision;
- GPS refinement stream leaks or concurrent refinement/tracking subscriptions that persist after completion;
- GPS stabilizer behavior: plausible bicycle motion must not be rejected, one-frame teleport jumps must not change accepted navigation state, and smoothing must never rewrite or advertise a smaller sensor accuracy value;
- Fused provider configuration: keep `forceLocationManager: false`; `distanceFilter: 2` is an update condition, never described as 2m accuracy;
- display-only route snapping must not feed off-route detection, rerouting, route progress, or TTS decisions; it must disengage when route departure is suspected;
- MapLibre Korean/native-first label patching: preserve complete symbol layer properties, never rewrite ref/IATA/elevation/housenumber labels, and fail open to the original map style;
- map camera/annotation/style desynchronization between vector and fallback renderers;
- OSM amenity signals must remain explicitly unverified; unnamed toilets/water/shelters need safe fallback names without fabricating operating status;
- responsive UI overflow or inaccessible actions on 360x800 and larger phones;
- misleading UX: never label a heuristic or fallback as verified comfort/weather data;
- excessive use of public OSM/Nominatim/Overpass infrastructure; preserve debounce/cache/rate-limit behavior;
- signing/version/package regressions in the Android build workflow.

For route-mode work, require graceful fallback when the routing server returns fewer alternatives than requested. Do not assume three alternatives always exist.

For turn-by-turn work, unknown future OSRM maneuver types must degrade gracefully instead of throwing. Voice guidance must remain optional and navigation must continue if Android TTS is unavailable.

For v0.6.6 GPS/map work, treat 100m-class fixes as display-only diagnostics, not navigation-grade positions. Korean label localization must prefer name:ko/name:nonlatin/native name and only fall back to Latin/English when native labels are absent.

For v0.6.7, distinguish three concepts in review: sensor-reported uncertainty, stabilized navigation coordinate, and optional visual route snap. Only the first is an accuracy measurement. The latter two may improve stability but must never be presented as hardware GNSS accuracy.
