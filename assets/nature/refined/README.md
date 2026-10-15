# Refined retained cliff source

`cliff_main_v4.glb` is a Blender refinement of the existing CC0 Quaternius Stylized Nature MegaKit `Rock_Medium_2.gltf`. Original files remain unchanged in `../quaternius`; see `../quaternius/License_Standard.txt` for the original license. This derived asset retains CC0 terms.

The user explicitly authorized Codex to operate Blender for this selected existing-source task on 2026-10-15. No Tripo service, purchase, new tree/building, or independent original rock body was used. The source silhouette vertices repair inherited inward knife folds; six oblique shoulder sections and directional deformation give broad local face changes. Near-coincident section vertices are welded before triangulation. The complete neutral GLB has 634 triangles, zero nonmanifold edges and zero degenerate faces in Blender.

Reproduce with `blender --factory-startup --background --python tools/art/refine_cliff_main.py -- v4` from the repository. Factory startup avoids user addons. Original and versioned work files are retained under `art/work/cliff_refinement/2026-10-15/output`; report, hashes and neutral five views are in `art/review/terrain_fidelity/2026-10-15/cliff_refinement`.

Runtime uses this source for main crown profiles23/41 and low rim shelves; high source1 and the calm lower closure remain. V1/v2 were rejected for added bands; v3 retains inherited thin folds. Only v4 is selected. This is a modest shape correction, not full island art acceptance or hardware performance acceptance.

`cliff_tall_v2.glb` refines retained source1 (`Rock_Medium_1.gltf`, original342 triangles) into816 triangles. It preserves the source surface (no convex reconstruction) and adds three broad oblique directional turns, keeping its original cap/foot shape. Original source hash remains unchanged. Saved `.blend`, exported GLB, five neutral views and `refined_tall_v2.json` record this variant. Reproduce with the same factory-startup command using `-- tall_v2`. The convex tall_v1 trial was rejected because its lower shoulder became pointed in the actual wall. Runtime uses tall_v2 for crown profiles11/37 and tall rim outcrops. Source2 main v4 is unchanged.
