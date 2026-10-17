# Cliff representation probe

**Goal:** Compare three existing adjacent cliff sources, their native Manifold union, and the same union reconstructed through the current 0.25m editable field. Separate geometry loss from shading and material contact.

**Scope:** An authorized throwaway art/geometry experiment, not a production terrain rewrite. Work in the current scene-art branch because the existing local ignored source assets are required. Preserve all originals and runtime defaults. No Tripo submission, tree/building/layout changes, engine fork, or new custom official geometry.

**Inputs:** Exact retained world-space closed crown_36/37/38 source triangles (walls plus closure lids) in art/work/rendered_island/2026-10-17/complete. Production draws walls without these lids. Record checksums and validate winding/closedness before trusting a solid conversion; omit identical covered horizontal lids in scene-only draw controls.

- [x] Export native CSG union and a bounded top-clip control; record geometry, operation timing and kernel failures.
- [x] Measure union topology, connected components, signed volume, and independent nearest-surface/ray consistency. Sample its signed distance at the existing 0.25m spacing without smoothing or extra form rules.
- [x] Reconstruct through the existing rock_sculpt_mesh implementation. Capture identical near, oblique and reverse cameras for source assembly, union and sampled reconstruction, with both flat and identical crease-normal controls. A geometric gain cannot be inferred from a normal change.
- [x] Only after geometry comparison, try a tool-only height-aware material-contact control on the same mesh and lighting. Preserve source geometry exactly; do not claim physical grass silhouette from material blending.
- [x] Review native images, publish a local comparison, replace stale current status, and commit/push reproducible tools and evidence metadata. Keep rejected candidates out of production. Art acceptance, runtime editing and target-device performance remain separate.

**Decision rules:** Failure to obtain valid closed input blocks that input, not the entire task. If union preserves a weak source shape, report source limitation rather than declare the kernel beautiful. If sampling loses features, quantify that difference before considering feature-aware extraction. Material work cannot compensate for a rejected silhouette. Small finite validation does not establish arbitrary player sculpting or real-time CSG performance.

**Result:**49valid native frames; production unchanged. Preserve boolean route as a candidate; reject sampled promotion and height-contact adoption. Source shape, editable fidelity and physical contact remain open. Review and exact limits: art/review/terrain_fidelity/2026-10-17/cliff_representation/README.md.
