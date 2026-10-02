# Scene art and module spec

Current consensus: [CURRENT_CONTEXT.md](../../CURRENT_CONTEXT.md). This spec implements the user's requirements for the three scene types and the sandbox. Module specs and verification combinations below are production suggestions; they do not mean the system is already implemented.

## Presentation constraint

Follow [3D art direction](three_d_art_direction.md): 3D characters and modular scenes, non-pixel ancient-Chinese stylized rendering, rotatable camera. 尘之回声 is a presentation reference; 墨境 (Realm of Ink) is also approved for character motion, combat presentation and art style. Do not import their action-game scope. 2D directional character/Spine production is stopped. Standard textures and particle effects may still be 2D. Existing module and gameplay requirements below remain.

## How references are used

The [courtyard concept image](../../art/source/visual_targets/2026-09-20/courtyard_user_target.png) only shows that the user finds this look usable. It does not lock scene composition, content density, landform, house orientation, or required landscape. Production requirements such as “cottage back-left, water on the right” from the image are removed.

The user provided the following references. Official store pages have been checked. The table below is a suggested split of later art observation, not a user ranking of the games, and not completed frame-by-frame or performance research:

| Official reference | Later observation focus (suggested) |
| --- | --- |
| [Spark in the Dark: Automated Adventure](https://store.steampowered.com/app/1817800/?l=schinese) | How placeable facilities, natural environment, and production layouts stay clear and coordinated |
| [Craftopia](https://store.steampowered.com/app/1307550/Craftopia/) | Visual pairing of characters, built objects, and open natural space |
| [Wildmender](https://store.steampowered.com/app/1599330/Wildmender/) | Natural feel of vegetation, soil and water, and player-shaped space |
| [V Rising](https://store.steampowered.com/app/1604030/V_Rising/) | Readability of buildings, ground, characters, and combat in top-down |
| [The Magistrate](https://store.steampowered.com/app/2052510/The_Magistrate/) | Pairing of ancient-style buildings, streets, and living facilities |
| [Mountain Gate & Illusion](https://store.steampowered.com/app/1963040/?l=schinese) | Cultivation buildings, natural environment, and settlement scale |
| [墨境 / Realm of Ink](https://store.steampowered.com/app/2597080/Realm_of_Ink/?l=schinese) | User-approved character motion, combat presentation and art style: observe pose transitions, attack movement, feedback, ink-inspired color and visual hierarchy |

GRIS, Journey, and Sky remain supplementary references for atmosphere, flow, and finish. The end need is one unified scale, palette, and material language. Do not mix realistic, cartoon, gothic, or other subject elements from the references directly.

Ancient style should show in concrete design: roofs and eaves, wood-to-stone ratios, object shapes, clothing, and motion. It cannot rely only on adding paifang gates, pines, or decorative motifs. Simplify detail while keeping silhouette, spatial layers, and natural color variation.

## Three scene types

- **Sea of Consciousness Courtyard:** sandbox-building core. Terrain, buildings, production facilities, plants, rocks, and decorations are designed as placeable, combinable elements. Do not bake a whole courtyard into an unsplittable landscape model.
- **Village:** independent scene type. Suggested expression is building groups, roads, and living facilities as an ancient-style settlement. Courtyard assets and materials may be reused. Whether players may remodel, and how it is generated, is not yet decided; do not lock that in art docs.
- **Exploration scenes:** prepare assets toward procedural generation. Suggested organization is landform/path structure, resource and event sites, then natural communities, layer by layer. Designed small combinations may be reused, but models must not be scattered at random. Entrances, routes, and key sites must remain reachable.

The three types share look. They are not required to share the same landform, density, or exact assets. Generation range, reset timing, exact algorithm, and village permissions are specified in the matching systems-design stage.

## Requirements for combinable assets

1. **Splittable and reusable:** buildings, facilities, plants, rocks, and similar have a clear footprint and independent identity. Repeatable modules must not ship with ground or neighboring buildings that only fit one image.
2. **Consistent scale and contact:** lock character reference, ground contact, and doorway/path/water-edge connections. After changing position, neighbors, or allowed facing, no floating bottoms, blocked doors, or obvious seams.
3. **Unified materials and color:** similar roughness, detail scale, and color range within a material class. Avoid one asset being finely realistic and another looking like an untextured prototype.
4. **Terrain fit:** logic cells, ground presentation, and placeable objects stay separate. Keep 47-state connection logic; organize visible modules by interface. Do not turn 47 states mechanically into 47 independent model generations. Terrain/water-edge combinations may use procedural joining and material transitions. Unart-directed prototype planes are not finished pieces.
5. **Independence:** main light-dark and grounding should adapt to layout changes. Local material shading is allowed, but do not bake a neighbor's shadow into a movable model, and do not make quality depend on fixed scene lights or a fixed camera.
6. **Natural variation:** a few coordinated shape variants and community pairings reduce repetition. Change size/direction only when the form allows it. Avoid arbitrary stretching of buildings and traversal openings.
7. **Clear function:** player objects, decoration, and distant views have distinct duties. Every blade of grass need not be a logic object; every picture element need not be pickable. Exact interaction is decided by systems.

Evaluate valid free resources for the chosen representation. Demonstrated custom 3D gaps may use user-operated Tripo after inspected four-view preparation. Preserve the running character, sword and cottage during the 3D rendering study; Qinglan corrections require evidence and a bounded scope. Do not batch-redo existing assets.

## Minimal verification (suggested)

First pick a small set of environment modules and combine them with existing buildings, character, and infrastructure. At least compare the following layouts with the same materials and render settings:

- Sparse layout: few buildings and plants, large movable space kept; do not hide ground problems by filling objects.
- Dense layout: more buildings and production facilities; check silhouettes, occlusion, clicking, traversal, and actual load.
- Relocated layout: move houses, change paths and adjacent terrain; both with-water and without-water combinations must hold. If rivers and bridges are used, also check corners, seams, and crossing.

Default top-down, near zoom, rotation, and character movement all need checking. Art passing means this module set stays coherent across placements, not that one angle can screenshot prettily. After exploration generation, also check connectivity, repetition, and content distribution across multiple seeds. Do not treat the current hand-built test scene as a completed procedural system.

## Performance and long sessions

About 60 FPS at low quality on a Windows thin-and-light laptop and a MacBook Air is a target still to be measured. Measure normal and dense layouts first, then set asset and visible-range budgets. Do not derive this project's frame rate from reference-game screenshots.

Suggested: instance reuse, LOD, regional culling, shared materials, and controlled shadows, water, and transparency. Prefer local updates when the player changes layout. Keep decoration draw cost and actual production simulation separate; do not hang per-frame logic on every decoration. Low quality still keeps unified style and key silhouettes.

Lighting must adapt to courtyard rearrangement. If the village has fixed parts, baking may be evaluated separately, but unconfirmed fixed layouts must not be the optimization premise for the whole project. Record device, resolution, backend, quality, frame time, variance, and long-session load. Do not claim the target is met without target-device verification.
