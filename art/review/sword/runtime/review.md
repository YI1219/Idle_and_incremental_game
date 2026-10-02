# Basic held-sword playtest review

Real Godot renders of idle, swing, and key parry moments were inspected. A problem of the sword pointing at the chest was changed so the wrist follows the forward swing path. Original hem/ribbon delay animation is kept. The sword comes from the user's Tripo export; the original file was not changed.

Runtime integration: left click / J swings; right click / K directional parry once; Space has 2 movement-art charges. Both sides use vitality and ward, close-range spiritual pressure drain, invulnerability windows, recovery intervals, and full reduction on the last point of ward, all existing rules. The static practice dummy keeps the old charge-ring attack and has not been upgraded to three move types or multi-enemy play.

Verification: sword_rules_test zero failures; sword_runtime_test zero failures (binding, last point of ward, front/back parry, movement-art charges, invulnerability and pressure); demo_test 21/21, space_test 21/21.

Boundary: keyframe inspection is not zero intersections in every pose. Fingers have no dedicated fist deform; sleeves still need further refinement. Not final combat animation or complete sword-cultivation growth.
