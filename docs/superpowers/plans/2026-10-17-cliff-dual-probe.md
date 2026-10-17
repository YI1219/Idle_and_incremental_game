# Feature-preserving cliff reconstruction probe

Authorized next local experiment; current scene-art branch, original sources and production defaults preserved. Reuse the previous exact closed union and .25m node records. Borrow Hermite/QEF math from the linked upstream descriptions without vendoring their implementation or importing a new engine.

- [x] Verify the box-constrained QEF with plane, corner and escaped-solution cases; five tests pass including sphere and diagonal-pocket topology regressions.
- [x] Compare DC from existing density/gradient information with DC supplied original surface crossings/normals. Keep the same spacing/signs; additional source data must be identified explicitly, not claimed recoverable from old saves.
- [x] Apply one existing public bounded-plane brush; check exact undo, redo and record reload. Recompute source-aware Hermite intersections from the same underlying source plus brush operation, not from unedited geometry.
- [x] Validate closedness/orientation/vertex links and finite geometric differences. Initial one-vertex-per-cell topology fails; face-connected patch splitting/sign-based winding fix that limited failure. Independent strict geometric review then finds self-intersections in all four outputs. Reject all candidates; do not equate closed topology with valid geometry.
- [x] Capture53matched native frames. Scene captures started after topology passed, before the crossing finding; retain them explicitly as rejected-geometry diagnosis, not valid candidate evidence. Review and publish evidence; no production brush/backend promotion. Commit/push after final verification.

Outcome: partial visual plane retention, inadequate far/contact improvement, geometric rejection. This is an independent uniform prototype, not a libfive integration or implementation of adaptive Manifold Dual Contouring. Follow-up must resolve intersections and persistent source constraints before editor integration; no blind diagonal/normal tuning sweep.

References: https://www.mattkeeter.com/projects/qef/ ; https://github.com/nickgildea/DualContouringSample ; https://github.com/libfive/libfive . SUSMA's separation of sculpt representation from grid conversion also informs this experiment: https://github.com/jaaamesey/SUSMA . No source-code reuse or licensing claim beyond the actual implementation.
