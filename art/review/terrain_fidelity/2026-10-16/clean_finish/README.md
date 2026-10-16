# Quieter color, retained stone feel

2026-10-16. User feedback: recent work feels worse than the early version; make the image cleaner and more beautiful without returning to plastic. **Retain this restrained cleanup as `clean_finish1`; full island art remains unaccepted.** Direct-solid recess studies are separate and are not promoted.

## Visible change and limits

[Seven-camera comparison](../../2026-10-14/courtyard_finish/clean_finish.html) has28actual Godot screenshots across four cumulative stages: fresh control, stone color, firmer body-face lighting, ground/shore cleanup. Exact recorded camera poses and four principal water clocks1.25 match; clouds/mist remain live. The parent and independent reviewer inspected all seven final views. Eleven fresh main gallery captures use the normal live water clocks; they are not advertised as phase-matched.

The most visible cleanup is smaller shore reeds, which reveal the pond silhouette instead of dominating it. Lawn color mottling is quieter. Large cliff faces read firmer, with dry grain still visible; no plastic/gloss or chalk flattening was observed in the reviewed views. The material-only improvement is small. Repeated broad slabs, long hard cap cuts and a heavy dark underside still dominate the island; this is not proof that the user's overall beauty correction is achieved. Do not accumulate more cosmetic patches while ignoring those forms.

Changes are limited to existing resources:

- Shared mineral color multiplier `.62+.95*paint` becomes `.78+.65*paint`, reducing contrast and slightly lifting the darker stone. Broad dark/brown deposit weights `.40/.18` become `.24/.12`; pale mineral specks and localized soil/lichen beneath dry caps remain. No new bitmap, outline or uniform green lip.
- Generated wall copies retain source geometry, UVs, colors and positions; normal-blend strength `.55→.28` at the existing42degree crease gate restores firmer large-face lighting. Shore/outcrop normal blending remains unchanged. Fine stone normal strength remains.07; packed mineral/roughness maps and specular remain unchanged. This is not polishing the surface smooth.
- Ground-map albedo contrast `.60→.38`, fragmented worn-soil mixing `.10+.38*fragments→.06+.22*fragments`, grit `.50→.30`. Ground normal-map gain, tuft relief, path wear and compression stay; changing soil coverage also changes the existing soil attenuation of relief locally. Do not claim all rendered normals remain numerically identical. This shared function also reaches dry shore blending/rim-leaf roots.
- Existing shore reed scales4.2/3.8 become3.1/2.8, preserving source meshes, origins, deterministic yaw and support filtering. No trees, bushes, flowers or cottage replacements. Source geometry and authoritative island/pond data unchanged. Water algorithms, lighting and camera navigation unchanged; visible reflections/shadows can change with reed size and bank appearance.

The retained early `edge_final` remains selectable on the main gallery. It is an earlier in-engine state, not the concept or an explicitly user-selected rollback target. User rejection takes priority over earlier independent modest-improvement recommendations.

## Fresh evidence

- `material_checks.json`: normal baker15/15 and all three existing terrain maps have mipmaps. No new tests for art constants; native visual controls provide the relevant evidence.
- `support_checks.json`: retained-source profiles625/514/654/717faces exactly match expected geometry, original source hashes valid; shore-prop default/dry/contract fixtures have zero invalid plants; shore stones93/78/94/79 across four fixtures, zero failures/4,445probes. Tuft428anchors/zero unsupported or invalid/157,950uploaded values. Decoration23/23. These finite cases do not establish arbitrary player shapes.
- Fresh native editor339/339, underside-material positive/negative control(11,236foreground/0invalid pond-tag changes/11,236valid bed changes), ground compression106,484changed pixels/0half-mask mismatch, rim compression1,953standing/0flat/1,103local-mask pixels, bed light/depth/morph controls(288/119/0shallow/middle/deep,413motion,377/556production changes/motion,0morph difference) pass without script/shader errors. Native decoration regeneration42/42 passes. All seven native runs, including captures, exit0 clean in `native_checks.json`. The compression fixture writes a historical default output path; its fresh JSON is copied here and the older tracked report restored, so it is not mislabeled as an October11 run.
- Control and all three staged seven-view native captures exit0 clean. Main has11fresh captures. Capture JSON and matched pose/phase proof are tracked; PNGs remain local under binary policy. Source hashes distinguish the current cleanup from earlier studies.
- Independent reviewer inspected all seven control/final pairs, independently ran normals15/15, found no actionable correctness issue or visible new reed contact issue, and recommends modest retention. It explicitly does not accept overall beauty or full island art; no reviewer GPU work occurred.

Previous full-scene geometry/water suites are stage evidence, not new full-suite verification. Target-laptop FPS, edit CPU cost, idle power and moving-camera stability remain unmeasured. No Blender/Tripo action, asset purchase or new user handoff is required by this pass. Active art goal stays incomplete.
