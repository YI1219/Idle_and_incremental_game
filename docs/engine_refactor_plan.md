# Purpose-built runtime: refactor plan

Written 2026-11-22 against branch `pr-18-lip` at `b5de5f7` plus the uncommitted tree; revised twice the same day from two rounds of owner answers (section 1.1). Implementation started on 2026-11-22; the state of the work is at the top of section 5 and in `CURRENT_CONTEXT.md`.

The owner has decided to build a purpose-built runtime. This document does not revisit that. No owner decision is open at this revision (`docs/engine_refactor_plan_questions.md` says so). Choices the agent made on its own authority are marked **(agent's call)** so they are easy to find and overrule.

**What binds the work.** The hard constraint is the locked gameplay (2.7). The soft constraint is the quality of today's picture: keep that feel and raise it. Earlier code, earlier requirement notes, earlier specifications and the current pipeline are reference, not rules. Where this plan keeps one of them it is because it is useful, and it may be dropped when it is not.

## 0. Summary

**What gets built.** One shared runtime and swappable scene layers. The shared runtime owns the save file, items and the warehouse, the cultivator and progression, input and camera interfaces, user settings, and a simulation that runs with no window. A scene layer owns its world data, its rules and its own renderer. The Sea of Consciousness is the first layer and the only one in the first slice. The village and the extraction map join later as two more layers in the same runtime, through interfaces named in section 2.

**Where the three gains come from.**

1. Performance: an island changes only when the player edits it or the light changes. Lighting, shadows and surface painting are baked when that happens instead of being recomputed every frame. Today's frame spends its time on per-frame work (MSAA, SSAO/SSIL, cascaded shadows, layered foliage cards, 1.3 M grass triangles) that this design does not have.
2. Look: lighting, materials and foliage are one model built for this picture, and the art goal (section 3.1) is a quiet, sharp, hand-painted classical Chinese picture that is comfortable on a desktop all day. Because the static island is shaded when it changes and not every frame, line, wash and surface painting can cost far more per pixel than a per-frame budget allows.
3. Wallpaper: with the camera still, the finished static island is kept as a picture. Each frame draws that picture plus water, falls, mist, clouds and the few things that move. When the wallpaper is covered or the display is off, by default no frame is drawn and the simulation keeps running.

**What changed with the owner's answers.** The first acceptance gate is the development Mac (M4 Pro) on its own screen at native resolution, 3024x1964, at 60 FPS, with 1080p at 120 FPS as the fallback; Windows and thin laptops come later and nothing waits on them. The island generator is not ported: generation is rewritten for the runtime, and all cliff form and surface work happens there from now on. Water becomes a simple source-driven flow with the spirit spring as an unlimited outlet. Each island is designed for 4,096 cells; more islands can be founded, they are staggered in space at heights the player sets, and several are on screen at once. Foliage sways only when a gust passes. The cultivator is a free skinned model. The art goal is set and pursued by the agent, with a hand-painted direction to be tried.

**What a runtime does not fix by itself.** Island form and the presence of large cliff faces are generation and content problems. The engine, the caches and the wallpaper path do nothing for them. They are addressed in this plan only by the generator rewrite (3.7) and the baked surface painting (3.5), which are design work with their own art risk. The phase table marks this step by step.

**Order of work.** Freeze the current tree; short risk spikes (macOS wallpaper glue, renderer cost at the screen's native resolution, look study, generator study) with a show-and-continue checkpoint; shared runtime and headless simulation; the new island generator and edit pipeline; the Sea renderer; the macOS shell; the vertical slice and its acceptance on the M4 Pro. Then a platform gate for Windows and thin laptops. The Godot project is frozen as the reference and stays runnable until the owner decides the cutover.

**How success is judged.** Four criteria, all required (section 6): a clearly better classical Chinese picture than today; native resolution at 60 FPS measured on the M4 Pro's own screen; live island editing still works; the wallpaper is cheap and its water never drains dry. Nothing is claimed for a thin laptop until one is measured.

## 1. Decisions and facts the plan rests on

### 1.1 Owner decisions of 2026-11-22

| # | Decision | Where it lands |
| --- | --- | --- |
| – | When the wallpaper is covered or the display is off, what happens is a user setting. Default: no frames, simulation keeps running. | 2.3 `Settings`, 3.9 |
| 1 | Today's picture is a fair baseline. The target is comfortable on a desktop all day, easy on the eyes in colour, stronger in classical Chinese atmosphere, naturally sharp and not muddy. The agent sets and pursues the art goal and does not wait for a fixed set of stills. | 3.1, criterion 1 |
| 2 | Today's soft 3D is clean and natural but lacks something for the genre. A more distinctive, hand-painted or hand-drawn quality is worth trying. | 3.1, 3.5, spike S3 |
| 3 | In wallpaper mode foliage may sway, but only when wind passes; there is little wind, so sway is infrequent. | 3.3 |
| 4 | The wallpaper camera is still. No drift. | 3.4, 3.9 |
| 5 | One day lasts about 12 minutes. | 1.3, 3.4 |
| 6 | Wallpaper mode is watch-only. | 3.9 |
| 7 | A true wallpaper is preferred on Windows and macOS and is expected to be achievable. | 3.9, phases 1, 5, 7 |
| 8 | After a full close, the simulation catches up at the next launch, capped at 12 real hours (60 game days). | 2.3, 3.9 |
| 9 | No water source, no ponds. Water is a simple flow model: with input, output continues; when input stops, output stops after a delay and the level falls to a height that does not leak. No conserved volume and no total water budget. A spirit spring is an unlimited water outlet. | 3.8 |
| 10 | Island area is limited by cultivation and realm, not by fishing. Fishing is a production activity or minigame in the home world. More islands can be founded through a dedicated option that costs more quota. | 2.3, 2.7, 3.7 |
| 11 | Each island is designed for 4,096 cells; further space comes from more islands. | 3.4, 3.6, 3.7, criterion 2 |
| 12 | Part one may use a free character model with skeletal animation. | 2.3, 3.3, phase 4 |
| 13 | The first acceptance target is the current Mac (M4 Pro MacBook Pro) at native 4K and 60 FPS. A Windows thin laptop is not part of this first gate. | 5, criterion 2 |
| 14 | Native 4K at 60 FPS; if that cannot be hit, 1080p at 120 FPS. | 3.6, criterion 2 |
| 15 | The owner does not judge engine internals. The proposed pass thresholds and the stack defaults stand. | 2.2, 6 |
| 16 | The dirty tree may be committed on `pr-18-lip` and tagged as a freeze. The 7.7 GB `art/lookdev/` archive is backed up outside the git repository and not committed. | 4, phase 0 |
| 17 | The current island generator is not ported as it is. Generation is adapted or rewritten for the runtime; the current logic likely went wrong from the start. | 3.7, phase 3 |
| 18 | Cliff form and surface work continues only inside the new runtime, not in Godot. | 4, 5 |
| R2-1 | Several islands are staggered in space, not lined up. The player sets each island's height. More than one island is on screen at once, in play and in the wallpaper. | 2.3, 2.7, 3.4, 3.6, 3.7 |
| R2-2 | The first gate is measured at the current Mac screen's native full resolution (3024x1964), not on an external 4K display. This replaces "native 4K" in 13 and 14. | 3.6, criterion 2 |
| R2-3 | A new game may start with one spirit spring already placed. What the picture and the water do when that spring is moved or removed is tested. | 3.8, criterion 4 |
| R2-4 | The agent has full authority over git for this repository: commits, tags, the freeze, ordinary management. The work tree is not discarded without a recoverable tag or backup. | 4, phase 0 |
| R2-5 | Where `art/lookdev/` is backed up is not important. Material there that is not needed as a picture baseline or reference may be deleted. Source references and anything needed to compare against today's look are kept. | 4 |
| R2-6 | Nothing waits on a Windows or thin-laptop gate. Accept first on this Mac; Windows comes later. | 5 |
| R2-7 | The agent is not bound by previous code, requirements or specifications; they are reference. The hard constraint is the locked gameplay. The soft constraint is the quality of today's picture: keep and raise that feel. | whole plan |

### 1.2 Measurements

All timing numbers are from the development Mac (M4 Pro, mains power, Godot 4.7.2, Metal), taken from `art/lookdev/20261121_perf_stack/README.md`. They describe today's Godot frame on the default 623-cell island.

| Fact | Value |
| --- | --- |
| One 3840x2160 render, default tier, three views | 28.4 to 38.4 ms (26 to 35 FPS) |
| One 3840x2160 render, light tier, three views | 17.4 to 25.0 ms (40 to 57 FPS) |
| One 1080p render, default tier / light tier | 12.0 to 15.4 ms / 7.0 to 8.8 ms |
| At 1080p: 2x MSAA; SSAO + SSIL together | 2.9 to 3.0 ms; 1.8 to 2.0 ms |
| At 1080p: foliage cards (27,752 triangles, layered alpha); sun shadows (four splits); grass blades (1.3 M triangles at full detail) | 2.0 ms; 1.7 ms; 1.6 ms |
| At 1080p: distant mountains (1.0 M triangles) / cloud deck / far blur / glow | 0.6 / 0.6 / 0.5 / 0.3 ms |
| At 1080p: cliffs and rocks; water, falls, foam, mist | under 0.1 ms; under 0.3 ms |
| Empty viewport with sky and post effects | nothing measurable |
| Draw calls and triangles per render, `whole` view | 274 and about 853,000 (`data/ablate_k3_1920x1080.json`) |
| Wallpaper mode, 720p at 30 FPS | 38 to 42% of one core; about 19 points are the water solver |
| Edit, release to published terrain | 660 to 990 ms, then a 0.55 s transition (`CURRENT_CONTEXT.md`, 2026-11-10 and 11-11) |

The gate resolution is the Mac's own screen, 3024x1964 (5.9 M pixels). Godot at the freeze, measured there on 2026-11-22 with `tools/perf/bench_presets.gd` on mains power (`art/lookdev/20261122_freeze/`):

| Tier | whole | game | reverse |
| --- | --- | --- | --- |
| native | 30.6 ms | 38.4 ms | 29.3 ms |
| default | 23.7 ms | 29.4 ms | 22.4 ms |
| light | 14.6 ms | 18.9 ms | 13.7 ms |

Against 16.7 ms for 60 FPS, the default tier misses on every view (34 to 45 FPS) and the light tier holds two views and misses the closer play view (53 FPS). That is with one island about a sixth of the size the owner now asks each island to be designed for, and no other island in view. These are single-viewport runs; every figure is above the 12.3 ms at which an idle window presents on this Mac, so none is clipped by that ceiling.

### 1.3 Facts about the tree that shape the design

- Terrain is a sparse grid of 1 m cells with heights in 0.5 m steps and 8 m chunks; the default island has 623 cells (`terrain_data.gd`).
- The key light barely moves. Across the four day keyframes the sun's azimuth stays between 28 and 42 degrees and its elevation between 22 and 28 degrees; what changes through the day is colour and strength (`time_solar_system.gd`). A day is 240 s today and becomes about 12 minutes.
- Walking, picking and placement read the cell grid, not render meshes. There is no physics engine in the island scene.
- The part-one production loop exists as a node-free simulation with save and load, where one long tick equals many short ones (`scripts/gameplay/base/base_sim.gd`, 39 checks in `tests/base_supply_loop_test.gd`). It is not wired into the scene.
- The reverse-wall study measured why the cliffs read as a palisade: every outer slab stands 0.66 to 0.89 m in front of the contour, slab widths follow near-equal chords of the rim (4.7 to 6.3 m in a row), slab feet end independently between 4.9 and 7.1 m down, and whether a run may carry a rock group was decided by gates tuned to one island (`art/lookdev/20261121_reverse_stagger/README.md`, `20261121_cliff_water/README.md`). These are properties of the generator's structure, which is why it is rewritten and not ported.
- No current lookdev pass is art-accepted. Today's picture is a fair baseline to beat.

## 2. Architecture: one runtime, swappable layers

### 2.1 Shape

```
                         +-------------------------------------------+
   host shells           |  desktop shell (macOS first, then Windows)|
   (one per platform     |  window, wallpaper attach, occlusion,     |
    concern)             |  power state, frame pacing, raw input     |
                         +----------------------+--------------------+
                                                |        headless shell (no window:
                                                |        tests, soak runs, catch-up)
                         +----------------------v--------------------+
   shared runtime        |  CORE                                     |
   (one, specified now)  |  save - settings - items and warehouse    |
                         |  ledger - cultivator - progression, quota |
                         |  run ledger - input intents - camera rig  |
                         |  sim clock - commands - events            |
                         |  scene director and layer contract        |
                         +------+----------------+-------------+-----+
                                |                |             |
   scene layers          +------v-----+   +------v-----+  +----v-------+
   (replaceable)         | SEA        |   | VILLAGE    |  | OUTING     |
                         | slice one  |   | later      |  | later      |
                         | islands,   |   | authored   |  | map recipe,|
                         | generation,|   | scene data,|  | loot,      |
                         | editing,   |   | NPCs,      |  | combat     |
                         | water,     |   | interiors  |  |            |
                         | production |   |            |  |            |
                         +------+-----+   +------+-----+  +----+-------+
                                |                |             |
   render layers         +------v-----+   +------v-----+  +----v-------+
   (one per scene        | Sea        |   | Village    |  | Outing     |
    layer, different     | renderer   |   | renderer   |  | renderer   |
    techniques allowed)  +------+-----+   +------+-----+  +----+-------+
                                |                |             |
                         +------v----------------v-------------v-----+
   render kit (shared)   |  GPU device, frame graph, palette and     |
                         |  atmosphere shading, skeletal animation,  |
                         |  text and HUD, capture and bench tools    |
                         +-------------------------------------------+
```

Dependency rules, enforced by the build:

- Core depends on nothing above it: no GPU, no window, no audio, no wall clock inside a simulation step. It builds and runs in the headless shell on any machine.
- A scene layer depends on core. Its simulation half never touches the render kit. Its renderer depends on the render kit and reads the layer's state; it never writes it.
- Scene layers never depend on each other. Anything two layers both need goes through core.
- Only host shells know about the operating system.

This is one runtime, not three engines: one process, one save file, one item catalogue, one character, one input map, one frame loop. What differs per scene is data, rules and drawing technique.

### 2.2 What "purpose-built" means here

The runtime has no scene editor, no scripting language, no general material system, no general light types, no physics engine in core and no plugin system. Rules are code plus data tables. Tools are command-line programs and in-game debug views. It uses ordinary libraries for what is not special to this game (a windowing library, a GPU abstraction, image and model decoding, font shaping); the purpose-built parts are the simulation, the scene layers, the generator and the renderers.

Implementation stack (owner: keep the plan's default): Rust; wgpu for graphics (Metal on macOS, Direct3D 12 on Windows, Vulkan as a fallback); winit for windows and input, with small native shims for wallpaper attachment. Reasons: one code base for both systems; the Sea renderer needs only ordinary features (render to texture, depth, instancing); a strict compiler suits a code base written mostly by agents; the simulation can be tested on any machine with one command. Tiny Glade's own renderer is written directly on Vulkan and reportedly uses features outside that common set; this design avoids needing them. What would change the choice is in section 7.

Proposed location when work starts (not created now): a `runtime/` folder at the repository root holding one workspace, with a `.gdignore` file so Godot does not import it. Working names: `core`, `render_kit`, `layer_sea`, `layer_village`, `layer_outing`, `shell_desktop`, `shell_headless`.

### 2.3 Shared runtime interfaces

Names and shapes below are the contract. Exact field types are settled in the core phase; the names and the direction of each dependency are not meant to change. Notation is Rust-like and reads as pseudocode.

**Save data and settings**

```
Profile {                         // one player's whole persistent state, one file
    meta:        SaveMeta,        // format version, last wall-clock time, total simulated seconds
    character:   CultivatorRecord,
    warehouse:   Stock,           // the shared storehouse, the same in every scene
    progression: ProgressionRecord,
    run:         Option<RunRecord>,          // an outing in flight, with its escrowed loadout
    scenes:      Map<SceneId, SceneSection>, // "sea", later "village", "outing"; private to each layer
    journal:     TransferJournal, // append-only record of every cross-container transfer
}
trait SaveSection { id(); version(); save() -> bytes; load(bytes, version); migrate(from_version, bytes) }

Settings {                        // per machine, separate from the save
    wallpaper: { when_covered: StopFrames | KeepDrawing,  // default StopFrames; simulation runs either way
                 ambient_fps, wind },
    display, input bindings, language, ...
}
```

- Every section carries its own version and migration, so a layer can change its data without touching the others.
- Writes are atomic (write beside, flush, rename) with rolling backups. Autosave on scene exit, on outing settlement, on a timer, and when the host is about to suspend.
- On launch after a full close, `SimClock.catch_up` advances the simulation by the elapsed wall-clock time, capped at 12 real hours (60 game days at a 12-minute day).
- A one-way importer reads the cells of today's Godot layout file (`user://terrain_editor/layout.json`, terrain versions 1 to 4) into an island of the `sea` section. Godot's files are never modified. Authored water levels in old layouts are not imported (3.8).

**Items, inventory and resources**

```
ItemId            // stable text key: qi, water, grain, herb, ore, ration, pill_heal, pill_fast, blade
ItemDef { id, name_zh, kind: Bulk | Discrete | Gear, tags, stack_limit, prosperity, icon }
Amount            // whole thousandths, no floating point, so long ticks and both platforms agree
Stock             // ItemId -> Amount, optional capacity; used for the warehouse, facility buffers,
                  // the cultivator's pack, an outing loadout and an outing loot bag
Ledger            // the only way items move between Stocks
    transfer(from, to, item, amount) -> Result
    reserve(from, items) -> Escrow;  commit(Escrow, to);  release(Escrow)
Recipe   { id, station, needs: Stock, makes: Stock, seconds, staffed }
LootTable { id, rolls, entries: [(ItemId, weight, amount_range, conditions)] }
Catalog           // all ItemDef, Recipe, LootTable and facility definitions, loaded from data files
```

- No layer writes the warehouse directly. Everything is a ledger transfer, and every transfer across a scene boundary is journaled. That is what lets the village's shops and the outing's loot use the same warehouse safely.
- Today's `base_catalog.gd` (goods, recipes, facilities, the outing kit) becomes data files in this catalogue.

**The cultivator's realm and progression**

```
CultivatorRecord { realm, cultivation, body: { food, drink, fasting_left, nourished_left },
                   equipment: Slots<ItemId>, known_recipes, activity, ... }
ProgressionRecord { unlocks, discoveries, prosperity_snapshot, islands_founded }
QuotaRule          // data: land_quota(realm, cultivation); cost of founding the n-th island
Modifiers          // typed bonuses with a named source
trait ProgressionSink { set_modifier(source, key, value); grant(unlock); add_cultivation(amount) }
trait CharacterView   { stats() -> WorkStats; combat() -> CombatStats; realm() -> RealmInfo;
                        land_quota() -> cells }
RealmTable         // data: today's five realms from realm_progression.gd, re-tuned and extended by data
```

- Land is limited by cultivation and realm only. `land_quota` is derived, never bought with fishing or credits. The cells of all islands plus the founding charges must fit inside it; founding another island costs more quota than its first cells. Each island is capped at 4,096 cells.
- Scene layers publish what they contribute (the Sea publishes prosperity, formations and decoration bonuses) and read derived stats. They never compute each other's numbers. That is how prosperity on an island becomes combat power on an outing without the outing knowing about facilities.
- Hunger and thirst only lower efficiency (floor at half speed today); a fasting pill suspends both. This lives in core because the same cultivator, with the same body state, walks into the village and the outing.
- The simulation knows the cultivator's `activity` (walking, carrying, tending, crafting, cultivating, eating). Which animation clip plays is the renderer's business.

**Input and camera**

```
Intent    // device-independent: PointerMove, Primary, Secondary, Scroll, Pan, Orbit, Zoom,
          // Confirm, Cancel, Undo, Redo, ToggleWallpaper, Hotbar(n),
          // and Move(axis), Aim(axis), Fire, Dodge (declared now, unbound until the outing)
InputMap  // raw device input -> Intent; rebindable; mouse, keyboard, touchpad gestures, gamepad
InputContext stack: HUD > active tool > scene commands > camera   // each layer registers its own
trait CameraRig { update(intents, dt); view() -> CameraView; at_rest() -> bool; frame(bounds) }
trait Picker    { pick(ray) -> Option<PickHit> }
```

- The simulation never reads a device. Controller code turns intents into commands (below).
- `at_rest()` is part of the contract because the Sea renderer's still-camera cache depends on it.
- Each layer supplies its own rig: an orbit rig for the Sea (today's orbit, pan and zoom), a still preset rig for the wallpaper (no drift), and whatever the village and the outing need later.
- In wallpaper mode no input context is active: it is watch-only.

**Headless simulation**

```
trait Simulation {
    step(dt_fixed, ctx)                  // fixed steps only; no rendering, no devices, no wall clock
    apply(Command) -> CommandResult      // the only way anything outside changes the world
    next_event_time() -> Option<SimTime> // lets an idle host sleep until something happens
}
SimClock   { advance(wall_dt); catch_up(elapsed, cap) }   // frames and simulation steps are independent
Command    // serialisable. Sea: Place, Remove, LayConduit, LiftConduit, SetRecipe, Order(haul |
           // harvest | craft | cultivate | take_pill), ClearOrders, Click(target),
           // TerrainStroke / CommitBlueprint, Undo, Redo, FoundIsland, SetIslandHeight, MoveSpring, Depart(loadout)
SimEvent   // one-way notes for presentation: Harvested, Crafted, OrderBlocked, FacilityChanged,
           // TerrainChanged(island, cells), WaterChanged(island, basins), Breakthrough ...
```

- Presentation subscribes to events and reads a snapshot after each step. With no window, nothing subscribes and the same simulation runs unchanged. This is the mechanism behind "production keeps running with no frame at all".
- `catch_up` must give the same result as the same time in small steps, within a stated tolerance, and a test holds it to that. `base_sim` already has this property and its test moves over with it.
- Same seed and same commands must give the same save on Windows and macOS. Commands are logged, so a session can be replayed in a test.

**Scene layer contract and scene director**

```
trait SceneLayer {
    id() -> SceneId
    enter(profile, EntryTicket) -> Result      // read character, warehouse, progression
    exit(profile) -> ExitTicket                // settle everything through the Ledger
    simulation() -> &mut dyn Simulation
    save_section() / load_section()
    input_contexts(); camera() -> &mut dyn CameraRig; picker() -> &dyn Picker
    background_policy() -> KeepSimulating | Pause   // the Sea keeps producing when not shown
}
trait SceneRenderer {                          // lives with the layer, outside core
    prepare(snapshot, events, camera_view, present_mode)
    render(frame)                              // built from render-kit parts, technique is its own
    invalidate(region)
}
SceneDirector { travel(to: SceneId, ticket) }  // exit, autosave, enter; one scene presented at a time
```

**Outings (loadout out, loot back, settled on exit)**

```
RunRecord  { state: InProgress | Settling, loadout: Escrow, loot: Stock, map_recipe, seed }
RunLedger  { begin(loadout) -> RunRecord       // moves the loadout from the warehouse into escrow, saves
             settle(outcome: Extracted | Died | Abandoned, rules: OutcomeRule) } // idempotent, journaled
OutcomeRule // data: what returns and what is lost for each outcome
```

**Host shell**

```
trait HostShell {
    present_mode() -> Interactive | Ambient | Occluded   // from focus, recent input, occlusion, display state
    power() -> PowerState                                 // mains, battery, saver, thermal pressure
    attach_wallpaper(display) / detach_wallpaper()
    surface(); poll_input(); wake_at(deadline)
}
```

### 2.4 Who uses which interface

| Interface | Sea of Consciousness (slice one) | Village (later) | Extraction map (later) |
| --- | --- | --- | --- |
| `Profile`, `SaveSection` | section `sea`: a list of islands, each with position, height, cells, sources, facilities, conduits, placements; the hour | section `village`: its own scene state | section `outing`: unlocked recipes and seeds only |
| `Settings` | wallpaper behaviour, wind, display | display, input | display, input |
| `Catalog`, `ItemDef`, `Recipe` | production recipes and facilities | shops and crafting use the same definitions | consumables and gear are the same items |
| `Stock`, `Ledger` | warehouse, facility buffers, pack | same warehouse; shop counters are ledger counterparties | loadout escrow and loot bag |
| `LootTable` | fishing, when it is added | optional: rewards | loot, data-driven per map recipe |
| `CultivatorRecord`, `CharacterView` | the worker being commanded; land quota | the same character walking the village | the same character fighting; reads `CombatStats` |
| `ProgressionSink`, `Modifiers`, `QuotaRule` | publishes prosperity, formation and decoration bonuses; spends quota on cells and islands | publishes whatever the village grants | publishes experience and discoveries at settlement |
| `Intent`, `InputMap`, `InputContext` | sculpt tool, orders, mouse worker, orbit camera | its own contexts | `Move`, `Aim`, `Fire`, `Dodge` |
| `CameraRig`, `Picker` | orbit rig, still preset rig; cell and facility picking | its own rig and picker | its own rig and picker |
| `Simulation`, `Command`, `SimEvent` | production, cultivator, water, terrain edits; keeps running in the background | its own; paused when not shown | its own at a higher step rate; not run in the background |
| `RunLedger` | `Depart` starts a run from the realm gate | not used | owns the run; `settle` on exit |
| `SceneLayer`, `SceneRenderer` | first implementation | second | third |
| Render kit: skeletal animation | one cultivator | many characters | player and enemies |
| `HostShell` | all present modes including wallpaper | interactive only | interactive only |

### 2.5 How the village joins

1. Add `layer_village`, implementing `SceneLayer` with id `village`, and a `SceneRenderer` for it.
2. It receives the same `Profile`: the same `CultivatorRecord` and the same `warehouse`. It moves goods only through the `Ledger`, and reports gains through `ProgressionSink`.
3. It brings its own scene data (authored or placed buildings, interiors, people and their schedules), its own navigation and spatial queries for many characters, and its own save section. It does not use the island terrain data, the terrain editor, the island generator, the water model or the Sea renderer's island caches.
4. Its renderer may use different techniques (static building batches, room and door visibility for interiors, instanced animated characters, local lights for lanterns indoors). From the render kit it reuses the device, the frame graph, the palette and atmosphere shading module, skeletal animation, text and HUD, and the capture and bench tools, so it stays in the same visual family and under the same measurements.
5. Travel is `SceneDirector.travel("village", ticket)`: the Sea exits and saves, the village enters. The Sea's `background_policy` decides whether the base keeps producing meanwhile.
6. Nothing in core changes to make this possible. If core has to change, it is a contract failure to be fixed in core for every layer, not worked around in the village.

### 2.6 How the extraction map joins

1. Add `layer_outing`, implementing `SceneLayer` with id `outing`, and its renderer.
2. Leaving: the Sea's realm gate issues `Command::Depart(loadout)`. Core calls `RunLedger.begin`, which moves the loadout out of the warehouse into escrow and saves at once. Today's `depart()` in `base_sim.gd`, which simply deducts the kit, becomes this call.
3. The map: a `map_recipe` (data: tile kit, size, layout grammar, enemy tables, `LootTable` ids, exits) plus a seed produces the map. Recipes and loot tables are data files; adding a map type is data, not code.
4. During the run, pickups go into `RunRecord.loot` and consumables come out of the escrowed loadout. The warehouse is not touched.
5. Coming back: on exit the layer reports an outcome and core calls `RunLedger.settle`. `Extracted` returns what is left of the loadout plus the loot to the warehouse and reports experience through `ProgressionSink`. `Died` and `Abandoned` follow the `OutcomeRule` table. Settlement is idempotent and journaled: a crash between leaving the map and settling is completed on the next launch.
6. Fighting strength comes from `CharacterView.combat()`, which core derives from the cultivator, the gear and the modifiers the Sea published. The outing never reads facilities.
7. Its renderer is its own and is built for fast map generation and stable combat frame times (pre-batched tile kits, pooled moving things, a fixed frame budget, nothing that waits on a bake). It may reuse the palette and atmosphere module and the animation module.
8. Its input uses the `Move`, `Aim`, `Fire` and `Dodge` intents already declared in core.

Neither layer is built in the first slice. What the first slice does include is a contract test: two stub layers of about a hundred lines each (a fake village that enters, trades one item with the warehouse and exits; a fake outing that begins a run, adds loot, and settles each outcome). They exist only as tests and prove the interfaces above before any real second scene depends on them.

### 2.7 The gameplay lock, mapped onto the runtime

| Locked design | Where it lives |
| --- | --- |
| Command the cultivator like an RTS unit | `Command::Order` queue in the Sea simulation; selection and orders are an input context; walking uses a path over the cell grid (new: today's walk is a straight line) |
| The mouse is an independent worker | `Command::Click(target)`, one unit of work with a cooldown, as in `base_sim.click`; not available while hung as a wallpaper |
| Food and water, never death, fasting pill | `CultivatorRecord.body` in core; efficiency floor is data |
| Spirit spring makes qi all the time | a source facility, and also an unlimited water outlet (3.8) |
| Qi planted into crops; ore seedlings | unstaffed recipes with growth states the renderer shows as planted, growing, ripe |
| Crafting gear and outing consumables | staffed recipes; the outing kit is a loadout template in data |
| Conduits carry qi; shapes wake formations | conduit network in the Sea simulation; formation shapes are a data table (today: a closed ring gives 1.25x) |
| Prosperity and decorations become bonuses and combat power | published through `ProgressionSink`; derived in core |
| Supply pipeline for the first outing | slice one ends at `Depart`: the kit is escrowed in a `RunRecord`; a stub settles it |
| Island size | gated by `land_quota` from cultivation and realm; 4,096 cells per island; `FoundIsland` spends extra quota. Islands are staggered in space, the player sets each one's height (`SetIslandHeight`), and several are on screen at once. The cultivator crosses between islands by flight, taking time by distance **(agent's call)** |
| Fishing | a production station with a `LootTable` roll, or a minigame, in the home world; unrelated to island size; not in slice one |
| Village and extraction map are later scenes | sections 2.5 and 2.6; not in slice one |

The older `scripts/gameplay/` director, fishing and meditation code is not ported. The realm table moves over as data and is re-tuned so that a full island is reachable.

## 3. The Sea of Consciousness layer

### 3.1 Art goal

The owner asked the agent to set and pursue the art goal. This is it; it is the yardstick for every look decision below and for the agent's own review before anything is shown.

**The picture:** a quiet blue-green island in the gongbi manner: sure, fine outline and flat mineral washes on soft, clear forms, standing in mist that is left as empty paper. Sharp where the eye rests, calm where the desktop needs room.

Four properties, each with something that can be checked on a frame. The numbers are the agent's starting targets and are tuned by eye; they are not owner thresholds.

1. **Comfortable all day.** Large areas stay in a middle band of brightness; nothing large sits near white or black, by day or by night. Night is moonlit mid-tones, not a dark screen. At least a third of a wallpaper view is quiet (mist, sky, water) so icons and windows sit on it legibly. Motion is slow and sparse: with a still camera every static pixel is identical from frame to frame, nothing shimmers or sparkles, and the day turns over 12 minutes without a visible step. Checks: brightness histogram by keyframe, quiet-area share, frame-to-frame difference of static pixels equal to zero.
2. **Easy colour.** The palette on record stays: warm mist, olive and moss green, soft grey-beige stone, jade water. Each hour uses three colour families and at most one small accent (lantern, seal red, blossom). Lit sides are warm, shadows are cool and low in saturation. Colour is managed for the display, so the wide-gamut Mac panel does not push it. Checks: saturation ceiling per family, accent share of the frame, the same frame compared on sRGB and on the Mac's display.
3. **Classical Chinese atmosphere.** Depth is carried by layers, near crisp, a mist band, far mountains as pale washes; the island root dissolves into reserved paper. Forms are drawn, not only lit: a warm dark-grey line (never black) that is heavier on silhouettes than on inner creases, over flat washes. Cliff faces carry sparse texture strokes that follow their structure, in the manner of axe-cut strokes on hard rock. Foliage is masses and dabs with the silhouettes of the genre (pine, willow, bamboo). Check: the agent's review against a board of open-access Song blue-green and gongbi landscape paintings and the game references already listed in `art/reference/`, with sources recorded as today.
4. **Naturally sharp, not muddy.** Silhouettes are crisp at the screen's native resolution. There is no depth-of-field blur, no glow haze and no global fog veil over the island: distance is shown by paler value and cooler hue in placed mist layers, not by blur. Neighbouring masses (lawn, stone, foliage, water) keep a clear value step so the picture never collapses into grey-green. Detail lives at two scales only, large brush planes and fine line, with no mid-frequency noise. Stylisation adds line and grain and never smears: no blur-based or smearing painterly filter touches the final image. Checks: edge contrast along silhouettes against the Godot baseline, value step between neighbouring masses, no blur pass in the frame.

The hand-painted quality the owner wants tried is pursued as three directions in the look spike, on the same geometry and cameras: A, the new lighting model with no line (the clean reference); B, gongbi line and flat wash (the expected choice); C, B with visible brushwork in the washes and dry-brush edges. The agent picks by the four properties, shows the three, and continues on its pick unless the owner redirects. Outcome at G1: B, line and flat wash on a warm silk-paper ground; C's sparse dry strokes on rock are kept as an accent to decide on real surfaces. Today's Godot picture is the baseline in every comparison.

### 3.2 Principle of the renderer

An island is a small diorama the player tends and then hangs on the desktop. Between edits almost everything in view is still: stone, ground, trees, buildings, their shadows and their light. So the renderer pays for the island when it changes and keeps the result. The frame is spent on water, falls, mist, clouds, and a little life: the cultivator, production feedback, a passing gust, drifting motes.

This is not today's frame moved to a new engine. The measured cost of today's frame is per-frame techniques from a general shading stack. Section 3.5 replaces them with a model in which most of those terms are baked, and section 8 lists what must not be ported.

### 3.3 What is static, what is live, and wind

| Static (baked, cached) | Live (drawn every frame) |
| --- | --- |
| Ground, lawn, paths, pond beds | Pond surfaces, ribbons, foam |
| Cliff body, rock groups, island root | Falls and their spray |
| Tree trunks and crowns, bushes, grass, between gusts | Root mist and veil drift, cloud sea, far clouds |
| Buildings, facilities, conduits, decorations | The cultivator (skinned) and what it carries |
| Sun shadows, sky occlusion, bounce light | Production feedback: glows, growth pops, order markers |
| Far mountains (as a panorama) | Motes, petals, the brush and blueprint preview, HUD |

One rule keeps this from being rigid: **static until it animates.** A chunk or object that is changing (an edit growing into place, grass fading under rising water, a crop changing stage, foliage in a gust) is drawn live while it changes and returns to the cache when it settles.

**Wind** is a presentation system with a seeded schedule, not part of the simulation. A gust is a front that crosses the island. Foliage inside the front sways; foliage outside it rests. Gusts are scheduled a little ahead, so before one arrives the still cache is rebuilt without the foliage it will touch, sliced over a few frames; during the gust that foliage is drawn live; it eases back to its exact rest pose, and the full cache takes over again with no visible change. In wallpaper mode the schedule is sparse (little wind, by owner decision) and the cost exists only while a gust is passing. While the camera moves, foliage is drawn directly anyway and can sway whenever wind passes. Shadows of swaying foliage stay still in the first version.

The cultivator is a free, skinned model animated from clips (idle, walk, carry, tend, craft, sit and cultivate, eat and drink), with sockets for held props. It is always live, shaded and outlined by the same model as the island so it sits in the picture, and it has a small contact shadow of its own.

### 3.4 Three caches

**A. Island bake (world space; survives any camera move).** Per chunk and per object, rebuilt only for what an edit touched:

- merged static meshes with few materials (aim: tens of draw calls for a default-size island, against 274 today);
- baked sky occlusion and bent normal, replacing SSAO and the sky ambient lookup;
- baked bounce tint between ground, stone and foliage, replacing SSIL;
- baked surface painting: the washes, texture strokes and lawn treatment are composed into per-surface texture pages when the surface is built, so runtime texture taps per pixel no longer grow with how rich the painting is;
- baked lantern and local-light reach, one scalar per surface point, coloured at resolve time.

Sizes are planned for 4,096 cells per island, about six and a half times the default island. Every island has its own bake.

**B. Light caches (world space; refreshed when the light direction or the island changes).**

- One static shadow map per island. An island is small enough that a single map covers it at centimetre-scale texels; there are no cascades and nothing is re-rendered per frame. It is re-rendered when an edit lands or when the sun's direction has drifted past a small threshold, which a 12-minute day and the narrow sun keyframes make rare.
- The far mountains become a panorama layer rendered once per light step instead of a million triangles per frame. The camera stays close to the island, so the mountains show almost no parallax.

**C. Still cache (screen space; valid while the camera rests).**

- When `CameraRig.at_rest()` holds, the static island is rendered into screen-sized textures that hold time-independent shading terms: surface colour, sun term (facing and shadow), sky term, bounce, mist depth, line weight, and scene depth. They are accumulated over several slightly shifted frames, which should give cleaner edges than 2x MSAA at no steady cost (to be confirmed by eye in phase 1) and is where the "naturally sharp" property is won.
- Each frame, one full-screen resolve turns the terms into colour using the palette of the current hour (3.5), then the live layers are drawn against the cached depth. The day cycle therefore never forces the island to be redrawn; only a drift of the sun's direction, a gust or an island change does, and those refreshes are sliced across frames.
- Water reads the cache for refraction, depth tint and reflection, as it reads the screen today.
- The wallpaper camera never drifts, so in wallpaper mode this cache is valid except during gusts and light steps.
- The cache holds the whole view, however many islands are in it. Several islands cost more only on the Moving path, where each is drawn from its own bake with detail thinned by distance.

The moving-camera path uses caches A and B only and computes the same terms, the same line and the same resolve directly, so the picture does not change character when the camera stops; it only sharpens as the still cache accumulates.

### 3.5 Lighting, materials and foliage as one model

- **Light is a palette, not energy.** Each material family (stone, ground, leaf, timber and tile, water) has lit, half and shadow colours per day keyframe. The existing keyframes already carry such colours per family (`stone_shadow`, `leaf_shadow`, `decor_shadow`). Shading picks along the family's ramp from the baked and cached terms. Shadow colour is chosen, never computed. There is no specular model except for water and a few wet or jade accents.
- **Atmosphere is a first-class term.** One shared function of height, view distance and hour gives the mist: explicit layers with authored density, the island root dissolving into the cloud sea, far things paler and cooler. Every material passes through it. It replaces generic fog, glow-as-haze and the far blur, none of which survive (3.1, property 4).
- **Line.** Outline and inner line come from depth, normal and material breaks, with weight by importance, in a warm dark grey. The line is computed in both frame paths so it does not appear or vanish when the camera stops; when still it is refined by accumulation.
- **Stone is washed and stroked, not noisy.** Flat mineral washes, broad brush planes and a few texture strokes aligned to each face and to gravity, built on the hand-painted washes already in the tree (`gouache_stone_sol61`, `gouache_stone_wash`) and composed at bake time per face. The generator supplies the face frames (3.7), so strokes follow structure. Being baked, the treatment can be much richer than today's ten taps per pixel at no per-frame cost.
- **Foliage is masses and dabs.** A crown is a few opaque clump shapes with soft, rounded shading normals, plus a small ring of painted leaf dabs at the silhouette only. This removes the layered-card overdraw that costs 2.0 ms at 1080p today, and gives crowns a shape that can sway as a whole in a gust. The lawn is mainly a painted surface with soft pile shading; real tufts stand where they read: along lips, shores, paths and silhouettes. This replaces 1.3 M blade triangles. Whether a painted lawn reads as well as today's blades is an art risk judged in the look spike, not assumed.
- **Water stays live and jade.** Ponds, falls, foam and mist are already nearly free and are drawn every frame. Their intent carries over (glassy lip, ropes, fraying sheet, sky sheen); they are re-authored against the palette, the atmosphere function, the still cache and the new water model rather than copied.
- **Paint-range, managed colour.** Shading works in a display-referred range with one gentle curve at the end and fine dither, which also serves as paper grain. Output is tagged for the display's colour space. This avoids wide floating-point targets and keeps colour as designed on a wide-gamut panel.
- **One look on every machine.** Quality settings change sharpness (number of accumulated samples, bake resolution and how long a bake takes), not the lighting model. This is the opposite of today's light tier, which is cheaper because it removes SSAO and SSIL and so is flatter.

### 3.6 Frame paths and design budgets

| Path | When | Each frame does |
| --- | --- | --- |
| Still | camera at rest: wallpaper, idle, watching | resolve the still cache; draw live layers |
| Moving | orbit, pan, zoom | draw the island from caches A and B; line; resolve; draw live layers |
| Editing | sculpt stance with recent input | as Moving; affected chunks are live until they settle |
| No frame | covered, display off, session locked (default setting) | nothing is drawn or presented; simulation only |

The first gate is the Mac's own screen at its native resolution, 3024x1964, at 60 FPS on the M4 Pro, with dynamic resolution off. The bench scene is a full 4,096-cell built-up island in focus with two more islands on screen at other heights **(agent's call; the owner's decisions are 4,096 cells per island and several islands on screen)**. Design budgets for that gate, to be tested in phase 1; they are targets for the design, not measurements:

- Moving path at 3024x1964: at most 12 ms, leaving headroom under 16.7 ms.
- Still path at 3024x1964: at most 4 ms.
- If phase 1 shows the Moving path cannot reach 60 FPS at native resolution, the owner's fallback applies: the Moving path renders at 1920x1080 and must hold 120 FPS (design budget 6 ms). The still cache keeps accumulating at native resolution either way, so the resting picture and the wallpaper stay native.

Measured in spike S2 on 2026-11-22 (stand-in scene, off screen, M4 Pro): Moving 1.59 to 1.86 ms and Still 0.48 to 0.55 ms at 3024x1964; Moving 3.8 to 4.1 ms at four times the pixels. The structure is six to nine times inside its budget, so the fallback is not expected to be needed, and the margin goes to the picture: supersampled edges and line while moving, richer baked surfaces, and real tufts where they read. The final picture will cost more than the stand-in in every pass; the gate is still measured on the real slice.

One thing the gate has to be honest about: the Mac's display is set to a scaled mode (1800x1169 points, 3600x2338 backing pixels, on the 3024x1964 panel, at 120 Hz). A full-screen window is asked to fill 3600x2338 pixels, which the system then scales to the panel. The gate is measured at 3024x1964 as the owner said, and 3600x2338 is reported beside it (S2: 1.9 to 2.2 ms Moving). Rendering at the backing size and letting the system scale down once is the sharper choice and is the default while it fits **(agent's call)**.

### 3.7 Island generation: rewritten, form first

The owner's decision is not to port the current generator. The measured causes of the palisade (1.3) are structural: faces hung at a constant distance in front of the contour, widths taken from rim chords, feet that end independently, gates tuned to one island, and separate shells whose joins had to be repaired case by case across about 14,000 lines. The new generator is designed with the renderer and for the art goal.

**Starting points, not locks.** The sparse cell grid (1 m cells, 0.5 m height steps), terraces and the stroke model are kept because live editing, walking and placement are built on them and they work; the cells stay the authority for where land is. Trees, rocks and props stay independently editable. Any of this may change if a better island needs it.

**Requirements** (the agent's, drawn from the owner's form notes of 2026-11-21 as reference, plus editing):

- organised main-face width and depth, with a primary and a secondary face; natural local protrusions;
- wide verticals, local side protrusions, reverse slopes and a downward inward taper are allowed;
- a blunt, connected lower body; no separate feet, no stepped skirting;
- no guard wall, no pillar arrays, no uniform expansion of the cliff ring; never one rock mesh for the whole island;
- closed from every camera pitch, including from below;
- every decision is local, so an edit changes only its neighbourhood (today's bound is 10.5 m; the new design states and tests its own);
- sealed joins at falls, terraces and the lawn lip by construction, not by repair passes;
- cost that depends on the size of the stroke, not the size of the island, up to 4,096 cells;
- it emits what the bake needs: face frames for strokes, material families, and a per-face importance for line weight.

**Direction.** The island is built as one designed body, not a row of parts: a plan stage that turns the rim into a few long gestures with deliberate primary and secondary rhythm at two scales; a section stage that gives each face a profile and draws the body inward to a connected root; a mass stage that cuts faces and protrusions out of a continuous body, so faces are hard and planar where wanted and everything is welded; a top stage where lawn lip, bare crowns and terrace steps meet the body by construction; then dressing (rock groups, planting, tufts) by composition rules.

**How the approach is chosen.** Spike S4 prototypes two or three constructions on the four review layouts and a 4,096-cell island: a planar-cut body, an implicit body with sharp-feature meshing, and a rim grammar placing an authored kit of multi-face groups. They are judged on pictures in the spike renderer and on the tests below. The agent picks and shows the comparison. Outcome at G1: the hanging-rock body on a liner was chosen over the plain hull; `art/lookdev/20261122_g1/README.md` has its numbers and its known defects.

**Tests that replace parity with Godot.** A form metric per layout (the longest run of flush, like-width faces, from the reverse-wall study's plan metric; spread of face width and depth; foot continuity); closedness from below; locality under scripted edits; seals at falls and terraces; determinism; cold generation time for 4,096 cells and time per stroke.

A rewrite makes better form possible, not certain. It is judged by pictures at the phase 1 checkpoint and at acceptance.

**More islands.** The `sea` section holds a list of islands, each with its own cells, position, height, bake and shadow map. Islands are staggered in space, not lined up; the player sets each island's height; several are on screen at once in play and in the wallpaper (owner decision). On the Moving path every island in view is drawn from its own bake, with detail thinned by distance, because staggered islands shift against each other as the camera moves; on the Still path they are all in the one cache. Slice one includes founding a second island and setting island heights, so the picture and the bench have several islands; the production loop itself needs only the first. Because a higher island is seen from below and from the side by a lower one, the generator must make each island's underside and root read well from those angles too.

### 3.8 Water: source-driven flow

The finite-volume solver is not ported. The owner's model replaces it:

- A **source** is a spirit spring: an unlimited outlet at a cell. Without a source reaching it, a basin stays dry; ponds cannot form by themselves and are no longer painted with a water tool.
- A **basin** is the set of cells water can fill before it spills, found from the height grid around each source; its **sill** is the lowest point of its rim. A basin fed by a source fills towards its sill at a set pace, then flows over its outlets into the next basin or off the island as an outer fall. While there is input, output continues.
- When input stops (the spring is removed, or an edit cuts the path), output continues for a set delay and fades; the level settles at the height that does not leak, which is the sill, and the pond stands.
- An edit recomputes the basins it touches. If a sill was lowered, the level falls to the new sill, with a short surge through the gap; if a basin lost its floor or wall, it runs dry.
- Nothing is conserved and no volume is stored. A basin's state is its level, whether it is flowing, and its timers. At steady state the model does no work at all; today's solver never sleeps and is about half of the wallpaper's processor time.

Presentation takes fall width and strength from the outlet and the sources upstream, and grass fades and recovers as levels change, as today. A new game's first island starts with one spirit spring, so the first picture has a pond and a fall and qi production can begin. Moving or removing that spring is a tested case (owner request): the falls it fed fade after the delay, each pond settles at its sill and stands, wet banks and grass follow, and a spring placed elsewhere fills its own basin from dry. The picture must stay coherent through every step of that. For comparison frames, an imported Godot layout gets a spring at its highest former pond.

### 3.9 The wallpaper path

Present modes come from the host shell and drive both renderer and simulation:

| Mode | Trigger | Frames | Simulation |
| --- | --- | --- | --- |
| Interactive | focused, input within about two seconds | up to the display rate | every step |
| Ambient | hung or idle, visible, no input | 30 a second, lower on battery or under thermal pressure by policy; Still path | every step, cheaply |
| Occluded | fully covered, display off, session locked | by setting: none (default), or keep drawing as Ambient | coarse steps, or sleep until `next_event_time()`, in both settings |
| Launch after a full close | n/a | n/a | `catch_up(elapsed)`, capped at 12 real hours (60 game days) |

- Hung as a wallpaper the game is watch-only, on a still camera view the player chose. Production, hunger, cultivation, conduits and water continue as the headless simulation, with or without frames.
- macOS (first gate): a window at the desktop level on all Spaces, behind the icons, ignoring the mouse; the window's occlusion state decides Occluded; display sleep and Low Power Mode feed the power policy. Spike S1 confirmed the attach, the window order and the occlusion signal. It also showed that macOS hands a covered window no drawable, so on macOS the "keep drawing" setting can only keep the renderer's own off-screen work going; nothing reaches the screen either way, and the settings screen must say so.
- Windows (platform gate): a borderless window attached into the desktop's own window hierarchy behind the icons, the method wallpaper applications use. Windows 11 24H2 changed that hierarchy and broke several such applications until they were updated, so the shell must detect the layout and re-attach when Explorer restarts or displays change. A true wallpaper is the requirement on both systems; a bottom-most borderless window is a development aid only, and if true attachment proves unreliable somewhere that is reported to the owner, not shipped around.
- Both: frames are paced by the system compositor, never by a busy loop; the HUD redraws only when something changed.

These are operating-system behaviours that have shifted before. They are verified by a spike on real machines, not taken on trust.

### 3.10 Live editing: what is invalidated and how the picture comes back

The stroke model is kept: a draft while the button is held, a jade preview at once, commit on release, cancel on right click or Escape, one undo step per stroke, prebuild while the pointer is held.

| Step after commit | Scope | Incremental? | Aim |
| --- | --- | --- | --- |
| Authoritative cells, undo journal | changed cells | yes | same step |
| Collision, walking, picking, placement validity | derived from cells in the same simulation step; active paths crossing changed cells are re-planned; facilities ride height changes; a stroke that would remove the ground under a facility, conduit or spring is invalid, shown red | yes | same step: the simulation is never behind the edit |
| Water | basins touched by the edit are recomputed; levels ease to their new sills | per basin; a basin can span much of an island | under a frame |
| Geometry (worker threads, cancellable, staged) | the body, lip and dressing within the generator's locality bound | yes, by the generator's design | at most 250 ms from release to published on the M4 Pro, on a 4,096-cell island; today 660 to 990 ms on 623 cells |
| Bake A, provisional | new and changed surfaces get approximate occlusion from the height grid and wash colour without strokes | yes | with the geometry |
| Bake A, final | changed surfaces plus a halo as wide as the occlusion radius; painting pages for new or changed faces | yes, with a halo | settles within 1.5 s, cross-faded under a grow-in like today's 0.55 s |
| Shadow map (B) | the edited island's whole map | no: re-rendered whole, which is cheap for one small static depth pass | next frame |
| Far panorama (B) | untouched by edits | n/a | n/a |
| Still cache (C) | bypassed while sculpting; rebuilt when the camera and the island are still | no: any camera move or stroke drops it | re-accumulates over a few frames |

What is not incremental, and why editing still feels right:

- The still cache cannot survive a camera move or a stroke. That is accepted: editing is foreground play on the Moving path, which must reach the frame-rate gate without the still cache anyway. The cache returns by itself when the player stops.
- The final bake is not instant. The provisional picture is complete (no holes, correct geometry, plausible shading); line and final painting ease in under the grow-in animation. A very large stroke takes longer to settle, not longer to appear.
- Island-wide terms are approximated locally: occlusion beyond the halo is not recomputed. If that shows, the halo grows, at bake cost only.
- Generator locality is what makes geometry incremental. It is a requirement on the new generator (3.7) and is tested, not hoped for.

### 3.11 What each part does and does not fix

- The engine, the caches, the frame paths and the wallpaper shell do nothing for island form or for the presence of large cliff faces.
- Island form is addressed only by the generator rewrite (3.7). It can also fail there; that is an art risk carried by pictures at each checkpoint.
- The presence of large faces is addressed by the generator giving faces planes, depth and frames, and by baked washes, strokes and line (3.5). Baking gives the budget and the place; what a large shaded face should carry is still design work.
- Asset taste (buildings, the character, props) and the quality of layouts across seeds are content work outside this plan.

## 4. Ownership, coexistence and the way back

**The runtime owns:** process lifecycle and present modes; the GPU device and frame graph; shaders; asset loading and build-time baking; the save file and settings; the simulation; island generation; input mapping; skeletal animation; HUD and text (Chinese text is required from the first slice); capture and bench tools; platform glue; packaging.

**The Godot project after the freeze:**

- It is frozen at the phase 0 tag and stays runnable: `scenes/terrain_editor.tscn` remains the single entry and the default way to run the game until cutover.
- No cliff form or surface work continues there (owner decision 18). It changes only to add export tools the runtime needs (cells, cameras, reference frames), guarded by the 40-case list and `run_suite.py`.
- It is the picture baseline: reference frames are captured from the freeze tag, at 3024x1964, with the existing capture tools and fixed cameras, which are exported to a shared file so both renderers shoot identical views.
- `tools/perf/gpu_run.sh` (mains check, one GPU job at a time, timeouts) wraps runtime benches and captures on the Mac as it wraps Godot's.
- The lookdev archive, references, model sources and the Python asset tools stay as they are; they are engine-neutral.

**Carried over, with the Godot version as the oracle:** the terrain cell format (imported); the production simulation and catalogue (`base_sim.gd`, `base_catalog.gd`), tested against recorded traces; the realm table as data; the day keyframes and palettes as data; the HUD as the reference for layout and wording.

**Rewritten for the runtime, not ported:** island generation; the water model; all shading, lighting, foliage and post-processing.

**Dropped:** the quality tiers; the half-resolution background path; the water and dry brushes; land credits; the old gameplay director, fishing and meditation scripts.

**The way back:**

1. The freeze (done 2026-11-22; owner decisions 16 and R2-4): the tree as it stood is the commit tagged `godot-freeze-20261122` on `pr-18-lip`, pushed to `origin`. It holds everything needed to run and re-measure today's game: code, shaders, tests, tools, docs, the assets the scene uses, and the scripts, notes and data of every lookdev package. The lookdev pictures (7.7 GB) are ignored in git and cloned to `~/Archives/the-scroll-within/lookdev_20261122/`; nothing was deleted. Raw model sources (`art/source/`) and unadopted candidate assets (`assets/candidates/`), about 580 MB, are committed under the local-only tag `godot-freeze-20261122-full` and were not pushed, because `origin` is a public repository **(agent's call)**; they also remain in the working tree.
2. The runtime lives in its own top-level folder and changes no Godot file. Removing the folder restores the frozen project exactly.
3. Saves move forward only: the importer reads Godot's layout cells and never writes Godot's files.
4. Cutover is a separate owner decision after section 6 is met on evidence. After cutover the Godot project stays tagged and archived, not deleted.
5. Each phase ends in something that can be run and judged, so the work can be stopped at a phase boundary with the frozen project intact and the measurements in hand.

## 5. Phases

**Status, 2026-11-22.** Phases 0 and 1 are done and checkpoint G1 has been reached: `art/lookdev/20261122_g1/README.md` and `compare.html` beside it. Runtime work is on branch `runtime-dev`; `runtime/README.md` lists what exists. Phase 2 is next.

- S1 (`runtime/spikes/s1_wallpaper/README.md`): a wgpu window hangs as a true macOS wallpaper, between the Finder's icons and the system picture. Covered, it presents no frames and uses 0.05% of one core while the simulation stand-in keeps stepping; visible at 30 frames a second it uses 3.6% of one core. Timer pacing puts about one frame in twenty a display refresh late. Display sleep, session lock and several Spaces were not tested.
- S2 (`runtime/spikes/s2_render/README.md`): on a stand-in scene with a 4,096-cell island and two more islands in view (388,000 triangles), the Moving path costs 1.6 to 1.9 ms and the Still path 0.5 ms at 3024x1964, against budgets of 12 ms and 4 ms. This is the cost of the structure, not of the final picture, and not a look.
- S4, the generator study (`runtime/spikes/s34_study/README.md`): two body constructions on one rim plan, on the four review layouts and a 4,096-cell island. Picked: hanging rock on a liner. The rim plan gives faces of 2 to 7 m with a longest run of two to four alike faces; no face changes farther than 12 m from a scripted stroke on any of the five islands; rebuilding a whole 4,096-cell island takes 172 ms with no incremental update at all. Its known defects are listed in the G1 README.
- S3, the look study: three looks on the same frames, beside 72 Godot reference frames at 3024x1964. Picked: line and flat wash on a warm silk-paper ground. Day frames have a median luminance of 0.82 with nothing near white; night is mid-tones (median 0.44). With four samples per pixel the study's look costs 5.2 to 8.5 ms a frame at 3024x1964 on the M4 Pro, and 1.7 to 1.9 ms with one sample, against the 12 ms budget.
- Exports: the cells of the four review layouts, the twelve fixed cameras, the reference frames, and traces of the GDScript production simulation for the phase 2 port (`tools/export/`, `runtime/data/reference/`).

Durations are the agent's estimates at the pace of recent sessions. They are uncertain and are not commitments. Phases 3, 4 and 5 can overlap once phase 1 is done.

| Phase | What happens | Ends with | Helps island form or cliff faces? | Estimate |
| --- | --- | --- | --- | --- |
| 0. Freeze and exports (done 2026-11-22) | The tree as it stood is committed on `pr-18-lip` and tagged `godot-freeze-20261122`, after a 40 of 40 regression run and a Godot bench at the gate resolution (`art/lookdev/20261122_freeze/`). Lookdev pictures are ignored in git and cloned to `~/Archives/the-scroll-within/lookdev_20261122/`. Raw model sources and unadopted candidate assets are in the local-only tag `godot-freeze-20261122-full`. Exported for the runtime: the cells of the four review layouts, the twelve fixed cameras, 72 reference frames at 3024x1964 from the tag, and production traces (`tools/export/`, `runtime/data/reference/`, `art/lookdev/20261122_g1/godot_baseline/`). | A recoverable tree and a baseline set | No | done |
| 1. Risk spikes (throwaway code; done 2026-11-22, checkpoint G1 reached) | S1: an empty window hung as a true wallpaper on macOS with correct occlusion, pacing and idle cost. S2: static meshes exported once from Godot (as a load stand-in, scaled to 4,096 cells) drawn through a skeleton of caches A, B and C; Moving and Still paths timed at 3024x1964 on the M4 Pro, with several islands in view, scripted camera paths and a scripted edit. S3: the look study, directions A, B and C of 3.1. S4: the generator study of 3.7. | **Checkpoint G1 (show and continue):** the agent presents its picks for look and generator with the comparison frames and the S1 and S2 numbers, and continues unless the owner redirects. If S2 misses native resolution at 60, the 1080p at 120 fallback is taken here. | S4 and S3: yes, this is where form and face treatment are first shown. S1, S2: no | 3 to 4 weeks |
| 2. Core and headless simulation | `core` as specified in 2.3, including settings, quota and the island list; the headless shell; production ported with trace tests; terrain cells and the Godot importer; the source-driven water model; paths over the cell grid; launch catch-up with the 12-hour cap; the two stub layers and their contract tests. | A program with no window that loads an island, runs days of simulated time in seconds, and proves production continues, water holds its levels, and catch-up matches stepping | No | 2 to 3 weeks |
| 3. Island generator and edit pipeline | The generator chosen at G1, built to the requirements and tests of 3.7; dirty tracking, worker builds, cancel, staged publish; edit latency measured on a 4,096-cell island. | The review layouts and a full island generated and edited within the form, locality and time tests; form pictures for each | Yes: this is the form work | 5 to 8 weeks |
| 4. Sea renderer | Bakes, light caches, palette, atmosphere and line, stone washes and strokes, foliage and lawn, gust sway, live water, falls, mist and cloud, the skinned cultivator, still cache, capture tool with the shared cameras. | Matched native-resolution frames against the Godot baseline for all review cameras, layouts and hours | Face presence: yes, with the generator. Form: no | 5 to 7 weeks |
| 5. macOS shell | Window, true wallpaper attach, present modes, the covered-or-display-off setting, power policy, settings screen, packaging. | The slice hangs as a wallpaper on macOS | No | 1 to 2 weeks |
| 6. Vertical slice and first acceptance | Part-one loop playable on one island: place facilities and a spring, orders, mouse worker, conduits and formations, growth states, HUD, save and load, `Depart` into an escrowed run. Then the section 6 proofs on the M4 Pro and the owner's picture review. | **Gate G2:** the four criteria, on evidence | No | 2 to 3 weeks |
| 7. Platform gate | Windows shell and true wallpaper on Windows; frame rate and wallpaper cost measured on a real Windows thin laptop and a MacBook Air-class machine. A Windows attach spike can run earlier, whenever a Windows machine is named. | **Gate G3:** about 60 FPS interactive and a cheap 30 FPS wallpaper, measured on those machines | No | not estimated |
| 8. Cutover, then later layers | Owner decides the cutover. More islands in play, fishing, the village layer, then the extraction map, each as its own plan. | n/a | n/a | not estimated |

**In the first vertical slice:** the whole of core as specified, including the interfaces only the stubs exercise; the Sea layer (new generation, live editing, source-driven water, the production loop on the first island up to an escrowed first outing, a second island founded and set at its own height, a skinned cultivator, gusts); the Sea renderer at native resolution with several islands in view; a true wallpaper on macOS; save, load, import and launch catch-up; measurements on the M4 Pro.

**Out of the first slice:** the village; the extraction map, its maps, loot and combat; any second renderer; people other than the cultivator; fishing; production chains that span islands; Windows and thin-laptop acceptance (phase 7); sound beyond an interface stub; store integration; paid model generation.

## 6. Success criteria for the slice, and how each is proven

All four are required at gate G2. Evidence is written to a dated package under `art/lookdev/` with raw data, as the current packages are. The pass thresholds are the plan's proposed ones, which the owner has said stand; where they were written for a thin laptop they are applied to the first-gate machine.

**1. A clearly better classical Chinese picture than today.**

- Proof: a matched review at 3024x1964. Left: Godot at the freeze tag, default tier. Right: the slice. Same island cells for the review layouts (the cliffs differ, because generation is new), same fixed cameras (whole, cliff close, game, reverse, foot reverse and the rest of the review set), day, dusk and night, plus short motion clips of water, falls, mist, a gust and a camera stop; plus the same views on a full 4,096-cell island and views with several islands at different heights, which have no Godot counterpart.
- With it: the agent's own review against the four properties of 3.1 and their checks, so the owner sees what was aimed at and where it falls short.
- The frames judged are the ones that meet criterion 2: no separate beauty setting.
- Judge: the owner, by eye. Pass is the owner's call that the slice is clearly better. The agent's review, passing tests and pixel metrics do not stand in for it, and a cheaper-looking picture that merely runs faster is a fail.

**2. Native resolution at 60 FPS, measured on the M4 Pro's own screen.**

- Proof: a built-in bench that plays scripted paths (still, orbit, pan, zoom, three edit strokes) on the bench scene of 3.6 (a full 4,096-cell island with two more on screen) and on the starter island, at 3024x1964, with dynamic resolution off, and writes frame-time percentiles with the adapter, system, resolution, power source and settings. It runs on mains power through `gpu_run.sh` after a ten-minute warm soak and refuses to produce a valid result on battery. It reports render cost by a method the window compositor cannot clip (the earlier Godot runs showed an idle window on this Mac presenting at about 85 frames a second), and presented frame pacing on the display as well.
- Pass: Moving and Editing paths at 3024x1964 with median frame time at or under 16.7 ms and 95th percentile at or under 20 ms; Ambient at 30 frames a second with the 99th percentile gap between frames within 1 ms of 33.3 ms **(agent's call on the tolerance)**. S1 showed that timer pacing misses this (99th percentile 39 to 42 ms), so the shell paces from the display's own refresh callback.
- Fallback, only if the phase 1 spike or this bench shows native resolution at 60 cannot be met: Moving and Editing paths at 1920x1080 with median at or under 8.3 ms and 95th percentile at or under 10 ms, with the resting picture still native. Which of the two was met is stated plainly.
- This gate says nothing about thin laptops. Nothing is claimed for a Windows thin-and-light or a MacBook Air until gate G3 measures one. Battery runs are invalid as frame-rate evidence.

**3. Live island editing still works.**

- Proof: tests for blueprint commit, cancel, undo and redo, the stroke plane, locality within the generator's stated bound, seals at falls and terraces, flooding and recovery under the new water model; a scripted stroke replay on a 4,096-cell island measuring release to published geometry and release to settled shading; a simulation test that a path and a placement made in the step after a commit use the new ground.
- Pass: on the M4 Pro, release to published geometry at or under 250 ms at the 95th percentile for a short stroke, and settled shading within 1.5 s. For reference, Godot takes 660 to 990 ms on the 623-cell island.

**4. The wallpaper stays cheap and its water does not drain dry.**

- Proof of water: a 24-hour hung run on the Mac with a spring in place, logging basin levels (at their sills throughout) and flow at every outlet, with hourly stills showing ponds and falls, production counters that kept advancing, and covered periods in between.
- Proof of cost: process time as a share of one core and GPU use in Ambient at 30 frames a second, and while covered at the default setting with the presented-frame counter at zero while simulation counters advance; the system's own energy readings; the same readings for Godot's wallpaper mode at the freeze tag on the same machine.
- Proof of the spring: scripted runs that move the starting spring and that remove it, with stills at each step: falls fade after the delay, ponds settle at their sills and stand, a spring placed elsewhere fills its basin from dry, and no frame shows a hole, a floating sheet or a stale wet bank.
- Proof of the setting: with `when_covered` set to keep drawing, frames continue while covered; with the default they stop; the simulation advances identically in both.
- Pass: Ambient at or under 10% of one core and at most half of Godot's wallpaper cost on the same machine (38 to 42% of one core at 720p today); covered, at the default, at or under 1% of one core with no frames presented.
- A battery run is done once, separately, labelled as a drain test. It is not a frame-rate bench.

**Structural checks (needed for the architecture lock, in addition to the four):** the two stub layers pass their contract tests; replaying the same commands gives the same save; `catch_up` matches stepping, and a 12-hour catch-up at launch completes in a few seconds; a Godot layout's cells import without loss; a second island can be founded headless with the right quota charge.

## 7. Risks, and what would change the plan

| Risk | Why it matters | Handling | What would change the plan |
| --- | --- | --- | --- |
| Native resolution at 60 with a full island and others in view | Godot's light tier needs 13.7 to 18.9 ms at this resolution for one island a sixth of the size; the still cache does not help while the camera moves | Baked terms; opaque foliage; no per-frame shadow pass; a painted lawn; distance detail levels on a full island. S2 measured 1.6 to 1.9 ms for the structure on a stand-in scene, so the risk is now that the real picture spends the margin, not that the structure cannot reach the gate | If S2 misses: the owner's fallback, 1080p at 120 with a native resting picture. If that also misses, stop and report before phase 3 |
| Incremental rebuild after edits | Bakes and caches are what make an island cheap; they are also what an edit invalidates | Provisional then final bake; halo-limited rebakes; whole shadow map kept cheap; still cache bypassed while editing; a scripted edit in S2 | If a typical stroke's final bake exceeds 1.5 s: coarser occlusion (per cell or per vertex), or a low-resolution screen-space occlusion used only while a region is unsettled |
| The generator rewrite | It replaces 14,000 lines that, for all their faults, produce today's fair baseline; a new design can also miss, and its edits must be local and fast at 4,096 cells | S4 before the build; requirements and form tests in 3.7; pictures at every checkpoint; the frozen Godot picture as the baseline | If no S4 candidate beats the baseline's forms: iterate S4 before phase 3 rather than build on a weak one; if one candidate is strong on form but slow to edit, restrict its expensive stage to idle time behind a provisional body |
| The new look is not better | Today's lawn and soft contact shading are attractive; line and flat wash can read as cheap or harsh, and a painted lawn can read flat | S3 with three directions on the same frames; the four properties and their checks; direction A as the safe fallback | If the owner redirects at G1, the look model is iterated on spike geometry before phase 4 |
| Platform and wallpaper glue | Desktop attachment relies on behaviour the systems do not promise; Windows 11 24H2 broke wallpaper applications; multiple displays, Spaces, scaling, Explorer restarts, signing and notarisation | S1 on macOS first; one shell interface; a Windows attach spike as soon as a machine is named | If true attachment is unreliable on a system, that is reported to the owner as a blocker for that system; if the windowing or graphics library cannot present in the attached window or pace correctly, the shell creates its surface natively for that case |
| Gust handling | Rebuilding the still cache without the affected foliage, and swapping back, must be invisible | Scheduled ahead and sliced; foliage eases to its exact rest pose before the swap; tested by frame difference | If the swap shows, foliage gets its own cached layer so no rebuild is needed |
| The skinned character | A free model that suits a robed cultivator, with usable clips and a clean licence, may be hard to find; skinning adds an animation module to the slice | Search free libraries first; record licence in `ATTRIBUTION.md`; one character only; clips mapped from simulation activity | If no suitable free model is found, a placeholder free humanoid carries the slice and the gap is reported |
| The rewrite valley | Months with no new playable build, and now no parallel look progress in Godot either | The frozen Godot build stays playable; headless simulation delivers testable gameplay early; every phase ends in something runnable; G1 comes early | If a phase overruns its estimate by half, stop at its boundary and re-plan rather than cut the proofs |
| Simulation determinism and catch-up | Wallpaper and the 12-hour launch catch-up depend on coarse steps matching fine ones | Whole-thousandth quantities; seeded streams; no wall clock in steps; the water model has no volumes to drift | n/a |
| Colour management | An unmanaged wide-gamut panel makes the palette harsher than designed | Tag output for the display; compare on sRGB and on the Mac's panel | n/a |
| HUD and Chinese text | Shaping, fallback fonts, sharpness at native resolution, and no redraw when idle | Choose the UI approach in phase 2 against those four requirements | If no library meets them, a small custom HUD layer for the slice's limited screens |
| Tooling loss | Godot's inspector, hot reload and capture scripts go away | Budget for shader and data hot reload, a capture command with the shared cameras, and debug views | n/a |
| Thin laptops are deferred | The design is first proven on a fast machine; a thin laptop may need more than the first gate shows | One look on every machine; the still path is nearly independent of the GPU; keep the Windows build compiling and the headless tests passing from the start | G3 numbers may re-rank work after the first gate; nothing is claimed for those machines before then |

## 8. What not to do

- Do not treat today's implementation, documents or pipeline as rules. They are reference. What binds is the locked gameplay, and the feel of today's picture as the floor to raise.
- Do not build three engines. One runtime, one save, one catalogue, one character; three scene layers.
- Do not build a general-purpose engine or a Godot replacement: no scene editor, no scripting language, no general material or light system, no plugin system. If a feature is not needed by the Sea, or named in section 2 for the two later layers, it is not built.
- Do not port today's techniques unchanged into a new renderer: MSAA, SSAO and SSIL, four-split shadows every frame, layered alpha foliage cards, 1.3 M live grass triangles, a million triangles of mountains, quality tiers that remove lighting. The same techniques cost the same in any engine.
- Do not port the current island generator or the finite-volume water solver. Do not continue cliff form or surface work in Godot.
- Do not build the village or the extraction map in the first slice. Their interfaces and stub tests are in; their content, rules and renderers are out.
- Do not throw away, reset or delete the current tree. It is frozen and tagged, and stays runnable until the slice meets all four criteria on evidence and the owner decides the cutover.
- Do not claim thin-laptop or Windows performance from M4 Pro numbers, from arithmetic, or from battery runs.
- Do not treat functional tests, pixel metrics, the agent's own review or any current lookdev pass as art acceptance.
- Do not let a renderer own game state. If something must keep happening while hung or covered, it belongs in the simulation.
- Do not let blur, glow haze or a smearing filter into the final image.
- Do not commit the `art/lookdev/` pictures, and do not delete source references or anything needed to compare against today's look. Do not use paid model generation for this work.

## Appendix: where each claim comes from

- Frame costs at 1080p and 4K, tiers, wallpaper processor time, the measurement method: `art/lookdev/20261121_perf_stack/README.md` and its `data/` folder.
- Shader tap counts, waterfall and pond treatment, slab feet depths: `art/lookdev/20261121_cliff_water/README.md`.
- Causes of the reverse-wall palisade, the plan metric, the locality bound: `art/lookdev/20261121_reverse_stagger/README.md`.
- Edit timings, stroke model, owner calls by date including the 2026-11-21 form locks: `CURRENT_CONTEXT.md`.
- Terrain representation and file format: `scripts/terrain_editor/terrain_data.gd`. Production rules and numbers: `scripts/gameplay/base/base_sim.gd`, `base_catalog.gd`. Realms: `scripts/gameplay/data/realm_progression.gd`. Day keyframes: `scripts/gameplay/systems/time_solar_system.gd`. Part-one objects: `docs/part_one_objects.md`. Art direction: `docs/art_direction.md`.
- Owner decisions in 1.1: the owner's answers of 2026-11-22 to the first version of `docs/engine_refactor_plan_questions.md`.
- Outside facts checked on 2026-11-22: Tiny Glade uses its own Vulkan renderer with an existing entity library and windowing; wgpu is actively released with Metal, Direct3D 12 and Vulkan backends; Windows 11 24H2 held back upgrades on machines running some wallpaper applications until those applications were updated.
