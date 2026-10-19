# Designed shallow bank — local native comparison

User selected refinement of the existing mother shape, grass/stone contact and bank. This is the bank component, not a new whole-island scene or art acceptance.

`sphere_*` versus `profile_*` are actual Godot1671×941 captures with the same source rock, camera, light and surface material. The change combines an elliptical floor/bank profile with raised static water, rather than pretending to isolate a single scalar setting. Water animation time is live.

The old sphere center floor is2.104m with water2.5m; the new center floor is2.561m with water3.0m. The floor rises continuously toward the dry shoulder, reducing the crater impression. All cuts remain ordinary editable density overrides over the immutable original source. No separate decorative lake floor. `profile_v1.json` is the actual source-bound v5 document.

`profile_breach.png` / `profile_restored.png` show a real cut through the bank, invalid water hidden, then exact document restoration by undo. Fresh bank-profile10/10 checks cover basin closure, wet/dry shoulder, outside land, v5 roundtrip and breach/undo. Capture report verifies8successful image writes and exact restoration.

Preservation comparison is **outside the old sphere brush's full support envelope**, including its signed-distance band, not merely outside the visible water outline. Three negative knots nearX.75,Y2.75,Z±.25 change by≤.056m while retiring that band, without changing signs. The original source/preset/document/save remain unchanged.

Reproduce with `tools/art/capture_volume_bank.gd`; profile factory `tools/art/volume_bank_profile.gd`. Remaining lower-body, rear-wall and grass-edge defects are addressed/assessed separately in [shape continuation](../volume_shape/README.md). This is a local improvement judgment, not the user's art approval.
