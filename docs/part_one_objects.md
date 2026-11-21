# Part one: object list and picture review (2026-11-21)

For the owner to lock. Nothing here was sent to Tripo and no new picture was generated. The rules these objects serve are in `scripts/gameplay/base/base_catalog.gd` (numbers are first-pass tuning values).

## Objects part one needs

"Picture" is the state of the input pictures in `art/source/model_refs_20261119/prompts/`. "Defined" means a prompt exists in `assets.json` but no picture was made.

| Object | In the simulation | Role in the pipeline | Picture |
| --- | --- | --- | --- |
| 灵泉 spirit spring | `spirit_spring` | makes qi all the time; a seat for raw-qi cultivation | defined (`spirit_spring`, 4 views) |
| 石井 stone well | `stone_well` | water for crops, cooking and drinking | done, 1 view |
| 灵田 spirit field | `spirit_field` | qi 3 : water 1 into spirit grain; qi 2 : water 2 into spirit herb | defined (`spirit_field_bed`) |
| 凝矿台 ore bed | `ore_bed` | qi 5 : water 1 into ore seedlings | defined (`ore_condenser`) |
| 灶台 hearth | `hearth` | grain 2 : water 1 into a spirit meal (food, and a cultivation boost) | **not defined** |
| 丹炉 alchemy furnace | `alchemy_furnace` | herb 3 : qi 2 into healing pills; herb 2 : qi 3 into fasting pills | defined |
| 炼器台 forge | `forge_hearth` | ore 4 : qi 6 into the first blade | defined |
| 灵气通路 conduit: straight, corner, tee, node | conduit cells | carries qi; a closed ring wakes a formation | defined (4 pieces) |
| 储灵瓮 qi urn | `qi_urn` | buffers qi on a conduit line | defined (`qi_reservoir_urn`) |
| 聚灵阵台 qi dais | `qi_dais` | a seat for cultivation away from the spring | defined; `meditation_dais` (done, 1 view) could stand in |
| 界门 realm gate | `realm_gate` | checks the kit and starts the outing | defined (4 views) |
| 储物箱 / 库房 storage | the store | where goods sit | defined (`storage_chest`, `storehouse`) |
| 石灯, 假山, 影壁 decorations | `post_lantern`, `rockery`, `spirit_screen` | prosperity and a small work bonus | done, 1 view each |
| 修士 cultivator | the cultivator | the worker the player commands | 3 of 4 views done |

Growing things need three states each (planted, growing, ripe) for spirit grain, spirit herb and ore seedling: **not defined**. Goods need icons, not models: qi, water, grain, herb, ore, spirit meal, healing pill, fasting pill, blade: **not defined**.

Defined in the qi tier but not needed for the first outing: tree nursery, workbench, drying rack, spirit-stone pile.

## Review of the existing pictures

Seen at reduced size as contact sheets; verdicts are mine, not acceptance.

- Style holds together across the set: matte clay-like forms, warm grey stone, grey-blue tile, grey-brown timber. It sits inside the island's palette.
- Ready for a white-model test (complete and consistent): thatched hermit hut (4 views), stone arch bridge (4), and the single-view props: flat slab bridge, spirit screen wall, stone steps, stone well, fishing spot kit, incense table, meditation dais, plank jetty, post lantern, rockery, mossy boulder pair.
- Incomplete sets, one view each was rejected earlier and not redone: waterside study (back and left missing), woodshed (back), moon gate wall (left), cultivator (right). Courtyard wall straight and corner have only rejected pictures.
- Cultivator: a robed chess-piece figure, no face, hands or feet; cream robe with sage trim and hair. It reads clearly at play distance and matches the "simple model" decision. Work can only be shown by leaning, bobbing and swinging the sleeves, which are separate masses in the picture. If carrying or hoeing must read as such, it needs a held prop per task rather than a new body.
- Taste notes for the owner: the hut's thatch and plain gable read more as a farmhouse than as a Song mountain retreat; the study's hip roof has no eave curve. Both are sound as shapes and could be pushed further toward the classical register if wanted.

## Pictures still to make once the list is locked

1. Cultivator right view (1 picture).
2. The qi tier as defined: spring, field, ore bed, furnace, forge, four conduit pieces, urn, dais, realm gate, storage chest (about 19 pictures).
3. New prompts first, then pictures: hearth; three growth states for grain, herb and ore seedling; one held prop per task (bucket, hoe, basket).
4. Goods icons (9), as flat pictures rather than models.

## Choices for the owner

- Should the spirit spring also be the source of the island's water? Today the ponds have no source and drain within minutes (`art/lookdev/20261121_perf_stack/README.md`).
- Is a hearth wanted, or should spirit grain be eaten as it is and the outing's food come from the furnace?
- Is the simple figure enough for part one, with held props for tasks?
