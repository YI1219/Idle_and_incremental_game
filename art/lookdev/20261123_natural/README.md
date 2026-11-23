# The natural look: runtime against the Godot baseline (2026-11-23)

## What to look at, and what is asked of you

Open `compare.html` in this folder (it opens from disk; click any frame for the full 3024x1964 picture). Each row puts the frozen Godot build on the left and the new runtime on the right: same island cells, same cameras, same hour.

My judgement: the runtime picture is now at the Godot baseline's level of clean, natural and comfortable, with the hanging-rock island body you asked to keep, and it costs 5 to 7 ms a frame while the camera moves, where Godot needed 14 to 38 ms for the same island at the same resolution. Whether the look is right is yours to decide: accept it, or send it back with what is wrong. Nothing here is art-accepted until you say so.

Worth a close look:

- Day, layout 7301, all twelve views, at the top of the page.
- The native-pixel crops: the same rectangle from each full frame, not scaled, for Godot, the runtime when the camera rests, and the runtime while it moves. This is where lawn, stone and water can be compared as surfaces.
- Dusk and night, and the other three layouts.
- Runtime only: three islands in the wallpaper view at three hours, and a full 4,096-cell island.

## What was kept and what was dropped after your G1 review

Kept: the hanging-rock construction of the island body (rock columns in two tiers hung on a hidden liner, faces of uneven width), and the generator behind it, which still keeps every edit local.

Dropped: look B, the ink line and flat washes on a silk-paper ground, and with it the drawn outlines, the paper grain and the painted-dab foliage. The picture was rebuilt toward Godot's own: natural light, real trees and props, a plush lawn, painted stone, jade water and a soft cloud sea.

## How the picture is made

Ported from the frozen Godot project, by reading its shaders and exporting its data: the trees, bushes, rocks, bench, lantern, scholar's rock and stepping stones (the exported meshes and textures, drawn by ports of Godot's three prop shaders); the broad-leaf rosette lawn; the stone painting (wash, brush planes, dry strokes and the mossy brow under the lawn's edge); the pond ripples and light lines and the waterfall threads; the painted sky, six cloud decks and three rings of far hills, placed where Godot placed them; the three times of day, from Godot's own light and colour presets; and its tone curve.

New in the runtime: the island itself (rim plan, hanging rock, smooth terrace walls cut along straightened steps, ponds held by their banks, falls placed in notches), lighting computed in linear light with a soft shadow map that is only redrawn when the sun moves, screen-space occlusion (the soft darkening in corners) at half resolution, mirror reflections in the ponds, and the mist under the island. Colours are written as you see them on screen and converted once, which keeps them from washing out.

## The numbers

All measured on this Mac (M4 Pro, mains power) at the screen's native 3024x1964, off screen, 120 frames with the camera orbiting. The plan's budget for a moving camera is 12 ms a frame.

| What | Runtime | Budget | Godot at the same size |
| --- | --- | --- | --- |
| One island, camera moving (12 review views) | 5.2 to 7.0 ms | 12 ms | light tier 13.7 to 18.9 ms, default 22.4 to 29.4 ms, native 29.3 to 38.4 ms |
| Three islands, wallpaper view, moving | 6.1 ms | 12 ms | no counterpart |
| The 4,096-cell island, moving (whole, game) | 10.4 and 11.1 ms | 12 ms | no counterpart |
| Resting camera, 2x supersampling (whole, game) | 20.3 and 21.7 ms | paid once when the camera stops | |

The resting mode is what the stills use. It is paid when the camera comes to rest and the picture is kept; it is not a per-frame cost. Godot's figures are from the freeze bench (`../20261122_freeze/README.md`).

Building an island from its cells, with props and grass: 58 ms for the 623-cell layout, 246 ms for 4,096 cells, from scratch every time (there is no incremental update yet).

Edit locality: three scripted strokes at the rim of each of five islands (the four review layouts and the 4,096-cell island). No rim face changed farther than 12 m from a stroke; the farthest change was 11.3 m away. Lines are in `final/edit_test.log`.

Colour: the page has a table of measured boxes (lawn, terrace wall, pond, block face, sky, clouds, and the cliff, lawn and cloud at dusk and night), Godot against runtime. Most agree within 0.02 of full scale per channel; the day lawn is 0.04 brighter, the sunlit block face 0.05 warmer, and the right-hand cloud 0.03 darker.

## Known differences and limits

- The three-island wallpaper view still uses a simpler cloud sea and no far hills. Godot's far field was authored for its steep review cameras and thins out toward the horizon at the wallpaper's low camera.
- The far hills at the top left of the `whole` view sit differently from Godot's.
- Godot's far depth-of-field blur is not ported; distant things are paler, not blurred.
- No sparkle glints on the water.
- The 4,096-cell island with real props runs at 10 to 11 ms, close to the budget, because the cut-out leaf cards of the trees are drawn over each other many times and props have no simpler versions for distance yet.
- Nothing is animated in these stills. Wind, water motion and the falls are built to move and are shown frozen.
- Thin shaded joints remain at a few places where three terrace steps meet; they show rock in shadow, not the inside of the island.
- All of this is study-tool code, to be rebuilt in the real renderer.

## If you accept

Phase 2 of the plan starts: the shared runtime core and the simulation that runs without a window, tested against traces of the Godot production simulation. The look carries forward as the reference for the real renderer in phase 4.

## What is in this folder

- `compare.html`: the comparison page, made by `checks/build_compare.py` from the frames on disk.
- `final/`: the frames (full size and `small/` copies), each run's `metrics.json` and log, the benches, `edit_test.log` and `crops/`.
- `checks/`: `build_compare.py`, `measure_boxes.py` and `boxes.json` (the colour boxes), `make_crops.py`, and the Godot regression run (`suite.json`, `suite.log`).
- The Godot reference frames are in `../20261122_g1/godot_baseline/`. Pictures are not in git.
