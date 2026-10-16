# Cleaner water without flattening materials

User direction: cleaner, beautiful image without plastic. Retain clean_finish1 stone/ground detail and whole island/model/layout.

## Retained change

Only production change: water.gdshader SPECULAR.60→.25. Roughness, surface slopes, screen-space reflection strength.28, physical bed/depth/transmission/refraction, waterlight and falls unchanged. Stones/ground retain mineral/detail maps, normal strength and dry roughness; no shape/data/source-asset changes.

Native layer isolation uses two real cameras and four principal water clocks1.25. The ten original images here compare current(.60),no_ssr,no_specular,flat_normal,no_caustic. Their actual rerun capture metadata is captures.json. Removing SSR/bed light does not cure the low-angle pale blanket. Specular0 removes it but loses too much sheen. Four additional spec25/spec35 images and strength_captures.json support the restrained.25 choice. Original first diagnostic metadata was overwritten by the strength run; the ten-layer run was repeated cleanly before the production edit, so no reconstructed metadata is presented as captured evidence.

The corrected diagnostic tool now saves under a shader-hash directory and records actual production SPECULAR/hash/modes: current always means the recorded source, not a fixed.60 baseline. Future reruns cannot overwrite this original study. This provenance correction does not alter runtime.

## Evidence and judgment

- Seven fresh baseline/final pairs: adjacent water_surface/clean_water_before_* and clean_water25_*. Positions/rotations and all four principal clocks match; clean_matched_views.json is generated with assertions. Mist/cloud clocks remain live.
- Eleven fresh main captures: courtyard_finish/clean_water1_*, no errors. Main gallery uses these; dedicated water_clean.html contains the matched pairs.
- validation.json: native capture stages, SSR real above-water marker729pixels with disabled/absent/stale0 and moved/angled729, impact8/8 and editor339/339 all exit0 without script/shader errors. These are this round's checks, not reused historical test counts.
- Parent inspected all seven pairs and main whole/far/rim. Independent review supports modest retention: less low-angle white band, more readable bed/shadows, still water sheen, no observed plastic regression. Whole/far benefit is smaller.

Wide shallow-bank bands, lower-pond hard reflection patches and sheet-like falls remain. Repeated cliff slabs/hard grass cuts/heavy underside remain. No whole-art acceptance, arbitrary-edit proof, dynamic/other-lighting proof or target-hardware claim. Unified crease study is separately rejected; default geometry stays retained model-based geometry.

Reproduce near pairs using tools/art/capture_water_finish.gd. Build gallery with `python3 tools/art/build_water_surface_review.py --clean`. The production baseline.60 is in parent commit c51151f; do not mistake current production for that baseline. Binary screenshots stay local per repository policy; code and JSON review evidence are tracked.
