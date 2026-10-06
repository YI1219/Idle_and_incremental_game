# Substantive floating-island rework

2026-10-06 — **Historical candidate `3a73663`: NOT ACCEPTED.**

The latest user review recognizes substantive progress in reduced vegetation noise, restrained trees, calmer lake bands and curved waterfall lips, but rejects the cliff shape language and incomplete boundary/water relationships. Preserve those gains. The [subsequent shape checkpoint](../shape_checkpoint/review.md) is current evidence; this report retains the original implementation and verification record below.

The starting candidate is `4d891bd`, which the user explicitly **did not accept**. Its [report](../review.md) remains historical evidence. This pass changes the existing editable scene, including shared geometry and integrated daylight. Sparse 2D XZ data, two flat terraces/two lakes and flow sequence, modest cottage, legal heights, editing/persistence/picking and horizontal pan/wheel-only height controls remain. No voxel conversion, separate showcase, renderer/dependency change or purchase occurred.

The actual [daytime target](../../../../source/visual_targets/2026-10-05/terrain_user_target.png) was inspected. The supplementary night concept was unavailable; it was not used as an inspected source. Source assets and unrelated local work are preserved.

## Runtime result

Fresh actual Godot 4.7.2/Metal Forward+ 1672×940 views use matched framing. The connected outlet→fall→receiving lake→shore→cliff sample and representative crown were tested in the gameplay scene before extending the treatment. These are engine pixels, not concept images.

![Reworked editable scene](rework_final_composition.png)

Compare [rejected baseline](baseline_composition.png), [close transition](rework_final_contact.png), [left](rework_final_left.png), [right](rework_final_right.png), [baseline clay](baseline_clay_composition.png) and [reworked clay](rework_final_clay_composition.png). Uniform material confirms that shoulders/ledges/recesses are geometry, rather than recoloring triangle faces.

| Reviewed defect | Cause established in this pass | Implemented change and evidence | Remaining issue |
| --- | --- | --- | --- |
| Long wedges, contracted shell | Deep global floor, strong inward taper, sparse height spans and independent flat triangle normals shaped the visible shell. | Shared bevelled masses, explicit irregular ledge-height breaks, selective creases, reduced broad-column noise and shallow unequal blunt feet. Composition/rotated/clay and four edits show substantial shape change. | Some long horizontal ledges, strongest in the left view. Narrow legal terrain necessarily retains constrained profiles. |
| Bulky crowns/weak vegetation hierarchy | Many similar leaf groups obscured primary branches; scattered tall grass and repeated vine drapes competed with large forms. | Four deliberate derived crown masses, branch space, unequal tree proportions, low common grass clusters and sparse short drapes. Original source models/textures remain. | Crown silhouette and detail richness still differ from the concept; no density increase was used. |
| Regular lake bands | Flat-normal isolation removed the bands; flat-color isolation retained them. Directional cosine slopes through BRDF were the confirmed cause. | Four continuous 2D height/gradient fields replace the directional lattice, with localized receiving-water disturbance. Normal/gameplay/rotated views and motion samples show quieter irregular surface variation. | No reflected cottage/tree geometry; static sky response only. |
| Subdued water/weak basin relationship | Uniform shallow beds plus weak margin optical-path differentiation reduced readable bank response. | R follows actual smoothed bank distance; authoritative G bed depth and B connected impact remain. Margin path length and blue palette were calibrated with daylight. Close and rotated views show calmer shallow transitions. | Default beds remain uniformly shallow; this is an opaque stylized approximation, not refraction or fluid simulation. |
| Abrupt grass–water gaps | Removing stones left unsupported-looking sharp contact. | Supported graded earth shelves cross dry/wet margins and belong to terrain meshes/picking/publication. Stone bends/outlets and small groups remain. New shore test checks wet/dry continuity and 142 actual bank/depth/impact samples. | Patch ends are blunt; shoreline stones remain comparatively repetitive. |
| Straight striped falls/disconnected foam | Simple crest/row profiles and fine full-height streaks produced rigid sheets; independent overlapping impact mounds weakened landing coherence. | Sampled rounded lips, canonical XYZ folds/sway, finite broader downward aeration and wet-foot metadata. Receiving foam is grouped by connected run with supported local fallback; outer falls have no invented splash. Close/default/edited views show changed connected forms. | Falls still read somewhat like translucent ribbons, and landing foam remains thin lace. These remain the weakest visual area and need the user's judgment. |
| Weak integrated lighting | Baseline fill/angle softened volume; no-shadow isolation also exposed a straight/stippled shadow artifact. | Warm sun at (-42,-48), energy 1.28/angular size 2°, blue fill .32 and blended shadow splits. Linear tone mapping/SSAO/4x MSAA and renderer retained. Clay/shaded views show more readable volumes and grounded props. | No added atmosphere disguises geometry. Screen-mapped clouds remain tied to product framing; unrestricted wrap is unverified. |

Costs below are measured for the integrated revision. Individual systems were not separately GPU-timed; the table does not invent per-effect cost attribution.

## Geometry and function verification

[Fresh 25-script results](checks_final.json) all exit 0 with no script errors. [Actual Metal runtime](runtime_metal.json) passes 22/22 checks in addition to headless fixtures. Coverage includes contours (1025), data (301), render publication (339), decoration (57), incremental publication (20), waterfalls (35), impacts (8), shoreline (9), picking/camera/UI routing/save-load, crown integrity/branch contact, shrub support, vine contact, constrained widths and shell floors.

The new geometry was rerun after review fixes:

- Broad interfaces: 8,884 compared points with zero separation; irregular broad/narrow polylines: 96 points with zero gap. A stronger reverse comparison first failed at 73 points/max 0.418 m and reproduced photographed sky slits. Extra bevel knots are now omitted only on shared narrow-boundary columns. Fresh irregular/reopened pixels show rock at the former slit locations.
- A wet island fully surrounded by lower water first produced zero receiving foam: ring impacts averaged into upper terrain. Local closed-ring groups and receiver-checked fallback now retain 1,038 impact vertices across four sectors, with wet-foot aeration and zero receiver metadata on dry outer feet.
- The lower-edit spike came from an outer corner misclassified as an internal wall. Outer-contour ownership now yields no default/four-edit vertices below the intended shallow floor. Minimum legal land remains -4 with a finite body to -4.5; the legal data constraint is unchanged.
- Narrow-wall checks: 568 slices, zero overlap; boundary walls: 416 samples, zero missing; shrub checks: 32,548 actual base points, zero unsupported. Crown sources remain enclosed by four closed/outward derived surfaces and match published meshes.

[Capture manifest](rework_final_captures.json) includes 14 fresh views: normal, close, two inspection rotations, raise/lower/expand/contract (16/12/14/16 changed cells), regeneration, minimum height, irregular and rotated irregular, and fresh-editor reopened irregular/default. Reopen checks serialized equality; minimum-height picking returns -4. These finite fixtures do not prove arbitrary edited topology, all prop footprints or navigation in every future layout.

Obsolete artistic expectations were updated explicitly: the taper test samples the actual foot/cap, narrow tests use the actual height range, broad normals require finite geometric hemisphere agreement plus both crease and smooth samples, and vine density no longer requires the rejected heavy drape count. Support/overlap/edge/picking/legal-height requirements remain. Simple aspect-ratio diagnostics are not aesthetic acceptance.

Rejected trials remain local stage evidence: scalar plateau relief crumpled; an embedded model layer looked like attached plugs and was removed; initial shared slabs read as even courses; large light angular size worsened stippling; initial peak-based falling-water noise looked dotted. The final shared-mass treatment differs materially from those attempts.

## Motion and cost

[Baseline clip](baseline_motion.mp4) and [reworked clip](rework_final_motion.mp4) are encoded directly from 300 unmodified actual 1280×720 viewport frames at fixed 60 Hz, following the same five-second pan/zoom/inspection-yaw path. Final frames 0/60/120/180/240/280/299 and matched baseline samples were inspected. Lake/fall patterns change without the previous dominant lake lattice; no new detached landing or cliff seam was observed in these samples. Full uninterrupted temporal playback remains unverified. Inspection rotation does not enable product orbit.

Native movie swaps skipped frames when the window was inactive, and an early viewport attempt captured initialization in frame 0. Both attempts are excluded. The final harness warms up and captures every actual viewport frame after scene transform synchronization. A real SubViewport also avoids the native-window draw-wait stall during still capture. H.264 encoding is lossy; no grading, compositing or generated frames are used. Motion is not presented as measured real-time performance.

Sequential matched [baseline](../rework_baseline_performance.json) and [rework](../rework_final_performance.json) use M4 Pro/Metal Forward+, actual 1280×720 SubViewport, 4x MSAA/shadows/SSAO, identical 593-cell path/four edits, two-second warmups and three 12-second runs, without concurrent engines.

| Metric | Fresh `4d891bd` baseline | Integrated rework |
| --- | --- | --- |
| Median submission/process interval | 6.901–6.903 ms | 6.896–6.903 ms |
| p95 interval | 7.428–7.496 ms | 8.082–8.178 ms |
| Maximum interval | 100.726–107.884 ms | 141.669–151.332 ms |
| Four-edit publication response | 195.318–242.376 ms | 222.978–300.847 ms |
| Draw calls at matched end sample | 510 | 468 |
| Rendered primitives at end sample | 2,260,231 | 353,627 |
| Video memory | 214.3125 MiB | 218.3125 MiB |
| Static memory across runs | 59.777–59.797 MiB | 64.458–64.479 MiB |

Typical intervals stay similar, but p95, edit latency and spikes increase; this is a recorded trade-off for changed shared geometry, not unchanged cost. Lower vegetation geometry reduces the rendered primitive sample, without eliminating terrain rebuild cost. The current scene has no newly enforced numerical editing budget; the 60 FPS target still requires actual laptop measurement. These minimized-window submission/process intervals are **not presented FPS or GPU frame times**. GPU timers return unavailable zeros. Windows thin-and-light/MacBook Air support, larger maps, long-idle power and stability remain unmeasured.

No original asset binary was modified in this rework. Eight unrelated tracked local files match their initial hashes. Runtime sources temporarily restored from `4d891bd` solely for matched baseline capture were restored byte-for-byte afterward; no project reset occurred. PNG/MP4/frame evidence stays local under the repository's art-binary ignore rule; code, review and JSON evidence are retained in Git.
