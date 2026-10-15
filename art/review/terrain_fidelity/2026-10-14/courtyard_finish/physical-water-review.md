# Physical water — verified progress, art goal remains active

2026-10-15. Current captures: `water_final_*`, Godot 4.7.2 Forward+ Metal, Apple M4 Pro, 1671×941. Same-camera water baseline: `natural12_*` at `193fb65`; earlier island baseline `edge_final_*` at `3e4b06c` remains selectable in the [local gallery](comparison.html). Eleven captures, eight principal views inspected. Concepts are references, never runtime evidence.

## Retained change

The opaque painted-bed approximation is replaced by an actual mineral lake bed. It comes from the authoritative water contours and same-level authored cell bed heights, with a gentle 1.45 m ramp near supported banks, a short submerged bank to the waterline, and no raised sill at waterfall openings. Matching-level grass caps are excluded in both raw terrain and joined rim terrain. No source authoring data, island footprint, tree/building model or placement changes.

Global grid cuts include contour breakpoints, so adjacent displaced bed triangles agree. A 0.1 mm neighborhood weld removes clipping-roundoff cracks and collapsed/duplicate faces. Small legitimate grass/bed triangles survive source assembly and chunk clipping. Flat production lawn skips unnecessary detail tessellation; its displacement remains zero.

The water samples the already lit opaque bed through scene color/depth, uses mild normal-driven screen-space refraction and depth-dependent transmission, and retains local fall turbulence. Displaced samples are rejected at foreground/dry/depth discontinuities. This is a screen-space approximation, not full optical refraction: off-screen objects and full scene reflections are unavailable. Water is ordered before transparent foam/falls/mist, and no longer shadows the bed as an opaque sheet. Picking remains on the visible water surface; the bed is derived from the same editable authoring records. Wet shore material blends damp earth/mineral instead of exposing a green submerged step.

## Actual view assessment

| Matched view | Observation |
| --- | --- |
| Shore | Bed grain and lily/stone shadows are visible through blue-green water; shallow margins are softer. The edge still has a fairly even submerged band, and the bed remains visually simple. |
| Courtyard | Clearer water gives the pool depth while preserving the existing tree/cottage scene. Shore plants and rocks remain stylized. |
| Overview | Both water levels remain readable; foam and fall curtains retain their ordering. No new water opening or footprint change. |
| Reverse | Bed and plant shadows remain visible from the other side; screen-space approximation does not establish complete reflections. |
| Distance | Water reads as one coherent body. Broad wall panels remain the dominant silhouette problem. |
| Rim | Existing stone mineral response and physical turf are unchanged. Some turf ends still read as thin folded cards. |
| Ground | Grass/earth route and stone detail retained; physical lawn relief is still disabled. |
| Bottom | Calm continuous underside retained; pre-existing angular root/core intersections remain. |

Intermediate studies are preserved as stage evidence: `water1` failed shader compilation and is invalid visual evidence; `water2` first exposed the bed but obscured transparent foam; `water3` fixed ordering, quieted bed grain and widened shallows; `water4` dampened submerged shore material. `water_probe` is a rejected isolated reflection-probe study: it changed indirect scene lighting without useful reflection improvement, so no probe was integrated. Only `water_final` is selected.

## Verification and review

Full outputs: [water_final_checks.json](water_final_checks.json). All 55 headless terrain scripts and five scripts with a rendering device pass. Rendered editor 339/339, regeneration 42/42, cottage seven/zero failures; ground compression passes, sod compression 4382 standing pixels / zero fully compressed / 3468 local-mask pixels. These do not establish target-laptop performance.

The lake-bed test checks original source preservation, raw/joined coverage and grass removal, authored depth edits without contour movement, dry removal, finite geometry, and actual chunk-clipped mesh coverage. Follow-up: 417 probes, zero unmatched interior edges in both assembled and published bed meshes. Waterline top boundaries intentionally join the existing bank rather than closing the volume across the water surface.

One apparent dry-cap miss was a test-only numeric false negative: a point strictly inside a very thin actual triangle was rejected by Godot's general point-in-polygon query. Strict scalar barycentrics, unchanged boundary exclusion and the exact point's neighborhood now verify real ownership. No production diagonal change was made. Separately, scanline caps now always include edge-intersection rows, protecting new wet-hole callers as well as rim union. A synthetic crossing-hole fixture produced 28 errors on the old vertex-row-only path and zero now. The actual shared top retains 1625 single-top samples and ten supporting-side samples with zero failures. The old zero overlap counter in the output is not cited as coverage.

An independent reviewer reran bed and union checks, independently confirmed the skinny-triangle diagnosis and found no new Important technical defect. Its earlier published-chunk coverage caveat is addressed by the follow-up above. Shader/capture log has no compilation/script errors. The gallery was checked in the browser: pool view switches correctly, both baseline selections update the source, and images load.

## Open work

The user chose existing-source cliff refinement first, new custom models only if the actual integrated result remains inadequate. The inspected source pack and brief remain ready; no refined model has been received. Cliff slab proportions and turf-card silhouettes remain visibly below the reference. Water clarity is improved, but natural reflections and richer light response remain limited. Overall art goal stays active; this is a reversible functional water checkpoint, not final art acceptance.
