# Courtyard scene study

User approved a scene-only pass. No new character, combat or Tripo work. No Git repository exists, so new scene/scripts/shaders isolate the study; original resources stay byte-identical.

1. Preserve hashes of existing runtime assets and core gameplay files. Copy two existing licensed tree variants and path modules with their dependencies; record provenance.
2. Add an independent `scenes/courtyard_study.tscn`. Reuse RiverTerrain, Cottage and CourtyardArt through an isolated subclass. Two presets move/rotate the cottage and recalculate its approach/path/plant exclusion. Deterministic scatter respects path and cottage clearance. Add path module instances and grouped peripheral rocks. Existing actor is optional stationary size reference only.
3. New ground shader blends soil/moss/grass and path transitions, preserving surface readability. Independent foliage palette and matte rock materials unify with cottage. No generated official models.
4. Camera orbit/zoom, preset switch, optional scale reference and UI hide make the study inspectable. Default scene stays unchanged.
5. Test actual loaded layouts for dry terrain, door/path clearance, preserved material scope and repeated switching. Capture real Godot frames at default, close and reverse views in both presets. Run existing scene integration and terrain/camera checks once.
6. Inspect captures, address obvious composition/material faults, document remaining geometry/style limits and no target-hardware claim. Provide runnable entry and engine captures.

## Result

Implemented and inspected six engine views. Study checks 77/77, scene integration 12/12, terrain 794/794, camera 8/8. Preservation: 65 existing files unchanged, 14 source-copy hashes match. See `art/review/courtyard_study/2026-09-21/review.md` for remaining art and performance limitations. No dependencies installed.
