# Terrain

2026-09-17. How ground is stored, joined, and drawn. Economy still follows [Core design](core_design.md). Clicking and walking follow [Courtyard operations](courtyard_ops.md). Look: [current courtyard style](art/style/README.md).

Data is a 2D sparse grid. Land uses fill plus seams. **Rivers use 2D connection textures that can join many shapes** (blob / 8-neighbor bitmask). This is not column voxels.

## Three layers; do not mix them

| Layer | What it is | What it is not |
| --- | --- | --- |
| Logic cells | Sparse dictionary: whether this cell has land, and which logic type | Cloud sea, wells, trees, pens |
| Surface | How the top face is drawn: land fill/seams; river blob connection textures | One Node per cell |
| Entities | Wells, houses, crops on ridges, pens, trees, cloud gates | A ground type |

Cloud sea = coordinates missing from the dictionary. A hole and off-island are the same thing. Do not make a `cloud` type.

## Logic types and skins

The experience slice opens only three **logic types**. Skins may be added later without opening a second economy ledger.

| Logic type | Walkable | Uses seepage | Top height | Experience-slice skin |
| --- | --- | --- | --- | --- |
| Living | Yes | No | 0 | Grass soil (start) |
| Cultivated | Yes | Yes | 0 | Ridges (start) |
| River | No | Yes | One step lower (~0.15 m) | Shallow water |

Later stone paths, wood decks, and brick yards are **living skins** and still do not use seepage. Formation eyes and special terrain are the new logic types.

Changing logic type = Build. Changing skin = decoration; it does not change water-adjacency or seepage.

## What connection textures join

When a cell changes, ask its eight neighbors. Land and river are not the same atlas.

**Land (living, cultivated):** same types join into a continuous field, world-space UVs. Do not use one repeating texture per cell that paints 1 m grid lines. Living and cultivated use 4-neighbor seams. Qinglan uses large color masses; land should not look like pixel fields.

**River: use the 2D connection-texture set that can join many shapes.** 8-neighbor bitmask (usually collapsed to 47 looks; or one compact atlas cut into quarter tiles and reassembled — RPG Maker water and Godot Terrain peering are this kind). Must join: isolated water, dead ends, straight runs, corners, T-junctions, crosses, interiors of wide water, inner and outer corners. The starting shallow bay is a small patch of water; a one-cell-wide ravine must also look right.

Do not join rivers with 16 four-way “pipe” tiles. Pipe tiles draw T-junction pipes on sheets of water and fake a shallow bay.

Banks are drawn **on river cells**; they are the edge of this connection set. Do not stack extra “grass–river” or “ridge–river” seams (double banks). Water-adjacency play still uses 4 neighbors; diagonal water is not adjacent and cannot cheat a hard gate. River **looks** at 8 neighbors (inner corners round); **play** only uses 4 neighbors.

| Neighbor | Which set | How many neighbors |
| --- | --- | --- |
| Same land type | Continuous fill | — |
| Living / cultivated meeting | Seam edge | 4 neighbors |
| River / non-river | River blob edge = bank | River looks at 8; water-adjacency play looks at 4 |
| No cell (island edge or hole) | Cliff mesh: straight, outer corner, inner corner | 8 neighbors. Missing-cell cliffs override river banks; do not paint a beach ring against the cloud sea |

Look still follows Qinglan. Borrow this **joining method**, not the pixel-field look. Quarter tiles are fine; 47 whole tiles are also fine. Choose what is easy to paint and swap.

**Do not:**

- Join shallow bays with 16 pipe tiles.
- Recompute the whole-map bitmask every frame. Only dirty the chunk of the changed cell and chunks intersecting its eight neighbors.
- Use one MeshInstance per cell. Rivers and land go into chunk meshes; cliffs use a small number of MultiMesh kinds.
- Use a 2D TileMap as the courtyard's main renderer. Bitmasks may be computed like 2D tiles, then drawn on 3D top faces.
- Use column voxels to “also” get connection textures. Height only needs the river one step lower.

Tiny Glade–style stroke auto-join is left for later roofs and paths, not as the ground base. Ground must share the same cells with Assist, footprints, and pathfinding.

## Cliffs and cloud sea

Logic cells stay a sparse 1 m grid (play, cost, footprints). The visible courtyard is not that grid. Each connected land component is built as its own floating volume: a smoothed, slightly noised coastline, a rounded shoulder, and an inverted-cone rocky underside hanging in the cloud sea. Grass top and earth/rock sides blend in the ground shader by normal and vertex color. Islands do not need to stay connected; any number of independent landmasses may exist.

Cloud sea is a viewing layer under/outside the island (animated fog planes plus height fog). It is not a cell and does not join the bitmask. Walking stops on the side with no neighbor. Distant mountains and distant islands are not drawn.

Rivers are not walkable, but river cells **have land**: if their outer edge meets the cloud sea, they also hang with the volume. Do not draw a shallow bay as a bite taken out of the island.

Shrinking land that still supports a placed object is blocked, with a Chinese sandbox reason. Only islands whose cell set changed rebuild.

## 息壤 (terrain-expansion points)

Painting land spends **息壤**, a data-driven point container (`docs/design_v0_2/prototype_config.json` → `xirang`). It accumulates from the same idle/offline `catch_up` as the economy kernel. Cost is newly added volume (`cell_area × island_thickness × cost_per_volume`), charged per brush step, and stops at zero. Removing land refunds `refund_ratio` of the base volume cost. Past `soft_cap_cells` on one island the cost multiplier rises; there is no hard wall. Exploration terrain pieces (`kind: terrain_piece`) can later be placed or decomposed into 息壤; only the data shape exists now.

## Show the grid only in Build

Everyday top-down should read as a courtyard, not a chessboard. Connection textures exist to hide the grid. Entering Build / laying ground overlays a light grid for click alignment. The grid is a tool, not a ground material.

## Chunks and dirty regions

Suggest 8×8 as a chunk. Changing one cell rebuilds that cell's chunk plus neighbor chunks intersecting its eight neighbors. At a hard area cap of 128 cells, the whole island can also rebuild as one piece. Chunking is reserved for later growth, not required for the experience slice.

The logic layer takes effect immediately (walkability, seepage, water-adjacency). Surface may lag a few frames. Do not use visual interpolation to delay the economy.

## Art the experience slice needs

- Two land fills: grass soil and ridges (world-space, weak tiling), plus a grass–ridge seam.
- One river blob connection set (quarter tiles or equivalent 47 looks), banks drawn on river cells.
- One cliff set: straight, outer corner, inner corner (shared inner/outer edges; overrides river banks facing the cloud sea).
- One cloud-sea layer.
- One tree or house corner next to the starting shallow bay; shelter is an entity.

When changing look, swap fills and the river atlas first. Do not split logic types first.
