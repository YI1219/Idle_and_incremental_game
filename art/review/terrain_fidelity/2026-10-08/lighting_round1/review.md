# Lighting / atmosphere round 1 — runtime review

2026-10-08. Scope of this round: lighting, post-processing, sky and atmosphere only. Terrain geometry, cliff construction, vegetation placement, props, materials and camera defaults are unchanged. The result is a review candidate, **not aesthetic acceptance**.

Captures are actual Godot 4.7.2 Forward+ renders of `scenes/terrain_editor.tscn` on a cloud VM using Mesa lavapipe (software Vulkan), 1671 × 941, MSAA 4×, gameplay camera. `tests/capture_lighting_round.gd -- <tag>` reproduces the default pose (pitch −27°, yaw 16°, FOV 31°, height 21) and the same left/right/back orbits as `capture_target_match.gd`. `before.json` / `after.json` record poses and submission counters. PNGs are kept locally (gitignored) and attached to the PR.

## Changes

| Area | Before | After |
| --- | --- | --- |
| Sun | rot (−40°, 125°), `ffe6bd`, 1.55, shadow opacity 0.68, angular 3.2 | rot (−34°, 140°), `ffdcb2`, 1.75, opacity 1.0, angular 1.6, bias 0.06, normal bias 1.4, specular 0.28 |
| Fill (no shadow) | `e1dfd5`, 0.48 | `dcd8d0`, 0.20 |
| Ambient (colour) | `bccbde`, 0.60 | `cac5bd`, 0.50 |
| Tonemap | Linear | Linear (Filmic/AgX tested: they compress the warm sky and haze to grey) |
| SSAO | radius 1.15, intensity 1.25, power 1.1 | radius 1.3, intensity 3.0, power 1.6, detail 0.5, light affect 0.25 |
| Glow | off | on: intensity 0.55, bloom 0, HDR threshold 1.0, soft light, levels 3–6 |
| Fog | none | exponential 0.0008, `e6cfae`, sun scatter 0.30, sky affect 0 |
| Sky | flat sun disc | shared `sky_palette.gdshaderinc` gradient, warm halo around the sun, HDR sun core (2.7, 2.15, 1.4), warmer cloud shadows |
| Mountains | unshaded, linear distance mix to grey | sun-direction shading; exponential aerial perspective toward the sky colour behind each peak, stronger near the sun and near the horizon band; lower slopes sink into cloud; sun burns through peaks at its disc; `fog_disabled` |
| Cloud sea | sky backdrop only | three world-anchored flat cloud decks (y −150, −270, −420) between the mountain rings: 256² seamless noise, 3 texture taps per pixel, sun-side lit / far-side shaded, aerial fade, thinning toward the horizon band; no shadows, no collision |

## Evidence

Default composition: cast shadows from trees, fences, cottage and shore stones are now clear. Cliff crevices and stone contacts are darker. The sun reads as a glowing disc with a warm halo, and mountain rings fade progressively into a warm cloud sea. Orbits: the sky sun follows yaw, as before. The low sun's reflection on the lower lake in the left orbit is broken sparkle rather than a clipped patch. The back orbit faces the sun-lit cliffs, which read warmer and brighter than before.

## Tests

28/28 headless `tests/terrain*_test.gd` scripts exit 0 (same as the pre-change baseline on this host). The two rendered suites pass on lavapipe: editor runtime 22/22 and cottage material 7 checks with 0 failures.

## Performance (current host only)

`tests/benchmark_lighting_round.gd -- <tag>` toggles each feature in the same running scene and view at 1280 × 720. The renderer is lavapipe on a 4-core VM. These are CPU-rasterized timings, useful only as relative shares; they say nothing about target laptops. Median per-frame viewport GPU time: before 373–410 ms, after 456 ms. In the after build, turning glow off saves about 50 ms and turning the cloud decks off saves about 20 ms; fog is within noise. Glow and the decks are the only added full-screen work. Both can be disabled for a low-quality preset. The PCSS angular radius was halved and the soft-shadow filter quality is unchanged. Target-laptop FPS and idle power remain unmeasured.

## Remaining gaps vs concept

- Clouds are flat noise decks, not the concept's sculpted, sunlit cumulus masses. Mountains remain simple faceted prisms, now hazed.
- Grass is still more saturated yellow-green than the concept's olive. Rock albedo is unchanged, so sun-facing cliffs in the back orbit look sandy. Both are material questions for a later round.
- The concept's dense hanging vines, flowers and richer cliff relief add much of its contact darkening. That is geometry/vegetation work for later rounds.
- Water still reflects the old sky cubemap pass (cool blue/ivory), not the new warm gradient.
- The painted sky's sun direction (≈5° from −Z) and the light direction (≈40° from −Z) still differ. This is a deliberate compromise so that sun-side cliffs are lit at the default camera.
