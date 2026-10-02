# Camera

Scroll wheel up pushes in; down pulls out. The camera moves along a path with horizontal offset. Pitch goes from about 38° near to about 58° far; default pitch is 50°. Distance, pitch, yaw and pan use a critically damped spring (`spring_omega`, `yaw_omega`, `pan_omega`). New targets replace the old goal and keep velocity, so transitions are interruptible. Do not snap between tiers.

The playable courtyard uses a longer lens (`lens_fov`, default 34°) with the rig pulled back (`default_distance` 22, `min_distance` 8, `max_distance` 32) for a miniature / diorama read.

Middle-mouse drag pans on the ground. Home or double-click middle mouse recenters. Q/E rotate 45° each time.

```sh
python3 tests/run_preview.py tests/camera_test.gd
python3 tests/run_preview.py tests/space_test.gd
```
