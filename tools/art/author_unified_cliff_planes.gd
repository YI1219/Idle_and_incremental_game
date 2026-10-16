extends RefCounted
## Explicit strokes: a broad shoulder, one turned neighbor and a recessed seam.
## This authors the same solid that players edit, without placing rock models.
static func author(data)->void:
 data.begin_stroke()
 for stroke in [
  [Vector3(-16.25,3.4,2.95),1.55],
  [Vector3(-14.7,2.8,3.6),1.65],
  [Vector3(-12.7,2.2,4.35),1.30]]:
  data.apply_rock_brush(stroke[0],stroke[1],'rock_add')
 # Broad, shallowly sloped crown. A larger plane brush reaches the whole
 # shoulder; the earlier small brushes only pressed dents into round blobs.
 for stroke in [
  [Vector3(-16.2,4.28,3.1),3.8,Vector3(-.12,1,.12)],
  [Vector3(-16.0,2.1,3.95),3.8,Vector3(-.32,.12,1)],
  [Vector3(-17.25,2.8,2.9),3.5,Vector3(-1,.12,.14)],
  [Vector3(-14.45,2.1,4.05),3.0,Vector3(.33,.03,1)],
  [Vector3(-13.1,3.05,4.0),2.8,Vector3(.15,1,.32)],
  [Vector3(-12.4,1.1,4.75),3.0,Vector3(.40,.14,1)]]:
  data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2])
 # A local oblique chisel creates a quiet recession between unequal fronts.
 data.apply_rock_brush(Vector3(-14.65,2.6,4.0),1.15,'rock_plane',Vector3(-.55,.18,1))
 data.end_stroke()
