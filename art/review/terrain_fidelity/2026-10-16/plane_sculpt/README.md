# Direct sculpting: bounded cuts and local-height body

2026-10-16. Functional foundation retained; whole-island art remains unaccepted. Player and prefab author directly sculpt the same volume through public brushes. No automatic stone assembly, tree/building replacement, authored cell change or default-art promotion.

## Behavior and compatibility

The plane brush previously blended old density into its outer region: repeated identical full-strength stamps continued changing the surface and left positive-side rock. It now removes the intersection of the selected half-space and the brush sphere. Radius, world bounds, atomic sample budget and stored sample representation remain.

The derived base previously unioned cumulative height regions including lower terraces beneath higher land. Their lower inset delayed high-side recession, leaving a thick extrusion. The new local profile keeps the stepped cap union and applies exterior recession using nearby authored heights. A continuous cell envelope protects the full upper shoulder of narrow low terraces beside tall land. A reviewer found the initial mean-only profile erased such shelves; the failing 12m/1.5m fixture is retained and fixed. The common bottom is unchanged.

New unified saves use version4 with mandatory `sculpt_profile:local`. Existing version3 files without a marker retain legacy geometry and serialize unchanged. Versions1/2 remain supported. Profiles survive mode toggles and renderer snapshots; load/preset clears incompatible history. JSON numeric versions are validated numerically, including parsed floating numbers. Missing/unknown new markers reject atomically.

## Fresh evidence

- `red.json`: original plane regression6/10. Final plane10/10, actual mesh59,592vertices,0open/inward probes.
- `profile_red.json`: old base8/12, including three intended profile failures and old fixture inward probes. `steep_shelf_red.json` and `profile_marker_red.json` preserve the later shelf/marker failures. Final profile15/15,214,488vertices,0open/inward probes. No probe thresholds weakened.
- `checks_final.json`: profile15/15,plane10/10,volume29/29,shoulder15/15,publication9/9,base23/23,data301/301,runtime22/22,contours1025/1025,decoration23/23; each exit0 and no script errors. Base includes55thin-ledge probes/0misses.
- `runtime_checks.json`: real Metal pointer17/17 (plane publish, repick and undo included); existing shoulder publication30,704triangles/0bad shared edges. Editor339/339; wet-material11,236foreground/0underside pond-tag changes/11,236positive bed changes. Full-study grass238anchors/0unsupported; shore0/3,526probes over four edits; vine338/338/347/349/368centroids over five states,0missing/separated.
- `whole_volume_checks.json` and `whole_volume_run.json`: actual final full-study SOURCE skin754,872vertices/125,808unique positions,1connected component,0invalid edges/nonfinite vertices,30,306overrides,unchanged cells. This is not a whole-island published-chunk proof; native small-fixture publication is separate.
- Independent reviewer found the shelf bug and checked its correction, profile/history/cache/snapshot compatibility, exact plane undo/redo and v4 roundtrip. It independently ran profile15/15 and base23/23, and255near-boundary height probes (maximum difference1.12e-5). No remaining actionable correctness finding in that scope; no independent GPU or art acceptance.

## Actual visual judgment

[28-image comparison](../../2026-10-14/courtyard_finish/local_profile.html) compares `old_body1`, `local_body2`, `local_shoulder2`, `local_full2` across whole/far/edge/grass/shore/reverse/bottom. Camera poses match exactly; water surface, bed light, fall and bank clocks are1.25. Cloud/mist still animate. Capture reports remain in adjacent sculpt_base; `profile_final_capture_checks.json` covers final local captures. Old body is the legacy continuous-volume baseline, not default model geometry. All seven final full-study views were inspected.

High sides start returning earlier and remain connected to a calm bottom, but the full result still has wide wall faces, hull-like mass, repeated coarse shoulders, hard turf edges and insufficient natural shore mixing. It is **not adopted as default art**. `return_exact1` and `lip_exact1` confirm exact planes alone still create cave pockets/thin knife lips and are rejected. Earlier local_body1/shoulder1/full1 are pre shelf-envelope-fix stages, not current candidates.

Default `surface_final` geometry and water remain unchanged. These are useful direct-authoring foundation changes, not concept parity. Arbitrary sculpture support, full dynamic water routing after carving, large edit latency, moving-camera material quality and low-device performance remain unaccepted. No model delivery or user-operated tool blocks further work.
