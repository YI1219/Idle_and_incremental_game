# Terrain material detail maps

Locally authored deterministic texture data, baked by `tools/art/bake_terrain_detail.py` using NumPy and Pillow. No purchased, photographic or generated-image source is used.

Both maps are 1024×1024 tileable **linear data**. R = value modulation, G/B = signed local slopes encoded around 0.5, A = roughness. Do not apply sRGB conversion, normal-map compression or alpha-border repair. Import files enable full mip chains. The runtime palette remains in the shaders.

`stone_detail.png` contains mineral clouds, fine grit and sparse shallow pits; it is projected in world-space triplanar coordinates at a 2.63 m repeat. `ground_detail.png` contains overlapping short blades and fibrous soil at a 2.08 m repeat. Ground value and slope strength follow the existing world-space compression mask so later trampling can flatten it. The bank and physical rim turf share this ground function. Stone uses value, normal slopes and roughness; ground preserves its established high roughness.

Rebuild: `python3 tools/art/bake_terrain_detail.py`, then reimport in Godot. Two uncompressed RGBA8 mipmapped maps need about 10.7 MiB of texture storage in total; this is not a measured target-device budget.
