# Floating-island look-development candidate — 2026-10-06

**Historical submission: READY FOR ART REVIEW at 4d891bd. User review: NOT ACCEPTED — substantive visual rework required (2026-10-06).** The retained candidate improves material continuity and shore treatment in the existing scene; it is not an exact replica or user-approved art. The native goal follows the user-supplied `FLOATING_ISLAND_LOOKDEV_BRIEF.md`. Original target: `art/source/visual_targets/2026-10-05/terrain_user_target.png`. No separate supplied night reference was found; night work is optional and deferred.

Terrain uses a sparse 2D height grid, not 3D voxels. Connected contours generate the surface and cliffs. [Tiny Glade](https://pouncelight.games/tiny-glade/) informs coherent procedural detail; its internal representation is not claimed. Seven runtime files change from `a41382f`: lake/fall/ground/cliff/sky materials, shore-field impact data and supported bank gaps. Geometry, layout, model sources, camera and unrelated systems retain baseline sources. Originals and eight unrelated local hashes are preserved; see [evidence](evidence.json).

## Scope review

| Area | Problem → inspected cause | Change or reason retained | Evidence | Remaining issue / cost |
| --- | --- | --- | --- | --- |
| A Composition | Competing texture contrasts; strong lake patchwork and ground flecks confirmed in shaders | Quieter water, grass and rock colors; retain cottage→lakes→falls layout and useful open ground | Matched composition/left/right | Trees still bulky; no layout or prop-scale change |
| B Terraces | Outline is stylized, with angular edited shoulders; authoritative shared contours already join both terraces | Retain asymmetry, flat usable land and lake layout; material work avoids unrelated boundary changes | Composition, four edits, contours 1025 | Sharp local corners remain; arbitrary topology unproven |
| C Rock | Long triangular wedges and strong facet contrast; real geometry and palette both contribute | Narrower gray range reinforces existing massing; geometry retained after ineffective archived trials | Rotated views, lower/contract; exact source preservation | Wedges and smoother contracted underside remain; no geometry fidelity claim |
| D Shores | Near-continuous similar stones exposed placement pattern | World field leaves supported gently curved grassy gaps; bends/outlets retain stones | Contact/four edits; shoreline 9, decoration 89 | Sharp grass contact, no shelf; whole stone footprints unproven |
| E Lake | Voronoi albedo mosaic, painted glints and neutral radiance confirmed | Continuous wave normals, dielectric BRDF, terrain depth/bank color, directional static sky radiance | Multiview/contact and motion; actual shader inspection | Opaque, subdued; regular wave bands, subtle depth. Sky-only reflection |
| F Falls | Crystal-vein pattern and global emission made sheets conspicuous | Continuous downward streaks, no emission; local receiving disturbance fades across same-level water | Motion/contact/edits; waterfall 35, impact 8 | Straight crests, striped sheet/soft foam; no particles or fluid simulation |
| G Vegetation | High-contrast flecks competed with existing grass; model geometry already reusable | Quieter ground palette; retain supported Kenney/Quaternius assembly and placements outside banks | Composition/detail/four edits | Wiry grass, bulky crowns and rigid reeds remain |
| H Cottage | Existing refined modest cottage already grounded with differentiated timber/plaster/roof | Retain cottage and entrance path; no replacement or regeneration needed | Composition/left/right; unchanged sources | Simpler timber/eaves, placeholders bench/lantern; original shell limitations remain |
| I Light | Baseline daylight/shadows/SSAO already reveal terraces; water issue not solely exposure | Keep sun, fill, tone mapping and shadows fixed to judge materials | Matched settings and captures | Some stippled shadow detail; no night workaround or new AO cost |
| J Sky | Screen backdrop provides composition but previous cubemap was neutral | Visible backdrop retained; cubemap uses directional cloud radiance | Multiview and sampled moving frames | Screen backdrop stays fixed; bitmap angular seam possible outside sampled directions |

## Runtime and visual evidence

Actual Godot 4.7.2 Metal Forward+ output, not edited/generated replacement imagery. [Baseline poses](baseline_captures.json) and [final poses](final_captures.json) use 1672×940, pitch 27°, FOV 31°, composition yaw 16°/height 21, inspection yaw −22°/50° and documented contact zoom. Sun/environment settings are unchanged except sky radiance. Both sets contain raise/lower/expand/contract from the same initial layout (16/12/14/16 changed cells), then regenerated default. Fresh final reopening exits 0 without attributable runtime errors. All nine final images and actual benchmark render outputs were inspected.

Before: ![Baseline actual Godot scene](baseline_composition.png)

After: ![Final actual Godot scene](final_composition.png)

Nine fresh functional scripts pass: impact 8/8, shoreline 9/9, waterfall 35/35, contours 1025/1025, data 301/301, render 339/339, decoration 89/89, incremental 20/20 and runtime 22/22. [Full outputs](verification.json). Impact red baseline was 4/6, retained code 6/6, then extended final 8/8. Runtime covers painting routing, camera height rules and isolated save/load. Geometry was not modified; older full geometry-suite results remain historical, not rerun claims.

[Baseline motion](baseline_motion.mp4) and [final motion](final_motion.mp4) each encode 300 unmodified runtime frames, 1280×720, 60 Hz, five seconds. Final frames 0/60/120/180/240/280/290/299 were inspected, including the yaw-zero crossing. Water varies and curtains remain connected without obvious new sorting/gap defects in these samples. This is sampled inspection, not proof of smooth full-clip playback, every angle or unrestricted orbit. Scripted pan/zoom/rotation is inspection-only; product keyboard/MMB panning stays horizontal and wheel-only height control is unchanged.

Independent source/multiview/edit review found no confirmed Critical/Important defect in the retained candidate. It did not run engines or approve aesthetics. Lake normals are world-anchored and correctly converted to view space; BRDF angle response is not doubled with custom Fresnel. See [Godot spatial shader documentation](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html). Static sky lighting is not reflected scene geometry.

## Matched performance and exclusions

Sequential baseline/final three-run comparison on M4 Pro (Apple9), Godot 4.7.2 Metal Forward+, real 1280×720 SubViewport, 4x MSAA, shadows/SSAO, identical time-based camera path/593 cells/four edits, two chunks/frame, input disabled, 2-second warmup + 12 seconds/run. Native window minimized; `force_draw(false)` submits actual GPU rendering. GPU timer returns unavailable zero values. These wall intervals measure process/submission, **not presented FPS**. [Comparison](performance_comparison.json), [baseline](baseline_isolated_performance.json), [final](final_isolated_performance.json).

| Metric | Baseline range | Final range |
| --- | --- | --- |
| Median interval | 6.901–6.904 ms | 6.898–6.903 ms |
| p95 interval | 7.482–7.525 ms | 7.489–7.523 ms |
| Worst interval | 102.812–106.244 ms | 91.770–106.922 ms |
| Renderer CPU median | .324–.347 ms | .316–.342 ms |
| Renderer CPU p95 | 1.128–1.187 ms | 1.085–1.182 ms |
| Edit publication response | 194.039–242.800 ms | 195.132–245.166 ms |
| Draw calls / video memory | 510 / 217.891 MiB | 510 / 217.891 MiB |
| Static memory | 59.774–59.794 MiB | 59.777–59.797 MiB |

No material regression beyond observed repeatability in this isolated method; no speedup claim. Edit spikes remain. Primitive sample is ~2.26 million including rendering/shadow passes, not unique asset triangles. Presented FPS, target Windows thin-laptop/MacBook Air, startup, larger maps and long-idle power/stability are unmeasured.

Visible-window attempts had inconsistent focus/timing and cannot isolate material cost. Earlier offscreen `root.hide()` error, a type-inference parse failure and a stopped overlapping partial run are excluded. A shallow-base trial conflicted with the legal minimum height and was reverted. A once-probe trial gave little useful reflection, altered ambient response and leaked seven texture RIDs on shutdown; removed. Progressive material trials are stage evidence only. [Exact exclusions](evidence.json) retain failure reasons; no failed sample is presented as passed.

## Reproduction

Open `scenes/terrain_editor.tscn` or run `godot --path . scenes/terrain_editor.tscn`. Capture/check/benchmark commands are in [terrain documentation](../../../../docs/terrain.md). For baseline, use a separate checkout of `a41382f` with the same current capture/benchmark harness; run each engine job alone. PNG/MP4 files remain local ignored artifacts; tracked manifests plus scripts reproduce them. User aesthetic judgment is the next step; further cosmetic changes should respond to concrete feedback rather than an indefinite variation loop.
