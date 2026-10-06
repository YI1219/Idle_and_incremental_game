# Floating-island shape checkpoint

2026-10-06 — **Intermediate implementation checkpoint; art NOT ACCEPTED; overall task remains open.**

Baseline: `3a7366350ab466e2a6bd532831ced934cefd3cbe`. The user recognized progress but rejected the horizontal slab language and incomplete water/boundary relationships. This revision preserves quieter vegetation, restrained tree instance scales, calmer lake shading, curved lips, daylight and approximate island thickness. The sparse 2D height grid, editable scene, legal heights, persistence, picking and horizontal pan/wheel-only height controls remain. No voxel conversion, separate rock shell, engine/renderer change, purchase or source-asset replacement occurred.

The actual [daytime reference](../../../../source/visual_targets/2026-10-05/terrain_user_target.png) was inspected. The supplementary night concept remains unavailable. It is not claimed as an inspected reference.

## Actual runtime result

![Current gameplay-scale composition](checkpoint_final_composition.png)

Godot 4.7.2, Metal Forward+, actual 1672×940 rendering. These are scene pixels, with the editor HUD hidden for comparison. Compare the [prior composition](../rework/rework_final_composition.png), [current connected region](checkpoint_final_contact.png), [left](checkpoint_final_left.png) and [right](checkpoint_final_right.png). Camera poses match the previous rework harness. Inspection rotations do not enable gameplay orbit.

| Defect and established cause | Implemented change | Evidence and remaining issue |
| --- | --- | --- |
| Horizontal courses and broad cap bands persist with gray material, geometric flat normals, white controlled light and no shadows/AO. The old aligned slab field and height knots are geometric causes. | Oblique unequal volume relief crosses old course heights; feature-following profile knots and shorter diagonals replace dense bevel rows. Overall floor/thickness remains. | [Before geometric normals](before_controlled_facets_left.png), [propagated geometric normals](propagated_controlled_facets_left.png), [final production normals under controlled light](checkpoint_controlled_left.png). Larger irregular masses now interrupt the courses. Local pointed facets, thin recess slits and broad flatter terrace walls remain below reference quality. |
| Soft/pinched shading changes between production and geometric normals on identical baseline geometry. The all-face average and whole-triangle crease fallback contribute. | Per-corner incident-face averages are restricted to shallow plane groups. No extra AO or lighting disguise. | [Before production normals](before_controlled_left.png) versus geometric-normal view above; final controlled views show selective plane breaks. The remaining geometry defects cannot be fixed by normals alone. |
| Falling water remained a striped translucent ribbon, with thin lace at the landing. | Preserve curved lip and calmer lake; broader unequal folds, near-opaque core, intermittent descending cellular aeration and shallow moving normals. A supported raised receiving roll begins at the actual curtain foot and joins fuller foam. Only wet receivers gain terminal aeration and a small froth emission contribution. | [Connected outlet and receiver](checkpoint_final_contact.png), [flow motion](checkpoint_flow_motion.mp4). The connection is fuller, but highlights still sometimes read as a net/outlined bubbles, especially in edited holes. Body response remains simpler than the reference. This is unresolved rework, not optional polish. |
| Removing vegetation exposed abrupt banks and repeated stone tracing. Independent strips had abrupt ends. | Selected banks now taper with shared corner normals and grass-to-earth blending; stone gaps use the same support/selection. Small turf lips follow actual dry-cap proximity. | Normal/close and edited views show connected banks without refilling grass. Some exposed banks remain polygonal and stone chains remain repetitive. Turf clipping initially produced bright triangles; interpolating cliff colors fixed the diagnosed publication defect and is regression-tested. |
| Crown lobes lacked primary/secondary hierarchy. | Four retained-source masses: broader lower primary, unequal secondary lobes and open branch spaces. Prior instance scales and quiet scatter remain. | Normal/rotated views; all five sampled wood extrema remain covered. Crown silhouettes still differ from the reference; no additional leaf density was used. |

## Representative sample before extension

Experiments ran in the actual gameplay scene around the connected upper outlet, adjacent wall, receiving lake and representative crown, captured at close and normal framing. The initial `volume_sample` made excessive bulges; `recess_sample` deepened knife-like cuts. Those treatments were rejected. `bounded_sample` limited relief; `joined_sample` used feature-following height knots and shorter diagonals, establishing a more coherent volume sample before relief propagation. The shared triangulation change affected other walls during this sample stage; it was not an isolated mesh patch. No separate showcase was substituted.

`receiving_sample`, `integrated_sample`, `transition_sample` and `response_sample` record connected water/bank/crown iterations. Opaque blotches, continuous curling contours and an overly regular cellular net were rejected or reduced. The final sparse cellular treatment is still visibly imperfect; further global noise changes are not an acceptance substitute. A first flattened crown trial exposed branches; the final arrangement restores tested branch coverage.

An independent code/art review found no confirmed Important/Critical functional defect in the scoped diff and supplied runtime views. It supported the sample's propagation and verification, not aesthetic acceptance. It independently identified pointed lower-front facets, flat terrace wall areas and outlined water highlights. The final invariant-site cache was verified separately by byte equality.

## Fresh verification

[26-script final results](checks_final.json): all exit 0, no script errors. [Actual Metal runtime](runtime_metal.json): 22/22. These were rerun after the final cache optimization. Existing tests were not weakened this checkpoint.

- Contours 1025, data 301, rendering 339, decoration 57, incremental publication 20, waterfall 35, impact 8 and shoreline 9 checks pass.
- Shared cliff interfaces: 96 standard and 5112 multi-elevation/irregular points, zero separated; 96 irregular broad/narrow polyline points, zero gap. Narrow profiles: 568 slices, no overlap. Boundary fixtures: 416 samples, none missing. Legal minimum picking remains -4 with a supporting body.
- Crown integrity: four closed outward surfaces contain all 3072 input entries; 2256 published entries match. Branch contact 5/5. Shrubs: 32,548 base samples, none unsupported. Sampled vine centroids remain in contact.
- Closed receiving ring retains 1554 impact vertices across four sectors with correct wet/dry-foot metadata. Turf regression records 552 gradient faces, 412 cap faces and no invalid values after chunk clipping. The shape diagnostic's zero long wedges is a finite numeric predicate, not proof of correct artistic shape language.
- [Capture manifest](checkpoint_final_captures.json): fourteen actual views, including raise/lower/expand/contract (16/12/14/16 changed cells), minimum legal height, irregular and rotated irregular boundaries, regeneration and fresh-editor reopening. Reopened serialization matches. These fixtures do not prove arbitrary topology or all prop footprints.

[Full-scene clip](checkpoint_final_motion.mp4) and [connected-flow clip](checkpoint_flow_motion.mp4) each contain 300 actual 1280×720 runtime captures encoded at 60 Hz, with no grading/compositing; H.264 is lossy. Frames 0, 150 and 299 from each clip were visually inspected. **Uninterrupted playback remains unverified.** Full-scene motion includes inspection-only yaw; connected-flow motion keeps yaw fixed and simulates horizontal pan/wheel height. The clips predate invariant caching, but [default/four-edit mesh attributes match byte for byte](cache_equivalence.json); shaders did not change afterward. [Verification manifest](verification.json) records source/evidence hashes and scope.

## Matched current-host cost

Fresh baseline `3a73663` versus this revision, serial engine runs on M4 Pro, actual 1280×720 SubViewport, Forward+, 4x MSAA, shadows/SSAO, 593 cells, four edits, 2-second warmup then three 12-second runs. Input/live pointer picking are disabled and the window is unfocused in both. [Before](../shape_checkpoint_before_performance.json), [after](../shape_checkpoint_after_performance.json).

| Metric | Baseline | Final checkpoint |
| --- | ---: | ---: |
| Median process/submission interval | 6.898–6.901 ms | 6.899–6.906 ms |
| p95 interval | 8.095–8.160 ms | 7.437–7.485 ms |
| Maximum interval | 146.988–148.326 ms | 171.626–175.851 ms |
| Edit publication | 220.342–275.777 ms | 222.628–285.950 ms |
| Draw calls | 468 | 480 |
| Primitives | 353,627 | 342,884 |
| Static memory | 64.458–64.479 MiB | 61.859–61.879 MiB |
| Reported video memory | 218.3125 MiB | 214.406–214.531 MiB |

The [uncached trial](../shape_checkpoint_uncached_performance.json) had 258.942–331.336 ms edit publication. Caching invariant geometric site data reduced this without changing output attributes. Final worst intervals and some edit costs still exceed the matched baseline; no unchanged-cost claim is made. These measurements are **not presentation FPS or GPU frame times**. GPU timing is unavailable. Target laptops, larger maps and long-idle power/stability remain unmeasured; no target-device acceptance is implied. Costs are integrated, not separately attributed to individual visual changes.

## Still-open artistic work

Localized pointed cliff facets and thin recesses, flatter terrace walls, cellular/net-like falling-water highlights and polygon-tracing shore rhythms remain active mismatches. There is no genuine new user choice required to recognize them: the requested blunt masses and integrated flowing water remain the direction. Further work should resolve these in the representative connected region before propagation, preserving the gains above. This checkpoint does not declare the visual task complete or ask the user to approve an inadequate effect as a budget compromise.

PNG/MP4 evidence remains local under the repository's existing binary-art ignore policy; source, reproducible harness, reports and measurement manifests are versioned. See [terrain documentation](../../../../../docs/terrain.md) for reproduction commands.
