# Qinglan fabric v05 review

Historical version evidence. Current runtime and unresolved visual status are in the [v06 garment review](../garment_v06/review.md). The v04 ankle-length trouser extension was not the intended design and is reverted to knee length in v06.

Date: 2026-09-20. This is a material and existing-mesh refinement, with Blender visual evidence. It is not full character art acceptance or a performance result.

## Diagnosis and changes

The inspected v04 garment had no UV layers or image textures. Robe, ivory lining, trousers and cyan sash all used flat color, roughness 0.86 and default specular. Increasing roughness alone would not address the broad rounded folds, outward sleeve volume and uniform surface that contribute to the plastic appearance.

The v05 refinement:

- Preserves the Tripo-derived robe mesh and its face topology. Lower garment depth is reduced by up to 19%, lateral flare by 7%, and sleeve depth by 12%. Shallow 2.5 mm sleeve creases use the existing vertices. The largest displacement is 0.06545 m at the previously most extended lower robe; most vertices move less.
- Adds a UV layer to each garment component at a consistent 16 cm texture repeat. Six 512 × 512 maps provide four subtly varied cloth colors, a shared plain-weave normal and a shared roughness map. Color encoding preserves the original blue-gray, ivory and restrained cyan palette.
- Uses low dielectric specular, local roughness variation and bounded sheen, with no metallic or coated surface. Texture detail is intentionally small, visible most clearly on the sash and near-camera sleeve/robe surface.
- Preserves the covered-calf body mesh, extended lower trousers, ribbon geometry, rig transforms and ten authored animation tracks. Only the upper trouser waistband has changed bindings, as described below; all robe and other garment weights remain unchanged. No scene or player-controller file is changed by this task.

The integration agent inspected Godot's imported materials: albedo, normal and roughness textures arrive correctly, but Blender's reduced specular does not carry through (Godot retains `metallic_specular = 0.5`). The integration adds a focused runtime override of `metallic_specular = 0.18` on robe/ivory/pants/teal. Blender sheen and specular should not be assumed identical in Godot; the images here describe Blender appearance, and runtime acceptance uses the integration captures.

## Inherited waistband intersection

Turning exposed large white wedges at the rear waist, also visible in the original v04 idle-back view. A diagnostic render with trousers colored magenta identified the wedges as upper trouser surfaces protruding through the fitted bodice. The old trouser top rings reached z=0.6163, above the actual waist around z=0.55–0.56.

The existing top rings now sit at z=0.553 and fit inside the robe, with a narrower transition into the upper thighs. Only the top 16 vertices per trouser are reweighted to Hips so the waistband follows the pelvis. The next two upper-thigh rings receive a lateral fit adjustment; knee/hem positions and lower-leg bindings remain unchanged. No faces or additional body surfaces are removed. [Diagnostic](diagnostic_pants_back.png) and the before/after turn renders document the true cause and correction. Ray inspection of the remaining long side wedge hit upper-trouser faces 0 and 17, confirming the trouser tubes were wider than the fitted robe. Narrowing those existing rings removes the broad white wedge in the reviewed turn frame; a thin line of white remains at the source garment side opening. These samples do not establish intersection-free motion for every frame.

## Visual review

The comparison images use the same CPU Cycles scene, cameras, lighting, animation and sample times for both versions. They are rendered from the actual Blender work files, not concept art or Godot screenshots. Six views per version cover front/three-quarter/rear idle, front/side run and a closer fabric view.

- [Fabric close comparison](fabric_closeup_comparison.jpg): the v05 sash and sleeve have a fine woven response; v04 is uniformly smooth. At full-character distance the texture difference is deliberately restrained.
- [Idle silhouette comparison](idle_threequarter_comparison.jpg): lower bell and sleeve volume are reduced while the layered outline remains.
- [Run front comparison](run_front_comparison.jpg) and [run side comparison](run_side_comparison.jpg): the sampled poses retain clothed lower legs and bare feet. These two poses are not an exhaustive intersection test.
- [Rear waistband](idle_back_comparison.jpg) and [captured turn](waist_turn_comparison.jpg): the inherited broad white waist/upper-thigh wedges are removed in the reviewed frames. A thin inner-white sliver remains at the source side opening.

The reviewed result is an incremental improvement, not a complete removal of the rigid appearance. The large cuff still forms a broad sail, some skirt folds are visibly coarse, the body/face remain stylized and unfinished, and v04's strong leg coupling in the lower robe is unchanged. These are shape, deformation and motion limitations that a weave map cannot resolve. Final judgment must include Godot lighting and the newly integrated gait/turn motion.

## Cloth simulation decision

No cloth solver was added. Cloth simulation is not required to make the surface read as fabric: UVs, yarn-scale normals, roughness/specular response and better fold geometry can do that. Dynamics are a separate problem. Simulation or controlled garment-specific secondary motion may help cuffs, hems and ribbons react to acceleration and turns; the current model still uses its preserved skirt/ribbon animation and body-driven skinning. This pass does not claim collision-aware cloth or natural free drape.

## Verification and reproducibility

[Export verification](export_verification.json) verifies that all ten GLB animation samplers/channels, rest nodes and inverse bind matrices are identical to v04. All ten meshes retain face topology. All robe/body/ribbon/belt skin weights remain unchanged. Trouser vertices below the three upper rings retain exact positions, and weights below the waistband remain unchanged. Body/ribbon/belt positions are exact. Embedded albedo and normal maps are present on all four cloth materials. This proves data preservation, not natural animation or complete art quality.

- Source: `art/work/qinglan/qinglan_clothed_v04.blend`, SHA-256 `3ddad51f7f28658eef83f260f2b010a2fff982b78784f36039ab68bafd431046`
- Work file: `art/work/qinglan/qinglan_fabric_v05.blend`
- Runtime: `assets/characters/qinglan/qinglan_fabric_v05.glb`, SHA-256 `572af160e2056283952e83a85e4f14484642dffb4dd4bf72c55e62f5a45d86e5`
- Preserved maps: `assets/characters/qinglan/fabric_textures/`
- Build: `blender --factory-startup -b --python tools/qinglan/refine_fabric.py`
- Preservation check: `blender --factory-startup -b --python art/review/fabric_v05/verify_preservation.py`
- Render: `blender --factory-startup -b --python art/review/fabric_v05/render_comparison.py`

No performance benchmarks, purchases, Tripo actions, original-file replacements or shared-document edits were made.
