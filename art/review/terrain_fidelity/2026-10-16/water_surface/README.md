# Water surface and falling-water continuation

The active island-art goal remains **incomplete**. This checkpoint retains a
modest material improvement on the existing default geometry. Player and prefab
author still directly sculpt the same volume in the separate opt-in study; this
water pass does not change that direction or introduce automatic rock assembly.

## Retained result and actual visual evidence

`water_before_*` and `water_final_*` are seven actual Godot camera pairs at
1671×941: upper shore, grazing water, lower lake, cascade, outer fall, reverse
shore and overview. `matched_views.json` compares successful image writes,
positions, rotations and four material clocks at1.25. Mist and cloud-sea clocks
remain live; their differences are not evidence of improvement. The separate
`surface_final_*` main gallery has11 actual current captures; eight principal
views were inspected. Static images do not prove moving-camera stability.

The hard polygonal pool-light network becomes broken curved interference light.
Physical bed, bed shadows and depth fading remain. Wider fall streaks have slight
lateral drift while retaining the previous transmission/opacity. Rings have
larger moving gaps and quieter tint. Surface slopes are slightly stronger;
screen-depth reflection confidence falls off before existing error/height
rejection boundaries. Tracing remains12 coarse steps plus5 refinements, with
the original linear screen sampler. Subtle shore-material fragments interrupt
the damp band above water without adding geometry.

No model, source texture, lighting, authored cell, footprint, tree/building or
placement changes. Current defaults keep negative clocks to follow engine time.
The helper overrides clocks only for review.

## Rejected studies and validator repair

- `curved1`: a useful curved-light direction, but shallow visibility92 did not
  meet the unchanged >100 fixture. Width.26 alone produced95. Increasing the
  dim patch floor from.25 to.35 restores readable light without increasing the
  default.12 strength or removing the depth fade.
- `flow1`: lower opacity/higher transmission made gauze-like thin falls;
  discarded. `flow2` restores previous opacity/transmission and retains broader
  streaks. `flow3` ring gaps were too sparse:8,830 visible samples; merely
  raising scale to.65 still gave9,464. Widening the arc mask's surviving regions
  restores12,005 while retaining25,878 gaps. No fixture thresholds were lowered.
- `flow4`/`flow5` mip-filtered reflection blur had no clear visual benefit;
  discarded. The final retains original linear filtering plus confidence fades.
- The changed strand phase bent away from both edges of the old centered
  refraction control. The fixture now sweeps five real phases/strip positions,
  preserving all original thresholds and exercising foreground rejection in
  three cases. It still compares a deliberately unguarded shader as a positive
  control. The original main foreground-displacement assertion is unchanged.
- Initial capture used nonexistent material key `foam`, instead of `bank`;
  its failed report is retained and excluded. A later verification wrapper
  stopped after the successful editor test on a nonexistent regeneration-test
  filename. Only the unrun tail was resumed using the real
  `terrain_decoration_regen_test.gd`; no live process was restarted. That actual
  test was subsequently killed by the wrapper at240seconds while still
  calculating. After its termination was confirmed, an extended900second run
  completed42/42 with exit0; both records remain. The longer test is not a
  measured interactive edit-latency or device-performance result.

## Verification and review

`final_checks.json` records fresh commands, actual exits and error scans. The
final actual-render fixtures establish:

| Check | Result |
| --- | --- |
| Bed light shallow / middle / deep |288 /119 /0 changed samples |
| Bed light motion / morph-equivalence differences |413 /0 |
| Production-strength light / motion |377 /556 |
| Ring visible / moving / gaps |12,005 /13,524 /25,878 |
| Opaque foam core / core motion |0 /26,598 |
| Fall refraction amplified / default changes |5,724 /2,716 |
| Covered foreground differences / positive edge rejections |0 /137 |
| Reflection marker and moved/camera controls |729 each; disabled/removed/stale0 |
| Native editor |339/339 |
| Complete native decoration regeneration |42/42, exit0 after extended run |
| Actual grass compression |106,279 changed;0 half-mask mismatch |
| Physical bed / rock-fall clearance |417 probes/0 failures;140 samples/0 intersections |
| Shore transition / shore-prop edits |0 failures /0 invalid |
| Falls / impact |35/35;8/8 |
| Vine centroids default/four edits |392/392/398/406/422;0 missing/separated |

Independent review reran all four water fixtures on Metal and inspected all
seven actual before/after pairs. Earlier two coverage findings are resolved;
no remaining actionable correctness defect was found in its scope. It judges
the curved light, broken rings and less comb-like streaks worth retaining as a
limited improvement. This is not full art acceptance.

Remaining: broad pale/grey reflection patches, translucent-sheet falls, pale
plunge foam, uniform shallow-bank band, cliff proportions and hard turf cuts.
Arbitrary layouts, moving-camera stability, sculpted water routing, GPU cost and
target-laptop performance remain unverified. Do not add more perimeter stamps
or dirt to conceal the unresolved continuous-body shape.
