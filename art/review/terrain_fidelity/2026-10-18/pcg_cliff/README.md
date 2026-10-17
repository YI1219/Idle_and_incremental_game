# PCG cliff: small-scene validation

The user explicitly requested PCG work on whole rock shape, grass/stone contact
and side-bottom continuity, with actual engine images beside the October16
target. [Native comparison](http://127.0.0.1:18773/).

**Decision:** retain a bounded structural lead, without production/default or
full-art promotion. The single volume removes the independently drawn lower
shell, with more legible unequal faces and clefts than the same-crop local-base
control. Tall column/finger proportions, thin scalloped turf, lower shoulders
and a broad flat cutoff sole remain. Neutral material exposes lattice facets.
Grass gives small local contact volume, not the target's rooted sod finish.

## What is being compared

- 81 dry height3.5 cells cropped from existing preset X[-21,-10],Z[-3,7], translated
by subtracting(-15,1). Straight rear boundaries belong to this artificial crop.
This is not the old three-crown draw replacement or a complete new island.

- `pcg_cliff_field.gd` derives a contour and seeded unequal sectors. Ordered
polygon sections share edges and have different shoulder heights, secondary
faces, recessed joints and a common inward return. Contour-ray ordering avoids
the earlier small orphan produced by independent tangential vertex movement.

- The output is explicit .25m production RockSculpt samples in ordinary v2 layout
payloads. Production tetrahedral meshing draws the entire sample; no extra cap,
wall plate or bottom shell. Authored cells and saved density are the source of
the visible land. Source assets, trees/buildings/layout/water and all production
scripts/shaders/assets/scenes remain unchanged.

- This tool-only compiler/preview is **not integrated into the full editor**.
Production v2 keeps its existing separate-volume drawing semantics; loading the
payload there does not automatically activate this single-skin preview. Native
pointer/picking, publication, collision and automatic PCG regeneration after
cell edits are not implemented or accepted here.

- The control is the existing `local` derived-body rule over the same crop,
materials, lights and cameras. **It is not the formal model-wall default.** The
approved target is separately labeled and has a different camera/composition.
Do not infer full-island beauty gains from this isolated result.

## Geometry, shading and contact

35current native Godot frames: seven states × close/grass/whole/reverse/bottom,
all1671×941. States: control, PCG shape, contact finish, seed7319, contracted
footprint, public below-cap carve, neutral material. Baseline/candidate camera
transforms and lights match. The reference camera does not match.

Five outputs (control, PCG, alternate seed, layout and carved) pass finite
1e-5-position-weld closed/oriented one-component, degeneracy, vertex-link and
strict nonadjacent triangle-crossing checks. Shared-position and coplanar pairs
are excluded; zero detections is not an exact global or arbitrary-edit proof.
PCG has50,828tri/500.77m³ versus control36,588tri/302.38m³. Body proportions and
volume differ deliberately; this is not an equal-volume/performance comparison.

The tool resets raw triangle normals before the42degree crease helper, matching
coherent-base meshing semantics. Separate-volume production meshing supplies
already shared field gradients, which cannot recover crisp turns by another
crease filter. All six earlier body-vertex hashes remain identical through this
normal correction. It changes prototype shading, not body proportions. Only
the no-leaf body controls isolate that normal change: grass color/low source
transforms also received a separate local adjustment.

Existing grass source triangles are retained completely. Roots are12mm buried,
with actual upward-triangle support agreeing with the production tetrahedral
height query within0.1mm. One fixed sampling scheme has irregular gaps, low
heights and a disclosed1.7horizontal/1vertical scale; original source bytes stay
unchanged. Root checks do not establish every leaf-tip contact. Exact counts,
hashes and support errors are in captures/validation JSON.

Fresh PCG14/14 covers same-seed determinism, distinct seed/cell layouts, bounded
finite densities, ordinary save/load, public carve/undo/redo/reload and protected
cap nodes. Original terrain-data301/301, five finite geometry gates,35clean
native images and full leaf/root checks pass. No broad gameplay, arbitrary cap
edits, wet ground, holes, disjoint islands, remap stability, FPS/power or target
laptop acceptance is claimed.

## Evidence and reproduction

`rejected_fluted` and `rejected_shallow_planes` retain initial9-frame trials.
`rejected_tangent_orphan` retains the visible orphan trial. The30-frame
`gradient_normal_control` is same-body geometry evidence, not accepted art.
Temporary previews are excluded from the final35frames.

```
godot --headless --path . --script tests/pcg_cliff_field_test.gd --log-file /tmp/yunlu-pcg-checks.log
godot --path . --script tools/art/capture_pcg_cliff.gd --log-file /tmp/yunlu-pcg-final.log
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/check_pcg_cliff.py > /tmp/yunlu-pcg-geometry.log 2>&1
godot --headless --path . --script tests/terrain_editor_data_test.gd --log-file /tmp/yunlu-pcg-data.log
python3 tools/art/build_pcg_cliff_review.py
```

The builder verifies dimensions/cameras, target hash, body hashes, geometry
reports, complete leaf/root counts, test logs and unchanged production paths.
Generated body binaries, JSON-content `.layout` snapshots and native images
remain locally preserved under existing art policy; source tools/reports are
versioned. No generated concept image substitutes for engine evidence.
