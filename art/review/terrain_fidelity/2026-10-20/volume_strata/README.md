# Edited-surface strata and actual-basin wetness correction

This is a material correctness continuation on the existing three-rock local candidate, not another shape variant or user art acceptance. Main-source geometry, ordinary density edits, water geometry, camera/light rig and original assets remain unchanged. The local mother still has ledges, separate feet and an angular turf boundary. No whole-island expansion, paid job, new house or review website.

## Reproduced cause and correction

The previous contact map stored edited top height and a source planting flag, but no original soil height. A new upward-facing cut could inherit green from the old planting column regardless of how far into rock it went. Wet material also used a fixed circle around the pond anchor, even for the actual elliptical basin or a breached/hidden lake.

`sampled_base.gd` now caches the interpolated original source top independently of edits. The same existing RGBAF contact texture carries R=edited top, G=authored planting eligibility, B=original source top and A=validated basin-column occupancy. Missing edge heights are padded independently to avoid interpolating against an absent-column sentinel. This adds no second GPU texture read. Preset bytes, source-bound save identity and save schema remain unchanged; source strata are rederived when the preset loads.

The production shader attenuates turf over12–35cm below original soil and soil over22–65cm, independently of the edited-top/slope transition. These are the local study's layer-depth choices, not a universal geological model. New deep floors retain world-space stone detail. Physical grass also rejects source-depth changes beyond35cm. Raised terrain inside existing planting columns retains the old eligibility behavior; newly added outboard terrain still has no authored planting column. This correction does not implement a vegetation-painting system or arbitrary layered soil authoring.

Wetness follows actual valid basin columns, with the existing linear contact sampling, an edited-top depth band and an upward-normal filter. It no longer stains unrelated lower walls or the island underside merely because they lie below the water plane near its anchor. Invalid/drained water clears the footprint and the native material's enabled flag. The projection is a bounded local approximation for this single static-level pond; it is not full3Dwater/soil transport or fluid simulation.

## Actual old/new evidence

`pond_before/after.png`, `low_before/after.png`, `cut_before/after.png` and `breach_before/after.png` are8native Godot frames. The retained `legacy_volume_patch.gdshader` is exactly the pre-change shader from commit71c0abf. Each pair renders one unchanged actual mesh/normal buffer, data state, grass mesh, camera and light rig; hash/data equality is asserted in `captures.json`. Only the material changes. Water animation time remains live. Grass uses the current supported helper identically on both sides, so these pairs isolate terrain shading rather than claiming an old/new physical-grass comparison.

The cut uses the ordinary public plane brush at(2,2.6,1),radius1.3. Before: green cut floor. After: exposed mineral floor. The pond shore loses erroneous radial staining; whole-body form remains inadequate. Breach still produces its actual coarse cut geometry, and wet color is now removed with the invalid lake. All8normal views and both false-color diagnostics were inspected. These screenshots demonstrate a specific correction, not finish parity with the island concept or the original full game scene.

`cut_classification.png` / `breach_classification.png` are explicitly diagnostic false colors, not art proposals. They instrument the **production shader calculations**, replacing only final albedo output: R=turf, G=soil, B=wet. A top camera samples actual terrain points, hides water/grass and reads the GPU result. Actual uploaded contact bytes equal the CPU map. Measured display values: deep-cut turf.0118, untouched turf1.0, pond-bed wet1.0, dry-cut wet.00784. Small nonzero display values include the unchanged lighting path; thresholds are deliberately separate from exact zero. Breached diagnostic has0blue-dominant wet pixels, with the pond-bed positive control recorded before breach. This finite fixture is not exhaustive coverage of arbitrary sculptures or every lake outline.

## Verification and limits

New regression test first fails3/8 under the old implementation: missing source height, incorrect wet channel, cut turf and drain clearing. Final8/8 verifies immutable source height versus changed cut level, exact actual-basin texel occupancy, upward-cut vertex classification, no document mutation, exact contact-map undo and complete drain clearing. One intermediate typed-vector inference error was corrected; final logs contain no script errors.

Fresh checks: original patch21/21, refined source8/8, source matrix15/15, module source7/7, prior grass8/8, module grass9/9, strata8/8, native original-study runtime12/12 and new native material/GPU fixture pass. Original-study mouse/font/collision/GPU checks and new module material captures are separate scopes. The old preset/source/scene preservation report remains valid and is rechecked against HEAD for this checkpoint.

New fixture synchronous surface builds434–478ms on the M4 Pro, including additional CPU classification; these one-run diagnostic timings are not comparative benchmarks or frame rates. The earlier assembly's degenerate-output-triangle issue is unchanged. Neither asynchronous/chunked editing nor target-laptop performance is accepted. The artistic gate and full goal remain incomplete. No mandatory art-direction answer is inferred from silence; the earlier optional main-mass question remains unanswered.

Reproduce native evidence with `tools/art/capture_volume_strata.gd`; data regression with `tests/volume_strata_contact_test.gd`. Inspect Godot output for script errors, not just exit status. Preserve the previous module capture reports as historical evidence; rerunning them with the changed material would not reproduce their old pixels.
