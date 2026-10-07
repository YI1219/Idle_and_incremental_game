# CURRENT → TARGET runtime environment pass

2026-10-06. Implemented in the existing `scenes/terrain_editor.tscn` entry point. These images are actual Godot 4.7.2 Forward+ / Metal renders on Apple M4 Pro. They are not generated concept artwork or offline renders. **The result remains visibly simpler than TARGET and is not claimed as aesthetic acceptance.**

## Images and reproducibility

- [Final default composition](final.png), 1671 × 941, same camera as [before](before.png): pitch −27°, yaw 16°, FOV 31°, height 21.
- [Left orbit](orbit_left.png), [right orbit](orbit_right.png), [back orbit](orbit_back.png).
- [Cottage/garden closer](garden_close.png), [water closer](water_close.png), [wider zoom](zoom_out.png), [gameplay UI](gameplay_ui.png).
- User's supplied [TARGET](../../../../source/visual_targets/2026-10-06/target.png) is retained as reference only. It is not used as a game texture.
- `tests/capture_target_match.gd` instantiates the actual main scene in an exact-size GPU SubViewport. UI/brush are hidden only for clean comparison; the final UI capture shows the workshop. It uses the gameplay camera's right-drag event path and wheel/recenter functions for alternate poses. No alternate meshes, materials or lights are substituted by the capture script.
- Run `godot --path . --script tests/capture_target_match.gd` to reproduce the final views. Water animation phase can differ. `final.json` records poses, renderer and render submission counters; `images.json` records image hashes.

## Visual iteration evidence

The unmodified main scene was first run and captured as `before.png`, matching CURRENT. Eight intermediate rendered candidates (`iteration01.png` through `iteration08.png`) were opened and compared with the supplied TARGET. Final multi-angle captures were also opened and inspected.

1. The first candidate restored shore-stone volume and water highlights, but the procedural sky mountains read as flat cutouts. That candidate was rejected.
2. Distant 3D mountains replaced the cutouts. Early versions were too large and thin; subsequent versions changed their distribution, compound shoulders, scale, facing and haze. Their normals/depth handling were corrected after the render exposed bright overlapping shards.
3. Cliff relief changed from broad, oblique stretched blocks to smaller, less oblique cells. Excess protrusion was reduced after dark angular recesses remained too prominent.
4. Curved retained grass replaced the coarse flat shore blades. Ponds gained small pad groups, subtle wavelets and supported receiving ripple arcs. External falls were shortened to the local shell and given a fading tail. Bright flow streaks were refined into narrower descending filaments.
5. Warm back-right sun improved top-plane/foliage separation but over-darkened the front cliffs. A broad shadowless fill restored readable rock planes. Final color changes are local material/light controls, not a global yellow or desaturation filter.
6. Close inspection exposed overlapping path slabs. The final beveled stepping stones have smaller footprints and visible gaps. Original cottage size and five garden rows remain, with terrain-supported short garden fencing.

## Implementation and preserved boundaries

- Both terrace elevations, lake outlines, connected flow routing, terrain presets and authoritative editable data remain. Shared cliff meshes also supply picking; no detached decorative island shell or locked courtyard ground was introduced. Rock underside thickness still uses the previous 60% support-depth factor.
- Cottage uses the existing refined Tripo model and 0.65 scale. Workshop material overrides use pale plaster, timber posts and charcoal tiles. No original cottage/character/sword asset was replaced.
- Four existing tree anchors and approximately 4.1 m mature heights remain. Derived canopy proportions/facet colors changed; shrubs, flowers, vines and reeds stay terrain-supported and instanced. Pads and path stones are simple local runtime modules. No new management, production or combat systems were introduced.
- Water remains an inexpensive opaque surface with animated normals/sky radiance. Receiving ripple geometry is clipped against actual wet support and published with the existing snapshot. This is not fluid simulation or scene-object reflection.
- Background uses three deterministic mountain mesh resources in 24 angular MultiMesh sectors, allowing frustum culling instead of submitting an entire ring. No shadows, colliders, per-mountain processing, buildings or foreground framing props. Mountains sit approximately 400–800 m away; the group follows the navigation focus horizontally so extended panning keeps the scenery distant. The sky reuses the original cloud texture with angular mapping. Camera far plane is 1800 m.
- Gameplay camera now supports right-drag yaw/pitch and Q/E yaw. Middle drag and WASD still pan horizontally; wheel still controls height/zoom. Orbit preserves focus and height, and pitch is bounded to 20–65°. Home/presets do not reset zoom or orientation. This follows the latest explicit request and supersedes the old fixed-orientation note.

## Verification

Fresh results: **28/28 headless terrain test scripts passed**, plus **2/2 actual-render test scripts** (22 editor-runtime assertions and 7 cottage-material assertions). See `checks_headless.json`, `checks_rendered.json` and individual logs. The new orbit test first failed against the fixed camera, then passed with orbit implementation. The obsolete lower-waterfall picking check was changed from a hardcoded −6 m cutoff to a point below the actual local shell; picking still succeeds on the shortened visible tail. Cottage checks now assert pale plaster and stable local timber posts rather than the superseded all-timber finish. The final mountain-sector optimization was exercised through the full rendered capture set.

No target Windows thin-and-light or MacBook Air benchmark, long-idle stability/power test, or 60 FPS claim is made. Captured draw/primitives counters are submission diagnostics, not GPU frame-time or target-device proof. The ordinary main scene was also launched directly for continued interactive review.

## Remaining visual differences

- The background mountains are still more geometric and isolated than TARGET's densely layered, foliage-covered karst. Cloud detail and mountain/cloud transitions are simpler.
- TARGET has richer foliage silhouettes, denser small natural detail and softer local light bounce. Current shrubs still read as simple faceted clumps; vines are comparatively narrow and repetitive.
- Cliff geometry is finer than CURRENT but still exposes procedural planar rhythms. Shore stones repeat more than TARGET; the rock/earth transition remains less richly sculpted.
- The water has animated wavelets and receiving rings but no reflected cottage or tree geometry. Falls and foam remain visibly stylized shader effects.
- Overall composition follows the existing playable layout, so the cottage/garden and tree arrangement do not duplicate TARGET exactly. The retained small cottage and common tree heights were prioritized as requested.

Functional passes do not establish that these visual gaps are closed. User aesthetic review remains separate.
