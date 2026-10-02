# Camera

Scroll wheel up pushes in; down pulls out. The camera moves along a path with horizontal offset. Pitch goes from about 38° near to about 58° far; default distance is 50°. Distance and pitch use exponential easing; do not snap between tiers.

Middle-mouse drag pans on the ground. Home or double-click middle mouse recenters. Q/E rotate 45° each time.

```sh
python3 tests/run_preview.py tests/camera_test.gd
python3 tests/run_preview.py tests/space_test.gd
```
