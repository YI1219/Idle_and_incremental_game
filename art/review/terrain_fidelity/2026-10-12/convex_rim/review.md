# Convex rim and wallpaper still — 2026-10-12

Baseline: `696fe317`. Branch `cursor/convex-rim-wallpaper-b864`. Godot 4.7.2 Forward+ captures through llvmpipe at 1671×941. The concept image and the pastoral references are look direction only. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Outer stone

The false hollows came from faces that folded inward and then lit that fold.

- Crown and root solids stay the closed intersection of their fracture planes. The old apex, including a negative relief push and a sideways offset, is no longer part of the visible mesh. It is still sampled only to keep `crown_z`, so terrace anchoring does not move. Each cut has one tint and an outward normal. `terrain_stone_volume_test` requires supporting-plane error under 0.012 m on crowns.
- Mantle plates are one outward plane, clipped under the lawn. Kinks of a few centimetres on a long edge were extruding into knives; those vertices are dropped. `terrain_block_mantle_test` reports 43 closed bodies and no front face more than 0.08 m outside its plane.
- Shell relief no longer goes negative. Outer buttresses only bulge outward. Long cliff triangles a few centimetres tall are not emitted. Broad faces share a vertex normal only when they are nearly coplanar, and the cliff shader lights each cut with the flat outward geometric normal plus fine mineral grain.

A rim-band crop from the runtime still is not systematically darker in face centers than on a 22 px border (more samples were brighter at the center than darker). Joints between plates, and the contact shadow in those joints, remain visible in a stone close-up. That is a seam between cuts, not an inward-folded fan.

## Still

Palette stays warm mist, olive grass and grey stone. Authored land, ponds, cottage and prop layout are unchanged. Ground cover keeps a metre-scale olive mottle plus finer flecks, shores and pond margins are softer, and the sun is a low warm source with milder SSAO and a light warm fog. Default, distant, rim, pond and stone views were written beside this note (PNGs stay local; `tests/capture_convex_rim_pass.gd` reproduces them).

The distant view is still softer and paler than a desktop wallpaper of the pastoral reference. The grass lip is a stylized edge. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.

## Checks run on this revision

Passed: stone volume, block mantle, broad facet normals, calm bottom (259 probes, no miss), shell floor, boundary wall (416 samples), crown integrity, base easing, rim systems (23/23), mantle transition, vine contact. The previous revision's full 51-suite and 42-suite figures were not repeated.
