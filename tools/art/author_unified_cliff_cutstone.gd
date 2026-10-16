extends RefCounted
## Authored strokes through the same production brush that players use.
static func author(data)->void:
 data.begin_stroke()
 for stroke in [
  [Vector3(-16.2,1.5,3.0),1.95,-.30],
  [Vector3(-14.0,1.0,4.0),1.55,.18],
  [Vector3(-12.3,.7,4.75),1.15,-.12],
  [Vector3(-16.25,3.10,2.8),1.05,-.30]]:
  var yaw:float=stroke[2]
  data.apply_rock_brush(stroke[0],stroke[1],'rock_shoulder',Vector3(sin(yaw),0,cos(yaw)))
 data.end_stroke()

static func full_island(data)->void:
 author(data)
 data.begin_stroke()
 # Explicit authored perimeter strokes; not runtime stone scattering.
 for stroke in [
  [Vector3(-18.6,1.25,.3),1.70,-.80],
  [Vector3(-9.6,1.35,5.5),1.75,.25],
  [Vector3(-6.8,1.0,7.0),1.80,-.10],
  [Vector3(-3.7,.7,7.6),1.50,.20],
  [Vector3(.0,-.2,8.6),1.45,.10],
  [Vector3(2.5,-.55,9.5),1.65,-.15],
  [Vector3(5.2,-.60,10.0),1.50,.20],
  [Vector3(7.6,-.45,10.0),1.30,.05],
  [Vector3(13.9,-.35,8.1),1.65,.65],
  [Vector3(16.2,-.50,5.5),1.80,1.05],
  [Vector3(17.4,-.60,2.7),1.55,1.65],
  [Vector3(17.0,-.60,0.0),1.75,1.95],
  [Vector3(14.3,-.40,-3.0),1.65,2.65],
  [Vector3(10.7,-.50,-4.1),1.55,3.0],
  [Vector3(7.8,.70,-6.0),1.60,3.15],
  [Vector3(4.7,1.4,-8.0),1.75,2.8],
  [Vector3(1.0,1.5,-10.2),1.80,3.0],
  [Vector3(-2.2,1.4,-11.2),1.40,3.2],
  [Vector3(-5.4,1.1,-11.5),1.80,3.0],
  [Vector3(-9.1,1.4,-11.1),1.70,3.45],
  [Vector3(-12.5,1.3,-10.0),1.65,3.7],
  [Vector3(-16.1,1.3,-7.7),1.80,4.0],
  [Vector3(-18.7,1.2,-4.3),1.60,4.5],
  [Vector3(-20.0,1.1,-1.0),1.50,4.5],
  [Vector3(15.8,1.15,5.4),1.00,1.05],
  [Vector3(4.8,3.05,-8.1),1.00,2.8],
  [Vector3(-18.4,3.1,-4.2),1.00,4.5]]:
  var yaw:float=stroke[2]
  data.apply_rock_brush(stroke[0],stroke[1],'rock_shoulder',Vector3(sin(yaw),0,cos(yaw)))
 data.end_stroke()
