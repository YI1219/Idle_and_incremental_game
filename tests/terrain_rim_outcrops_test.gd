extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func build(data)->Array:
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 return [field,deco]
func signature(deco)->String:
 var result:=PackedStringArray()
 for rock:Dictionary in deco._outcrops:result.append(str(rock.kind,rock.pose))
 return "|".join(result)
func cap_contains(p:Vector2,grass:PackedVector3Array,height:float)->bool:
 # Inclusive barycentric ownership of the actual horizontal cap. A vertical
 # ray exactly on a new scanline edge can miss both triangles through float
 # rounding; four 20-micron neighbor probes reproduced that ambiguity.
 for i in range(0,grass.size(),3):
  if absf(grass[i].y-height)>.01:continue
  var a:=Vector2(grass[i].x,grass[i].z)
  var ab:=Vector2(grass[i+1].x,grass[i+1].z)-a
  var ac:=Vector2(grass[i+2].x,grass[i+2].z)-a
  var det:=ab.cross(ac)
  if absf(det)<1e-10:continue
  var u:=(p-a).cross(ac)/det;var v:=ab.cross(p-a)/det
  if u>=-.000001 and v>=-.000001 and u+v<=1.000001:return true
 return false
func inspect(field,deco,label:String)->void:
 var bad:=0;var points:=0;var high:=0;var low:=0;var detached:=0
 for rock:Dictionary in deco._outcrops:
  var mesh:Mesh=deco.assets[rock.kind][0].mesh
  var bounds:AABB=rock.pose*mesh.get_aabb()
  if bounds.end.y-rock.height>.85:high+=1
  else:low+=1
  # Independent rays against actual stone and cap triangles verify the
  # block crosses the land plane, rather than resting as a separate prop.
  var faces:=PackedVector3Array()
  for v:Vector3 in mesh.get_faces():faces.append(rock.pose*v)
  var rock_points:=0;var backed:=0;var connected:=0
  for z in range(floori(bounds.position.z*5),ceili(bounds.end.z*5)+1):
   for x in range(floori(bounds.position.x*5),ceili(bounds.end.x*5)+1):
    var origin:=Vector3(x*.2,bounds.end.y+1,z*.2);var hit:=false;var bottom:=INF;var top:=-INF
    for i in range(0,faces.size(),3):
     var point=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
     if point!=null:hit=true;bottom=minf(bottom,point.y);top=maxf(top,point.y)
    if not hit:continue
    points+=1;rock_points+=1
    var cap_hit:=cap_contains(Vector2(origin.x,origin.z),field.surfaces.grass.vertices,rock.height)
    if cap_hit:
     backed+=1
     if bottom<rock.height-.10 and top>rock.height+.05:connected+=1
    else:
     var p:=Vector2(origin.x,origin.z);var distance:=INF
     for loop:PackedVector2Array in field.rim_regions.get(rock.height,[]):
      for j in loop.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[j],loop[(j+1)%loop.size()])))
     if distance>.37:bad+=1
    var wet:Dictionary=field.surface_at(Vector2(origin.x,origin.z))
    if not wet.is_empty() and wet.water>=0:bad+=1
  if rock_points==0 or float(backed)/rock_points<.58 or connected<4:detached+=1
 check(points>0,label+": non-vacuous rock footprint samples")
 check(bad==0,label+": only bounded exterior overhangs; no lake overlap")
 check(detached==0,label+": each cliff block crosses and connects through the terrain cap")
 print(label,": rocks=",deco._outcrops.size()," tall=",high," low=",low," support_samples=",points," invalid=",bad," detached=",detached)
 if label=="default":
  check(high>=3 and low>=3,"Distinct tall bedrock and low rough shelves")
  check(deco._outcrops.size()<deco._columns.size(),"Most rim spans remain open rather than a continuous rock fence")
func run()->void:
 var data:=Data.new();data.make_preset(0)
 var first:=build(data);inspect(first[0],first[1],"default")
 var initial:=signature(first[1])
 check(initial==signature(build(data)[1]),"Unchanged terrain rebuild is deterministic")
 if first[1]._outcrops.is_empty():quit(1);return
 var target:Vector2=first[1]._outcrops[0].anchor
 for mode:String in ["contract","raise","water"]:
  if mode=="water":
   for rock:Dictionary in first[1]._outcrops:
    if rock.height<3.0:target=rock.anchor;break
  data.begin_stroke();data.apply_brush(target,2.2,mode,false,1.5,7);data.end_stroke()
  var changed:=build(data)
  if not changed[1]._outcrops.is_empty():inspect(changed[0],changed[1],mode)
  check(signature(changed[1])!=initial,mode+": affected outcrops regenerate")
  check(data.undo(),mode+": undo available")
  check(signature(build(data)[1])==initial,mode+": undo restores exact rocks")
 print("RIM OUTCROPS: %d/%d"%[checks-failures,checks])
 quit(1 if failures else 0)
