extends RefCounted
## Bounded art study: replace a broad rim mass using the player's own tools.
## These are authored strokes, not hidden density writes or runtime scattering.
static func author(data,compact:bool=false)->void:
 data.begin_stroke()
 # Remove the old wall across its mid-height before adding unequal main masses.
 for stroke in [
  [Vector3(-16.0,.8,2.45),3.7,Vector3(-.20,.12,1)],
  [Vector3(-12.8,.5,3.80),3.3,Vector3(.15,.10,1)]]:
  var changed:int=data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2].normalized())
  print('MASS CUT: ',changed)
 var shoulders=[
  [Vector3(-16.35,.55,1.95),2.95,-.28],
  [Vector3(-12.65,.05,3.35),2.30,.24]]
 if compact:shoulders=[
  [Vector3(-16.35,1.20,1.95),2.50,-.40],
  [Vector3(-12.65,.70,3.15),2.00,.38]]
 for stroke in shoulders:
  var yaw:float=stroke[2]
  var changed:int=data.apply_rock_brush(stroke[0],stroke[1],'rock_shoulder',Vector3(sin(yaw),0,cos(yaw)))
  print('MASS SHOULDER: ',changed)
 data.end_stroke()

static func finish(data)->void:
 data.begin_stroke()
 # Turn the main faces diagonally; trim the raised crown and return the
 # low front into the common body instead of leaving two upright slabs.
 for stroke in [
  [Vector3(-16.3,4.10,2.8),3.6,Vector3(-.12,1,.18)],
  [Vector3(-15.25,1.45,4.05),3.0,Vector3(.75,.18,1)],
  [Vector3(-12.10,.7,4.75),2.6,Vector3(-.65,.12,1)],
  [Vector3(-16.1,-1.6,3.6),3.7,Vector3(-.15,-.70,1)],
  [Vector3(-12.6,-1.6,4.8),2.8,Vector3(.15,-.65,1)]]:
  var changed:int=data.apply_rock_brush(stroke[0],stroke[1],'rock_plane',stroke[2].normalized())
  print('MASS TURN: ',changed)
 data.end_stroke()
