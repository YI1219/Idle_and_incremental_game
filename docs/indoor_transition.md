# Indoor transition

A preloaded independent interior map chunk plus a position switch under a short fade. The character does not have to walk through the same world coordinates from exterior to interior.

Approach the outer door → about 0.16 s cyan-ink fade → at full cover, switch character and camera → hold about 0.035 s → about 0.20 s reveal interior. Leaving the cottage uses the same treatment. Total length is about 0.4 s; input is blocked only during this window. Held keys resume automatically.

- Interior is 16×12 m, pre-placed at `(1024, 0, 1024)`.
- The same player instance switches position after fade peak. The camera is already in place; it does not fly the long distance in between.
- Only the current region is shown; the camera selects the matching render layers. The transition draws a plain 2D color overlay.
- The doorway has a short re-entry cooldown.

Double-click **Play Indoor Transition.command** to launch the playable scene for this flow.

```sh
python3 tests/run_preview.py tests/space_test.gd
```
