# Existing short-leaf contact pairing — local candidate only

`bare_*` / `grass_*` are actual matched-camera Godot captures of the same lower-return mother and shallow pond. Terrain/data/geometry hash is unchanged when grass appears; no new ground or rock/tree placement tool is rendered. **This is a modest contact candidate, not accepted island art.** Sparse leaves soften isolated joins, but the angular turf edge and inadequate main rock form remain conspicuous. The side-plane candidate is independently rejected and is not used here.

## Resource pairing and root correction

The retained `Grass_Common_Short.gltf` contains three short9vertex leaf components and six taller21vertex wisps. Scaling the whole plant made fine wiry tufts. The final helper explicitly reuses only the three short components, preserving their original curves. Source files are unchanged. No new model, texture or atlas is generated. All emitted leaves share one mesh/material, with the same broad ground-green formula; the terrain is not changed to conceal the join.

The first helper used the generic terrain triangle builder and flattened every bottom10%point onto the ground. That discarded/collapsed tiny root triangles, leaving some rendered bases about1.5cm from recorded roots. An independent actual-mesh support test caught it. The final helper retains nondegenerate small leaf triangles (cross²threshold1e-14 rather than terrain1e-8), follows local slopes without flattening lower stems, and buries literal source-base points9mm. Fans with unsupported bases are rejected.

Correction2026-10-20: the up-to.079mm measured difference was Mesh.get_faces helper snapping, not uploaded/retrieved display vertices. Direct vertex-array tests now show0m root drift; [precision correction](../volume_collision_precision/README.md). The following historical tolerances/results remain measurements of that earlier helper representation. The independent test locates each actual emitted root within.2mm and checks its density≤.0001 in the authoritative edited solid. This tolerance still rejects the earlier1.5cm gap. It does not assume metadata counters alone prove rooting or promise every leaf-tip support after arbitrary edits.

## Actual evidence

Final native fixture:48fans/1008triangles/288root checks,2unsupported candidate fans rejected. The early whole-plant version was about5535triangles; its screenshots were overwritten by the corrected final capture, not retained as claimed comparison frames. The test failure and diagnosis are described here; no claim that both visual stages remain available.

`grass_cut.png` / `grass_restored.png`: a real local cut removes the previous anchor; undo restores terrain data, terrain hash and grass hash exactly. Full erasure and restoration are separately tested. The grass helper reads the current edited height/gradient/density, never a hidden decorative floor or old static cap height. This is a tools-only derived cosmetic build, not production object-placement integration.

`grass_cut_before.png` adds a matched close control focused on the actual front anchor; the cut is visibly in frame. The underlying study material can still give a newly cut upward surface green from its original planting column. Physical grass removal is verified separately; source-depth soil/grass classification after large cuts remains an art limitation, not a solved feature.

Fresh grass8/8: emitted geometry/support, independent actual root positions, no terrain mutation, local cut/undo, full erasure and exact restoration. Native11frames verify same solid/data and exact undo. OneM4Pro fixture measures36.8ms grass build initially and24.4ms after the local cut; not target-device cost, steady gameplay or an optimized incremental build.

Reproduce: `tools/art/capture_volume_grass.gd`; helper `tools/art/volume_grass_contact.gd`; shader `shaders/terrain_editor/volume_grass.gdshader`. Source/default/preset/save untouched, no paid job. Overall goal remains active, local user art gate unchecked. Do not use this small improvement to approve the mother or expand the island.
