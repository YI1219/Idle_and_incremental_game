# Soft meadow still — 2026-10-12

Baseline: `db375bf` (PR #12 continuous-turf head). Branch `cursor/soft-meadow-lookdev-f0ab`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941. The pastoral reference and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Close turf

The close still now reads as one grey-olive meadow. An open patch away from the stepping stones is about sRGB (108, 116, 81). The dark and bright ends of that patch sit near (100, 109, 75) and (113, 121, 85), so the lawn is not a field of loam holes or pale cards. The nap is a few millimetres tall and uses the same lawn colour as the cap. Skyward normals and a matte roughness keep a stroke from flashing.

A tight crop of that patch still resolves a fine grain. It is not a dense photographic blade mass, and it is not the tall crossed cards of the previous still. The homestead preset places 34,264 of these clumps. That count is a beauty choice on this host, not a measured laptop frame rate.

## Still

Default and distant framings keep the warm mist, olive terraces, grey convex stone and teal ponds. A sampled patch of the default lawn is about sRGB (123, 116, 87). A corner of the default sky is about (205, 196, 179). A patch of the near rim stone is about (77, 70, 58). Fog is warmer and a little thicker than the previous still, so the island sits in the cloud sea. SSAO is broader and gentler, which seats trees and stone without drawing a dark line around every grass stroke. Column joints darken in the stone shader. The coarse normal bend that shaded a flat cut as a pit is gone; a short grit remains, and each cut still uses one outward geometric normal.

Pond water darkens across a wider bank, the near-shore ripples are calmer, and the damp soil band feathers into the lawn instead of ending as a hard tan stripe. The footprint and the convex-rim assembly were not edited.

`tests/capture_soft_meadow.gd` reproduces the five stills. Decoration placement was 26/26 and grass-compression binding passed. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.
