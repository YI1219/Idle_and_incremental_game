# Clumped tufts, lake shore field, prop contact

Render-only. Heightfield `H` is not written. Coastline shoulder and shore-stone placement were left alone.

Captured with `tests/capture_ground_detail.gd` on llvmpipe (Mesa), 1280×720, OpenGL. Same overview and lake cameras as `tests/capture_heightfield.gd`, plus a close view of the potion-bench crate. PNGs are gitignored; before/after frames are on the pull request.

| | before | after |
| --- | --- | --- |
| overview | sparse tufts and regular pebble dots | clumped 5–13 cm tufts, pebbles removed |
| lake | disc butted against the bank | sheet overlaps the bank; shallow band and contact seam |
| device | hard crate/tree bases in a uniform tuft field | noisy ground-contact darkening, grass pulled back from the cottage and facilities |

Playable island after the pass: land triangles 6188, grass 862 tufts / 20688 triangles / 4 chunk draws, shore field on, 16 draws total in `heightfield_stats` (land chunks + water + falls + dressing + grass). Far islands drop the tufts with `visibility_range_end` 40 m.

Tests: `heightfield_test` 42/42, `island_volume_test` 24/24, `terrain_test` 795/795.
