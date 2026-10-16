extends RefCounted
## Local authoring study: carve the body below retained shoulders using the
## same bounded plane tool exposed to players. No private density writes.
static func author(data)->void:
 preload('res://tools/art/author_unified_cliff_cutstone.gd').author(data)
 data.begin_stroke()
 for stroke in [
  [Vector3(-17.7,-.35,2.6),2.70,Vector3(-.35,-.45,1.0)],
  [Vector3(-14.4,-.75,3.8),3.35,Vector3(.20,-.52,1.0)],
  [Vector3(-11.7,-.15,4.8),2.70,Vector3(-.32,-.38,1.0)],
  [Vector3(-15.3,1.25,3.8),1.35,Vector3(.85,-.10,1.0)]]:
  data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2].normalized())
 data.end_stroke()

static func lip_study(data)->void:
 preload('res://tools/art/author_unified_cliff_cutstone.gd').author(data)
 data.begin_stroke()
 data.apply_rock_brush(Vector3(-13.4,2.65,4.3),1.25,'rock_shoulder',Vector3(.30,0,1).normalized())
 for stroke in [
  [Vector3(-16.45,3.8,3.15),1.60,Vector3(.20,1.0,.10)],
  [Vector3(-14.7,3.4,4.25),1.25,Vector3(.30,-.10,1.0)],
  [Vector3(-12.6,2.7,4.85),1.35,Vector3(-.40,.10,1.0)],
  [Vector3(-15.3,.25,3.7),1.80,Vector3(.40,-.70,1.0)]]:
  data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2].normalized())
 data.end_stroke()
