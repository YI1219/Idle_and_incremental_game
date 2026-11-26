# Round k5b: edits stay local, unloading retracts then merges, rock walls without stripes (2026-11-27)

The owner's review of 2026-11-26 (around 18:05 China time), after the round-k5 work. In scope: look, edit feel and performance. Not a full art accept, and phase 2 has not started. The k1 chamfer is kept.

Open `compare.html` (videos play in the browser). Pictures and videos are not in git; `checks/render_k5b.sh` renders and measures everything again (detached, restartable), and `checks/build_compare.py` rebuilds the page. "Before" is the build of `backup-before-k5b-20261127` (commit dd9a597, the round-k5 package); "after" is this round's build.

## Question 4: is the original procedural generation at fault?

**Partly yes.** The coupled changes came from the island generator: four places were not local for edits that change the island's outline. The strange polygons when unloading, and the vertical stripes, came from round k5's own settle motion and junction pieces. All of it is measured and fixed in this round; `compare.html` opens with the full answer and the evidence.

## 1. Edits stay local (no coupled changes, no restart)

**How it was measured.** `S34_DIFF=1` compares every triangle of the island before and after an edit. It prints how far from the edit the changed triangles lie, by part, and renders a check frame with them tinted.

**Before this round:**
- Edits that only change height (raise, lower, ramp, water, items) were already local: only the edit's own top-surface triangles changed.
- Erase and expand changed the body up to 20.9 and 22.2 m away.
- With an erase, 1,010 triangles changed more than 3 m from the stroke and 686 more than 6 m: hanging columns to 18.9 m, rim blocks to 10.1 m, the liner to 22.2 m.

**The four causes in the generator, and the fixes:**
- **Columns and liner:** their grids were anchored to the field's corner, which moves with the island's bounds, and their depth was sized from a 7 m blur. The grids are now anchored to the world, and depth comes from the distance to the outline within 8 m.
- **Rim-block lean:** it read the 2.5 m blur; it now follows the outline's own normal.
- **Rim plan:** its breaks are chosen in windows 2 to 6 m wide either side, so an outline change re-planned faces about 10 m away. An edit now keeps the old breaks outside the zone it changed, so faces wholly outside are the same faces.
- **Lip grass:** it took its random numbers from a counter running over the whole rim, so one changed edge changed every lip plant after it. Each plant now takes them from its own place.

**After:**
- Erase changes nothing beyond 9.0 m (rim blocks within 7.1 m).
- Expand changes nothing beyond 8.0 m.
- Height edits and item edits change only their own triangles.

**The restart:** every edit still rebuilds the whole island (24 to 55 ms on worker threads) and swaps it in without stalling the frame loop. The window runs below show a steady 60 frames a second, before and after, with an erase every 2.5 s. Because the rebuilt island now differs from the old one only near the edit, the swap no longer shows as a restart.

| Build | Scenario | Frames on the glass a second | Interval p50 / p95 / p99 / max (ms) | Intervals over 25 ms | GPU p50 / p95 (ms) | Erase to first motion frame on the glass (ms) | Rebuild (ms) |
|---|---|---|---|---|---|---|---|
| before | idle | 59.98 | 16.67 / 16.67 / 16.67 / 25.0 | 0 | 10.27 / 10.46 | | |
| before | erase every 2.5 s | 59.82 | 16.67 / 16.67 / 16.67 / 25.0 | 1 | 10.39 / 10.65 | 105 to 122 | 47 to 54 |
| after | idle | 60.00 | 16.67 / 16.67 / 16.67 / 16.67 | 0 | 10.23 / 10.39 | | |
| after | erase every 2.5 s | 59.77 | 16.67 / 16.67 / 16.67 / 25.0 | 0 | 10.33 / 10.62 | 98 to 113 | 45 to 51 |

Mac display at the owner's setting (3600 x 2338 drawable, 120 Hz ProMotion), 20 s each. Times on the glass are from Metal's presentation timestamps. Load averages 7.6 (before run) and 5.4 (after run). Neither build drops or stalls frames when an edit lands; the difference the owner saw was what changed on screen, shown in compare.html section (b).

## 2. Unloading a raised block: retract, then merge

**Now:** where an edit lowers the ground, the old volume above the new ground is kept as a ghost and sinks into the new ground by the height it lost. That volume is a raised block's top and walls, with their grass, or the lawn over a new pit. It uses the ground's ease and small overshoot, and is hidden once it meets the new ground, where it then lies. The new ground stays put, items standing there ride down, and grass on the lowered cells regrows.

**Before:** the new, lower surface was pressed up to the old height and released, so it spanned from the block's top to the ground as stretched faces, then flattened.

**New sequence `unload`:** a block raised 1 m (rock walls) lowered back to the lawn in one edit.

## 3. Rock walls without the vertical stripes

The stripes were three pieces round k5 added where two rim blocks meet:
- a 3.5 cm corner arc that caught the light;
- a 0.22 m overlap that left a sliver of each block's end showing;
- a backing plate behind every joint.

Two blocks that meet with a step under 45 cm, or at an inside turn of the rim, now share one sharp corner, giving a single crease. The plates are gone. Folds are only on faces over 4 m and push 6 to 14 cm. No face is narrower than 1.4 m. Larger steps keep the accepted rounded edge.

## Also in the package

- The construction from one mound, recorded again with this build, with the same stroke script as round k5.
- Checks:
  - the hole view over the twelve review views;
  - the edit-locality test. That test re-plans the rim without the kept breaks, so it still reports faces changed up to 11 m for expand; it measures the plain generator, not the edit path.

## Known limits

- A sharp concave notch that the erase brush cuts into the rim (the bay in the demonstration) leaves a deep V between two faces of one block. It reads as the bay's inner corner.
- The ramp's first 0.2 s still shows brief earth-coloured faces where its lower half is pressed down.
- The hanging columns under the island are sized from the outline within 8 m, so an outline edit can still change columns under the island within that distance.
- The prop scatter for synthetic islands still uses a sequential random stream. Layout islands and the demonstration do not use it.
