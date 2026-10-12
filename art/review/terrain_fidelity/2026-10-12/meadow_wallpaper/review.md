# Meadow wallpaper still — 2026-10-12

Baseline: `a668a26` (PR #13 soft-meadow head). Branch `cursor/meadow-wallpaper-9b6b`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941. The pastoral reference and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Close turf

The close still is one grey-olive meadow. An open patch in the foreground averages about sRGB (104, 116, 79). Across that foreground the green channel runs from about 71 to 131, so the lawn carries soft dual-tone blotches of roughly a tenth in value rather than a single fill. Loam speckle and the old high-frequency grain are gone. The homestead preset places 31,062 turf clumps: low opaque mounds with a short wide fringe, coloured by the same world-space cover as the cap, lit with the cap’s tilt so a stroke does not flash as a pale card.

A tight crop still resolves the mound facets. It is a stylized nap, not a photographic blade mass, and it is not the tall crossed cards or the millimetre grain of the previous still. From the default and distant frames the same cover reads as mottled turf.

## Still

Default and distant framings keep the warm mist, olive terraces, grey convex stone and teal ponds. A corner of the default sky is about (207, 198, 183). A patch of near stone is about (83, 72, 58); a rim face sits darker, about (69, 59, 48). Fog is a warm mist with the sun still visible, and the island keeps its olive instead of washing out to beige. SSAO is a broad contact under trees, rocks and the cottage, not a dark line around every clump. Crown blocks differ in value and their outer edges darken; each cut still uses one outward geometric normal, and the coarse bend that shaded a flat face as a pit is still absent. The faces remain broad convex cuts. They read more as separate stones than the previous still, and they are not coursed masonry.

Pond water darkens across a wider, calmer bank. The damp soil band stays in the olive family and feathers into the lawn. The footprint and the convex-rim assembly were not edited.

`tests/capture_meadow_wallpaper.gd` reproduces the five stills. Decoration placement was 26/26 and grass-compression binding passed. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.
