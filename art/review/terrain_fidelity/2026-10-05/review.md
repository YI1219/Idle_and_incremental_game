# Terrain fidelity candidate — 2026-10-06

This is an editable Godot reconstruction of the [user reference](../../../source/visual_targets/2026-10-05/terrain_user_target.png), not accepted final art. The sparse 2D height data owns all visible land; it is not a 3D voxel volume. Shared contours and atomic terrain/detail/picking publication remain in use. Camera pan stays horizontal and only the wheel changes height.

## Actual engine evidence

- [Full composition](composition_wip.png), [shoreline](detail_shoreline.png), [cliffs](detail_cliffs.png), [vegetation and cottage](detail_vegetation.png)
- [Raise](edit_raise.png), [lower](edit_lower.png), [expand](edit_expand.png), [contract](edit_contract.png), [editor](editor_ui.png)

These are fresh 1672×940 Godot 4.7.2 Metal Forward+ captures. Each edit starts from the same layout and drains normal two-chunk-per-frame publication. Changed cells: raise 16, lower 12, expand 14, contract 16. Capture timing is fixed-step and is not performance evidence.

## Current visual implementation

The two terraces, rounded ponds, two falls, cottage and surface props follow the supplied composition. Broad cliff spans now subdivide within their stable endpoints at no more than .65 units. Narrow spans retain their existing profile. A world-anchored clipped-octahedron distance field produces stronger physical rock shoulders and recesses; the material uses matching site dimensions/metric and smaller oblique faces. Relief remains width-limited and cached per refresh. The first stronger-relief capture exposed a rock tongue through the lower waterfall. Wet walls and immediate mouth-side neighbors now limit protrusions behind the shared stream envelope, fading clearance at crests to preserve cap joins. Final captures remove that tongue. Embedded CC0 stones retain original model facets and share the terrain palette.

Waterfalls retain physical folds, smooth chunk normals, translucent downward flow and separate opaque pond shading. Kenney CC0 parts supply raised overlapping solid crowns, lifted original forks, grass, shrubs, hanging foliage, reeds, lilies, paths, fences and flattened varied shore stones. The refined cottage retains its original geometry and material-role-based wall/gable panels. Bench and lantern remain placeholders. Original models are unmodified. The sky uses a generated cloud-only bitmap with its [source record and prompt](../../../source/skies/2026-10-05/cloud_backdrop_v01.json), plus neutral cubemap lighting.

Remaining differences include deep cliff scallops, pointed lower projections and elongated patches; modular crown lobes, repeated shore stones and simple lawns; rectangular falls and repeated splash forms; simpler cottage timber/eaves; and more detailed clouds than the scene props. Independent read-only review cleared the initially reported waterfall intrusion, confirmed the crest connection and found no new Important issue. Review inspected actual source/captures without repeating the tests or benchmark. Human visual acceptance remains pending.

## Verification and measured cost

Fresh final checks: contours 1025/1025, incremental 20/20, data 301/301, decoration 118/118, rendering 339/339, runtime 22/22, camera 8/8, waterfall 30/30, shoreline 9/9, model bounds 9/9, narrow cliffs 794 slices with zero overlap (minimum gap .0306). The new actual reference-mesh clearance test failed 29/30 with six blocked curtain samples of 242 before correction; it passes 30/30 with zero blocked samples afterward. Existing mixed-height/fold/splash checks remain passing. This does not exhaust arbitrary layouts, all outlet orientations, unsampled intersections, transparent ordering or temporal shimmer. Checksums confirm eight unrelated local files, eleven Kenney GLBs and two cottage GLBs unchanged. Cottage material 7/7 belongs to `fed1ca3`; unrelated gameplay checks remain older stage evidence. [Verification](verification.json).

Measured on Apple M4 Pro, Metal Forward+, 1280×720, shadows and SSAO enabled, vsync disabled: three 12-second runs after two-second warmups. Median frame time 9.158–9.357 ms; p95 18.554–18.632 ms; worst sampled frame 127.769 ms. Edits became visible in 193.123–221.067 ms. Draw calls 492; static memory about 60.1 MiB and video memory 207.25 MiB. Every frame includes normal incremental-update waits. The preceding waterfall revision measured median 9.070–9.421 ms and edits 130.243–184.492 ms. Denser cliff geometry increases edit latency; this is a visual-fidelity tradeoff, not a performance improvement. [Measurements](performance.json). Windows thin-laptop/MacBook Air performance and long-idle power/stability remain unmeasured.
