extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0)
 for state in ["default","dry","contract"]:
  if state=="dry":
   data.begin_stroke();data.apply_brush(Vector2(-3,0),6.0,"dry",false,1.5,3);data.end_stroke()
  if state=="contract":
   data.undo();data.begin_stroke();data.apply_brush(Vector2(12,4),2.2,"contract",false,1.5,3);data.end_stroke()
  var field:=Field.new();field.refresh(data)
  var deco:=Deco.new();deco.load_assets();deco.contours=field
  var chunks:Dictionary={};var counts:Dictionary={};var bad:=0
  for cell:Vector2i in data.cells:chunks[Data.chunk_of(cell)]=true
  for chunk:Vector2i in chunks:
   var placed:=deco.placements(data,chunk)
   bad+=placed.grass.size() # Squashed broad blades read as loose discs.
   for pose:Transform3D in placed.vine:
    var at:=Vector2(pose.origin.x,pose.origin.z);var support:=field.surface_at(at)
    if pose.basis.y.normalized().y<.2 and not support.is_empty() and support.water<0 and pose.origin.y>=support.height-.05:bad+=1
   for kind in ["grass_clump","reeds","lily"]:
    counts[kind]=counts.get(kind,0)+placed[kind].size()
    for pose:Transform3D in placed[kind]:
     var p:=Vector2(pose.origin.x,pose.origin.z);var distance:=INF
     for level:int in field.water_regions:
      if absf(level*.5-pose.origin.y)>.15:continue
      for loop:PackedVector2Array in field.water_regions[level]:
       for i in loop.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[i],loop[(i+1)%loop.size()])))
     if kind!="lily" and distance>.85:bad+=1
     if kind=="lily":
      for part:Dictionary in deco.assets.lily:
       for v:Vector3 in part.mesh.get_faces():
        var world:Vector3=pose*part.pose*v;var support:=field.surface_at(Vector2(world.x,world.z))
        if support.is_empty() or support.water<0 or absf(support.height-(pose.origin.y-.06))>.01:bad+=1;break
   # Shore cleanup must still keep living water decoration in the default.
  if state=="default" and (counts.lily<3 or counts.reeds<3):bad+=1
  failures+=bad
  print("SHORE PROPS ",state,": ",counts," invalid=",bad)
 quit(0 if failures==0 else 1)
