# Complete section studies — rejected

The user wants a cleaner beautiful image without returning to plastic. Production stays `clean_water1`: no changes to runtime scripts, shaders, textures, source models, layout, authored cells or the default gallery candidate in this round. Previous restrained stone/ground cleanup and reduced water specular remain. This report records failed shape studies, not a new visual improvement.

## What was actually tested

`tools/art/author_cliff_section.gd` authors one bounded front-left section into ordinary version4 sculpt-save density records, then loads them through `TerrainData.deserialize`. The existing land cells/heights remain identical. These are authoring studies in the same editable solid, with no model scattering, decorative mesh overlay or new base profile. They are not proposed production prefabs. Loading a study clears history as an ordinary load does; this does not claim its mathematical authoring operations are available as individual player UI strokes.

- `section1`: unequal oblique clefts and a continuous cap/side/lower profile,11,373 samples. Removes some separate-model joins but reads as broad soft vertical walls.
- `section2`: firmer lateral facets and earlier whole-section lower return,13,208 samples. The dark lower band remains; broad upright faces dominate, and the side still resembles an extruded perimeter. Rejected rather than promoted for reduced apparent weight.
- `section3d1`: two nonuniform, three-axis rotated signed volumes using the existing geological shoulder distance function, joined below to a receded common body,24,810 samples. This is a prefab density experiment, not a claim that player UI supports these transforms. Creates grass-roof overhangs, isolated hanging blocks and small reverse-side fins. Rejected.
- `section_control_neutral` and `section2_neutral`: actual native material isolation. Uniform matte stone/cover colors, zero specular, other island geometry and waterfall mist hidden. Same data/skin vertex/normal/color/UV hashes as their normal-material counterparts. Upright boards and a horizontal lower body remain visible. This supports a geometric cause; it does not rule out every lighting contribution.

All five successful stages have seven actual Godot Metal views: close, overview, far, grass contact, reverse, shore, bottom. Positions/rotations match retained `return_control1` and unmodified unified `mass_control1`. Four principal water clocks are1.25; water is hidden in the neutral stages. Clouds and non-neutral waterfall mist remain live. Binary images are in the adjacent `sculpt_base` directory; captured metadata is tracked there. Final successful logs are retained here. An initial neutral-helper call attempted to hide the decoration data object; it was corrected to hide actual chunk geometry, and both final neutral runs completed without errors. No failed run is counted as a successful capture.

## Review and consequence

Parent review rejects all three shape variants. Independent reviewer `/root/solid_smooth_review` inspected close/overview/reverse/bottom against both baselines and agreed. Its follow-up also rejects the three-dimensional study: offsetting volumes itself does not produce natural interlocking, and that trial increases discontinuity. The overpaint also partly hides column structure with texture/shadow, so it is not a proven geometric blueprint.

Do not continue whole-perimeter profile tuning, radius/cut/crease sweeps or more rotated shoulder stamps. The unsolved relationship is the actual three-dimensional meeting of the upper ground, neighboring main rock faces and lower body: local exposed shoulders must cross ground naturally, adjacent planes must have coherent thickness from both sides, and their lower transitions must merge without a repeated horizontal handoff or suspended blades. A future candidate must prove those relationships in one small volume before whole-island propagation. This is an acceptance requirement, not evidence that an unspecified new model or user delivery is necessary.

## Fresh verification

`validation.json` records35 successful new native captures with matching cameras and principal clocks, exact neutral-pair shape/data hashes, unchanged production files against `2cbc9fe`, and gallery HTTP checks. Fresh existing sculpt-base23/23 (55 thin-support probes, zero mismatches, zero invalid mesh edges) and shoulder15/15 (zero open/inward faces) pass. Those are tool regressions, not closure or support acceptance of the rejected whole-scene study meshes. No new target-device performance or whole-art claim is made.

Reproduce with native Godot and `tools/art/capture_sculpt_base.gd -- <tag> details fixedwater <flags>`; flags are `section`, `leansection`, `volumesection`, `neutral`, or `leansection neutral`. The density author helper starts only from an unmodified unified default. `build_cliff_body_review.py` validates all retained camera evidence and includes these studies on the separate rejected-study page, now112 images total (77 prior plus35 new). Main `comparison.html` remains unchanged.
