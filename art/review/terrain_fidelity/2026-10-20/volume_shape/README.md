# Existing mother refinement — first local candidate

The user explicitly chose “先修现有岩体母样的大形、草石交界和岸坡”. **Local art remains unaccepted.** This is one bounded existing-source correction, not whole-island promotion, a new generated rock, or a completed beauty goal.

## Actual changes and assessment

- Existing source vertices belowY2.15m receive horizontal lower-body smoothing and a gradual inward return. Upper source positions at/aboveY2.15m and all vertical coordinates are retained; the island is not made shallow. Source topology remains5028triangles/2516vertices, one closed connected body. Original GLB bytes remain unchanged. Work file keeps a hidden canonical original plus the selected refined copy.
- The [bank study](../volume_bank/README.md) replaces the deep spherical crater with a designed shallow bank and higher water, in the same editable solid.
- A separate material comparison narrows world-space grass depth/slope coverage. `wide_*` / `narrow_*` use the same refined terrain hash. New values are capture-tool settings; shader defaults retain the previous appearance. No physical turf, grass models, new texture map, high-poly normal bake or extra terrain representation is claimed.

Visual ruling after inspecting front, close, reverse, low, neutral and edited captures: the lower contour is calmer and the pond less crater-like. Narrow contact reduces green on steep faces, a modest change. **The middle remains bulbous, the rear remains a broad blank wall, and the grass/silhouette facets remain visible.** Do not declare the mother attractive enough, expand it across the island, or keep adding texture as a substitute for those remaining structural issues. Next local design discussion should address the main middle/rear planes and cap-edge shape, keeping the mass/contrast baseline; simple lower-body taper alone is insufficient.

## Native evidence

`old_*` versus `refined_*`: identical cameras/lights/material/lake profile, changing the lower mother shape only. `old_neutral` / `refined_neutral` omit pond and maps to expose the actual converted form. `refined_tunnel`, `refined_breach`, `refined_restored` show actual editable geometry and exact undo, not concepts or image edits. `captures.json`:13frames,14904terrain triangles plus78water triangles for the new profile versus16592plus78 for the old mother with the same bank. Native small synchronous rebuild307ms in this run onM4Pro; not an async or target-device result. Contact comparison adds6frames; bank adds8.

`refined_v1.json` is a separate v5source-bound document. `volume_refined_document.gd` inherits the existing save/history validation and binds a different immutable preset hash. Old and new documents atomically reject each other's source-bound edits. No original scene/default/preset/user save is changed. Candidate files live under `art/work/volume_shape/2026-10-20/`; runtime preset is `assets/terrain/volume_patch/source_rock_lower_return_v1.res`.

Blender5.2.1 work audit: no loose/nonmanifold edges or missing images. Its10056triangle scene total includes **both**5028triangle original and candidate; export selects only the candidate. One material, no UV map or textures in this white source; world-space runtime material supplies the finish. Blender and Godot source imports differed by≤.785mm at8.5mwidth; the working copy is explicitly conformed one-to-one to2516preserved Godot source positions before refinement. Godot reimport of the new identity-transform GLB differs by≤.209mm at sampled vertices. These vertex checks are not continuous surface-distance bounds.

Fresh verification: original document21/21; bank10/10; refined source8/8; native original-scene public-input/collision/contact/erasure/undo12/12. Final capture/runtime logs clean. A bounded independent reviewer reran the two new tests, checked source/export/preset hashes, and found no Critical/Important issue; its finite refined-source crossing check found zero strict crossings. That is not a proof for all player edits or user art approval.

## Reproduce and limits

1. Blender: `tools/art/refine_volume_mother.py`, then skill audit script on its saved work file. Use `--python-exit-code 1` so an assertion cannot look successful.
2. Godot headless: `tools/art/pack_refined_volume.gd` verifies actual GLB reimport and packs the independent preset.
3. Godot native: `tools/art/capture_refined_volume.gd`, then `tools/art/capture_refined_contact.gd`. No webpage.

The original source, white model, full-island baseline, saves and unrelated experiments remain preserved. No new Tripo/texture credits, house job, chunks/async architecture, second layout, target-laptop, idle-power or release-export acceptance in this round. Full goal stays active; stage2/3 remain behind the local user art gate.
