# Floating-island terrain revision

Status: functional review passed; visual acceptance pending. The goal remains active.

The active workshop now uses shared rounded contours over sparse 2D height data, rather than a 3D voxel volume. Fixed vertical cliff samples and local profiles preserve distant rocks after local edits. Exposed grass caps subtract higher regions, including holes. An immutable revision builds two chunks per frame, then publishes its meshes, instanced detail, support props and picking together. Newer input coalesces into the next snapshot, so sustained painting continues to publish terrain.

Actual Godot 4.7.2 Metal Forward+ captures, 1672×940:

- [Composition](composition_wip.png)
- [Shoreline](detail_shoreline.png), [cliffs](detail_cliffs.png), [vegetation and cottage](detail_vegetation.png)
- [Raise](edit_raise.png), [lower](edit_lower.png), [expand](edit_expand.png), [contract](edit_contract.png)
- [Editor controls](editor_ui.png)

These captures drain ordinary incremental updates and do not force a full rebuild to mask stale geometry. Each edit starts from the composition layout. [Capture metadata](captures.json) records brush centers, radii and changed cells. PNGs remain local per repository policy; the capture script reproduces them.

The wider upper terrace, shifted ponds and falls, supported trees, cottage, fences, bench and lantern now follow the reference composition more closely. Existing CC0 Kenney source models and the refined cottage remain unchanged. The supporting cliff body now carries broad world-anchored material facets and physical shoulders, with occasional embedded stone_largeA models rather than repeated vertical stacks. Extra shoulders fade out on narrow profiles. Runtime canopies use fewer, larger overlapping lobes; hanging foliage assembles flattened leaf sprays; shoreline stones have flattened runtime tops. The cottage has broader workshop proportions and adjusted timber shading. Bench and lantern remain placeholders. No custom generation service or purchase was used.

Pond shallow-bank and floor-depth color derive from the same terrain snapshot. Its texture publishes alongside the completed mesh, keeping partial rebuilds from changing visible water early. This adds a shoreline appearance transition, not refraction or fluid simulation.

Visual differences remain: broad cliff areas are smoother than the target's broken rock volumes; tree crowns use regular rounded lobes and grass remains spiky; shoreline stones repeat; falls read as luminous curtains with flat, sharply cut foam; the cottage lacks finer timber bays and ornament; procedural clouds lack volume. This is a closer editable reconstruction, not an accepted reproduction. Fine custom-model changes remain subject to the user-operated asset workflow.

Fresh canonical fixed-60-Hz checks for this refinement: 10/10 relevant scripts passed. These cover contours (1025), incremental edits (20), data (301), decoration (146), rendering (339), runtime (22), camera (8), waterfall continuity (24), atomic shoreline publication (9), and narrow cliff separation (794 mesh slices). The shoreline test failed before its implementation and passed afterward. Actual triangle slicing caught two mid-height wall overlaps after the added shoulder relief; removing the new relief passed as a control, and width-based fading fixes the overlaps. Independent review verified the classification and reran the 794 slices without overlap. Minimum sampled gap was 0.0306 world units. This case is not exhaustive across all terrain configurations. The unchanged 28-script gameplay suite belongs to an earlier revision. [Verification](verification.json).

Measured on Apple M4 Pro, Metal Forward+, 1280×720, shadows and SSAO enabled, vsync disabled: three 12-second runs after two-second warmups. Median frame time 5.915–5.953 ms; p95 15.247–15.724 ms; worst sampled frame 67.383 ms. Four edits per run became visible in 104.250–151.149 ms. Normal editor updates provide the two-chunk budget; every frame is sampled independently through edit waits. [Measurements](performance.json). The default has 595 cells; samples end at 593 after edits. Draw calls include shadow passes (503 in these samples). Static memory was about 57.8 MiB and reported video memory 194.4 MiB. Capture runs use fixed-step timing; screenshot UI counters are not benchmark evidence. The prior revision measured lower p95 values; these samples do not show a performance improvement from the visual changes.

These short development-machine samples do not establish large-layout scaling, target laptop performance, or long-idle power/stability. Function, visual quality and performance acceptance remain separate.
