# Wallpaper nap — 2026-10-12

Continues `1153f9ed` (living carpet, PR #14) on `cursor/wallpaper-nap-e68a`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941, MSAA 4×. The courtyard concepts and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

The footprint and convex-rim assembly were not edited. Each cliff cut still has one outward geometric normal. A bow that would have rounded the crown hull failed containment of the oak points and was not kept; the crown remains one closed hull around those points.

## Close lawn

The standing flower cups are gone. The retained bloom is flattened into the nap, and the meadow scatter is thinner, so a close crop is lawn rather than a field of grey stubs. Foreground sod in `after_grass.png` averages about sRGB (108, 118, 80). The green channel in that patch runs from about 102 to 147: olive mottling and settled hollows, with small cream blossoms, and no readable pad discs. The hexagonal path stones stay faceted. Reeds at the pond edge are still spiky blades.

The homestead preset places 29,968 turf clumps. Cap, lip, banks and clumps share one world-space cover, and each lobe conforms to the lawn wave.

## Rim and still

`after_default.png` and `after_distant.png` keep the warm mist, olive terraces and teal ponds. A corner of the default sky is about (211, 203, 190). The lower mist in the distant frame is about (205, 199, 191). The sun stays readable and the island stays olive.

A broad patch of the near rim face in `after_rim.png` averages about (162, 155, 144): warm grey, lighter than the living-carpet face, with the green life in the sage drapes and pocket moss rather than a wash over the cut. The drapes are leafy hangs, not black spikes. The planes are still the convex-rim facets. Short tangent grit and colour chips break a flat slab; they do not bend a face into a pit.

A pond-bank patch in `after_pond.png` averages about (113, 121, 82), with the green channel falling to about 59 where the soil meets the water. The outer feather stays lawn. Shore stones and reeds are still low-poly.

## What this still is

Default and distant are softer and greyer than the living-carpet still, and the close lawn no longer hints a pad or a flower cup. They remain a stylized engine diorama: polygonal cliff cuts, a convex crown silhouette, and cheap reeds. They are not a painting that could hang beside the concepts.

`tests/capture_meadow_wallpaper.gd` reproduces the five stills (`out=2026-10-12/wallpaper_nap`). On this revision, crown integrity was closed and outward with 3072/3072 source points contained, decoration placement was 26/26, and model bounds were 9/9. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.
