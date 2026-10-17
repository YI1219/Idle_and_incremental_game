# Goal continuation: two rejected structural rounds

The previous goal turn defined the target and diagnosis. This turn makes
concrete progress by testing two different structural constructions and
obtaining actual geometry/art evidence. The **goal remains active/incomplete**;
user visual approval is absent and all three art requirements remain unmet.

**Decision:** both new rounds are rejected for art. The goal's two-round
stop condition is reached. Stop shape-rule tuning/contact decoration and ask
for a decision before a broader shape-data/authoring change. This is the first
turn reaching that decision dependency, not a repeated blocked-state audit.

## Actual work and evidence

Same81dry-cell crop, .25m production sculpt field and tetrahedral mesher, same
cameras/lights/materials as the rejected ring experiment.24new native frames:
two rounds × ring-neutral/new-neutral/new-stone × close/whole/reverse/bottom.
These are real Godot renders. The target camera/composition differs. No leaves
or contact-polish pass proceeded after the main form failed.

Round1 uses full3D oblique convex constraints, an interior support volume,
real-depth soil field and a varying curved lower bound. A fixed lateral
contour guard hides much of the projected shoulder geometry. Result: upright
walls, stepped lawn/roof plates and lower ledges. Finite geometry also fails:
one27,342vertex main component plus one38vertex component; no strict crossings
reported. Do not use it as a runtime candidate.

Round2 replaces the nearly upright front constraint with four oblique planes
that widen beneath the shoulder then turn inward twice; its lateral guard
relaxes below the cap, its roof is clipped consistently and interior support
recedes beneath the wall. Lawn terraces reduce and shoulders tilt, but the
result still has broad panels, long seams, a hard lawn cut and a dish-like lower
mass with angular recesses. The new continuous field is not visually continuous
enough to meet the target. Finite gate passes for this unedited fixture only.

Fresh generic compiler14/14 checks determinism, alternate seed/contour data,
finite/capacity bounds, ordinary v2 save/load and public carve/undo/redo/reload
with protected cap nodes. Independent reviewer reran14/14. No edited geometry,
leaf/root support, native editor interaction, full layouts/seed visual coverage,
collision or target-device check is claimed for these rounds.

Body hashes, images, dimensions, camera matching, two geometry reports and
clean native/test logs are checked by `build_bedrock_goal_review.py`. Round1
compiler/capture snapshots and round2 compiler snapshot preserve the inputs.
No production scripts/shaders/assets/scenes changed. No Tripo/purchase/new
asset, tree/building/layout/water or default modification occurred.

## Diagnosis and concrete next decision

These failures do not establish that PCG cannot reach the look, or that another
mesher would solve it. The shape grammar itself still dictates uniform roofs,
broad panels and a global lower mass. The .25m grid adds faceting but cannot be
blamed for the meter-scale composition already present in the source field.

Proposed next step, requiring a user decision after the stop condition: extend
only the local prototype with **editable, saved construction constraints** for
main planes/adjacent clefts, shoulder-to-bottom connections and the grass/soil
edge. Make these part of the shared author/player terrain representation,
rather than constants hidden in a generator or a locked display model. First
directly author one visually acceptable standard segment from those controls;
only after that derive procedural variation and assess how density edits and
feature constraints coexist. Do not start a full backend/save migration or
claim this architectural proposal will produce the target before that sample
has been rendered and accepted.

This proposal preserves the final editable-PCG objective. It expands the
current scalar-only prototype's source-data/authoring scope; it does not
authorize asset generation, abandon shared player tools or replace defaults.
If that expansion is not approved, keep the rejected prototypes as evidence
and wait for direction instead of a third parameter trial.

## Reproduce the current round

```
godot --path . --script tools/art/capture_pcg_bedrock.gd --log-file /tmp/yunlu-bedrock-round2-native.log
godot --headless --path . --script tests/pcg_cliff_field_test.gd --log-file /tmp/yunlu-bedrock-checks.log -- --compiler=res://tools/art/pcg_bedrock_field.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/art/check_pcg_cliff.py -- --input=art/work/pcg_bedrock/2026-10-18/round2 --stages=ring_neutral,bedrock_neutral
python3 tools/art/build_bedrock_goal_review.py
```

Round1 is archived separately and requires loading its saved compiler snapshot;
the current compiler intentionally represents round2. The gallery labels the
old ring sample separately from the formal island default and the target.
