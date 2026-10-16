# Complete rock-source input and rejected local return

Separate input: the original six body/shore/bed surfaces, 42 closed crowns and all 14 existing high outcrop/shelf meshes. The first 48 component hashes match the prior export. Original transforms and models are preserved in the source, without new rock instances. Raw buffers and Blender copies remain local. The density grid is still a bounded local patch, so this does not convert/preserve the whole scene or its decoration.

`rendered_body_complete.json` applies the previous explicit vertical-envelope/cap-distance method to this complete input. `retained_return_v1.json` then replaces only the lower front between actual upper/lower source cross-sections. Its report records the unchanged input hash, actual sections and node count. Both ordinary v4 files load in native Godot; exact cells and upper/lower density isolation are checked in the review builder. No new edit, topology, publication, support or performance fixture is attributed to these two versions.

High outcrops return within the local patch. However, both remain visually unaccepted; the lower-return curve creates a heavier hull despite removing a ledge. No production promotion and no further numeric curve sweep. [Actual review](../../../../review/terrain_fidelity/2026-10-17/cliff_face_replacement/README.md).
