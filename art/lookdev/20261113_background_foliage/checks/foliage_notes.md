# Botanical foliage candidate — in-memory experiment

Production scripts, shaders, atlas, tree/shrub counts, colors and lighting were not edited. This experiment has no native captures or GPU/FPS measurement of its own. Parent samples it serially in the shared native harness.

## Call and restore

```gdscript
var foliage = load("res://art/lookdev/20261113_background_foliage/checks/foliage_candidate.gd").new()
var report: Dictionary = foliage.apply(editor, "early_alpha")
# Wait for shader compilation and normal warmup; measure the normal runtime.
foliage.restore()
```

Modes are `early_alpha` (default), `exact_index`, and `combined`. Restore before another apply. Apply after scene construction settles; later rebuilds use original production assets. The object retains exact original mesh references and shader text for restoration. It never saves resources. It keeps the original shader resource path so existing environment/day-night material matching still works. Restoration skips an object if somebody changed that object's mesh or shader code after candidate application.

`exact_index` changes only the known one-surface triangle meshes with position/normal/color/UV/optional UV2 streams and no existing indices; unfamiliar meshes are left intact. All shared users reuse one replacement. It retains ordered triangles, materials, CPU geometry metadata, every original vertex attribute, and the original five-point curvature. The source shader never uses vertex indices; therefore vertex reuse does not change the shader's inputs, animation, normals, UV interpolation, shape or area. Prototype construction retains the original meshes for reversal, so this test does not demonstrate lower total application memory or faster rebuilds.

## Exact Godot 4.7.2 alpha behavior

Installed version: `4.7.2.stable.official.ed1daf0bf`; project uses Forward+. Confirmed against the official version tag:

- [Forward+ fragment implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl#L1383): the custom fragment body runs first. Normal color/depth/shadow rendering then discards alpha below the scissor threshold. This happens **before** alpha antialiasing.
- [AA implementation](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/scene_forward_aa_inc.glsl#L43): when scissor and AA both exist, the effective edge is the clamped sum of the scissor and AA edge values. Here it is `.23 + .27 = .50`. The remaining alpha is sharpened using its derivatives and clamped to [0,1] for coverage.
- Current foliage does not write `ALPHA_TEXTURE_COORDINATE`. The renderer initializes that coordinate to zero, so the AA helper's mip-level multiplier contributes zero. Texture sampling itself still uses the runtime-generated mip chain.
- [Official documentation](https://docs.godotengine.org/en/latest/tutorials/3d/standard_material_3d.html#alpha-antialiasing) recommends an AA edge lower than the scissor threshold. This candidate preserves the current `.23/.27` constants and their actual rendered behavior; it does not attempt to restyle edges.

`early_alpha` adds only `if(tex.a<.23)discard;` immediately after the existing texture sample. The same pixels already fail the renderer's later scissor, while local pigment/normal/mist math is skipped sooner. The comparison is strict `<`, exactly matching the renderer. It does not use `.27` or `.50` as a discard threshold. Existing terrain transition discard remains first. The texture sample and all inputs/constants remain unchanged. Local pigment math contains no derivatives or side effects, and the engine's derivative-based AA remains after the same failed pixels are discarded. GPU compilation may already move or predicate similar work; performance benefit remains unmeasured until native sampling.

Boundary: `MODE_RENDER_MATERIAL` (material baking) sets alpha to zero instead of discarding at this point. The early discard candidate is intended for the current ordinary live scene and its depth/shadow passes, not a change to material-bake semantics. It has not been tested with other renderers or future engine versions.

## Counts and choice against geometry trimming

Base-level atlas data (`foliage_atlas_analysis.json`) shows zero-alpha texels in 76.18%, 76.44%, 74.89%, and 74.99% of the four cells. Texels below `.23` account for 78.13%, 78.39%, 76.58%, and 76.66%. These are texel counts, **not** screen pixel coverage or savings. Bilinear sampling, trilinear mip blending, camera angle, overlapping cards, MSAA helper quads, depth, and shadows affect actual work.

The alpha content is concentrated inside each 512² cell: nonzero inclusive bounds are `[62,79,453,351]`, `[60,80,452,348]`, `[37,106,466,369]`, `[40,109,463,365]`. Merely cropping to those bounds is not a sound exact substitution: production loads the full atlas and calls `Image.generate_mipmaps()`, so filtering has support outside base-level content. More importantly, inserting/moving clip vertices changes the sine/cosine flutter evaluated per vertex and the normalized vertex normals before interpolation. This can change visible interiors even if a static discarded corner appears safe. A correct clipping implementation would need to reconstruct interpolation from each original animated triangle and prove filtered-alpha bounds across the mip chain; that extra complexity is outside this candidate.

Conservative alternative `exact_index` preserves 4 triangles/card and 100% of geometry/raster area, while changing 12 submitted vertices to 5 (58.33% fewer vertices). It can reduce repeated vertex shader invocations and vertex bandwidth, but does not reduce transparent raster area or fragments. The source shrub has 45 cards plus 8 collar triangles: 564 source vertices and an expected 234 exact unique vertices, with all 188 triangles retained. The native helper reports actual whole-scene unique vertex counts. No target hardware result is inferred.

## Verification

- `foliage_candidate_test.gd`: initial RED was the missing helper (1 explicit failed assertion, retained in `foliage_red.log`). GREEN: 22 checks, zero failures (`foliage_green.log`), headless dummy renderer, roughly 0.1 seconds.
- The fixture checks complete expanded position/normal/color/UV streams, ordered triangle positions, curvature, AABB, original material and shader identity, shared mesh reuse, two-instance placement buffer and count, unrelated geometry, source path, exact early-only text, combined mode and reversible restoration.
- `foliage_atlas_analysis.py`: read-only PIL/numpy atlas analysis, with original source/atlas SHA256s in the JSON output. It changes no texture or import options.
- No native Godot process, frame capture or GPU benchmark was launched by this subtask. Functional checks do not establish art acceptance or FPS benefit.
