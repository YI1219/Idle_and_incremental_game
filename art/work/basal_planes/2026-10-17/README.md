# Rejected basal-return authoring studies

`tools/art/sculpt_basal_planes.py` derives two real source hull planes from crown36/37 and the ordinary cleaned shoulder save. Default writes `basal_planes_v1.json` using direct plane intersections; `--union` writes `basal_planes_union.json` with each clipping plane confined to its own true hull before original root-v2union/core/fades. Exact source/parameter/save hashes are in reports.

Both are ordinary version4shared scalar saves with unchanged cells. Source skins are local ignored binaries from `probe_bedrock_local.gd -- basalplanes`/`basalunion`; exact topology and finite compatibility are retained in JSON. Neither shape is adopted. `build_basal_planes_review.py` binds actual native views and checks. [Current review](../../../review/terrain_fidelity/2026-10-17/basal_planes/README.md).
