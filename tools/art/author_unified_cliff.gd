extends RefCounted
## Explicit artist strokes on the shared terrain solid, not arranged models.
static func author(data)->void:
 data.begin_stroke()
 data.apply_rock_brush(Vector3(-16.25,3.35,2.9),1.35,'rock_add')
 data.apply_rock_brush(Vector3(-15.0,2.5,3.5),1.65,'rock_add')
 data.apply_rock_brush(Vector3(-12.8,2.1,4.5),1.4,'rock_add')
 data.apply_rock_brush(Vector3(-16.2,4.35,3.1),1.9,'rock_plane',Vector3(.18,1,.15))
 data.apply_rock_brush(Vector3(-16.3,2.6,4.1),2.0,'rock_plane',Vector3(-.60,.03,1))
 data.apply_rock_brush(Vector3(-15.0,1.9,4.55),1.9,'rock_plane',Vector3(-.20,.08,1))
 data.apply_rock_brush(Vector3(-13.0,1.8,5.05),1.8,'rock_plane',Vector3(.45,.10,1))
 data.apply_rock_brush(Vector3(-14.15,2.1,4.65),.85,'rock_plane',Vector3(.20,.06,1))
 data.apply_rock_brush(Vector3(-13.1,3.4,4.6),1.5,'rock_plane',Vector3(.55,.85,.20))
 data.end_stroke()
