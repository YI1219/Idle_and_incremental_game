# Actual mature-kernel feasibility: bounded leads, no art promotion

2026-10-17. User approved the next step after the rejected home-grown DC probe. This round actually builds and runs upstream libfive, and compares installed Godot Manifold direct-boundary edits. [Native gallery](http://127.0.0.1:18771/cliff_kernel.html). Default `spall_finish1`, runtime editor, original sources, island footprint, trees, buildings, water and layout remain unchanged. Overall beauty remains incomplete.

**Decision:** retain only bounded technical evidence. The six libfive outputs from this adapter/settings combination fail the finite geometry gate. Manifold source/plane/grow/localcut pass; the later carve and its exact history replays fail. The local cut also looks like an artificial curved incision and is **rejected as art**, with no useful distant improvement. No backend or default promotion. Grass/stone contact remains a hard boundary; no new material variant is claimed.

## Actual integration and fixed controls

- Unmodified libfive core commit `918387a9220dbac2f7ab32fb35e274c6794439cf` (MPL2), separate temporary Release build; GUI/bindings/tests disabled. CMake3.31.6, Eigen3.4.0, Boost1.85.0, installed libpng; no global install or engine fork. Source files were checked byte-for-byte against the pinned upstream archive. [Build provenance](../../../../work/cliff_kernel/2026-10-17/build_provenance.json) records successful build and incomplete dependency downloads. Required Boost headers were recovered from the complete header portion of an interrupted official archive; this is not a verified complete Boost archive. Reproduction should use the complete official release.
- Own C++ external oracle wraps the **same existing closed crown36/37/38 union**: BVH Euclidean triangle distance, three oblique parity rays for sign, selected SDF gradient, conservative center-distance ± half-diagonal interval plus1e-4 float margin. It does **not** provide the full competing feature-gradient fan. Thus these failures cannot establish a general limitation of libfive itself.
- Actual libfive DC, ISO_SIMPLEX and HYBRID run before/after the continuous bounded-plane subtraction, fixed cubic region[-23,-6,-5]→[-7,10,11], min_feature.25m, max_err1e-8, four workers. Raw index edges close correctly, but exported float geometry has collapsed/tiny faces and proper crossings. No algorithm/normal/resolution sweep to hide this.
- Manifold uses the installed Godot4.7.2 CSG implementation on the same source; sphere brushes use128radial segments/64rings, so they are finite polygonal approximations. It preserves original boundaries directly, without density remeshing. No replacement original custom asset is constructed.

## Geometry results

| Output | Triangles | Proper crossing pairs detected | Finite gate |
| --- | ---: | ---: | --- |
| Manifold original | 2,248 | 0 | Pass |
| One bounded upward plane | 2,290 | 0 | Pass |
| Then grow | 9,126 | 0 | Pass |
| Then carve | 16,564 | 8 | **Fail** |
| Single separate below-cap side cut | 4,910 | 0 | Pass |
| libfive DC, before / after plane | 6,372 / 6,214 | 100 / 76 | **Fail / fail** |
| libfive ISO_SIMPLEX, before / after | 104,812 / 103,324 | 53 / 46 | **Fail / fail** |
| libfive HYBRID, before / after | 129,280 / 125,572 | 8 / 6 | **Fail / fail** |

Undo restores the grown mesh exactly; redo and reload restore the carved mesh exactly, including its defects. They are not three additional independent successes. Carved/redo/reload each have18non-two-use edges,18collapsed index faces and20bad vertex links under the1e-5position weld. The original library index-edge checks are zero for all six libfive outputs; float-position welding is a separate test, and many native faces are geometrically tiny or collapsed. Do not conflate index-manifold topology with an embedded usable surface.

Finite gate uses positive volume/one connected component, oriented two-use edges, vertex links and the same zero-epsilon BVH + float64 strict segment/triangle verifier as the previous round. Shared-position, coplanar and near-touch cases are excluded; zero detected crossings is not a global exact-predicate proof. Counts are lower bounds. Independent reviewer reproduced the principal Manifold checks and verified passing outputs have no exact zero-area triangles. [Full hashed geometry report](../../../../work/cliff_kernel/2026-10-17/geometry_validation.json), [capture/review validation](validation.json).

## Editing and persistence limits

The continuous expression is `max(source_sdf,min(y-3.25,4-length(p-center)))`, center(-15,3.25,3). This is an analytic source-plus-operation test, not recovery of original features from density-only saves.

Source adapter agrees with12,169original nodes: zero sign disagreements away from the source boundary, maximum truncated-distance difference2e-5 (the original positive anti-zero bias), gradient norm error below6e-8. Against11,846edited public-brush records, comparable strict-interior values and signs away from both boundaries pass. However48node density values differ (max.25) outside the strict brush domain, and one sphere-boundary point is negative in the public field versus zero analytically. The public brush skips distance>=radius; the continuous CSG expression changes some negative distance values outside that domain without changing their signs. **No exact nodal/edit equivalence, seamless old-save migration, complete gradient-feature correctness or exact interval proof is claimed.** [Oracle checks](../../../../work/cliff_kernel/2026-10-17/oracle_validation.json).

The Manifold sequence stores the source path/hash and three commands (plane/grow/carve) in a tool-only recipe. Undo/redo/reload produce byte-identical corresponding derived meshes. Initial JSON tests failed: decimal parsing can differ by one double ULP even with full-precision output. Recipe loading canonicalizes vectors to the engine's actual Vector3 precision, then checks operational values and derived bytes. This is not a lossless arbitrary-double codec, TerrainData save version or production history API. Failed precision evidence remains in logs.

## Native visual review

44successful new Godot frames:36isolated (original/plane/grow/localcut × flat/65degree-crease/stone × three views), eight actual-scene views (original/localcut × close/grass/reverse/far). Same materials, cameras and lighting. Scene replaces exactly three draw slots; covered horizontal source lids are omitted consistently, full closed meshes retained for measurement. Local brush maxY2.82452345 is below the unchanged grass capY3.5; actual authoritative data hash remains identical. No edited upper-plane/grow/carve is shown beneath an unchanged lawn. Clouds/mist remain live; four water phases are fixed.

Parent inspection: original direct surface keeps the existing turns but also keeps broad molded masses and thin-triangle shading scars. Localcut leaves a conspicuous circular/crescent incision near the vine/cleft rather than a convincing geological plane. Far silhouette/material/contact barely changes. Whole source/body continuity and grass/stone hard cut remain. Reject this art candidate; do not propagate more bounded sphere/plane stamps. Ground contact was inspected but no new material experiment was justified by this result.

Ten numerical tests pass (previous five QEF/topology cases plus strict crossing hit/miss/coplanar and vertex-link fixtures). The refactored detector exactly reproduces previous120/79/108/77DC rejection counts. Logs for successful build/query/kernel/capture runs are clean; failed dependency/initial recipe trials are labeled separately. Current-host offline timings are recorded as diagnostics only, not edit responsiveness, FPS, low-device power or performance acceptance.

## Reproduction and next boundary

Sources: [libfive](https://github.com/libfive/libfive), [oracle contract](https://github.com/libfive/libfive/blob/918387a9220dbac2f7ab32fb35e274c6794439cf/libfive/include/libfive/oracle/oracle.hpp), [settings](https://github.com/libfive/libfive/blob/918387a9220dbac2f7ab32fb35e274c6794439cf/libfive/include/libfive/render/brep/settings.hpp), [Godot Manifold PR94321](https://github.com/godotengine/godot/pull/94321). No upstream implementation is copied into game runtime.

Build the pinned core separately with the flags/versions in provenance. Compile `tools/art/cliff_libfive_probe.cpp` against its include directory, Eigen/Boost and `libfive.dylib`; temporary executable path used by the Python helpers is `/tmp/yunlu_cliff_libfive_probe`. Run `check_cliff_kernel_oracle.py`, `run_cliff_libfive_probe.py`; Godot `probe_cliff_kernel_boolean.gd`; Blender `validate_cliff_kernel_probe.py`; the two numerical test modules; native capture helpers with the input/output paths in capture JSON; then `build_cliff_kernel_review.py`. Native lab shapes are `boundary,boundary_edited,boundary_grown,boundary_localcut`; scene shapes `boundary,boundary_localcut`. Binary source/mesh/images remain preserved locally under existing art policy; source tools/JSON/logs are tracked.

This completes the bounded feasibility step, not the art goal. A future backend proposal must address full feature representation, robust continuous edit sequences, source/recipe compatibility and production publication/support/collision before promotion. For beauty, source major planes, neighbor/shoulder/basal relationships and rooted grass contact still need direct art work. Do not infer that another mesher swap, circular cut or parameter sweep will supply that composition. New Tripo generation remains paused; no credits/task submitted.
