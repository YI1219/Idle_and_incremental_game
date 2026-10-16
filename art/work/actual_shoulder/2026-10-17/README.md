# Actual shoulder authoring study

Input: retained ordinary `exposed_cleft_v1.json`, actual cap/skin positions, original crown37frame. `tools/art/sculpt_actual_shoulder.py` saves one bounded subtractive shoulder cut. With `--remove-orphan`, exact prior raw connectivity identifies four isolated scalar knots of the inherited96-triangle orphan; their sign removal saves `shoulder_cut_clean.json`. Both are ordinary version4shared editable saves with unchanged cells/non-rock fields.

Native capture flags: `actualshoulder actualcap capfans details fixedwater fieldnormals`, optionally `shoulderplanes` only for the rejected normal diagnostic. Final cleanup uses `actualshoulderclean` and omits `shoulderplanes`. Raw exports: `probe_bedrock_local.gd -- actualshoulder`/`actualshoulderclean`. `analyze_cliff_volume_skin.py` writes exact source topology; `check_face_replacement_save.gd` covers finite ordinary compatibility. `build_actual_shoulder_review.py` binds all actual evidence and builds the local comparison.

Source binary skins are ignored local work files; JSON saves,reports,tools and small logs are retained. No source model/default changes. Full scope and limitations: [current review](../../../review/terrain_fidelity/2026-10-17/actual_shoulder/README.md).
