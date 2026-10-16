# Existing-source bedrock studies — no art promotion

The user-endorsed [cliff target](../../../../source/visual_targets/2026-10-16/cliff_user_target.png) remains the finish target, not an engine result. Default `spall_finish1` and all production paths remain unchanged from `3a4c613`. This continuation investigates actual source thickness and source-to-ground/body intersections; it does not deliver a more beautiful whole island. The goal remains active/incomplete. No user model delivery or external operation is blocking progress.

## What changed and what was rejected

All seven trials below are ordinary version4 density saves loaded through the existing terrain API, preserving canonical cell records. There is no new player brush, automatic rock assembly, runtime source substitution or locked decorative ground. Compared with formal default, **unified mode itself changes the whole derived body**; `exposed_control1` is the fresh unified control. Do not attribute that global difference to one local stone.

| Local trial | Density samples | Observed result |
| --- | ---: | --- |
| exposed1 | 13,235 | Three original integrated sources retain their exact current crown poses/normalization, but expose their complete shoulders. Wide grey caps rise above the lawn, the wall remains and one small piece detaches. Rejected. |
| scannedbedrock1 | 18,844 | Closed Namaqualand scan group inverted beneath its repaired base, fitted to the old edge. Most form stays buried; dark sloping wall dominates. Rejected. |
| scannedbedrock2 | 19,014 | Same source moved1.15m outward. Exposes hanging ledges/teeth and a thin reverse panel. Rejected. |
| scannedbedrock3 | 7,648 | Upright group with inward lower return, unchanged core. Source again mostly buried; little improvement to the wall. Rejected. |
| scanned_single1 | 7,622 | Already-closed Boulder01 fitted anisotropically to3.8×5.4×3.6m. Only an applied vertical strip reads; reverse has a pointed upper transition. Rejected. |
| scanned_replace1 | 8,600 | Same fit, raised center and1.25m local base/cap recession. Reveals the source but creates a moat behind it and stretched upper horns. Rejected. |
| scanned_fitcap1 | 7,262 | Boulder01 uniform3× scale and rigid rotation, highest point4.1m. Its actual3D cap-back intersection controls local recession; lower-only smooth union. Moat reduces, but a singular bulge and pointed upper silhouette still attach to a broad wall. Rejected. |

The whole-source exposure uses a.14m smooth union. Scan signing uses nearest triangle distance and three-ray majority parity. Final fitcap preserves source proportions rather than stretching its vertical axis. All use the existing.25m density lattice, with a.002 minimum absolute changed-node value to avoid near-zero numerical slivers. Trial transforms, world bounds, exact sample counts and save/source hashes are in the corresponding work reports.

The new sources have real uneven fracture surfaces; that usefulness does not make their mapping successful. Embedding a plausible rock in an almost intact broad body leaves a bump, while arbitrary recession exposes caps, moats or overhangs. A rigid long-axis rotation also turns an original small projection into an unwanted peak. These are form/placement failures, not a reason to add dirt, stronger noise or more repeated blocks. Do not expand any of these saves around the island.

## New source qualification

See [source provenance and license](../../../../source/third_party/polyhaven/2026-10-17/README.md). Only official glTF and geometry buffers were downloaded, size/MD5 checked and SHA256 recorded. No website raster preview or material image was downloaded. Separate geometry-only copies strip material references without changing buffer bytes. Blender5.2.1LTS refines those copies; original files are preserved. Work files, exports and native PNGs stay local under the project art policy; their JSON evidence/tools are tracked.

| Source | Delivered triangles after weld | Open/nonmanifold edges | Reduced study |
| --- | ---: | ---: | --- |
| Namaqualand Boulder02 | 97,964 | 396/396 | 4,000 triangles,116/116; still open |
| Rock Face02 | 29,564 | 752/760 | 3,998 triangles,278/286; thin open patch, not a solid candidate |
| Boulder01 | 66,122 | 0/0 | 4,000 triangles,0/0; already closed |

These are actual delivered files, not the website's advertised highest-detail counts. Namaqualand's high-detail source is separately cropped below Blender Z=.10m to remove its scanned skirt, then its single remaining boundary is sealed. That copy has74,976 triangles, one component and zero bad/degenerate edges before reduction;4,000 triangles and zero bad edges afterward. Its group remains low/wide, with a thin oblique central slab; a closed mesh is not automatically a good cliff module. The inserted cap of this repaired source must remain concealed.

An initial normal recalculation on open sources flipped exterior faces. Ten actual inside-out preview frames and the failed work copies remain explicitly marked failed, excluded from the35valid neutral views. Preserving open-source winding corrected that preview. An earlier reduced-source holes-fill also produced five four-face edges; it is not the accepted closed copy. Failure logs remain evidence, not source qualification.

## Fresh verification and limits

There are **24 successful native Godot Metal local images**: eight stages×close/grass/reverse. All three camera transforms match exactly. Four principal water clocks are fixed1.25; cloud sea and waterfall mist remain live. Separately there are **35 valid native neutral source images**: three original geometry copies, three reduced copies and one repaired copy, five views each. No retouched screenshot is used as a runtime result. The gallery is `http://127.0.0.1:18771/bedrock_sources.html`; main preview remains unchanged.

Parent inspected all24local views and selected neutral quarter/back views; the independent review scope is recorded separately. No new whole/far/shore/bottom comparison was made in this continuation. The formal default and user target are reused references, not fresh captures.

Actual exact-float32 raw-skin diagnostics find one component and zero non-two-use edges for all six scan saves. Exposed1 has two components, including a24-triangle detached fragment, despite zero non-two-use edges. These checks precede chunk clipping/publication and do not establish collision, props, grass/vine contact, arbitrary edits, water routing, export or performance. Functional closure does not grant art acceptance.

`build_bedrock_source_review.py` checks the59valid native PNGs, local camera matching, successful capture markers, original/download/reduced source hashes, density/cell/save reports and unchanged production paths. Seven affected Python files parse; Godot's capture dependency check passes. No production support/editor suite was rerun for rejected tool-only source work. No target-hardware claim is made.

Reproduce original sources with `fetch_polyhaven_rocks.py <slug>`, neutral reductions with Blender `refine_polyhaven_rocks.py`, and the separate closed group with `close_polyhaven_boulder.py`. Original-source export/bake use `export_exposed_bedrock.gd` and `bake_exposed_bedrock.py`. Scan saves use Blender `bake_scanned_bedrock.py -- v1|v2|v3|single|replace|fitcap`. The local helper deliberately saves only three views; trial flags are recorded in its parent capture helper. Run `probe_bedrock_local.gd` and `analyze_cliff_volume_skin.py` for bounded raw-skin checks. These are research tools, not automatic game authoring tasks or accepted assets.
