# Living carpet still — 2026-10-12

Continues `cursor/meadow-wallpaper-9b6b` after the [meadow wallpaper still](../meadow_wallpaper/review.md). Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941. The pastoral reference and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Close turf

The upright fringe and the faceted mound are gone. Each clump is three overlapping pads a few millimetres tall, and the homestead preset places 29,968 of them. They take the same world-space cover as the cap, with almost no per-clump tint, so a pad does not cut a disc out of the lawn.

An open patch of the foreground averages about sRGB (124, 131, 89). In that patch the middle of the green channel sits between about 121 and 139: a soft dual-tone olive, brighter than the previous still, without the dark creases the mound facets were casting. Moss shows as small cooler dabs inside broader mossy ground. Wildflowers are small world-locked blossoms, cream or soft gold, with a finer cream sprinkle. A tight crop resolves those blossoms and the broad olive blotches. It does not resolve a field of polygonal shards.

## Still

Default and distant framings keep the olive terraces, teal ponds and convex stone. A corner of the default sky is about (210, 202, 189), against about (206, 196, 181) in the previous still. The lower mist in the distant frame is about (206, 201, 193), against about (198, 191, 182). The sea is a brighter warm cream and the sun is still readable. The island stays olive rather than washing out to beige.

A broad patch of the near rim face averages about (102, 95, 85), against about (82, 74, 63) before. The crowns are a lighter weathered grey. Edge darkening is a broken cleft, not a continuous course, and each cut still uses one outward geometric normal. The coarse bend that shaded a flat face as a pit is still absent. The faces remain the convex-rim assembly; this pass did not move them.

Pond water is unchanged in its shader. The bank stays in the olive family. The footprint was not edited.

`tests/capture_meadow_wallpaper.gd` reproduces the five stills. Decoration placement was 26/26 and grass-compression binding passed. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement. The still is closer to the painted meadow than the faceted nap it replaces, and it is not that painting.
