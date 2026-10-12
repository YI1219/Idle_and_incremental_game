# Soft silhouette — 2026-10-12

Continues `eaccb9fb` (wallpaper nap, PR #15) on `cursor/soft-silhouette-bcaf`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941, MSAA 4×. The courtyard concepts are look direction only. Nothing from 《我有一片田》 was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

The authored footprint and convex-rim assembly were not edited. Each cliff cut still has one outward geometric normal. The shared olive nap and warm mist stay.

## Crowns

The wallpaper-nap crown was one convex hull, an umbrella in the still. This pass builds four closed outward lobes. Each lobe keeps a wedge of the retained oak points and adds a shell pushed off the crown centre, so the union outline is lobed instead of one ellipsoid. Placement is unchanged. Mature height stays about 4.1–4.2 m.

In `after_default.png` and `after_distant.png` the four trees read as irregular olive masses, some with a shallow heart or clover cleft. They are no longer a single smooth umbrella. They are still low-poly canopy solids, not the painted pine and deciduous crowns in the concepts.

## Cliff, vines, reeds

Side faces of the crown solids gain a smooth outward dome on the render skin. The dome falls to the face boundary. A shared edge keeps one small bow, pinned at the corners. A larger bow threw pale ridges and was not kept. Authoring vertices, the footprint, and the one-normal-per-cut rule are unchanged.

A lit patch of the near rim in `after_rim.png` averages about sRGB (182, 169, 150). Shadowed cuts sit nearer (106, 100, 85). Moss is a broken veil on the grey, and the hanging modules are squat pads rather than needle leaves. Plate joints remain. Some crevices still show pale fragments up close. From the default and distant cameras the wall is weathered grey and still faceted.

Pond-edge reeds are short olive ribbons. In `after_pond.png` they sit in the bank and do not dominate the frame. Shore stones stay faceted.

## Close lawn and mist

The lawn cover was not edited. Lawn pixels in `after_grass.png` average about sRGB (106, 121, 77). The green channel in that mask runs from about 91 to 159: olive mottling, settled hollows, small blossoms, and no readable pad discs. The hexagonal path stones stay faceted. The homestead preset places 29,968 turf clumps.

A corner of the default sky is about (219, 199, 166). The distant sky is about (218, 200, 173), and the lower mist about (213, 200, 182). The sun stays readable and the island stays olive.

## What this still is

Default and distant are less cheap than the umbrella-crown still: the trees have an irregular mass, the cliff faces pillow outward, and the bank plants are quiet. They remain a stylized engine diorama. The concepts are paintings. These stills cannot hang beside them yet.

`tests/capture_meadow_wallpaper.gd` reproduces the five stills (`out=2026-10-12/soft_silhouette`). On this revision, crown integrity was closed and outward with 3072/3072 source points contained, canopy contact was 5/5, stone volumes 72/72, rim union failures 0, block mantle passed, vine contact failures 0, decoration regeneration 42/42, shore props valid, model bounds 9/9, and homestead 34/34. Llvmpipe on this host is not a Windows thin-and-light or MacBook Air measurement.
