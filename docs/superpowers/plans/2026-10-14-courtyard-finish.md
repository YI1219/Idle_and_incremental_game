> 2026-10-14 用户范围纠正：本计划中替换树木/植被、小屋比例及布局改动已撤回。当前方向仅为色调、材质质感与水体；以 CURRENT_CONTEXT.md 和 corrected_* 实景为准。下文是历史执行记录。

# Courtyard reference finish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Move the editable floating island toward the October 14 courtyard reference through softer layered nature, warm light/cool atmosphere and more intimate readable materials.

**Architecture:** Retain authoritative terrain and existing formal cottage. Reuse retained textured CC0 nature assets through an isolated material-preserving loader; keep instancing and support checks. Tune world-space ground, sky and water materials through matched runtime views.

**Tech Stack:** Godot 4.7, GDScript, spatial shaders, existing CC0 glTF assets.

**Spec:** Latest user request and attached courtyard image; CURRENT_CONTEXT.md sandbox and source-preservation boundaries.

## Global Constraints
- All visible courtyard land must share the authoritative build data.
- Nature props are independently editable; no bundled tree/rock placement tool.
- Keep the existing cottage and original source files.
- Art, function and performance acceptance remain separate.
- Preserve calm unified underside and local grass/stone exposure.

## Review Focus
- Multi-surface textured meshes must retain UVs and distinct bark/leaf materials.
- Shrub roots must remain terrain-supported after terrain changes.
- Camera movement and reset must preserve user-selected zoom/orientation.
- Low/reverse views must not expose new detached vegetation or grey lip rings.
- Added visual richness must not be reported as measured target-device performance.

### Task 1: Courtyard finish in the editable scene
**Files:** Create `scripts/terrain_editor/textured_nature.gd`, `tests/terrain_textured_nature_test.gd`, `tests/capture_courtyard_finish.gd`; modify existing models, decoration, editor, camera and terrain shaders as justified by rendered studies.
**Interfaces:** Loader produces one multi-surface ArrayMesh per kind, local vertices baked and grounded. Existing `assets[kind]` and `placements()` interfaces stay intact.
- [x] Capture baseline courtyard, overview, shore, rim and reverse/low views in a new review folder.
- [x] Write and run a material/UV/grounding test against actual retained assets before introducing the loader; expected missing loader assertion.
- [x] Integrate existing textured trees/shrubs/flowers, preserving surface materials, morph and support. Run loader and decoration tests; expected zero failures.
- [x] Render lighting/camera and ground/material studies. Accept clear improvement against baseline, inspect close and whole-island views. Reversible visual parameter choices use images rather than assertions mirroring constants.
- [x] Run relevant existing camera, decoration, material, terrain and edit-regeneration suites; expected zero failures. Produce final comparison and fresh screenshots.
- [x] Commit, obtain one fresh whole-change review, address important findings with targeted red/green proof, update current status and push reversible work.
