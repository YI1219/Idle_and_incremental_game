# Direct rock sculpting — prototype, not final island art

The user's October16 correction is explicit: players and prefab authors directly shape the SAME rock/mountain data. There is no phase in which the player builds a mountain and the system adds/composes rocks. The prototype changes scalar volume samples through grow, carve and bounded plane brushes. Those samples belong to TerrainData and share terrain history/save/load; meshing, chunk publication and picking consume a frozen snapshot. The toolbar labels this as a trial affecting new sculpt volumes only.

## Shape verdict

Actual Godot `sculpt1` and `sculpt2` studies reuse the production brush API through `tools/art/author_sculpted_cliff.gd`. They are REJECTED as default island art. Sculpt1 is overly rounded/clay-like. Sculpt2 has clearer cuts but forms a broad vertical sheet; retained model-based cliff/grass overlaps remain conspicuous. The runtime default island is not replaced. These studies establish direct-shape editability, not a natural cliff solution.

The next art/integration step must bring the existing cliff body and its lawn boundary into the sculptable volume/coverage representation, rather than overlaying another rock skin. There is no user Blender/Tripo delivery blocker. Player tooling, whole-island art and performance are separate acceptance gates.

## Bounds and limitations

Initial .25m lattice; brush radius .25–4m; world XZ±1024m and Y−16..24m with a complete brush margin;160,000 stored samples. Unsupported/invalid/out-of-bounds/capacity brush requests are atomic. This is an initial prototype budget, not target-laptop acceptance. Sculpt samples are independent of land-cell height morph; an independent review identified accidental inherited morph and the rendered regression/fix is recorded separately. No existing models, island/pond footprint, tree/building assets or original source files are replaced.

## Evidence

Data/mesh tests cover neighboring strokes, actual closed outward finite geometry, carve/plane, mixed history, save/load, invalid input and capacity atomicity. Runtime test covers volume-only geometry, negative/chunk-corner publication (3,052 triangles, zero invalid edges), snapshot isolation, picking and cuts. Input-helper test checks toolbar/cursor/undo/stationary-pointer behavior; a helper-only test does not prove the full native screen-pointer route. Actual studies and check reports are stage evidence, not final acceptance. See JSON reports in this directory for fresh commands, outputs and exit codes.


## Final verification of this checkpoint

Nine affected headless scripts pass (native exit0/no script errors), including data301/301, runtime22/22, rim27/27, volume29/29 and published sculpt9/9. Actual Metal queue passes:11default matched captures, editor339/339, sculpt-input-helper8/8 and decoration regeneration42/42. Morph regression initially exits1 with10,117 silhouette-mask changes; after opting world-anchored sculpt out of land morph it exits0 withzero changes across0/.5/1,16,804foreground pixels and unchanged rock samples/picking. Two sculpt headless checks re-run after that correction pass. See headless_checks.json/render_checks.json/post_review_checks.json for complete outputs and exit codes. Independent review's sole Important finding is fixed; its full native pointer-route test gap is deferred and explicitly not claimed verified.
