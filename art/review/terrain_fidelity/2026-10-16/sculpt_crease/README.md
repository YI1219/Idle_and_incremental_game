# Unified sculpt normal isolation — rejected

The user asks for a cleaner, beautiful island without plastic. This study tests whether global smoothing erased useful turns on the existing cutstone shoulder; it does not change the default model-based island.

Three native Godot Metal runs compare65°,55°,50° at strength1.0. Each uses identical existing four shoulder operations,4,022samples and702,480vertices. Seven matched views per variant:close,overview,far,grass,reverse,shore,bottom. Four principal water clocks are1.25; live cloud/mist can differ.

`isolation_checks.json` verifies exact serialized-data,vertex,color and UV hashes match, while normals differ. `capture_checks.json` records three exit0 clean runs and byte-for-byte production restoration. Capture metadata includes the hashes; screenshots are local binary evidence in the adjacent sculpt_base directory, not concept images.

Parent and independent reviewer inspected all21images. Reject55°/50°:55° gives negligible whole-island benefit;50° reveals more small triangle/grid facets near shoulders, turf and lower surfaces. Neither fixes broad wall proportions, flat panels or the heavy bottom. Retain65° for this existing shape, without claiming it is universally optimal. Production geometry/materials/default mode unchanged by this experiment. No new model delivery is requested.

Static evidence only: no motion, arbitrary-sculpture, performance or full-art acceptance claim. Do not repeat crease tuning on this geometry as a substitute for major-form improvement.
