# Limited near-shore screen-space reflection

2026-10-15. Baseline `140ece9` / `weather3_*`; selected candidate `reflection3_*`. Eleven matched Godot 4.7.2 Forward+ Metal captures, eight principal views inspected. This is reversible water-material progress, not full art or performance acceptance.

## Behavior and art choice

Water keeps the actual authored mineral bed, existing depth transmission/refraction and foam/fall ordering. A bounded reflected ray now samples opaque above-water geometry visible in the current camera. Screen-edge and distance fade avoid stretched screen-edge copies; below-water hits are rejected. No geometry, authoring data, scene layout, original asset or picking changes. `reflection_strength=0` skips the trace; current default is .28.

`reflection1` used weak reflection (.18) with a long trace; `reflection2` strengthened it (.36), but pale lower-lake reflected rock masses read as ghost patches. `reflection3` reduces trace work to 12 steps with five bisections on a potential hit, and fades reflected contribution between 3 and 12 m. Upper shore reflections add modest environmental color while preserving visible bed detail. Pale lower-lake masses are quieter but still simplified; no claim of complete natural mirror, richer final water motion, or concept parity.

An independent review of the earlier candidate found one P3 endpoint mismatch: the last bisection midpoint supplied color/depth while the positive endpoint supplied error/confidence. The final shader reprojects and samples that positive endpoint before all validation and color lookup. The reviewer otherwise found consistent ray/morph coordinates and a small shoreline improvement, with ghost-patch limitations.

## Verification

The rendered marker fixture fails on baseline: zero red pixels at the expected mirror position. With reflections, it finds 729 red pixels there, zero when disabled or marker removed; after moving the marker it finds 729 at the new mirror and zero at the stale position; after changing camera it again finds 729 at the correctly projected mirror. This tests actual reflected geometry, motion and negative controls, not a shader-text assertion. All captures compile/draw cleanly. Fresh rendered editor339/339 and water-impact8/8 pass. No full geometry suite was rerun for this shader-only change. See [fixture outputs](fixture_checks.json) and [fresh check log](checks.json).

The same-process cost probe alternates reflection off/on over three paired cycles at 1280×720. [Final measurements](readback_cost_final.json) include synchronous drawing, image readback and CPU/GPU synchronization. Host drift is large (first off median17.117 ms, subsequent off9.970/9.722, on10.973/10.778/9.970), so these are not pure GPU timing or gameplay FPS, and do not establish overhead or target thin-laptop acceptance. Earlier longer-trace measurements are stage evidence in `readback_cost.json`. Probe source is preserved as text.

## Limits

This is current-screen opaque reflection only: off-screen objects, transparent falls/water, hidden surfaces and full scene reflection are unavailable. Depth discontinuities and thin geometry may miss or pop; moving-camera temporal stability across arbitrary layouts remains unaccepted. Existing sky radiance remains the fallback; the trace does not install a second render pass or reflection probe. See Godot’s [screen-reading documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) and [reverse-Z reconstruction](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html).

The cliff/source-shape and grass-contact art gaps remain the dominant unresolved work; actual user-refined main stone has not been received. Do not use this water step to declare the overall goal complete.

Final independent follow-up confirms the endpoint finding is fixed, with no remaining actionable code defect in its limited review. It recommends retaining reflection3 as restrained shoreline improvement while explicitly leaving residual ghost-like lower-lake masses, moving-camera stability and target-device performance unaccepted.
