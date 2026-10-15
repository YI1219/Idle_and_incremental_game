# Natural island finish — verified candidate, goal still active

2026-10-15. Baseline: `3e4b06c` / `edge_final_*`. Current: `natural12_*`, actual Godot 4.7.2 Forward+ Metal captures at 1671×941 on Apple M4 Pro. Capture harness: `tests/capture_courtyard_finish.gd`. Eight principal same-camera comparisons are available in `comparison.html`; three additional courtyard framing views are in the capture manifest. Concepts remain references, never engine evidence.

## Changes retained

- Retained Quaternius Rock_Medium_1/2 source shapes replace the old carved upper crown profiles, with four closed cut variants. No original source model changed. Deep roots remain a separate narrower, buried assembly over the continuous bottom.
- Exact concave cap boundaries and one joined lawn top fix missing ground slivers discovered in the first source-mesh trial. Wall-only crown meshes are drawn and included in picking; hidden authoring caps do not create ghost hits.
- Actual rotated source-shoulder extents fit around fall curtains. The previous nominal cap-width fit missed the source's wider lower shoulder and produced three obstructed probes; the current test records zero.
- Crease-aware normals soften shallow face changes without changing source topology/UV/color/material/bounds. Meaningful sharp breaks remain. Stone shaders honor mesh normals; per-triangle color jumps are reduced. The legacy procedural-crown color test now checks quiet mineral variation rather than requiring the former conspicuous minimum contrast.
- Existing packed maps remain, plus the versioned generated mineral albedo ([exact prompt/provenance](stone-material-generation.md)). It is shared with approximate shallow-bed detail. Lighting has quieter sunlight/ambient energy and softer shadow penumbrae.
- Smaller, less continuous sod patches have darker undersides and frayed tips. A stone overlap removes a complete patch rather than leaving cut-off triangles. World-space compression still works. Production lawn micro-displacement was withdrawn because it exposed fine scanline T-junction cracks; visible fine ground relief is currently material-normal relief.
- Water loses the conspicuous closed white surface-noise contours and has restrained view-dependent sky/near-bank response, depth absorption and shallow mineral detail. Fall grooves/opacity, foam and mist are quieter. This remains an opaque stylized approximation, not true refraction or a new physical lake bed.

## Same-camera inspection

| View | Evidence | Assessment / remaining |
| --- | --- | --- |
| Whole island | `edge_final_overview.png` → `natural12_overview.png` | Quieter face paint and less stark illumination; trees/building/overall island retained. Upper wall still has too many broad pale slabs. |
| Distance | `edge_final_distant.png` → `natural12_distant.png` | Continuous floating mass remains readable. Local rock accents survive at this scale; fine texture cannot fix silhouette. |
| Rim/contact | `edge_final_rim.png` → `natural12_rim.png` | Source shoulders and smaller cover are less harsh; no continuous grey lip added. Some turf ends still look like cards and mass proportions remain too broad. |
| Ground | `edge_final_ground.png` → `natural12_ground.png` | Existing grass/earth route, new stone mineral detail and compression path retained. Physical ground micro-displacement is off. |
| Shore | `edge_final_shore.png` → `natural12_shore.png` | White noise lines reduced, visible body/bank variation restored after an over-muted trial. Water is still too opaque for reference-level clarity. |
| Reverse | `edge_final_reverse.png` → `natural12_reverse.png` | Material response stays coherent around the island; coarse source shapes remain apparent. |
| Bottom | `edge_final_bottom.png` → `natural12_bottom.png` | Calm continuous underside retained. Some angular root/envelope transitions remain visible at low angle. |
| Courtyard | `edge_final_courtyard.png` → `natural12_courtyard.png` | Original cottage/trees retained; stone/water finish softened. Does not establish concept parity. |

Intermediate trials: natural1 was waxy; natural3 had over-pale reflection streaks; natural5–8 exposed top/cap and micro-displacement seams, so those are not selected. natural9 repaired closure/seams; natural10 added mineral albedo; natural11 fixed actual curtain clearance and sod patch clipping; natural12 strengthens water absorption and reduces neutral reflection haze.

## Fresh functional evidence

Full output: [natural12_checks.json](natural12_checks.json). All 59 terrain test scripts were run: 54 headless and five with a rendering device. Commands use `/opt/homebrew/bin/godot --headless --path . --script tests/<name>.gd` for headless cases and omit `--headless` for render cases.

- 54/54 headless scripts pass, including all four source crown closures, concave cap-join coverage, rim union/closure/rhythm, stone volumes, bottom closure, fall clearance, outcrop/shrub support, vine contact, picking/editor/runtime/data/snapshot checks and frozen authoring-source preservation.
- Rendered editor: 339/339. Rendered decoration regeneration: 42/42. Cottage materials: seven checks, zero failures.
- Grass compression render passes. Sod compression: 4382 standing pixels, zero fully compressed pixels, 3468 within local-mask test, passes.
- Eight principal matched screenshots (11 total) reviewed. Shader compilation/capture log has no script/shader errors. `git diff --check` passes.

Scope limits: source closure covers the four selected profiles, contact/support checks sample their named fixtures, and no test proves every leaf or arbitrary future layout. `terrain_lawn_relief_test` covers a helper's default behavior; production passes zero relief. These results are not final art acceptance or a target MacBook Air/Windows laptop performance measurement.

## Remaining work

The visual goal remains active. The next useful change is cliff mass proportion and neighbor rhythm, followed by the remaining turf-card and opaque-water feel. Texture alone cannot repair broad slab silhouettes; inspect retained-source proportions before requesting custom assets. If a new custom cliff set becomes essential, first show this exact deficiency and make a batched user-operated asset decision. No new model-production task is published or ready for submission.

## Independent review and follow-up

A separate reviewer independently reran four source closures, cap joins (41/0 missing), union (1642 single-top + 10 side probes/0 failures) and curtain clearance (140/0 intersections). No Critical or Important correctness issue remained for a reversible progress commit; visual acceptance remained incomplete.

Three Minor findings were addressed: enable mineral-map mipmaps and extend the existing map check (new map first failed, then passed); restore the historical October11 compression record and save this round under October14; retire the old per-crown alpha/UV tint probe that selected zero shared-top triangles, keeping its real footprint/chip/cap-hole checks and the new join/union coverage. Both affected headless checks passed again. `natural12` captures were rerun after mipmap import, with unchanged cameras. New screenshots remain local under the repository's review-binary policy; code, runtime texture, manifests, generator and reports are committed.
