# Original body conversion evidence

`source.json` records six original body/shore/bed draw surfaces and 42 closed crown meshes. Per-component raw buffers and Blender copies remain local, originals untouched. High outcrop props and scene vegetation/buildings are excluded. Cells are identical to the canonical preset. Export and bake tools are under `tools/art/`.

`rendered_body_v1.json` and `rendered_body_closed.json` use an unreliable iterative-ray classifier and are rejected conversion evidence. Edge-manifold Blender closure did not fix coincident opposite cap surfaces. The independently computed intersections in `ray_diagnostic.json` and `coincident_diagnostic.json` identify why iterative ray stepping skipped a hit. Closed-source signed volume is not proof of a solid union.

`rendered_body_envelope.json` and `rendered_body_envelopecap.json` instead use analytic vertical intervals. They fill visible overhang air as well as internal gaps, so are not exact or shape-preserving conversion. The cap variant repairs near-top distance interpolation only. All four saves are unaccepted. Only the cap variant has fresh finite 12/12 save/edit checks and raw-skin connectivity checks. See [review and native evidence](../../../review/terrain_fidelity/2026-10-17/cliff_face_replacement/README.md).
