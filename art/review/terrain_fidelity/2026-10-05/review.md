# Floating-island terrain revision

Status: functional review passed; visual acceptance pending. The goal remains active.

The active workshop now uses shared rounded contours over sparse 2D height data, rather than a 3D voxel volume. Fixed vertical cliff samples and local profiles preserve distant rocks after local edits. Exposed grass caps subtract higher regions, including holes. An immutable revision builds two chunks per frame, then publishes its meshes, instanced detail, support props and picking together. Newer input coalesces into the next snapshot, so sustained painting continues to publish terrain.

Actual Godot 4.7.2 Metal Forward+ captures, 1672×940:

- [Composition](composition_wip.png)
- [Shoreline](detail_shoreline.png), [cliffs](detail_cliffs.png), [vegetation and cottage](detail_vegetation.png)
- [Raise](edit_raise.png), [lower](edit_lower.png), [expand](edit_expand.png), [contract](edit_contract.png)
- [Editor controls](editor_ui.png)

These captures drain ordinary incremental updates and do not force a full rebuild to mask stale geometry. Each edit starts from the composition layout. [Capture metadata](captures.json) records brush centers, radii and changed cells. PNGs remain local per repository policy; the capture script reproduces them.

The two terraces, ponds, waterfalls, cottage, fences, bench, lantern and solid foliage now follow the reference composition. Existing CC0 Kenney source models are retained with recorded hashes. Cliff modules now use larger embedded stone_largeA groups along the local taper; thin shells reduce their width and depth. Smooth shared normals on the supporting body reduce construction stripes, while stones keep their flat facets. Grass clusters are denser, shrub/vine meshes are centered on their XZ anchors, and the cottage material pass now also handles corrected plain materials. Waterfalls use shared world-height ribbons with larger landing foam. Runtime leaf parts are subdivided, rounded and assembled; originals are untouched. The refined cottage is reused with workshop material/door modules. Bench and lantern remain placeholders. No custom generation service or purchase was used.

Visual differences remain: cliffs read as repeated stacked boulders rather than the target's continuous mass with varied broad facets; tree crowns use regular rounded lobes and grass remains spiky; ponds lack a convincing depth/shore transition; falls still read as luminous curtains with limited splash; the cottage lacks finer timber bays and ornament; procedural clouds lack the target's volume. This is a closer editable reconstruction, not an accepted reproduction. Further custom cottage/model refinement requires a specific asset decision under the user-operated workflow.

Fresh canonical fixed-60-Hz checks for this refinement: 8/8 relevant scripts passed. These cover contours (1025), incremental edits (20), data (301), decoration (171), rendering (339), runtime (22), camera (8), and waterfall continuity (24). Independent review found a mixed-height receiver slit in the first curved ribbon implementation. Its regression failed 12/24 before the fix and passed 24/24 afterward; the reviewer independently reran it and cleared the issue. The unchanged 28-script gameplay suite was verified on the preceding revision, not rerun as new evidence here. [Verification](verification.json).

Measured on Apple M4 Pro, Metal Forward+, 1280×720, shadows and SSAO enabled, vsync disabled: three 12-second runs after two-second warmups. Median frame time 4.17–4.72 ms; p95 13.34–13.59 ms; worst sampled frame 73.24 ms. Four edits per run became visible in 121.9–152.8 ms. Normal editor updates provide the two-chunk budget; every frame is sampled independently through edit waits. [Measurements](performance.json). The default has 545 cells; these samples end at 543 cells after edits. Draw calls include shadow passes (529 in these samples). Capture runs use fixed-step timing; UI counters in their screenshots are not benchmark evidence.

These short development-machine samples do not establish large-layout scaling, target laptop performance, or long-idle power/stability. Function, visual quality and performance acceptance remain separate.
