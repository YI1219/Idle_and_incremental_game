# Coherent terrain sculpting trial

The player and prefab author directly shape the same mountain/rock volume. This is a functional checkpoint, **not final island art acceptance**. Default `tone_final` remains unchanged; these opt-in studies do not replace its cliffs.

The workshop control **整体岩体塑形 · 试验模式** converts the authoritative cell contours, real ground/pond-floor heights and calm bottom into one closed surface. It replaces old caps/walls and model-based wall/outcrop overlays. Sparse add/carve/bounded-plane brush samples override the derived solid; the same production brushes author the example. No automatic rock assembly or locked decorative land. Existing trees/buildings and originals are preserved.

Switching modes is allowed only with empty sculpt samples. Undo sculpt edits before switching back, or save and reset. Land history remains usable within the base capacity; rock history belongs to its originating mode. Incompatible or oversized undo/redo is rejected atomically and preserves the entry. Version3 saves the unified mode/cells/overrides; version1/2 remain supported. The derived grid has a2million-node allocation guard. This limit is a protective bound, not target-device performance acceptance.

## Actual scene evidence

`capture_sculpt_base.gd` captures five actual Metal/Godot views per study: local front, whole, local reverse, shore and bottom. `author_unified_cliff.gd` uses the same public brushes as players. Files remain locally beside this report; bitmap evidence is ignored by the repository as usual. The existing local gallery has a separate `sculpt_base.html` trial page.

- `base1`: coherent skin but too thick and sheet-like; original overly large authored shapes. Rejected.
- `base2`: smaller authored masses/earlier lower taper, still excessively round; missing geological structure. Rejected.
- `base3`: wet-bed tags no longer stain the down-facing bottom. This is a material correction, not shape acceptance.
- `base4`: actual face normals with42degree crease preserve cuts but reveal too many coarse lattice facets. Rejected.
- `base5`:65degree crease softens shallower turns while retaining stronger corners. All five views inspected. The overall shape remains broad, round and uniform; grass is sparse and shores remain too simple. **Still rejected as default art.**722,232skin vertices/2,847override samples in this authored full-island fixture. No frame-rate/cost claim.

These five prototype views do not fulfill the goal's six-group final visual acceptance. No new water beauty claim: water routing remains authored by the existing cell layout, and arbitrary sculpting of outlets/floors has not been accepted as hydrological behavior.

## Fresh verification

Actual native runs persist full stdout and exit status in JSON, with errors scanned even when Godot exits0.

- `post_normal_checks.json`: final data23/23; native full screen-pointer → begin/continue stroke → publication/pick → undo10/10;30,184published fixture triangles/0invalid shared edges. Geometry is checked after actual chunk publication.
- `integration_checks.json`: actual unified-shader fixture11,236foreground pixels, pond tags change0down-facing underside pixels; valid upward wet-bed control changes11,163pixels. Red run changed all11,236underside pixels. An initial0foreground fixture is explicitly invalid and retained separately.
- `verified_checks.json`: shore contact0/3,526actual mesh section probes across default/dry/raised/contracted cell states;83/68/84/67stones. Legacy data301/301 and native editor339/339 pass. Complete pointer path rerun10/10.
- `support_final_checks.json`: unified vine centroid contact across default/raise/lower/expand/contract:387/387/398/400/417modules,0missing/over-.10m separation. Legacy volume29/29 and published9/9 pass. Its `legacy_data` entry used an incorrect file path and is **invalid**, superseded by the correct301/301run above.
- `support_red.json` → `support_green.json`: actual thin carved ledges55mesh intersections,23mismatches →0. The base data test now includes this and oversized history/cross-mode replay cases. Early `history_green.json` had an undersized test fixture and was not a passing run; the corrected diagonal-span fixture is included in the final23/23.

The first unified shore fixture had114apparent failures. Most used the sloping dry pivot height instead of the pond elevation for section ownership. The remaining4were generic ray-epsilon misses on real tiny triangles (debug point had field top1.405875m but generic ray skipped it and hit the bottom). The final independent check uses scalar projected triangle barycentrics; it does not call the production field height query. No shore placement change was made to hide a fixture defect. These checks cover finite module/sample contacts, not every leaf vertex or arbitrary sculpted layouts.

## Independent review

One fresh reviewer found two Important defects, both reproduced and fixed:

1. Pre-conversion land history could restore an oversized base. Restore now validates the candidate before mutation and only pops a successful history entry. Nonempty rock patches also check originating authoring mode.
2. Support queries checking only.25mY endpoints missed thin carved ledges. Exact vertical tetrahedral linear segments now include crossings at localX/localZ fractions. The reviewer reran the original wider scan and found0mismatches, including0missing supports, then confirmed both fixes with no remaining actionable issue in that scope.

The last face-normal adjustment changes shading only; final data and native pointer/closure checks were rerun afterward. Art and performance remain unaccepted. Next shape work should establish a convincing large rock plane/shoulder/recess rhythm in one representative edge using these same authoring tools before expanding to the whole island. Do not return to model scattering or compensate with more texture/decoration.

## Geological shoulder continuation

Retained **tooling**, not a new default island. `rock_shoulder` (HUD item9) is an oriented volume brush with unequal planes and an inward basal return. Player screen input and `author_unified_cliff_cutstone.gd` call the same production API. Original prototype private writes survive only as clearly labeled historical `.txt` evidence. The stroke remains editable, bounded, undoable and serialized through the existing data path. No stone models are automatically arranged.

`planes1` was rejected for broad sheeting and cuts into the lawn. `cutstone1` had straight hanging feet. `cutstone2` adds an inward foot; its grass camera was poorly framed, superseded by the correctly framed later views. `cutstone3` gives oblique fronts. `shoulder4` retains that local brush, slightly larger irregular source-grass fans, and coverage limited to the original dry-ground footprint. VertexG carries dry contact provenance through actual chunk color interpolation; the shared root material no longer gives arbitrary outboard stone the soil/lichen of a nearby dry record. A small margin preserves original grass coverage at the lip.

`shoulder_full1` extends the exact production brush to explicitly authored perimeter strokes. Its sole purpose is visual evaluation and support verification; **it is rejected as a default replacement**. Side rhythm improves over the unshaped coherent body, but its broad wall/hull, coarse shoulders and sparse joins remain worse than needed. The next decisive shape change must improve the initial body's major planes/lower silhouette; adding more similar perimeter strokes will not resolve it. Water remains unaccepted and is unchanged this continuation. Trees, buildings and default scene stay.

The new `shoulder_sculpt.html` presents four states across seven matching cameras: current legacy default, plain coherent base, local shoulder4 and full shoulder_full1. `build_shoulder_review.py` asserts exact matching positions/rotations and successful image writes, recording `shoulder_matched_views.json`.28actual images, seven full-study views inspected. These are stage comparisons, not final visual acceptance. Generated page syntax and HTTP200 were checked. The initial legacy helper completed images then hung on an invalid unified-only final diagnostic; the corrected helper completed natively with exit0. `shoulder_capture_checks.json` records the timeout honestly.

Current fresh results:

- `shoulder_final_checks.json`: shoulder15/15, including capacity rejection; rooted source fans238anchors/0unsupported; actual compression2,251standing/0compressed/1,785local pixels; actual material11,236foreground/0underside-tag changes/11,236valid upward-bed changes; shore0/3,526probes with83/68/84/67stones across four cell-edit states; vines338/338/348/351/368centroids with0missing/separated across five edit states. These edit fixtures start from the sculpted field. Legacy volume29/29,data301/301 and native editor339/339 pass.
- `shoulder_pointer_final.json`: complete native player shoulder route13/13;30,704published triangles/0invalid shared edges. Undo restores exact original terrain.
- `shoulder_island.json`: actual full-study skin752,976vertices,1connected component,0invalid exact shared edges,19,205sample overrides and unchanged authored cells.
- `shoulder_checks.json`: coherent-base23/23 (including55actual thin-ledge mesh intersections/0mismatches). Early `shoulder_green.json` is not passing: a4cm normal probe stepped through a neighboring face at an oblique corner. `shoulder_normal_fixture.json` records positive values on both sides at4cm, and the correct positive/negative values at1mm. The new shoulder inspector uses local1mm probes; legacy normal tests keep their original4cm default. No geometry winding change was made to hide that fixture issue.

Fresh independent review found no actionable correctness defect in orientation, bounds/atomicity, cache/snapshot handling, brush/history/save/native-input integration orG-channel propagation. It independently ran14/14 before the extra capacity assertion; final15/15 is in the retained report. Art and target-device performance remain unaccepted.


## Local return and lip cuts — rejected October16 follow-up

After the water-material checkpoint, two local studies reuse only the public
shoulder and bounded-plane brushes. `return1` cuts beneath retained shoulders:
4,486changed samples, highest changedY2.5 below the original3.5cap, original
authored cells unchanged. The probe source and actual result are retained.
Seven native captures exit0 without errors,724,512skin vertices. Close/grass/whole/
bottom views show concave cave-like pockets while the broad wall remains; reject.

`lip1` instead allows small cuts to reach the ground edge, adds one exposed
shoulder and planes the first mound. Seven native captures exit0,723,216skin
vertices. Close/grass/whole/reverse inspection shows thin pointed lips and
knife-like folds; reject. No default geometry, material or player-tool behavior
changes. These are not accepted natural geology or full support/closure checks.

Both studies keep their explicit stroke source in
`tools/art/author_unified_cliff_return.gd`. The gallery now compares six states
at seven checked camera positions (42images). These captures span water-material
stages and live animation phases, so only geometry is compared here. Do not infer
a water improvement or fully frozen scene from this gallery.

The next shape work should address the continuous base's large proportions and
the bounded cut's falloff: clipping within a small spherical influence can leave
a taper or pocket at its boundary. More perimeter stamps or deeper repeated
cuts on the same thick slab are not a solution. Preserve the common bottom and
overall footprint without freezing every small segment of the grass lip.
