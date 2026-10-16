extends RefCounted
## Explicit strokes shared with the runtime editor; a shape study only.
static func author(data)->void:
 data.begin_stroke()
 data.apply_rock_brush(Vector3(-14.8,.45,3.65),3.1,'rock_add')
 data.apply_rock_brush(Vector3(-15.05,2.65,3.7),2.65,'rock_add')
 data.apply_rock_brush(Vector3(-12.4,1.7,4.4),2.1,'rock_add')
 data.apply_rock_brush(Vector3(-15,4.65,4),4,'rock_plane',Vector3(.18,1,.10))
 data.apply_rock_brush(Vector3(-14.5,1.5,5.15),4,'rock_plane',Vector3(-.20,.02,1))
 data.apply_rock_brush(Vector3(-14.5,3.5,5.11),4,'rock_plane',Vector3(-.20,.02,1))
 data.apply_rock_brush(Vector3(-14.3,-1,4.9),4,'rock_plane',Vector3(.12,-.12,1))
 data.apply_rock_brush(Vector3(-17,1.4,4),4,'rock_plane',Vector3(-1,.10,.25))
 data.apply_rock_brush(Vector3(-16.6,2.6,4.8),4,'rock_plane',Vector3(-.75,.10,.6))
 data.apply_rock_brush(Vector3(-12,3.15,4.7),3,'rock_plane',Vector3(.4,.9,.15))
 data.apply_rock_brush(Vector3(-13.4,3.5,4.5),3,'rock_plane',Vector3(.65,.6,.22))
 data.end_stroke()
