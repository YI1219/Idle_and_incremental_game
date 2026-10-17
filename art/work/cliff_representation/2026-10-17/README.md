# Cliff representation probe inputs and outputs

Original three closed crown-source files remain under art/work/rendered_island/2026-10-17/complete and are never overwritten. assembly.bin is their byte-exact concatenation. Native Godot Manifold produces union.bin and union_clip.bin. Sampling/reconstruction tools produce samples.json, sampled.bin and sampled_normals.bin. These are standalone tool data, not an ordinary whole-island terrain save or runtime asset.

Binary source/output/maps stay local under project convention. samples.json is generated local density data; regenerate with the review instructions rather than treating it as an accepted island preset. Metadata is committed. Height maps are regenerated to height_maps only; exact original packed PNG hashes are checked. Source height fields are original procedural material data, not inferred from mineral albedo.

See ../../../review/terrain_fidelity/2026-10-17/cliff_representation/README.md for actual evidence and limitations. No production geometry, player brush, engine fork or Tripo task is introduced.
