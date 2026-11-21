# Non-water rendering work

User asks to continue beyond water while preserving cliff color and lighting. Approved existing performance scope, same project and entry.

1. Measure candidates in memory before changing production. Frozen explicit-draw probe suffered drift/sky recompilation cost; do not use it as gain evidence. Separate normal live 4s+6s runs show no reliable throughput benefit for noise reuse, cloud math reorder or no-transition-discard. Reject those candidates.
2. Fix sky radiance scheduling for slow daylight changes: keep the same high quality importance filter and radiance resolution, spread routine updates across frames. Initial/manual palette requests retain QUALITY for at least one rendered frame; regular ticks then use INCREMENTAL. No lighting/color/material constant changes.
3. RED→GREEN native scheduling contract, held-seed/angle/day-night actual images, dynamic preset-transition comparison, normal ABBA 2K/4K/4K-scaled frame-time runs, current-stage suite and independent review. Retain only measured improvement; report throughput separately from slow frames and power.
4. Close this task's Godot windows/processes, leave original editor. Update concise current record. Larger background/vegetation/terrain strategies remain proposals unless implemented and verified.

Completion: actual implementation is only time_solar_system scheduling plus8-check native regression (RED2→GREEN0). Manual/initial updates hold QUALITY until after a drawn frame; slow ticks use same-quality INCREMENTAL. Native ABBA FPS1–1.5%, P95 improvement1.6–2.1ms.30native2K images/15pairs exact;168dynamic lowres diagnostic frames and18full640 keyframes within1/255.33current-stage groups pass; independent review no Important. Hidden independent SubViewport remains out of scope. All candidate shader rewrites rejected. Normal entry90frames passes; original editor retained, no task Godot process.
