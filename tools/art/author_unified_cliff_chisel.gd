extends RefCounted
## Explicit subtractive author strokes, identical to player plane operations.
static func author(data)->void:
 data.begin_stroke()
 # Open face cuts cross the top and lower wall, avoiding a retained thin lip.
 for stroke in [
  [Vector3(-16.0,3.4,2.9),2.1,Vector3(.32,.0,1.0)],
  [Vector3(-16.0,1.2,2.9),2.1,Vector3(.32,.0,1.0)],
  [Vector3(-16.0,-1.0,2.9),2.1,Vector3(.32,.0,1.0)],
  [Vector3(-12.4,3.4,4.1),1.65,Vector3(-.30,.0,1.0)],
  [Vector3(-12.4,1.6,4.1),1.65,Vector3(-.30,.0,1.0)],
  [Vector3(-12.4,-.2,4.1),1.65,Vector3(-.30,.0,1.0)],
  # Broad lower return joins the untouched common body below these faces.
  [Vector3(-16.4,-.8,2.9),3.8,Vector3(.12,-.42,1.0)],
  [Vector3(-12.6,-.8,4.2),3.7,Vector3(-.18,-.38,1.0)]]:
  data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2].normalized())
 data.end_stroke()
