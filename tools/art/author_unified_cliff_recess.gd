extends RefCounted
## Compose one real recess using the same geological cutter as the player.
static func author(data)->void:
 data.begin_stroke()
 data.apply_rock_brush(Vector3(-15.7,1.6,4.5),2.7,'rock_cleave',Vector3(.18,0,1).normalized())
 for pass_index in 2:data.apply_rock_brush(Vector3(-15.7,2.0,3.1),3.25,'rock_smooth')
 data.end_stroke()
