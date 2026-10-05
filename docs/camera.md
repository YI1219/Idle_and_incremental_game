# Terrain workshop camera

The active demo uses a fixed orientation. WASD/arrows and middle-mouse drag pan on the horizontal XZ plane, preserving camera height. The scroll wheel alone changes height and zoom along a bounded dolly path (height 6–100 world units). All movement eases smoothly with elapsed time.

Vertical movement, fly mode and orbit are disabled. Q/E and Alt-drag do not move or rotate the camera. Home recenters horizontally; layout reset, load and preset changes preserve the wheel-selected height. UI text input suspends keyboard panning; focus loss cancels active input.

Verify with `python3 tests/run_preview.py tests/terrain_editor_runtime_test.gd --headless`. The retained legacy gameplay scene uses its original camera and is not the active workshop.
