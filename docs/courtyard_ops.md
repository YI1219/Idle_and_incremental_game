# Courtyard operations

This document describes operations, camera, clicking, facility UI, and visual duties for the Sea of Consciousness Courtyard. It does not mean they are already implemented. The courtyard is a sandbox, organized separately from the village and exploration areas. Elements are designed for placement and combination, not from concept-image coordinates. Look spec: [current courtyard style](art/style/README.md). Exploration: [Exploration](exploration.md).

## Current implemented building slice · 2026-09-21

Sandbox building is the immediate priority before further static scene polish. In the main demo, B opens footprint-based nature placement, selection, move/cancel/remove, cottage relocation, guarded land editing and manual layout save/load. Use the root `打开沙盒营造.command` for direct entry. See the [implementation review and controls](../art/review/sandbox/2026-09-21/review.md).

Nature trial is free and yield-neutral; production facilities remain fixed. Cottage keeps its facing and is unique. All visible land now belongs to the sparse build data: erase unoccupied cells and expand any edge, including by dragging. The playable preset starts at 130/256 cells; the generic simulation preset remains unchanged. Nature props are individual, with no tree/rock bundle tool. v2 layout saves preserve the entire island, and v1 saves migrate their former implicit background and split bundles. Rivers/bridges have no dedicated editing tool, and the original logical/visual facility overlap remains a documented initial-site compatibility exception. Complete production construction costs, retyping, full route validation, undo and multiplayer are not implemented. Layout files preserve placement and the complete land set only, without rolling back resources. See the [land refinement review](../art/review/sandbox_land/2026-09-21/review.md). The design below still describes the broader intended system.

## In-progress HUD: player clicks and character actions are separate

While the courtyard is running, it must be obvious at a glance what **the player clicks themselves** versus **what they assign a character to do**. Both are sources of incremental work, but they are not the same toolset.

- **Assist** occupies its own slot and does not enter the character action bar. It is like the hand tool in Photoshop's toolbar: always there, easy to find, not the same class as the brushes next to it. The hotkey may still be 1. Its role is a short intervention past a startup bottleneck, not long-term optimal labor. Late stable lines should not mainly rely on remote click-spamming.
- **Character actions** are a separate bar: gather, cultivate, assign, and later items that truly belong to character labor. Switching buttons on this bar only changes what left click means for the character queue.
- Inspect is not a fifth hotkey next to Assist. Clicking a facility opens its panel; resource nodes can use hover tips.
- Build, meridian linking, pack, and menu keep their own entries and are not stuffed into the character action bar.
- Opening a facility panel, pack, or dialogue does not pause world simulation; camera and scene clicks yield to the UI by existing rules.

Default entry to the courtyard may rest on Assist, so an idle click is easy. The selected state of the character action bar must be visible, so “I clicked a tree and don't know if I clicked it myself or sent someone” does not happen.

## Camera

Keep Don't Starve–style wheel push (distance and pitch ease together) and Q/E rotate. WASD still moves the character relative to camera facing.

The camera may unlock from the character. After unlock, hold-drag on empty ground to look elsewhere; the character keeps working on existing assignments. Home or starting WASD movement returns to follow. Middle-mouse drag remains a pan that does not switch tools, so it does not fight Assist left click. Space stays for pausing assignments, not as a hand-tool key.

Drag-look must not teleport the character, and must not interrupt character labor already in progress.

## Scene and map edge: grotto-heaven floating island

Scene style: [current look](art/style/README.md). The courtyard image is a look reference only. Actual art must hold under many player layouts.

Map edges are **grotto-heaven islands floating on a cloud sea**. Do not let tiles cut suddenly into void, and do not pretend this is a boundless continent that paints infinite plains as the player walks.

- Ground is a 2D sparse grid of typed cells. Start with a prefab island. Existing cells can change type or be deleted back to cloud sea; holes on the island are allowed. New cells can only be laid against an existing land edge, never isolated in the cloud sea. Cells occupied by wells or buildings cannot be deleted. Surface joining: [Terrain](terrain.md) — fill hides grid lines, unlike types draw seams, missing cells hang cliffs.
- Walking only works on **living cells and cultivated cells**. River cells, holes, and island rims stop movement. The courtyard has no fall-damage penalty. Later, sword flight can cross holes and cloud sea between two land masses; landing must still be on a walkable cell. Sword flight also cannot leave the grotto-heaven boundary (the same bound as the area cap). Laying-ground rules do not change: flying over cloud sea cannot isolate-lay.
- Outer rims and inner hole rims both draw cliffs. Cloud sea is a viewing layer, not a cell.
- Wells, facilities, pens, and decorations are entities on cells, not a ground type. Decorations do not add yield. A pen occupies a living cell and does not convert that cell into production land.
- **Living cells** (ordinary land, paths, leftover space) only consume the area cap and a one-time laying cost, not seepage. The start must leave living and landscape slack. Do not make “delete the yard” the correct lesson as soon as someone learns building.
- **Production cells** (cultivated, river, later formation eyes and special terrain) consume qi by cell count. The experience slice starts linear, later with rising marginal cost, supplied **automatically** by well seepage; energy is not carried. Seepage does not drop because the island grew. If the next cell would make production land exceed total seepage, it cannot be laid or retyped; existing cells do not scatter. Changing cultivated or river back to living, deleting cells, or cutting holes all reduce drain. One well supports starting production land; more wells are needed for more. The laying preview must show remaining-seepage change. There is also an upgradable area cap.
- **River:** production cell, not walkable. Start with an edge-attached shallow bay only. A river that splits the island into two walkable regions is forbidden — the experience slice has no sword flight, so a split wastes half the yard. Water-adjacent means at least one of four neighbors is river. Shelter means a tree, house, cliff, or a dedicated shade entity, not the river itself.
- Cultivated water-adjacency is a soft preference: growth is faster, with a hard cap. Water-adjacency is not required to plant. That lets pens and fields compete for the same shore, so the two yards can exist.
- Leave at least one shelter (tree or house corner) next to the starting shallow bay, or “only stable with shelter” cannot be staged in the experience slice. Shelter is an entity; it does not change land type and does not use seepage.
- Place a cloud gate on the south rim (entity; occupied cells cannot be deleted). Walking in goes out. Exploration: [Exploration](exploration.md).
- Distant views may be painted beyond the cloud sea as a viewing layer; they do not provide landing or walking.

These tile and cloud-sea edge rules are for the Sea of Consciousness Courtyard. The village is an independent scene type; exploration is designed toward procedural generation. Shared art does not mean a shared map or the same building permissions.

## Character scale and labor animation

Characters follow [current courtyard style](art/style/README.md). Head and hem should be recognized first in oblique top-down. Doorway scale follows current runtime size and actual traversal checks. Do not use realistic adult proportions, and do not use blocky minifigs. Character and cottage share one silhouette language; do not mix two head-to-body ratios.

Labor must have actions that match tool and target, not one generic “working” clip. At least split: chopping, mining, herb gathering, carrying, cultivating, operating a facility. Contact frames may spawn hit effects; yield is still timed by the sim kernel. Animations do not emit items.

## UI quality

The in-progress UI should be simple, but not translucent dark rectangles plus a row of default buttons. Reference Genshin Impact's whitespace, alignment, and icon hierarchy, and Humanica's tool grouping and “one building, one dedicated window.” Do not copy Genshin's full-screen gold-border frames.

- Light paper, thin strokes, few shadows; jade cyan for selection; warm gold only for emphasis. Icons before long sentences.
- Keep the persistent HUD thin: top-left status, Assist, character action bar, a few system entries. Task text and queues should not cover labor animation for long.
- Hover tips are short and follow the cursor or object; they do not occupy a whole right-side panel.
- Same spacing, corner radius, and type size. Do not let each drawer invent its own dark card.

## Click picking

When planning land, emphasize cell accuracy. When choosing objects in daily play, emphasize that the seen target and the feedback match.

**Build, laying ground, demolish:** only recognize occupied cells. Do not use inflated 3D click boxes to pick a neighboring tree.

1. Camera ray hits the ground and takes that cell.
2. Only hit objects whose **footprint includes this cell**.
3. Multi-cell buildings hit every cell they occupy, with no extra expansion.
4. An empty cell is empty: allow drag-look or walking; do not snap to a nearby tree or crate.
5. On overlap, take the primary object registered on that cell. A model sticking above the ground must not steal a neighboring cell.

Hover highlight also draws the footprint. In oblique top-down, a canopy may project onto a neighboring cell. Daily selection uses outline, ground marks, or candidate highlights so “click the thing I see” works. Do not expand planning-mode cells just to click trees.

## Automatic facilities: open the facility panel directly

Left-clicking an automatic facility, workbench, storage, or similar device opens **that facility's dedicated panel**. Do not pop a mutually exclusive list of “Assist / start work / add to assignments / recipe dropdown.”

The panel answers three things first, then details: what it is doing; net output; **why it is not working** (not connected / no input / output full / not enough qi — split at a glance). Recipes, buffers, and config come later. Do not make the player open four panels and reason it out. Move and demolish sit in secondary positions. World simulation continues while the panel is open. Offline summaries likewise explain stoppage and how long remaining stable run time is.

The Assist tool on **resource nodes that still need human push** (trees, ore, herbs, unautomated springs, etc.) contributes work directly, without opening a panel first. Clicking an already automatic facility opens the panel. Remote Assist, if needed, is pressed inside the panel, not via another choice list.

## Explicitly out of this round

Exploration combat form, Yunyin Village content, day length and realm numbers, sword flight, shapeshift, formations. Exploration camera is not locked this round. The kernel slice is walking only. The experience slice uses visible fog as failure and does not make combat first.
