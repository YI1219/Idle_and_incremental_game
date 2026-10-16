# User-endorsed cliff target and local stone relief

The user explicitly endorsed `art/source/visual_targets/2026-10-16/cliff_user_target.png` with “如果真的能改进到这个结果那就完美了”. It is now the current visual target, superseding the earlier interpretation of the similar agent overpaint as a form-only guide. It is still a reference image, not an achieved Godot render or acceptance of an implementation. Existing trees/buildings, overall footprint and editable land remain required.

## Retained implementation

Current default candidate: `spall_finish1_*`, replacing clean_water1 only for stone material detail. `MaterialDetail.bind` loads `assets/textures/terrain/stone_detail_spall_v3.res`, a native lossless ImageTexture with embedded mip chain. The shared stone shader's strength is calibrated to.25 for this packed map. Original stone_detail.png and its nominal.07 fine response are retained as the bake input; the new strength is not an unscaled fine-noise increase.

The generated grayscale guide contributes only its lower35% as shallow depressions; most broad faces remain quiet. The original R mineral-value and A roughness bytes remain identical across every mip level. Existing fine slopes are recalibrated before adding the geological slope; quantization and1.3449% channel limiting mean exact fine-response identity is not claimed. Delivered base-level inspection finds59.66% of pixels within.0028 slope change of the previous fine surface and36.75% with change above.02. The material remains matte; no dirt/albedo/specular increase, new texture fetch, displacement, source geometry, authored data, tree/building, grass, light or water algorithm change.

Source and technical bake:

- Native `image_gen` built-in tool; final complete prompt: [cliff_spall_prompt.txt](../../../../source/materials/2026-10-16/cliff_spall_prompt.txt).
- Saved generated source: `art/source/materials/2026-10-16/cliff_spall_height_v1.png`; original generated file retained under `/Users/yi/.codex/generated_images/01a12b7f-422c-7c23-a8f2-99b82c1e92b9/exec-d9570ccf-6ee3-4dfe-8e1f-589acb750956.png`.
- This grayscale image is an artistic relief guide with some shaded appearance, not measured displacement. It is used only for technical slope baking, never as shaded albedo.
- Reproduce `tools/art/bake_cliff_spall.gd -- local`, which conditions boundaries, filters, keeps local depressions, combines calibrated fine slopes, preserves value/roughness and saves PNG plus mipmapped native texture. Work output: `art/work/stone_spall/2026-10-16/stone_detail_spall_v3.res`; selected runtime asset: `assets/textures/terrain/stone_detail_spall_v3.res`. Provenance/hashes are in validation.json.
- A first whole-project editor import stopped on unrelated unconfigured Blender source importing, despite process exit0; no successful-import claim is made. Auto-created untracked UID files were removed. Native ImageTexture avoids unrelated model importing and is verified through production preload. An exported game package has not been built or tested.

## Actual review

Five stages×seven actual Godot Metal views (35images): before, uniform shallow1, wider2, localized3, production-bound final. All seven cameras, authoritative-data hashes and four principal water clocks1.25 match; clouds/mist remain live. Eleven additional main production captures use the established cameras (water/cloud/mist time is not fixed in that main helper). Main preview uses those images; stone_spall.html contains exact-clock comparisons. Sources remain in adjacent sculpt_base and courtyard_finish directories; no retouched scene screenshot is presented as runtime evidence.

Parent and independent reviewer `/root/solid_smooth_review` support only a limited near-view material improvement. Uniform1 is less organized; wide2 resembles round plaster ripples and is rejected. Local3 preserves calmer planes and reads more like shallow erosion, without observed plastic highlights, full-face ripples or obvious distant noise. Production views and normal binding were reviewed again. Paving shares the material change and remains acceptable. Some artificial etching remains; whole/far gain is small. Wide panels, hard grass lip, horizontal waist band and separate lower shell are unchanged. The full goal stays active/incomplete.

## Fresh checks

`check_cliff_spall.gd` verifies the delivered resource, every-mip R/A identity, mip presence, dimensions and local relief/quiet-face coverage. Existing mip coverage4textures and normals15/15 pass. Actual native wet/downward material controls pass (11,236 foreground, zero unwanted pond-tag changes,11,236 valid bed changes). Bed light/depth/motion/morph controls pass; editor339/339 and decoration regeneration42/42 pass. These establish relevant runtime/asset integrity, not full art, arbitrary scene edits, motion stability, exported-package or target-device performance acceptance. Validation/logs distinguish those scopes. No new GPU timing claim is made.
