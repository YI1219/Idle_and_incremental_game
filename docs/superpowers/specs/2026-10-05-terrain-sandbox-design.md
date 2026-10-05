# Editable floating-island demo

## Outcome and boundaries

Replace the active demo entry with a terrain editor whose appearance targets the user's attached floating-island picture: sunny grass, faceted stone cliffs, layered land, blue ponds, waterfalls and coherent vegetation. The picture guides materials, lighting, silhouette and finish; editing must support other layouts. The old terrain and placed scene objects may be removed or replaced; they are not preservation requirements. Original asset source files and economy sources remain available. No character, combat, village, exploration or paid-asset work is included.

## Architecture and alternatives

Use a sparse height grid with 8×8 render chunks. The existing single-height renderer cannot express the target; extending it directly would also entangle the old gameplay scene. A continuous sculpting mesh would allow arbitrary topology but complicate the requested single-cell connection rules. A dedicated editor scene with discrete cell data and continuous brush placement is the selected approach.

One data model owns land existence, terrain height, optional water level and deterministic decoration seed. Terrain heights use bounded increments of 0.5 world units, from -4 to 12. Water has exactly eight elevations, 0 through 7, spaced by 0.5 world units. Water occupies cells whose ground is below the selected surface; raising the floor through the surface removes water from that cell. This is an editable pond system, not a fluid simulation.

Separate modules handle terrain data and brush operations, chunk geometry, decoration instancing, editor camera, input/UI and diagnostics. Edits immediately change data and mark intersecting chunks plus their neighboring boundary chunks dirty. The renderer rebuilds only dirty chunks, with rebuild work bounded per frame. Nothing rebuilds while idle. Chunk collision/picking follows the same geometry; no decorative ground exists outside the editable data.

## Editing behavior

Left drag applies the selected raise, lower, expand or contract brush. Raise/lower adjust existing cells by one increment per stroke visit. Expand fills absent cells within the brush using the selected height; contract removes cells and their attached water and generated decoration. A stroke does not repeatedly change the same cell unless a new stroke begins. Brush radius is adjustable.

Snapping on aligns the brush center to cell centers and uses integer-cell height increments. Snapping off follows the world-space cursor and circular coverage continuously while retaining the authoritative cell model and height increments. The UI explains this distinction. Free terrain editing means free footprint and elevation editing, not arbitrary polygon vertex editing.

Water painting and removal are additional tools, with an eight-position elevation selector. Reuse Blob47 normalization: diagonal connectivity requires its two orthogonal neighbors. Connected water must have the same elevation. All 47 normalized states are supported; these are connection cases rather than 47 economic ground categories. Higher water adjacent to lower water or an absent boundary produces waterfall geometry. Ground steps expose rock faces. Undo/redo covers strokes; layout save/load preserves land, heights, water and seed without changing legacy gameplay saves.

## Rendering and automatic decoration

Chunk meshes combine grass tops, soil transitions and faceted cliffs using shared materials. Water uses a shared inexpensive animated shader; waterfalls use bounded strips with opaque or minimally layered foam. Avoid per-cell nodes and expensive transparency stacks. World-space ground detail hides the construction grid; the grid is an optional editor overlay.

Use existing CC0 Quaternius grass, bush, tree and rock meshes. Extract reusable mesh surfaces and instance them in chunk-local MultiMeshes with shared materials. Choose decoration from coordinate/seed hashes, rejecting submerged cells and unsuitable terrain. Grass aligns with the top surface; surface rocks partially embed in the ground. Cliff rock transforms anchor within exposed side faces rather than floating alongside them. Edits regenerate only affected chunk populations and remove obsolete instances. Decoration is generated separately by kind; no bundled manual nature-placement tool is restored.

A starting composition supplies two terraces, ponds, a connecting spill and scattered trees, optionally using the existing cottage as a scale/style anchor. Every terrain cell remains editable. Presets include a compact island, an elongated terraced island and a sparse island with holes. They use the same renderer and module rules. No new custom original models are generated in code; missing surface objects use identified placeholders.

## Camera and UI

Camera orientation stays fixed. WASD/arrow keys and middle-mouse drag pan forward, backward, left and right on the horizontal XZ plane, preserving camera height regardless of terrain elevation. Vertical movement, fly mode and orbit are disabled. Only the scroll wheel adjusts camera height and zoom along a bounded dolly path. Smooth movement uses time-based exponential easing with height changes driven exclusively by wheel input. Reset/preset changes and horizontal recentering preserve the current camera height. UI captures do not edit terrain, and focus loss cancels active navigation and strokes.

A compact panel exposes terrain tools, brush radius, snap toggle, water elevation, grid toggle, undo/redo, save/load and reset/preset selection. An on-screen legend explains camera controls. Diagnostics report cells, dirty chunks, edit time, frame time and draw calls. Low quality disables costly shadow/detail work while retaining major composition, grass color, cliffs and tree silhouettes.

## Verification and completion

Fresh data tests exercise all four edits, snap coverage differences, brush stroke deduplication, undo/redo, serialization, all eight water levels, all 256 input masks yielding exactly 47 normalized states, same-height connectivity and neighbor invalidation. Runtime checks verify horizontal keyboard/drag panning preserves camera height, vertical/orbit inputs have no effect, only wheel input changes height/zoom, reset and preset changes preserve height, input cancellation, dirty chunk updates, water/cliff changes and deterministic decoration. Inspect actual engine captures for three substantially different edited layouts, including holes, elevated banks and a waterfall.

Benchmark 4096 cells at 1280×720 low quality, without fixed-FPS simulation or headless-render substitutes: three runs of at least 60 seconds, median frame time ≤16.7 ms and p95 ≤25 ms. Record hardware, rendering backend, draw calls, memory and edit response latency, then run a 30-minute stability session. Missed thresholds remain unresolved. Development measurements do not prove Windows thin-laptop or MacBook Air acceptance; those remain separately pending. Visual acceptance requires actual rendered evidence consistent with the reference, not a concept image or functional test alone.

## Implementation sequence

1. Add the data model and meaningful operation/connection tests.
2. Add chunk terrain/water/cliff geometry and verify localized rebuilds.
3. Add instanced decoration and the editable reference composition.
4. Add camera, editor tools, undo/redo and isolated layout persistence.
5. Switch the active demo entry, update launchers and current documentation.
6. Fix runtime/visual issues from engine inspection, then run the benchmark and stability gates.

Ask for user action only when an external resource is unavailable or a material requirement conflict cannot be resolved from the current request. Preserve unrelated working-tree changes.
