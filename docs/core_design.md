# Core design

Systems rules are kept. Some candidate assets exist in scenes, but overall art is not accepted. Look is rebuilt to [current courtyard style](art/style/README.md). Formulas in `design_v0_2` may be used as prototype parameters and **must not override the ledger already locked here and in courtyard operations**.

- Exploration judgment, retreat, and knowledge layers follow [Exploration](exploration.md).
- Spirit-beast duties and incremental rules follow [Spirit beasts](spirit_beasts.md).
- In-progress courtyard HUD, camera, clicking, facility panels, and floating-island edges follow [Courtyard operations](courtyard_ops.md).
- Qi, spirit springs, spirit stones, offline, two slices, and the experience-slice loop follow this document.

The endgame fantasy is not the most money, the largest island, or the highest attack. It is: understanding part of how heaven and earth work, bringing it home, and building a grotto-heaven that runs itself and still keeps personal traces. One can stay in peace, or travel at ease.

Automation should reduce old labor, not add management. Exploration should bring back new abilities, not only lengthen a materials list. Building should make room for taste, not force the yard into production cells. Cultivation should change what can be done, not only raise the next-gate number.

## Core experience

Through active exploration, the player permanently changes how a mountain dwelling of cultivators runs. The more mature the dwelling, the more capable — and the more at ease — the player is to do what they actually want.

This is not a cultivation-skinned farm. It is turning understanding of the world into the running rules of a grotto-heaven.

Scenes split explicitly into the Sea of Consciousness Courtyard, the village, and exploration areas. The courtyard is a placeable, combinable sandbox of management. The village is organized separately. Exploration is designed toward procedural generation. The three share art but not layout duties. Do not make the whole game one courtyard landscape. Village remodeling scope and exploration generation details are specified separately. Exploration gains development chances; facilities turn chances into ongoing return; quiet cultivation provides predictable personal growth. Do not design ascension or resource resets. When characters leave the courtyard, production must keep going. There is no penalty for not logging in to feed.

In equal time, active investment should have extra return, but do not fold every reward into one “total growth speed” ranking. Duties:

| Play | Best at providing | Must not degrade into |
| --- | --- | --- |
| Exploration | New options, scarce breakthroughs, understanding of world rules | Fixed farming of the most valuable route |
| Planning | Long-term efficiency, stability, changing how resources are used | Placing machines to a unique answer |
| Quiet cultivation | Predictable personal growth, low-attention progress | Sitting as punishment when nothing else can be done |
| Assist and hand work | Startup, emergencies, temporary adjustments | Normal return only from continuous clicking |

A good plan should keep producing value for a long time afterward. Rule details: [Spirit beasts](spirit_beasts.md), [Exploration](exploration.md).

## Nearest neighbor: Frontier Tale

The closest loop skeleton is *Frontier Tale*: leave home into a random wild, trade off going deeper versus retreating, turn what you bring back into workshops, fields, and gear, so the next outing is different.

The two places that must diverge are look and incremental. Look follows [current courtyard style](art/style/README.md), not its cel-shaded fairy tale. Once incremental is taken seriously, the home side is no longer the same game:

| Frontier Tale | Yunlu Village |
| --- | --- |
| Home is a workshop between two trips; partners water, farm, and tend livestock | Home itself is the product: Assist, character assignments, and meridian facilities can stack, and keep running when no one is present |
| Farming has daily watering | Production layer is automatic; no daily watering, no penalty for not feeding |
| Exploration is the main loop, “one more run” | Exploration is faster and brings back permanent abilities; management is not a ticket to explore; complete habits are still an advantage for going out |
| Fixed ruined territory + recruited partners who both fight and work | Cloud-sea floating-island grotto-heaven, later movable; spirit beasts are production-line formulas, not ranch dailies |
| Offline adventure farming | The same grotto can idle with friends; public world, private pack |

What can be learned is how to make “going out once” clear: coming back safely is not the end; visible change must remain in the territory. Do not learn watering partners as a substitute for automation, and do not make the courtyard a midgame waiting for the next trip.

## Courtyard operations and presentation

The in-progress UI takes **Assist** out of the character action bar and gives it its own slot, like Photoshop's hand: not the same tool group as gather, cultivate, and assign. The player can unlock camera follow and hold-drag on empty ground to look elsewhere. Wheel push-pull and Q/E rotate remain. Clicking an automatic facility opens that facility's panel directly, without a multi-choice popup first. Build recognizes cells; daily selection recognizes the seen target. Facility panels first answer why it is not working.

Scenes follow [current look](art/style/README.md) and [module spec](art/scene_art_and_module_spec.md). Cloud-sea floating-island edges of the Sea of Consciousness Courtyard should adapt to laying-ground changes; tiles should not cut off suddenly. Village and exploration landforms are not required to copy the courtyard. Characters follow the locked look; labor needs matching animation. UI references Genshin's hierarchical whitespace and Humanica's facility windows and tool grouping: simple, not cheap. Full rules: [Courtyard operations](courtyard_ops.md).

## Player freedom and guidance

Hand farming, management, and exploration can all develop. Automation should become an efficient route the player discovers, not a requirement for every player.

At the start, the master is injured, and treatment supplies are delivered in stages. The injury does not worsen offline. After recovery, the master may provide limited qi as a story crutch, not as a second spring. Late game relies on the player's own wells and facilities.

## From hand work to automation

Continuous upgrade of one field cell: clear wild ground → sow → natural growth → hand harvest → upgrade in place to a spirit field → after meridian linking, auto-replant and harvest → later transport. No daily watering. When qi is low, automation stops; existing crops still grow naturally, and the player can keep planting and harvesting by hand.

Spirit patterns are not only connectivity: formations provide local efficiency bonuses. Automaton beasts fit stable carrying and cross-region work; shapeshifted beings are for window boosts or short observation in exploration; fixed qi paths fit long low-cost production. Domestic livestock is isomorphic with herb fields: if meridians, qi, and layout conditions hold, they fill a buffer by day; feed and breeding are optional multipliers.

**The first local loop comes early; cross-facility, cross-region, freely combinable automation comes late.** Do not mash “auto” into one thing:

- **Early: one line that turns itself into a small buffer.** Results are visible when no one is there. The well seeps by itself; another very simple generator (for example a meridian-linked herb field) outputs into its own lid. It cannot freely supply other facilities yet; there is no filtering or long-distance transport.
- **Middle: more nodes, loops not closed.** Fields grow themselves, springs produce qi themselves, crates do not collect themselves.
- **Late: loops close.** Paths, filters, automaton beasts, formations, and spirit-beast formulas connect; after going out, whole courtyard stretches keep running.

“The home still grows while I am away” must be cashed in once in the first stretch of play. Do not wait until generic automation is done. Do not give plant, harvest, store, and haul all automatic at once.

Assist is a short intervention past a startup bottleneck, not a required operation for long-term best yield. Early: do it by hand. Middle: assign. Late: run stable, intervene only when changing goals. Once mechanisms and formations exist, the main path should not be click acceleration.

## Qi, spirit springs, spirit stones (2026-09-16)

Both cultivation and expansion should feel short of qi. Tight qi is the heartbeat, not a starting brick wall.

Spirit springs seep qi on a schedule. Seepage is the well's own attribute: it changes only when upgraded or when wells are added, and **does not drop because the island grew**. Start with one. Liquid lives only in each well's volume; it is not carried and does not go through stone refining.

**Seepage first automatically feeds production land.** Cells that change how things run — clearing, river, formation eyes, special terrain — consume qi by count, with rising marginal cost, without anyone carrying energy. Ordinary land, paths, and leftover space only consume the area cap and a one-time laying cost; they **do not consume seepage**. Decorations do not add yield. Wells are still amplified (they feed production capacity), and leaving an empty patch does not make the yard poorer.

Production land forever ≤ total well seepage: the next cell that would exceed cannot be laid. Seepage does not drop as the island grows, and wells are not drained dry to feed land. Starting prefab-island production land must be fed by this one well. Holes take no footprint and no qi. Changing clearing back to ordinary land or deleting cells frees qi immediately.

The laying preview must show “what remaining seepage will become.” When remaining is zero, recovery is: change production land back to living land, add a well, or hand work / trade. Do not discover after failure that the only option is tearing down the house. Do not make the only recovery path long click-mining.

Another well is needed to feed more production land. Adding or optimizing wells must use advanced exploration materials or equivalently expensive bought materials. Common wood, ore, and boards must not copy generators.

Only seepage remaining after production land fills well lids, and only then goes to stone refining. Wells themselves do not print stones. Refining needs a device (operated by a person or clicks; later automatable). Pumps only move. Do not design gas tanks, gourds, or listening stones.

Spirit stones are both money and first-generation portable energy, kept in two places:

- **World fuel:** remaining liquid in wells; refining output cells; later facility fuel cells. Offline: production land settles automatically by seepage; remainder fills well lids.
- **Wallet spirit stones:** do not grow offline.

The first slice has no stone refining. The kernel slice must show “clearing consumes seepage, leftover space does not, well lids only take remainder.”

### Voided: whole-island tax, discoloration, protection quota as exploration reward

v0.2 charged upkeep on every land cell, still allowed laying past the cap (only discoloration and a discount), and made exploration rewards “+16 tax-free cells.” That set **does not enter the main track**.

It fights “willing to leave an empty patch”: empty land still pays tax. It fights “going out changes how things run”: quota only makes the island larger and greener; the yard's formula did not change. It also fights how wells amplify: wells should feed production land, not a property fee on all land.

The main track only recognizes:

| Ledger | Consumes | If exceeded |
| --- | --- | --- |
| Living cells | Area cap, one-time laying | Cannot lay more empty land |
| Production cells | Seepage (linear in the experience slice, later rising marginal) | Cannot convert the next cell to production land |
| Device running | Spring pool / later fuel cells | Stops; the land remains |

If protection objects, soft discoloration, or a whole-island budget are later made sandbox options, they must not replace the three rows above, and must not again be the experience-slice outing reward.

## Offline

After closing the game, things already running continue at most 10 hours from the state at leave. Totals use closed-form math. Do not simulate walking or per-frame work.

Facility panels and offline summaries must both answer: **under the current arrangement, how long can this still run stably?** Do not let a buffer that fills in twenty minutes hollow out a ten-hour promise. “How long one can leave at ease” is itself a growth reward.

If before going offline one saw “this line can run stably,” coming back should not yield almost nothing in a way that is hard to understand. When upstream and downstream feed each other, the summary must still say which ring stopped.

“No seeds offline” means **first-unlock seed stock**. Automatic fields already running replenish seeds each cycle from the line itself. Do not make a so-called permanent line require repeated outings to restock seed.

Wallet does not grow offline. If spirit stones produced by devices offline can enter the wallet, the economy has already earned; count by final spendable value. Do not pretend offline earned nothing.

Can accumulate: remaining liquid in wells (up to the lid); refining output cells when refining is automated; herbs, wood, ore, and primary processed goods on connected lines; assigned character labor that is not carrying stones / hand refining (including cultivation).

Cannot accumulate: wallet spirit stones, unlocked-not-yet seed stock, recipes, physical habit tokens, exploration drops; Assist no one clicked, new jobs no one assigned. Exploration sites remain; they do not push deeper automatically. Patterns in field notes are not “accumulation”; they remain even on failure. See [Exploration](exploration.md).

## Exploration

Rules: [Exploration](exploration.md). This section does not repeat them.

## Cultivation and production-line uses

Cultivation accumulates permanently. Farming and husbandry do not directly add attack. Important realms should change what can be done, not only add a number gate. Not every layer needs a new mechanic. Sword flight over holes is reserved. An earlier layer should open an exploration or management means (reading a class of habits, short shapeshift, operating a more complex formation); sword flight comes later.

**The experience slice does not unlock realm actions.** Observation is walking to a sheltered shore, not shapeshift; crossing holes is not sword flight. The next slice locks the first layer: only short shapeshift can trigger the observation that is “not open to people.” Do not stack shapeshift and sword flight into the same slice.

Main production lines should have not-identical uses: stable supply, building upgrades, improving how other facilities run. Do not let every product convert to spirit stones without friction, leaving only a spirit-stones-per-minute leaderboard.

## Spirit beasts as incremental

Wild spirit beasts grow in exploration; domestic ones grow in the courtyard. The village keeps only people's schedules and passerby rumors. A few hard gates decide whether it runs; several soft preferences decide what it is better at. Shapeshift is a short multiplier: observation in exploration, window boosts in the courtyard.

The courtyard stays safe. No added hunger, no penalty for not feeding. Full rules: [Spirit beasts](spirit_beasts.md).

## Moving settlement and narrative

The settlement moves with regions so that experience stays at home, not to refresh an outing list. A trip's habit becomes a courtyard corner; objects become decoration; characters have short responses. Important places are not permanently missed by idling, and people should not chase seasons on a real-world clock. Ten minutes a day, sixty days a season overlapping the ten-hour offline cap: spirit-beast windows and migration must not be designed as “come back and just miss it.”

Late game may control sailing. Already-placed lines whose conditions still hold do not stop because the village left. The table of wild formulas that can be met may change with region.

## Long-term building

No reset is an advantage. Stage goals should change the problem the player faces: early “can I get resources stably,” middle “how do lines cooperate,” late “how to configure goals, layout preferences, and far travel.” Do not mainly stall time with “the next well costs ten times more.” A mature grotto-heaven one can live in or travel from can itself be a stage result. There is no need to promise infinite play.

## Two slices

**Kernel slice:** one well + walking protagonist + 2D sparse grid. Clearing consumes seepage; ordinary land does not. Editable and deletable, holes allowed, new cells edge-attached. No stone refining, sword flight, or exploration. Used to confirm the rules run.

**Experience slice (immediately after):** one well, 2 fields → 1 medicine bench turning into a small buffer, a shallow-ravine fork, one water-adjacent beast, two courtyard layouts that compete for shore, one retreat the player actively chooses. No formations, no shapeshift, no locked combat. The player should be able to say: herbs will not need me watching later; this outing was for the shore beast; I went home because the seed was already overhead; I got greedy in the fog so I am willing to take the right path again; shore for beast and shore for fields are two yards; empty land does not have to be deleted to live.

### Experience-slice loop (2026-09-17)

The village herb line already turns. Going out is not to farm herbs again; it is to give the courtyard a **layout that only exploration completes**.

**Shallow-ravine fork:** [Exploration](exploration.md). **Bamboo Ravine beast:** [Spirit beasts](spirit_beasts.md). Courtyard land types and shallow bay: [Courtyard operations](courtyard_ops.md). This section only locks how the loop bites together:

1. Starting prefab island has one well, two cultivated field cells, and an edge-attached shallow river bay (production cells, not walkable, does not split the island). The well must feed these production cells and leave slack for a little more clearing or river. Living cells are most of the island.
2. 2 fields and 1 medicine bench turn into a buffer on the existing small loop, supplying the master and short exploration endurance. This is basic supply the village can already have.
3. South-rim cloud gate goes out. Left path: ravine-sprout seed, must be brought back overhead/in the pack. Right path: write “does not approach on an open shore; only with shelter; placement must be water-adjacent.” Farther left is visible fog; stepping in returns to the village with ward, losing only carried items. Walking back to the entrance is retreat.
4. With seed stock, a **Bamboo Ravine pen** can be placed on a living cell (entity; does not change land type). Hard gate: at least one of four neighbors is river, or it does not run. Soft: more stable next to shelter; next to an herb field gives the field a small bonus but occupies shore. Geometry and habits **do not read** the research-complete flag.
5. Researching seed stock does not consume the body and does not grant protection quota. First completion only writes soft preferences into readable notes. Placement is possible without research; the pen may sit on an open shore; the beast can run but is unstable.
6. The experience slice does not build Yunyin Village. Place a passerby's leftover **fluff loom** in the courtyard (or the one in the master's cabinet): it can make ravine fluff, needs no water, has no field bonus, produces no dew. Bought or present at start, proving basic supply without going out. The complete village comes later. A complete beast produces fluff + dew and opens the shore-layout problem.
7. Two yards compete for the same shore: shore to the beast (pen + shelter, fields in the back row taking the beast bonus, not water-adjacency); shore to fields (fields occupy shore for water-adjacent growth; pen omitted or on a worse shore). Goals differ; it is not the same spirit-stones-per-minute.

Only after the experience slice: crossing paths that raise formations, shapeshift observation, a second well, stone refining, sword flight. Do not use formations to prove “layout has a choice” — the shore already proves it.

## Time and server

Keep 10 minutes a day, 60 days a season, UI does not pause. Local offline fuel and materials cap at 10 hours; rules above. Seasons, spirit-beast windows, and settlement movement must not be “come back and just miss it.”

Target is a light independent server: identity binds an in-world character; the world owns buildings, meridians, and the clock; the person owns growth and pack. Multiplayer amplifies an already fun loop; it does not replace validating the loop. First define public-resource permissions, that important changes are reversible, how late joiners connect, and unified settlement of server-online vs client-offline. One person expanding production land or removing a facility must not quietly harm another.
