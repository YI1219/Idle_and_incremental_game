# Exploration

The Sea of Consciousness Courtyard is safe; going out is voluntary. Exploration areas are organized separately from the courtyard and the village, and are designed toward procedural generation. Exact algorithm, map scale, and reset behavior are not yet decided. The existing demo is not completed procedural generation. This document specifies the push-in vs retreat tradeoff. Combat principles are in [Combat](combat.md).

Exploration art uses combinable modules. Procedural layouts must account for traversable paths and resource and risk distribution; they must not reproduce one fixed courtyard reference image. Suggested organization: [Scene art and module spec](art/scene_art_and_module_spec.md).

## Three questions a trip should answer

Before departure and along the way, the player should be able to answer:

1. What am I looking for this time? (Which home bottleneck does this solve?)
2. If I go back now, what can I already make work?
3. If I push farther, what might I gain, and what extra risk do I take?

The high point should be “with this, I can finally make that thing work at home,” not twenty extra herbs in the pack. Materials matter, but the reward of an important trip is a permanent change to how the courtyard runs: a formula, a seed stock, a layout that can exist.

## Failure and knowledge

Failure loses all carried items and this trip's **physical** gains, then returns to the village with ward. Cultivation growth, the settlement, storage, and already-placed production lines remain.

- **Sights and understood patterns go into shared field notes and survive failure.** Dying does not make the player forget what they just understood.
- **Seed stock, materials, and tokens needed to start a production line must be brought back safely.** Rushing in naked, looking once, and dying home does not grant a long-term line.
- Unique items and quest tokens are counted separately from remakeable daily gear. Daily exploration gear should be stably supplied by home production. Recovery cost after failure should be short and clear. Do not make people afraid to use good gear and only farm safe zones.

Full drop-on-death can stay if restocking does not become a second expedition.

## Risk comes from a readable situation

Danger level, return time, and supplies as both offense and retreat must all be readable. The player should see signs, choose detours, spend limited resources to get out, and judge whether this one is worth fighting. After failure, they should be able to say “I got greedy / I didn't leave return time / I misread the sign,” not “the system decided my gear was too low.”

## Alternatives to exploring

Going out is not required. Village traders and commissions should let someone live, run a basic production line, and restock daily gear.

**Complete habits, unique variants, and understanding that makes a layout actually work remain exploration advantages.** Without exploring, one can still manage and grow stronger, but the grotto-heaven will not become the same place. If both paths grant identical final abilities and only differ in speed, exploration is no longer “discovery becoming a permanent ability.”

## Observation

Observation is “find a clue → guess → verify,” not waiting on a progress bar in front of a beast. Shapeshift is a short-range approach tool. In exploration, small terrain edits that last only this trip (dig a ditch, dam a stream) may be used to verify habits. Do not grow the exploration map into a second grotto-heaven.

## Experience slice: shallow-ravine fork

A small map, two paths, a visible fail condition. Used to cash in the three questions; do not lay out combat.

- **What this trip is for:** seed stock for the shore beast, and why it only approaches at a sheltered water's edge. Not another pack of herbs.
- **Left path:** ravine-sprout seed (physical). Approach puts it overhead; if full, picking stops. Without the seed, a Bamboo Ravine pen cannot be placed at home.
- **Right path:** observation stone. Standing on it writes into field notes: “Does not approach on an open shore; only approaches with shelter; placement must be water-adjacent.” Produces no item. Survives failure.
- **End of the left path:** one cell of dark fog. Stepping in returns to the village with ward, losing overhead and pack, not home or field notes. The cell in front of the fog is safe; the player can see it and turn around.
- **Entrance:** walking back is retreat. Seed still on the head or in the pack. Home herb line keeps running.

Do not block the path with “the system decided gear is too low.” Do not use floating-stone protection quota as this trip's reward. The village start may have herbs and a fluff loom; it must not have ravine-sprout seed, and must not write the complete habit into the description first.
