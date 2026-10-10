extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():call_deferred("run")
func inside(point:Vector3,faces:PackedVector3Array)->bool:
 var direction:=Vector3(.937,.231,.265).normalized()
 var hits:Array[Vector3]=[]
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(point,direction,faces[i],faces[i+1],faces[i+2])
  if hit==null:continue
  var duplicate:=false
  for previous:Vector3 in hits:
   if previous.distance_squared_to(hit)<.000001:duplicate=true
  if not duplicate:hits.append(hit)
 return hits.size()%2==1
func run():
 var data:=Data.new();data.make_preset(0)
 var original:=data.serialize()
 var tested:=0;var blocked:=0
 for operation in ["default","expand","contract"]:
  data.deserialize(original)
  if operation!="default":
   data.begin_stroke();data.apply_brush(Vector2(3,7),2.2,operation,false,1.5,3);data.end_stroke()
  var field:=Contours.new();field.refresh(data)
  var deco:=Decoration.new();deco.load_assets();deco._column_layout(field,data.seed)
  for veil:Dictionary in field.fall_veils:
   var out:=Vector3(veil.out.x,0,veil.out.y)
   var tangent:=Vector3(-out.z,0,out.x)
   for side in [-.8,-.4,0.0,.4,.8]:
    for down in [.2,.4,.6,.8]:
     var point:Vector3=veil.lip.lerp(veil.foot,down)+tangent*veil.half_width*side+out*.05
     tested+=1
     for stone:Dictionary in deco._columns+deco._mass:
      var mesh:Mesh=deco.assets[stone.kind][0].mesh
      var local:Vector3=stone.pose.affine_inverse()*point
      if not mesh.get_aabb().has_point(local):continue
      if inside(local,mesh.get_faces()):blocked+=1;break
 print("ROCK/FALL CLEARANCE: ",tested," curtain samples, ",blocked," inside stones")
 quit(1 if blocked else 0)
