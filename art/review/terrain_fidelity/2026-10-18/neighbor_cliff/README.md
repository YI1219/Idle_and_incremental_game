# Reference-informed neighbor-cliff decision: reject this generator

2026-10-18. User explicitly asked to reference Brushland/similar games and set a
small goal. The goal tool returned null before creation; the new goal is a
bounded adopt/reject experiment, not a completion/reset of the former full art
criteria. No paid generation, external art asset or runtime/default edit.

## Evidence and implementation boundary

[First-party sources and inspected code](sources.md) establish context-sensitive
tile behavior in Brushland, multiple curated pipelines in Tiny Glade, and the
distinction between logical state and rendered fields in Oskar's explanation.
Brushland's cliff internals and shipped Tiny Glade terrain algorithm remain
unknown. Exact country-slice revision3f6a459c0424ed9177a0dceec4d72a380cbd80c2
was inspected: its hobby terrain is height-texture displacement; its brick-wall
constructor is not a cliff generator. No claim that we replicated either game.

Own experiment: four convex3Dface regions fit shared frontage spans/tangents.
Unequal inclined shoulder/end planes constrain their shapes; exact Boolean union
with a common core yields one closed exterior. It is not concentric ring
extrusion or the former random3Dfracture partition. Region heights/depths/leans
are still curated parameters; the four-region adjacency chain is NOT a complete
neighbor-state grammar, arbitrary footprint compiler or editable player tool.

## Actual results

- **neighbor1:**746tri/375vertices. Full3Dbevels break the old planar panels,
  but front masses read as attached shields/columns, the shared lower core as
  a plinth, and the rear as a broad wall. Art rejected.
- **neighbor2:**752tri/378vertices. Shared front body recedes, ends nearer the
  rock-region bottoms, and lower-region front planes turn inward; two oblique
  rear planes replace the single rear bound. The front plinth is less exposed.
  Actual underside still has broad flat/angular patches and abrupt separate
  ends; reverse still reads as a blank wall. Main faces remain box-like and
  repeated. This is insufficient natural main-face/basal improvement; rejected.
- Current control112tri and BOTHcandidates pass finite closed/oriented topology,
  vertex links, one positive-volume component and zero strict crossing checks.
  Detector excludes coplanar/shared-position pairs, not a global exact proof.

Both candidates use one uniform scale+translation to match the original code
guide's11.025522m width,3.389612m upperpeak and XZ bounding center. No independent
height compression. Control dimensions11.0255×6.1196×5.4026m; neighbor1
11.0255×6.2388×5.5715m; neighbor2 11.0255×5.6864×5.5294m. Heights remain different
because proportions are preserved. Normalization parameters and raw sources
remain recorded; no size advantage is hidden in the current comparison.

15CURRENTnew actual Godot neutral frames: control/neighbor1/neighbor2 ×close,
upper contact angle, whole, reverse and underside. Same42degree normal handling,
material, environment and exact camera records. Control is the old code guide,
NOT the formal courtyard default.10earlier raw-width frames are separately kept
in direct_raw/, not used as current matched-width comparison. Prior formal
default scene evidence is linked as historical context and labeled accordingly.

## Adopt/reject decision and small-goal completion boundary

**Do NOT adopt this convex-region-union construction as the next runtime cliff
generator.** Keep the general context-sensitive/element-specific design lesson,
but it does not validate this particular geometry. Two substantive rules are
complete; no third rule, seed/material/detail sweep or paid task follows.

Neither candidate is converted to the editable density field: the source-art
prerequisite failed. No new grass/soil contact, support, carve/undo/redo/save,
layout/seed, editor, performance or user-art acceptance is claimed. Earlier
checks from other prototypes are not reused as current validation.

This supports a NEGATIVE feasibility decision for the small goal, not a general
verdict against PCG, reference games, Boolean modeling or a future richer rule
system. The former full target still requires all three art effects, shared
sculptable data, multiple real contours/seeds and explicit user acceptance.

[Current finite evidence](../../../../work/neighbor_cliff/2026-10-18/geometry_checks.json),
[current captures](direct/captures.json), [verification](verification.json).
Local gallery: http://127.0.0.1:18776/art/review/terrain_fidelity/2026-10-18/neighbor_cliff/index.html .


## Reproduction and independent review

[Fresh independent review and scope rulings](independent_review.md) reproduces
both current candidate bytes and all finite reports, inspects all15actual
images and supports rejection; no retained Critical/Important/Minor finding.
The reviewer did not regenerate native captures or inspect the later final
publication. Final page/manifests are verified by the author.

From repository root, with Blender5.2.1 and Godot4.7.2:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/build_neighbor_cliff.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/build_neighbor_cliff.py -- --variant=neighbor2
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/check_pcg_cliff.py -- --input=art/work/neighbor_cliff/2026-10-18 --stages=control,neighbor1,neighbor2
/opt/homebrew/bin/godot --path . --script tools/art/capture_master_landform.gd -- --input=res://art/work/neighbor_cliff/2026-10-18/ --output=res://art/review/terrain_fidelity/2026-10-18/neighbor_cliff/direct/ --stages=control,neighbor1,neighbor2
python3 tools/art/build_neighbor_cliff_review.py
```

Last command requires existing NumPy/Pillow. This reproduces current matched
sources, not the preserved earlier raw-width outputs. Preserve originals before
rerunning tools. Native captures/art review are separate from finite geometry.
