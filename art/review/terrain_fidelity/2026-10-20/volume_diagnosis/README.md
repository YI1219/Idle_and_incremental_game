# Volume contact correction and shape diagnosis

This continues the local art gate, not whole-island integration. **Overall art remains unaccepted.** The then-pending direction question is now answered: the user chose existing-mother shape/contact/bank refinement. This earlier correction did not change shape; see the subsequent [local candidate](../volume_shape/README.md).

## What changed

The isolated study now derives one41×27RGBAfloat contact map from the actual edited volume: edited upper height and original planting coverage. Grass/soil/wet contact is evaluated per fragment in world space instead of interpolating the already-classified triangle vertex colors. Height padding does not extend planting outside actual supported columns. Outside the map, planting is zero. Total erasure disables the contact map; undo restores it.

The map's pixel payload is17,712bytes; this is not measured total GPU allocation. Creation/upload currently happens in the small synchronous rebuild. No new geometry, model, high-poly bake, extra Tripo job or official default-scene change. Old vertex-color behavior remains a diagnostic shader switch, not a second terrain representation.

## Actual evidence

- `contact_vertex.png` / `contact_fragment.png`: matched native mesh, normals, camera, light and texture detail. Geometry+normalSHA256identical before/after; the source document is unchanged. The front edge and pond boundary lose much of the triangular color smearing. Physical silhouette jaggies, crater-like bank, broad rear wall and puffy lower masses remain. This is a local contact improvement, not accepted island art.
- `contact_tunnel.png` / `contact_breach.png`: actual sculpted states with refreshed contact data. The through-hole remains real geometry; breaching the basin hides unsupported water. Undo restores the source document and mesh/normal hash.
- `cover_without_lighting.png` / `world_normals.png`: false-color diagnostics, not proposed game palettes. The cover view shows the legacy vertex-color fields still retained for fallback/diagnosis; it exposes triangle-shaped color transitions even without lighting. Counts in `diagnosis.json` describe those legacy fields, not the newly evaluated fragment coverage.

Fresh document21/21 includes contact height following added land. Native public-input/runtime12/12 includes exact GPU contact-image data matching the published CPU image and disabling it after full erasure. Final native logs are clean; `verification.json` stores them and the actual PNG hashes. Earlier legacy tests are historical to the preceding milestone, not rerun here.

## Separate geometric limitation

Blender's read-only nearest-surface diagnosis compares the unedited0.25m conversion against the actual source. Source5028triangles → conversion16,464triangles. Finite vertex/centroid source-to-conversion distances: mean2.85cm,P959.33cm,max25.28cm. Reverse mean1.17cm,P954.54cm,max12.16cm. These are samples, **not a continuous Hausdorff bound** or a guarantee about all silhouette points.

This supports two separate actions: improve the designed source masses for the rounded/broad shape, and address lost sharp source features during conversion. More surface texture cannot recover a quarter-meter missing corner. It does not justify blindly increasing whole-island density or declaring a different mesher accepted.

## Reproduce

`tools/art/diagnose_volume_patch.gd`: legacy contact/normal diagnostic and unedited converted triangle export. Blender with `tools/art/measure_volume_conversion.py`: finite nearest-surface measurements. `tools/art/probe_volume_contact.gd`: matched old/new contact and actual edit captures. No webpage.

The original source and preset are unchanged; the runtime preset remains byte-identical to commitc8c558f. Current complete art checkpoint remains pending user judgment. Async/chunks, new cottage, multi-layout, arbitrary lake networks, release export, target-hardware and long-idle acceptance remain future work.
