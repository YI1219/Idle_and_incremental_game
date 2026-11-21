# Background / foliage performance work

Approved: continue non-water optimization, protect current cliffs' color/light and foreground clarity; sole scene, no new gameplay/content, close test windows.

- [x] Artifact prototypes: two cloud/mountain separation composites and early-alpha/indexed foliage; source snapshots saved. GPU jobs exclusive. Keep near clouds in main pass. HDR linear intermediate and final main postprocessing once.
- [x] Sky-channel composite ABBA prototype: native2K57.77→61.51FPS; native4K28.92→30.41; internally1080p only small gain with slightly worse tail, so production should bypass for low internal pixel counts. Original extra opaque composite rejected for higher overhead.
- [x] One-draw camera-motion diagnostic (16 positions/yaw/height): first and second candidate frames have comparable small differences, no additional one-frame lag observed. Composite still replaces far background depth; guard foreground/near-cloud ordering and document far-depth/DOF boundary.
- [x] Production: shared sky-color include, HDR background viewport sampled in sky background branch, preserve original cubemap lighting; layer separation, camera/palette sync, native/low-res/safety fallback, warm before activation, explicit minimized suspension and restoration.
- [x] TDD native contract before implementation: real HDR target dimensions/layers/near clouds, native override, low-res bypass, minimize/resume, source material/layer/camera restoration. Render captures across several seeds/angles/day/night, motion and foreground color/light comparison.
- [x] Final normal-loop ABBA FPS at actual pixels, full current-stage suite, independent read-only review, concise records and process cleanup.

Scope rulings: foliage early-alpha/exact-index prototype has no reliable gain in first native4K samples; do not ship unproven shader changes. New background feature should only activate at useful internal pixel budgets with hysteresis; target Air/Windows and temperature/power remain unmeasured. No destructive git operations or second checkout/version.
