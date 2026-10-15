# Uneven weathering and surface mixing candidate

2026-10-15. Latest user correction: stone faces and grass–stone joins look too clean. Current candidate `weather2_*` uses the same cameras as `fracture2_*` at `cbcfcc1`. Actual Godot renders, not concept images; eight principal views inspected out of eleven captures. Gallery: `../../2026-10-14/courtyard_finish/comparison.html`.

## Retained change

Existing mineral albedo and packed detail maps are reused with stronger mineral/normal response. Uneven world-space deposits add mineral staining, small grains and sparse earth/lichen below actual dry caps. Ground shares the deposit coordinates, with fragmented earth/grit and grass remnants at path margins. Full compression retains exposed earth. This introduces no new bitmap, model, displacement or outline. Geometry, authoring data, source assets, layout and trees are unchanged.

`weather1` was rejected for overly broad tan lawn patches. `weather2` reduces that broad mask and breaks it with fine fragments. It is a modest improvement in surface variation, not final visual acceptance. No continuous grey/green lip appeared in the inspected views. Abrupt grass-to-wall geometry, applied oval root pads and broad wall panels remain conspicuous; dirt cannot replace shape refinement. Shore props still need better visual integration in the broader art goal.

## Fresh verification

[Checks and full outputs](checks.json): actual-render editor 339/339, decoration regeneration 42/42, and grass compression render pass. Compression changes 106,279/107,520 sampled pixels, with zero half-mask mismatch. Eleven matched captures compile/draw without shader errors. An initial headless regeneration invocation correctly refused the dummy rendering device; the real Metal rerun passed. No geometry changed this round, and previous full geometry-suite results are historical evidence only.

Independent read-only review inspected code and matched rim/ground plus overview/shore/bottom/distant renders. No actionable correctness defect found; cap metadata, include guards and existing morph/compression coordinates are consistent. Reviewer agrees with modest material improvement and remaining shape/root-pad limitations.

Performance and moving-camera temporal stability are not established. The deposit field adds three 3D value-noise evaluations per ground/stone fragment, with five more near upper stone contact; low-quality GPU cost needs measurement before performance acceptance. This M4 Pro render verification does not prove target thin-laptop performance. The full island art goal remains open.
