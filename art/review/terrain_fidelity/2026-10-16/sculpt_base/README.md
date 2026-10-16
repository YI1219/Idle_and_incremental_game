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
