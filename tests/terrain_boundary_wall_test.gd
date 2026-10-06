extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var samples:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
 # Every boundary of the lowest occupied level must own a supporting wall.
 # Independently smoothed upper outlines can extend past this boundary;
 # querying them to decide whether a deep wall is exposed used to omit it.
 for operation in ["default","raise","lower","expand","contract"]:
  var data:=Data.new();data.make_preset(0)
  if operation!="default":
   var center:Vector2={"raise":Vector2(-13,2),"lower":Vector2(13,7),"expand":Vector2(18,4),"contract":Vector2(3,7)}[operation]
   var radius:float={"raise":2.3,"lower":2.0,"expand":2.6,"contract":2.2}[operation]
   data.begin_stroke();data.apply_brush(center,radius,operation,false,1.5,3);data.end_stroke()
  var field:=Contours.new();field.refresh(data)
  var faces:PackedVector3Array=field.surfaces.cliff.vertices
  var missing:=0
  for loop:PackedVector2Array in field.land_regions[field.levels[0]]:
   for i in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()];var p:=(a+b)*.5
    var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
    # Probe halfway below the local supporting terrace. A fixed -2 world
    # plane lies below the deliberately shortened shell in the homestead pass.
    var profile:=field._cliff_profile(p,out)
    field._outer_profile(p,out,profile)
    var probe_y:float=lerpf(profile.top,field._shell_floor(p,profile.top),.5)
    var origin:=Vector3(p.x+out.x*3,probe_y,p.y+out.y*3)
    var direction:=Vector3(-out.x,0,-out.y)
    var nearest:=INF
    for j in range(0,faces.size(),3):
     var va:=faces[j];var vb:=faces[j+1];var vc:=faces[j+2]
     if origin.y<minf(va.y,minf(vb.y,vc.y)) or origin.y>maxf(va.y,maxf(vb.y,vc.y)):continue
     var hit=Geometry3D.ray_intersects_triangle(origin,direction,va,vb,vc)
     if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
    samples+=1
    if nearest>6:
     missing+=1;failures+=1;push_error("%s outer wall missing beneath %s (nearest %s)"%[operation,p,nearest])
  print("BOUNDARY WALL ",operation,": ",missing," missing")
 print("TERRAIN BOUNDARY WALL: %d samples, %d failures"%[samples,failures])
 quit(1 if failures else 0)
