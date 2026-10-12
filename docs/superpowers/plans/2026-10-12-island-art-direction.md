# Floating island art direction implementation plan

**Goal/spec:** The 2026-10-12 user request delegates art direction and supersedes earlier footprint, pond and flat-bottom constraints. Make the island read as a convincing floating landmass, especially its silhouette and rim at gameplay distance, using the supplied concept.
**Architecture:** Keep authoritative editable terrain and modular detail. Rework procedural stone shoulder/fracture geometry, proportions and the closed lower envelope. Compare three structural directions in actual runtime renders, then refine the strongest. Continue inline in the requested checkout from ff4db69.
**Authorization:** The user explicitly authorizes free iteration and art decisions. No additional design approval is needed. Preserve original assets and sandbox behavior; no purchases, character work or Tripo operation.

**Latest acceptance:** classical Chinese fantasy; close and distant readability; no continuous grey lip or bevel band; physical moss clusters, varied tight/open stone clefts; one calm bottom without hull/rubble; soft shores, stone/ground material maps with grass compression, no orphan shore props. These supersede earlier unconstrained art wording.

## Review focus

- Outer and internal terrace shoulders must meet the playable top without holes.
- Expansion/contraction/deep lowering regenerate locally and preserve undo/save.
- Roots must stay attached and clear of waterfall curtains.
- All directions must be judged from far/normal cameras and low orbit, not isolated close-ups.
- Removed aesthetic constraints must not conceal real closure/contact regressions.

## Tasks

- [x] Capture baseline and add geometric shoulder/silhouette evidence. Compare broad shouldered crags, hanging rock clusters, and a thin ledge above a tapered mass. Files: procedural_stone.gd, terrain_decoration.gd, block_mantle.gd, contour_terrain.gd; tests/capture_island_art_direction.gd and relevant mesh tests. Structural changes are verified with meaningful red/green geometry checks; visual studies use render comparisons.
- [x] Refine retained direction: macro rhythm, joins, stone/light/vegetation composition. Record at least two materially different follow-up studies that fail to improve before declaring a plateau. Do not stop while an actionable visible defect remains.
- [x] Run applicable terrain suites and rendered regeneration (default, expand, contract, deep lower), capture whole orbit, fresh independent review, resolve findings. Replace superseded aesthetic assertions with relevant coverage. Update current context and gallery, commit and push.
