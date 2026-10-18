# Two-route PCG continuation

Latest user approval: try fracture-network route1, then actually try master
route2 if route1 fails. Both have now been rendered, including one additional
existing-master main-face refinement;64native frames in total. **No art candidate is
accepted; full goal incomplete.** No production/default change or new asset.

## Latest: main-face / shoulder / basal refinement also rejected

The earlier blanket handoff of all master refinement to the user was too broad:
AGENTS also permits refinement of existing sources. Within that existing-source
scope, one further deliberate coordinate deformation creates an asymmetric
central major-face turn, unequal shoulder projection and shared inward basal
return. The original and earlier trial remain untouched.24new native frames in
`route2_faces` compare original/direct/sampled, neutral/stone, all4views.

The turn is more visible, but the wide slab/three-pillar composition, hard green
roof and hanging/angular lower masses remain. Direct geometry also fails with
3strict self-crossings near face6149 despite closed oriented topology. The
sampled25,340triangle body passes the finite gate, but this cannot validate the
crossed input or faithful conversion. Source remains2248triangles, direct8992.
Never use sampled validity to promote the rejected source.

17,359samples,569independent float64 three-ray crosschecks and3resolved BVH
disagreements. New actual-data/history9/9 pass. The extracted default deformation
is byte-identical to its archived old output; exact cap occurrences and finite
values pass3/3regression checks. These do not validate geometry or art. Positive
coordinate scales and monotone profiles do not guarantee an embedded final
triangle mesh. Code now explicitly says so.

Parent and targeted independent reviewer reject retention. This is the second
mother study without useful target-art gain, so the goal's stop condition now
requires a source-strategy decision: deliberately refine an existing-source copy
against approved shape direction, or explicitly authorize a new master concept/
four-view reference package. Neither means master-based PCG is disproven. No new
Tripo task, user submission or automatic generation is implied or authorized.

## Route1: reject the present implementation

First3D weighted partition uses shared pair planes but layered seed placement
creates masonry courses. Its8native frames are archived in
`route1_layered_rejected`. It has4edge/link defects, one component, zero strict
crossings under the finite detector. Shared compiler data checks14/14 pass.

The one substantive correction uses19unlayered anisotropic Poisson sites with
shared pair planes, tilted exterior facets and inward lower planes.8new frames
reduce courses but retain broad wall panels, continuous lawn roofing, jagged
cleft edges and an abrupt underside. Finite geometry also fails:4edge/link
defects and components26,480+14vertices. No source-mesh fragment deletion or
normal trick hides this failure. Fresh field14/14 and pair-plane4/4 checks
establish bounded data behavior and the declared shared-plane metric only.
Four candidate cells per sample are a tool approximation, not an exact global
distance-to-partition proof. No more rule tuning or leaves proceeded.

## First route2 study: conversion feasible here; qualified master missing

Actually tested the preserved closed2248triangle union of crowns36/37/38,
translated by(15,0,-3). Original source SHA256 remains
`aa2a16c21c8c3eeeedb2c89cf5d8c5ba4ab1387d879e42a87ae3d2b73cd1bb4b`.
One linear midpoint subdivision plus coherent deformation narrows/deepens its
lower part; this refines existing geometry rather than creating an original
model. Original input files remain untouched. Editable Blender copy:
`art/work/pcg_fracture/2026-10-18/route2/existing_master_refinement.blend`.

24native frames show original, deformed direct mesh and .25m production
reconstruction, each in neutral/stone and four matched views. All3finite
unedited geometry gates pass:2248/8992/23584triangles, one component, no recorded
edge/link/degeneracy/strict-crossing errors. These are finite tests, not a global
proof. Conversion uses3BVH rays per node plus556independent float64 three-ray
crosschecks;2BVH disagreements resolved by that fallback.15,780saved samples.
3299protected cap entries count triangle vertex occurrences, not unique points.

The direct master already has a three-pillar composition and hard green cap;
deformation lengthens the broad faces. Sampling softens turns and adds edge
scalloping. Neither is an acceptable master or a useful target-art promotion.
This does not disprove a master-based workflow: it identifies its missing
prerequisite. Stop global stretch/grass/detail sweeps; deliberately author the
main-face/cleft/shoulder/basal composition in the master first.

Independent review found sampled material depth initially came from the
unrelated81cell contour while direct controls used the actualY3.5cap. Corrected
sampled depth to the same3.5-y rule and freshly recaptured all24frames. Checked
body hashes remain identical. Initial mismatched captures are superseded and
not counted. New actual-master data checks9/9 verify ordinary load, finite
capacity, public carve, exact undo/redo and edited reload. **Edited geometry was
not checked**; data history is not a surface-validity guarantee.

## Evidence limits and next work

All64native frames are1671×941, same4cameras/light/material settings. Route1
uses the81cell crop; route2 uses a different existing-source strip. Reference
composition differs. Four older ring-neutral images are labeled reused.
No leaf/contact decoration, rooted support, native editor controls, arbitrary
layouts/edits, two-contour/two-seed visual coverage, collision or target-device
performance acceptance. Prototype recipes are separately archived; they are
not newly implemented shared author/player semantic editing controls.

Both parent and independent reviewer reject art promotion. Route2 remains the
recommended direction only after a qualified source master. See
`master_art_brief.md` for concrete shape corrections. Current source files and
brief are reviewable; no new Tripo task, credit spend or model generation is
required by this report. User visual approval is still required for the goal.

## Reproduce

```
godot --path . --script tools/art/capture_pcg_fracture.gd --log-file /tmp/yunlu-fracture-native.log
godot --headless --path . --script tests/pcg_cliff_field_test.gd -- --compiler=res://tools/art/pcg_fracture_field.gd
godot --headless --path . --script tests/pcg_fracture_partition_test.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/probe_cliff_master.py
godot --path . --script tools/art/capture_pcg_master.gd --log-file /tmp/yunlu-master-native.log
godot --headless --path . --script tests/pcg_master_data_test.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/check_pcg_cliff.py -- --input=art/work/pcg_fracture/2026-10-18/route2 --stages=master_source,master_warp,master_sampled
python3 tools/art/build_fracture_master_review.py
```

For the additional mother study run Blender `tools/art/refine_master_faces.py`,
then `capture_pcg_master.gd` with user args
`--input=res://art/work/pcg_fracture/2026-10-18/route2_faces/`
`--output=res://art/review/terrain_fidelity/2026-10-18/pcg_fracture/route2_faces/`.
Run the same geometry checker on route2_faces with all3stages. Data test accepts
`--input=res://art/work/pcg_fracture/2026-10-18/route2_faces/master_sampled.layout`.
Blender `tools/art/check_master_refinement.py` reproduces3regression checks.

Archive first layered compiler snapshot separately; current compiler is the
unlayered correction. Generate route1 geometry checks similarly with its input
directory and `--stages=fracture_neutral`. Builder requires exact expected stages,
matching body hashes, matching camera/image records, current clean capture/test
logs and unchanged production paths. Reports/documents are tracked; images,
mesh/save/Blender files remain local, reproducible from the preserved inputs.
