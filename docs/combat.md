# First-version sword-cultivation combat design

Basis: on 2026-09-20 the user confirmed moderate manual control, mouse direction with a small aim assist, a first-slice path for one class of armed enemy, and full damage reduction on the last point of ward. This document separates confirmed rules from tunable trial values.

## Confirmed rules

- Common god-view; keep a rotatable, zoomable camera. Combat information must be readable from a distant view. The mouse sets swing and parry direction; only a small assist is allowed. Do not auto-turn to defend the back.
- One-on-one can be handled calmly through observation and parry. Multiple attackers are hard to cover by direction. Close-range spiritual pressure stacks and accelerates ward drain. All hostile characters (including the player) apply pressure to each other; allies do not drain each other.
- If ward > 0 before a direct hit lands, the hit gets full damage reduction from the realm difference. The reduced portion is paid by ward, floored at zero; any shortfall is not transferred to vitality. The last 1 ward still grants full reduction. If ward is 0 on the next hit, there is no reduction.
- Active qi damage drains ward first and overflows to vitality. Passive close-range spiritual pressure drains ward only and does not damage vitality.
- When the same move includes both direct damage and qi damage, snapshot ward before the hit, resolve direct damage first, then active qi damage. This avoids order-of-call drift on one hit. This is an implementation convention and may be adjusted after playtests.
- Ward reduction does not drop with remaining ward fraction. Delayed recovery is allowed only after leaving pressure and after being hit. Recovering 1 ward while still under pressure must not re-grant protection over and over.
- Ordinary sword hits, sword moves with a directional parry window, and a limited number of movement-art charges. Each parry blocks only one attack that matches direction and timing; it is not omnidirectional continuous defense. Movement-art invulnerability is short and leaves a gap afterward. Passive close-range pressure does not vanish during movement-art invulnerability.
- First enemy moves: linear thrust, forward sweep, and a charged slash with an outer qi envelope. Core sword path and outer envelope are judged separately; the envelope must not double-count the same qi damage.
- Each move has startup, active, and recovery. The same move settles once against the same target. A long frame that straddles the active moment must neither miss nor double-hit.
- Breath concealment, sword flight, the realm-growth system, and official death-loss are out of scope for the first verification slice.

## Trial values (not final balance)

- Same-realm reduction 80%; ±5 percentage points per realm difference; clamped 60%–95%. Realms use test integers; do not add official realm names.
- Starting vitality/ward 100/100. After leaving pressure and 3 s after being hit, recover 12 ward per second. Vitality does not auto-recover.
- Pressure radius 2.2 m; source strength inside 0.7 m, then linear falloff. Same-realm source strength 6 per second; each test rank above multiplies by 1.5. Strength and distance are parameters.
- Swing assist only considers targets within mouse direction ±12°, within 2 m, with no occlusion; correction at most 6°. If there is no candidate, keep original direction. Do not lock onto the back.
- Ordinary swing: startup 0.20 s, total 0.55 s. Parry sword: parry window 0.08–0.28 s, active 0.34 s, total 0.80 s. Sidestep: total 0.38 s, invulnerable 0.04–0.22 s. Movement art: 2 charges, recovered one by one, 2.4 s each.
- Enemy thrust: startup 0.65, total 1.15. Sweep: startup 0.80, total 1.35. Charged slash: startup 1.20, total 1.85 s. Direction locks after startup so the player can read and dodge.

## Current implementation and work order

The Tripo starter sword, right-hand binding, and basic swing/parry/movement art are integrated. Player and practice dummy use ward and pressure rules. Current state is single-dummy practice. Three enemy attack types, multi-enemy, realm growth, and sword flight are not fully integrated. Finger grip and full-pose intersections still need review.

Current priority is courtyard art and performance. This document keeps combat rules and does not require expanding combat immediately. Overall direction: [current consensus](../CURRENT_CONTEXT.md). Asset sources and finish: [asset status](../art/README.md).

## Verification

Hand-calculated damage cases cover: 1 ward + 80% reduction + 100 direct damage → vitality loss 20, ward to zero, next identical attack loses 100; active qi overflow; passive pressure is not lethal; no friendly fire; multiple enemies can stack; no recovery under pressure; leave-and-recover timing is frame-consistent.

Direction tests cover mouse planar projection and rotated views, no snap to a back target, assist angle cap, no back parry, parry once only, movement-art charges spent and recovered one by one, no miss on a cross-frame active, and charged-slash core vs envelope hitting separately. After game integration, validate actual feel and target-device performance with one-enemy, three-enemy, and higher-realm scenes. Logic tests passing does not complete those acceptances.
