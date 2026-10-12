# Continuous meadow turf — 2026-10-12

Baseline: `9e8ed69` (PR #11 matte-lookdev head). Branch `cursor/continuous-turf-lookdev-fece`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941. The pastoral reference and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Close turf

The close still now reads as continuous sod. Short opaque blades overlap into a meadow instead of sitting as separate fans on a flat olive sheet. A low-frequency field keeps some metres thicker and some thinner. The path stones and the kitchen garden stay clear, and the thinner patches plus the stone margin show warm loam. Blade normals are biased skyward, roughness is matte, and the blades do not emit, so they do not sparkle as plastic cards.

The nearest blades are still individual low-poly faces. That is visible in `after_grass.png`. They join into one surface rather than a scatter of rosettes, and the gaps that remain read as soil. A sampled patch of that close lawn is about sRGB (138, 141, 93). The same framing on the matte pass was separate dark fans on a painted plane.

The homestead preset places 44,757 of these clumps. Open lawn is on the order of several dozen clumps per square metre; the wave troughs are lighter. That count is a beauty choice on this host, not a measured laptop frame rate.

## Still

Default and distant framings keep a soft olive meadow across both terraces. A sampled patch of the default lawn is about sRGB (116, 135, 118), grey-olive rather than the pale straw of an earlier iteration or the flatter painted grade before it. Warm mist, grey convex stone and teal ponds remain. The rim still rolls turf over outward stone faces, with hanging vines in the joints. Pond banks stay soft, shore stones stay readable, and contact darkening still sits in the stone and grass joints. The footprint and the convex-rim assembly were not edited.

`tests/capture_continuous_turf.gd` reproduces the five stills. Decoration placement was 26/26 and grass-compression binding passed. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.
