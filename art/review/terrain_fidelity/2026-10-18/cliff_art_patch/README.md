# Local cliff form and contact study

Decision: retain `assembly_seated` only as a limited, **unaccepted local structural lead**. No production, default, source-asset, editor or backend promotion. Full art goal remains incomplete. [Native comparison](http://127.0.0.1:18771/cliff_art_patch.html).

The user approved the next actual art step after pausing broad kernel research. This study refines the three existing world-space source copies crown36/37/38, then tests physical grass contact in the same scene. It does not generate a model, use Tripo credits, replace trees/buildings, darken materials, or change the island footprint/layout/water.

## What the images establish

- `assembly_cage`: coherent frame-aligned piecewise-affine changes add slight turns to existing faces. Broad molded wall proportions persist.
- `assembly_seated`: an additional unequal monotone lower-height mapping covers some separate lower shelf beneath the left/central sources. It also lengthens broad panels. The distinct dark faceted underside, wide shoulder and long reverse wall remain; far gain is small.
- `assembly_baseline_contact` and `assembly_seated_contact`: six low groups use the existing full grass-leaf source, with mixed lean, irregular two-dimensional footprints and supported roots. They add small local silhouette volume. Long hard cap lines remain, reverse views still read as blade groups, and the far composition barely changes. This is not a finished sod/stone transition.

Parent and independent reviewer inspected the current controls. Neither recommends art promotion. Do not propagate the lower extension or add a grass-density sweep. A later attempt needs to change the relationship between unequal main faces, shoulder and basal return together; independently stretching existing panels cannot deliver the target.

## Geometry and contact evidence

`tools/art/sculpt_cliff_art_cage.py` works on retained source copies in Blender, splitting along affine cage boundaries before moving vertices. Tangent coordinates and cap positions stay pinned; optional lower seating changes height monotonically. Original files remain byte-identical against recorded SHA256 hashes. Retained work is in `art/work/cliff_art_patch/2026-10-18/retained_cage.blend`.

All six individual cage/seated source components pass the finite closed/oriented one-component, vertex-link, degeneracy and strict nonadjacent triangle-crossing checks. They have 1,290/1,242/1,246 and 1,650/1,550/1,556 triangles respectively. This finite detector excludes shared-position adjacency and coplanar overlaps; zero is not an exact global proof. Cap area differs by less than 1e-4 m²; bidirectional cap-vertex coverage also passes at 1e-5 barycentric or 1e-6 m nearest-edge tolerance. The maximum measured new cap-point edge deviation is 5.313e-7 m. Triangulation changes, so cap topology/bytes are not identical.

The rendered `assembly_*` inputs are exact concatenations of three independently overlapping source bodies, matching production drawing semantics. They are **not** a validated single embedded surface. Diagnostic native Boolean unions are rejected: cage has four bad edges/four collapsed faces/six vertex-link defects; seated has twelve/twelve/sixteen plus two strict crossings. Neither union is drawn in the current controls.

Contact checks retain all 84 intended fans and all 84×465 = 39,060 source vertex occurrences. Roots are 12 mm buried at Y3.488 and supported by actual drawn dry-cap triangles at Y3.5. The original authored contour alone omits derived crown extensions, so it is insufficient for this fixture. This validates root anchors, not every leaf contact. No solid turf pad, painted band, added ground or new model is used. These six composed locations are a tool-only fixture, not an editable placement algorithm.

The existing vines are not re-seated on modified walls. No vine-contact, collision, picking, support after edits, save migration, editor integration, FPS or target-device acceptance is claimed.

## Native capture and rejected stages

20 current native Godot frames: twelve geometry controls and eight contact controls. Four matched views (close, grass, reverse, far), 1671×941, same material/65° normal helper, exactly three replaced stone draw slots. Authoritative data SHA256 is unchanged across runs. Covered horizontal lids are omitted as in production wall rendering. Water clocks are fixed at 1.25; cloud/mist remain live, so images are not pixel-identical controlled renders.

24 additional frames are explicitly quarantined and excluded from the 20 current controls:

- `rejected_plane_fit`: eight frames of the initial independent fitted-plane displacement. Sources37/38 and the union self-intersect; rejected regardless of visual appearance.
- `rejected_authored_domain_only`: eight frames retain only seven of 84 intended fans because support queried the original contour rather than the derived drawn cap. Incomplete test.
- `rejected_low_comb`: eight frames retain all source faces, but low uniformly leaning groups resemble combed straw; art rejected. The final contact fixture changes composition, not density.

`validation.json`, `geometry_checks.json`, `cage_refinement.json`, contact metadata and retained logs record scope and hashes. `build_cliff_art_patch_review.py` checks original hashes, exact assembly concatenation, per-component gates, cap coverage, complete leaf counts/support, image dimensions/camera matching/data identity and clean final logs before rebuilding the gallery. Fresh broad gameplay tests were not run because production files are unchanged; historical tests are not claimed for this round.

## Reproduction

Run `export_cliff_art_frames.gd`, then Blender `sculpt_cliff_art_cage.py`; this writes source copies and the exact independent draw assemblies. Diagnostic `union_cliff_art_patch.gd -- cage` / `-- seated` outputs remain rejected and are needed only to reproduce their checks. Run Blender `check_cliff_art_patch.py`, then serial Godot captures with `capture_cliff_representation_scene.gd` (assembly_baseline,cage,seated) and `capture_cliff_art_contact.gd` (assembly_baseline_contact,seated_contact). Supply this work/review directory through their input/output arguments. Finally run `build_cliff_art_patch_review.py`. All native assets/images/work files are local ignored evidence; tools, metadata, reports and logs are tracked.
