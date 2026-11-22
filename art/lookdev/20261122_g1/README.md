# Checkpoint G1: generator and look direction (2026-11-22)

This is the plan's first checkpoint (`docs/engine_refactor_plan.md`, phase 1). It shows where the runtime's picture is heading and what the first studies measured. It is a "show and continue" checkpoint: work goes on along the picks below unless the owner redirects.

Open `compare.html` in this folder. Nothing here is art-accepted.

What the runtime frames are: output of throwaway study code (`runtime/spikes/s34_study/`) on procedural stand-in content. Trees, rocks and stepping stones are generated, not modelled; there are no buildings and no character; everything is a still. They show a direction, not a finished look. The left-hand frames are the Godot project frozen at tag `godot-freeze-20261122`, captured at the same 3024x1964 with the same cells and cameras.

## Picks

These are the agent's calls, made on the frames in `compare.html`. Any of them can be overruled.

1. **Body of the island: hanging rock on a liner** (section E, right-hand frames), not the plain faceted hull (left-hand frames). The hull is one inverted low-polygon terrain; it is closed and cheap but reads as a shallow bowl with no faces. The hanging-rock body keeps that hull as a hidden liner and adds two tiers of rock columns: rim faces in a broad-and-narrow rhythm with shelves and shoulders, and deeper masses behind them. It has vertical weight, depth between the tiers, and a root that dissolves into the mist.
2. **Look: line and flat wash** (look B in section D). Forms are drawn with a warm dark line, heavier on silhouettes than on inner creases; light is gathered into two flat washes on stone and ground and three on foliage; shade on a face is one of two washes depending on which way it turns. Look A (the same lighting with no line and smooth shading) is the safe fallback and reads as a clean low-polygon picture, close in kind to today's. Look C adds brushwork: its first form was soft smudges and was thrown out; its second form is sparse hard-edged dry strokes on rock, which is promising for large faces and is kept as an accent to decide on real surfaces later.
3. **Ground of the picture: warm silk paper.** The cloud sea, the mist the root dissolves into, and the far distance are one pale warm tone with soft cool bands. It is what keeps the frame calm and gives the island its weight by contrast.
4. **Terraces: smooth in plan, cut rock in section.** Terrace edges follow smooth curves derived from the cells, and each step is a near-vertical cut face.
5. **Colour is authored as display values and written as authored.** No tone curve, no bloom, no blur, no fog veil.

## What to look at first

1. Section A, `whole` and `game`: the same island in both renderers.
2. Section A, `reverse` and `foot_reverse`: the back wall, which was the open form problem in Godot (a row of like-width slabs).
3. Section F, the three-island wallpaper view by day and at dusk.
4. `study/s3_look_b/small/s3_look_b_whole_crop.png`: a crop at native pixels, for line quality and sharpness.
5. Section B: dusk and night.

## How the study frames score against the art goal

The art goal is in section 3.1 of the plan. Numbers are measured on the written frames by the study tool (`metrics.json` in each run folder; table in section D of the page).

| Property | Check | Measured (look B, `whole` view) |
| --- | --- | --- |
| Comfortable all day | nothing large near white or black | by day: median luminance 0.82, 95th percentile 0.87, 0.1% of the frame above 0.94, none below 0.08 |
| | night is mid-tones, not a dark screen | at night: 5th percentile 0.27, median 0.44, 95th percentile 0.53 |
| | room for icons and windows | 63% of the frame is near-flat in the `whole` view, 69% in the three-island wallpaper view (share of 32x32 blocks with almost no detail) |
| Easy colour | saturation stays moderate | mean saturation 0.17 by day, 0.26 at dusk, 0.32 at night; the 99th percentile by day is 0.51 |
| Classical atmosphere | layers, reserved paper, drawn forms, foliage as masses | by eye only: see the picks; the agent's view is that B reads as a drawn picture and A does not |
| Naturally sharp, not muddy | no blur, glow or veil; clean edges | no such pass exists in the frame; four samples per pixel; see the native crop |

Not checked: anything in motion (water, falls, gusts, the camera stopping). The study writes stills.

## Generator study (S4)

All numbers are for the chosen body on the rim plan it shares with the hull. Table in section E of the page.

| Layout | Cells | Faces | Columns | Face widths | Longest alike run | Building the whole island |
| --- | --- | --- | --- | --- | --- | --- |
| 7301 (default) | 623 | 27 | 72 | 2.0 to 5.7 m | 3 faces, 8.7 m | about 40 ms |
| 2104 | 623 | 24 | 67 | 2.0 to 6.4 m | 3 faces, 12.6 m | 40 ms |
| 4242 | 503 | 27 | 64 | 2.0 to 6.9 m | 2 faces, 5.2 m | 35 ms |
| 913 | 571 | 25 | 62 | 2.0 to 6.9 m | 2 faces, 9.0 m | 36 ms |
| generated, design size | 4,096 | 64 | 395 | 2.0 to 6.6 m | 4 faces, 18.4 m | 172 ms |

- **Form.** A rim is cut into faces by a local rule, then long faces are paired into one broad and one narrow. "Longest alike run" counts neighbouring faces within a quarter of each other's width and within 0.3 m of each other's step. For orientation only, since the measure is not the same: Godot's reverse-wall study counted its longest plain row at 9 slabs and 38.1 m on seed 7301 before its stagger pass and 4 slabs and 21.8 m after.
- **Locality.** Three scripted strokes at the rim per layout (add a 3x3 patch, remove one, raise one). On all five islands no face changed farther than 12 m from a stroke; the farthest change was 11.3 m. Two of the three strokes on layout 913 changed no face at all, so they tested nothing there. The first version of the plan failed this for strokes that change the outline, because outline points were spaced by arc length from a start point and all slid together; they are now anchored to a world lattice.
- **Time.** Building a whole island (fields, top surface, body and stand-in content) takes 35 to 40 ms for the review layouts and 172 ms for 4,096 cells, on one thread. This is a rebuild of everything, with no incremental update at all.
- **Closed from below.** The `below` view of layout 7301 shows no opening. That is one view of one layout, by eye, not a proof.

Known defects of this construction, to be dealt with when it is built for real:

- thin slivers where two blocks pass through each other at a shallow angle;
- the liner's triangles show in the gaps between blocks, clearly so from below;
- blocks are leaning prisms with one bedding step; there are no true overhangs, arches or caves;
- the rhythm comes from a hash of position, not from composition: it does not know where the main view is;
- the faces of large blocks are still plain apart from line, gradient and the optional strokes. What a large face should carry is still open;
- terrace edges on shallow diagonals still show steps about a cell long (visible on the 4,096-cell island): the level-set blur is too narrow for long stairs, and each terrace contour should be relaxed the way the outline is.

## Look study (S3)

- **A, B, C** on six views: section D.
- **Hours:** section B (against Godot) and section F. Day and dusk were tuned; night was only checked for value range and needs its own pass (lantern light, the moon, the falls are too bright).
- **Several islands:** section F. The other two islands are the 4242 and 913 layouts built by the same code at other positions and heights.

## Cost

Table in section G of the page. Off screen on the M4 Pro at 3024x1964, the study's real look:

- with four samples per pixel (drawn at 6048x3928 and filtered down): 5.2 to 6.0 ms a frame for one island, 5.3 to 5.6 ms with three islands in view, 6.7 to 8.5 ms for a 4,096-cell island;
- with one sample per pixel: 1.7 to 1.9 ms a frame.

The plan's budgets are 12 ms moving and 4 ms still. The still path was measured in spike S2 (0.5 ms) and is not measured again here. Nothing here says anything about a thin laptop.

## What is not in these frames

- Real assets: buildings, the cultivator, authored trees and props. The stand-ins are simpler than Godot's models, most visibly the lawn (a painted surface with sparse tufts against Godot's dense blades) and the scholar's rock.
- Motion of any kind, including the wind gusts and the still-camera cache.
- The production loop, facilities, conduits, HUD.
- Baked occlusion and bounce from real geometry: the study uses simple stand-in terms.
- Falls and ponds from the planned source-driven water model: here the cells' water flags stand in for filled basins.

## What happens next

Unless redirected: phase 2 of the plan (the shared runtime core and the headless simulation, with the production traces already exported to `runtime/data/reference/production_trace.json` as its oracle), then phase 3 and 4 building the generator and renderer for real from the picks above.

## Files

- `compare.html`, rebuilt by `checks/build_compare.py`.
- `godot_baseline/<set>/`: 72 Godot frames at 3024x1964 (six sets of twelve cameras), each with `captures.json`; captured with `tools/export/capture_reference.gd`.
- `study/<run>/`: runtime study frames, reduced copies in `small/`, numbers in `metrics.json`, the tool's output in `<run>.log` beside the folder.
- Pictures are not tracked in git; the scripts, logs and numbers are.
