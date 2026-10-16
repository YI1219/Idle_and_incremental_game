# Terrain material detail maps

Original stone/ground packed data is baked by `tools/art/bake_terrain_detail.py` using NumPy and Pillow without photographic/generated-image input. The current stone-detail variant described below also uses a generated grayscale relief guide.

Both maps are 1024×1024 tileable **linear data**. R = value modulation, G/B = signed local slopes encoded around 0.5, A = roughness. Do not apply sRGB conversion, normal-map compression or alpha-border repair. Import files enable full mip chains. The runtime palette remains in the shaders.

`stone_detail.png` contains mineral clouds, fine grit and sparse shallow pits; it is projected in world-space triplanar coordinates at a 2.63 m repeat. `ground_detail.png` contains overlapping short blades and fibrous soil at a 2.08 m repeat. Ground value and slope strength follow the existing world-space compression mask so later trampling can flatten it. The bank and physical rim turf share this ground function. Stone uses value, normal slopes and roughness; ground preserves its established high roughness.

Rebuild: `python3 tools/art/bake_terrain_detail.py`, then reimport in Godot. Two uncompressed RGBA8 mipmapped maps need about 10.7 MiB of texture storage in total; this is not a measured target-device budget.

Current stone binding uses `stone_detail_spall_v3.res`, a lossless native ImageTexture with embedded mips, baked by `tools/art/bake_cliff_spall.gd -- local`. It preserves the original stone map's R/A bytes across all mip levels and its nominal fine slope base, then adds localized shallow erosion from an AI grayscale artistic guide. The paired shader strength is.25; using this factor with the old map would incorrectly amplify fine noise. The old map is retained as source. No extra texture lookup or displacement is added. See [source, prompt, actual views and limitations](../../../art/review/terrain_fidelity/2026-10-16/stone_spall/README.md). This material improvement does not resolve the cliff geometry or establish target-device performance.
