# The natural look, second review (2026-11-24)

## What is asked of you

Open `compare.html` in this folder (it opens from disk; click any picture for the full 3024x1964 frame).

The four things you asked for after the first review are at the top of the page, in your order, each with the picture before the change, after it, and the Godot reference: the hollow joint in the terrace wall, buildable slopes and ramps, rock walls aligned with the Godot baseline, and clearer water. Nothing else was changed on purpose; the rest of the page is the full set of views again (day, dusk, night, the other three layouts, the three-island view and the large island) so you can check that nothing else moved.

This is still yours to accept or send back. The next phase has not started and will not start until you accept the look.

## 1. The hollow joint (day, `game` view)

What it was: left of the waterfall, a joint in the middle terrace wall looked like a hole into the island. Two faults met there: a patch of lower lawn was painted as if it were a pond bed (the dark cavity), and where three terrace steps meet, the walls left a slit through which the wall's back side showed.

What was done: the lawn is now lawn, and terrace walls turn corners as one continuous piece of stone with their feet set into the ground. Every other place where a wall, a grassy bank or a ramp meets the island's edge was checked and closed the same way.

What to look at: your own crop, then the same rectangle before, after and in Godot. The cavity and the slit are gone; the joint is a plain stone corner with lawn in front.

Not perfect: the stones and plants around the joint are placed a little differently from Godot's, as before.

## 2. Slopes and ramps

What it was: you asked for slopes and ramps to be buildable.

What was done: a cell of the island can now carry a slope. A ramp is drawn as a stroke from a point on one terrace to a point on another, with a width; every cell under that strip becomes part of one inclined plane from the first height to the second. A stroke is refused if either end is in water or off the island, if it is shorter than 2 m, steeper than about 31 degrees, joins two equal heights, or would cover water. The island then joins the surfaces by itself: a soft grassy bank where the ramp's side rises only a little above the lawn beside it, and a wedge of cut rock (a "cheek") where it rises a lot. Ramps work in any direction, including diagonals, and an edit changes only the island near the stroke.

What to look at: six camera views made for this (`ramp1`, `ramp2`, `ramp3` on layout 7301 with three ramps joining its four lawn levels; `slope` on layout 4242 with a broad hillside; `diag1`, `diag2` on layout 2104 with two diagonal ramps), each beside the same view of the plain layout, plus close-ups at full resolution; then the 7301 ramps layout in the `game`, `terrace_close` and `close` views, at dusk and night, and in the moving-camera mode. The edit test is in the Cost section.

Not perfect: grass covers a ramp like any lawn, so in the general views ramps read gently; that is why they have their own views. A ramp is a flat plane per cell with rounded creases between cells, not yet a free-form hill tool. Where a ramp passes close to a wall, the rock cheek under it can leave a shaded pocket of lawn (visible at the right of `ramp1`).

## 3. Rock walls

What it was: you asked for the rock walls, and the size and arrangement of their blocks, to align with the Godot baseline.

What was done: the island's cliff is now made of tall faces that run the full height, with a few large wedge-topped slabs standing against them, sized after Godot's own cliff scripts, and painted in Godot's warm beige with its strong contrast between sun and shade. The hanging rock columns under the island are fewer and fade into the cloud behind them. Rock faces that face the camera now carry a lawn cap with a grass fringe instead of a bare stone ledge. The hanging-rock construction you kept at G1 is still the body; only its blocks and painting changed.

What to look at: `foot_front`, `outer_hull`, `cliff_close`, `reverse`, `foot_reverse` and `side_106`, each Godot / before / after, then two crops at full resolution. The wall colour table on the page shows the sunlit and shaded stone now within 0.01 to 0.03 of Godot's (they were 0.05 to 0.08 too light before).

Not perfect: at full resolution the painted brushwork on the stone is blotchier and less vertically streaked than Godot's, and the tops of the large slabs show a faint crease. At dusk and night the measured cliff box in the `whole` view is now darker than Godot's (by 0.09 at dusk, 0.04 at night), with the new rock faces; I have not yet looked into why.

## 4. Clearer water

What it was: you asked for clearer, more limpid water.

What was done: a pond is now a clear layer over a visible pale bed with pebbles. Looking through the surface shifts the bed a little (refraction), deeper water is a deeper colour, the margin at the shore is clear and shallow, and light lines play on the bed. The mirror image of the sky and banks now lies lightly on top instead of covering the water.

What to look at: `terrace_close`, `close` and `outer_hull`, Godot / before / after, and the pond crop at full resolution. The ponds are lighter and more turquoise than before, with the pale shallow margin at the edges.

Not perfect: in the middle of the larger ponds the bed and pebbles show only faintly, so the change reads more as lighter, softer water than as water you can see deep into. The centre of the `terrace_close` pond is now somewhat lighter than Godot's (0.08 on the green channel); the smaller ponds match Godot within 0.02 to 0.04.

## The numbers

The Mac was busy while the review benches ran (load average about 7 to 10: a VPN process using a full core, and several other applications). That makes every frame time read higher than on an idle machine, so the raw numbers on the page cannot be compared with the first review's.

To get a fair comparison, the build of the first review and the current build were measured back to back, twice, under the same load (camera moving, 3024x1964, 120 frames per view):

| Island | First review's build | Current build | Current / first |
| --- | --- | --- | --- |
| One island (layout 7301), 12 views | 6.65 to 9.09 ms | 7.03 to 9.87 ms | 1.03 to 1.09 (about 5% more) |
| The 4,096-cell island (whole, game) | 13.33 to 14.50 ms | 13.40 to 14.35 ms | 0.97 to 0.99 (no more) |

Load average (1 minute) at the start of each of the eight control runs: 7.7 to 10.7. Every view, both passes, is in the table on the page.

The first review measured, on an idle machine, 5.2 to 7.0 ms for one island and 10.4 to 11.1 ms for the 4,096-cell island. Applying the ratios above, the current build would take an estimated 5.5 to 7.6 ms for one island and 10.2 to 11.0 ms for the 4,096-cell island on an idle machine, inside the budget. These idle figures are estimates until the benches are repeated on an idle machine. The plan's budget is 12 ms a frame with the camera moving.

As measured under load in the review benches: one island 7.0 to 9.5 ms (with its three ramps 7.0 to 9.5 ms: the ramps cost nothing measurable), three islands 8.0 ms, the 4,096-cell island 13.4 and 14.0 ms (with ramps 13.4 and 13.9 ms), the resting mode 26.5 and 28.3 ms (paid once when the camera stops). **Under this load the 4,096-cell island is over the 12 ms budget**, as was the first review's build under the same load (13.3 to 14.5 ms in the control).

For comparison, the frozen Godot build needs 13.7 to 18.9 ms (light tier), 22.4 to 29.4 ms (default) and 29.3 to 38.4 ms (the reference frames' tier) for the same island at the same resolution.

Building an island from its cells, with props and grass, from scratch: 72 to 75 ms for the 623-cell layouts (82 and 84 ms with ramps), 60 to 64 ms for layouts 4242 and 913, 290 ms for the 4,096-cell island (324 ms with ramps). There is no incremental update yet.

Edit test: on each of five islands (the four review layouts and the 4,096-cell island), scripted strokes at the rim (add a patch, remove one, raise one) and two ramp strokes, one straight and one diagonal, 25 strokes in all. No change reached farther than 12 m from its stroke; for the ramps, the farthest change to the lawn surface was 4.0 m away and to the rim 4.0 m. Lines are in `final2/edit_test.log`.

## Known differences and limits

- Rock at full resolution: the painted brushwork is blotchier and less vertically streaked than Godot's, and the tops of the large slabs show a faint crease. At dusk and night the measured cliff box in the `whole` view is now darker than Godot's (by 0.09 at dusk, 0.04 at night), with the new rock faces; I have not yet looked into why.
- Ramps read gently in the general views because grass covers them; they have their own camera views for that reason.
- A ramp is a flat plane per cell with rounded creases, not yet a free-form hill tool.
- The 4,096-cell island is close to the 12 ms budget: an estimated 10 to 11 ms on an idle machine, and over it (13.4 to 14.2 ms) as measured on the busy machine; its cut-out leaf cards are drawn over each other many times and props have no simpler versions for distance yet.
- The three-island view still uses a simpler cloud sea and no far hills.
- Godot's far depth-of-field blur is not ported; distant things are paler, not blurred.
- No sparkle glints on the water.
- The stills show wind, water and falls frozen; they are built to move.
- All of this is study-tool code, to be rebuilt in the real renderer.

## What is in this folder

- `compare.html`: the comparison page, made by `checks/build_compare.py` from the pictures on disk.
- `final2/`: this review's frames (full size and `small/` copies), each run's log and `metrics.json`, the benches, `edit_test.log`, `load_at_benches.txt`, and `control/` (the like-for-like benches).
- `final/`: the first review's frames, used as "before".
- `crops2/`: the full-resolution crops (made by `checks/make_crops.py`).
- `owner_notes/`: your crop from the first review.
- `checks/`: the scripts that render (`render_review.sh`, `bench_control.sh`), crop, measure (`measure_boxes.py`, `boxes.json`) and build the page, and the Godot regression run (`suite.json`, `suite.log`).
- The Godot reference frames are in `../20261122_g1/godot_baseline/`. Pictures are not in git.
