# Matte lawn and still lighting — 2026-10-12

Baseline: `afc47c5` (PR #10 convex-rim head). Branch `cursor/matte-grass-lookdev-6e09`. Godot 4.7.2 Forward+ captures through llvmpipe (LLVM 20.1.2) at 1671×941. The pastoral reference and 《我有一片田》 are look direction only. Nothing from that project’s code or assets was copied. This note does not claim concept parity, owner approval, or target-laptop frame rate.

## Grass

The lawn shader no longer paints candy tufts or an emission fill. Colour stays inside a close grey-olive pair, with a soft world-space mottle that remains when the camera backs off and a fine normal grain that drops out at distance. Roughness is matte and specular is disabled on the cap.

Short opaque fans sit on the authoritative lawn. A low-frequency field makes some metres denser than others. Path, cottage garden and water stay clear. Up close the fans are still separate low rosettes with shader ground between them; they are not a continuous sod. At the default and distant framings they read as stippled turf rather than a flat painted plane. A sampled lawn patch on the default still is about sRGB (104, 106, 78), duller than the previous (152, 152, 112) grade.

## Still

Sun energy is higher, fill and ambient are much lower, and the grade is AgX (exposure 1.08, contrast 1.16). SSAO radius is 0.20 m with intensity 2.4, so contact darkening is meant to sit in the joints rather than wash the whole island. Pond water darkens softly toward the bank. The warm mist remains, though AgX pulls the sky corner quieter than the previous linear grade (about (206, 196, 179) versus (249, 229, 196) in the same crop). Olive grass and grey stone stay the island palette.

The floating-island footprint and the convex-rim stone assembly were not edited. Default, distant, rim, pond and grass-close stills are committed beside this note. `tests/capture_matte_lookdev.gd` reproduces them. Lavapipe on this host is not a Windows thin-and-light or MacBook Air measurement.
