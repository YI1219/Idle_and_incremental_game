# Floating island: unified bottom and terrain joins

Date: 2026-10-11. Baseline: `f39052c`. Continued in the existing checkout without resetting. The retained result is the strongest of this round's studies; it is ready for owner art review, not a claim of equal beauty to the concept.

## Visual result

Open the [concept and matched before/after gallery](comparison.html). Its five fixed cameras show overall composition, bottom, side join, rim/turf and pond shore. Twelve additional elevated/low orbit views expose the back and underside. All comparison images are actual 1671 × 941 Godot runtime captures under unchanged lighting; water animation phase can differ. The concept is separately labeled.

The bottom now has one continuous interior face with shallow asymmetric variation. It is excluded from the individual mantle-block extrusion, removing the layered slabs through its center. Side backing recession fades toward the base; shared cap/wall vertices remain welded at shallow terrace feet. The center has no radial keel.

Small rounded, closed turf patches replace pointed double-lobed flaps, drape over actual crown faces, and share the lawn's greener palette. Shore crests have more irregular scallops, feather into dry lawn and darken at the waterline. Existing cliff, mantle and shore stones share restrained mineral shading. Shore stones were toned down after a chalky intermediate study. Existing stone meshes and placement remain.

## Studies and stopping decision

- Studies 1–2 established the continuous bottom and removed its painted cell pattern.
- Studies 3–4 tested turf coverage and replaced pointed flaps with rounded supported patches.
- Studies 5–6 unified stone materials, restrained bright shore rocks, improved bank joins and tuned the grass palette. Study 6 is the retained visual basis.
- Study 7 increased underside undulation. It made the face busier without a defensible improvement in side continuity; reverted.
- Study 8 made turf patches broader and less frequent. It emphasized a manufactured border; reverted.
- Study 9 smoothed shared base normals. It did not improve the angular join and softened stone character; reverted.
- The final version adds the independently reviewed seam repair to the retained basis. All 17 final images were recaptured afterward.

Two materially different follow-up studies failed to improve the retained version, satisfying the goal's plateau rule. Extreme low views still show an angular floor-to-side bend and a broad flat interior. This is the remaining artistic tradeoff: stronger geometric relief compromised the requested calmness, while smoother shading weakened the stone. No objective beauty parity or owner approval is claimed.

## Fresh verification

- [46/46 headless terrain suites](tests.json), on the final implementation.
- [42/42 rendered regeneration checks](regeneration.json), using Godot 4.7.2, Forward+ on Apple M4 Pro.
- [Frozen geometry comparison](frozen_geometry.json): exact matching hashes for authored cells, rim regions, pond vertices and waterfall vertices against this round's baseline.
- Default, expansion, contraction and deep-lower integration fixtures: zero missing base samples, open mantle edges, lawn leaks or buried vine centers; zero movement in remote mantle and continuous cap vertices.
- New calm-bottom regression: 259 interior probes, zero misses, layered hits or steep faces. Baseline failed with 242 layered hits and 180 steep faces.
- New seam regression: 20 shared vertex entries at five heights; six split entries (up to 0.227 m) before repair, zero separation afterward. [Red/green evidence](regression_evidence.json).
- Rendered moss compression: 7,900 visible standing pixels, zero fully compressed, 5,843 with a local mask; [evidence](lip_compression_render.json).
- [Independent review](independent_review.md) found the shared-vertex defect above; repaired and freshly verified. No other concrete shore/turf/material regression found.
- [Final capture metadata](after_captures.json): 17 images, zero save errors. Functional tests are not visual acceptance.

No cottage, character, custom source asset, authored layout, waterfall shader or global lighting change. The renderer still derives terrain and detail from editable build data. No target laptop performance or long-idle acceptance was measured this round; current-host captures cannot establish those targets.

## Reproduction and evidence storage

Run `godot --path . --script tests/capture_island_goal.gd -- after orbit` for final views. Run each script named in `tests.json` with `godot --headless --path . --script <script>`; rendered regeneration uses the command recorded in its JSON report. Compression uses `tests/terrain_rim_green_render_test.gd` (see its argument defaults before regenerating).

PNG captures and the local HTML gallery are retained in this directory under the repository's existing ignored-review-artifact policy. Source, tests, review notes and JSON evidence are committed. The original supplied concept is preserved locally as `concept.png`.
