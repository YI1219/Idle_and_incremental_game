extends SceneTree
## Every interior probe meets exactly one shallow closure face. Side stones
## may overlap that backing, but the bottom itself must not be layered rubble.
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco.contours=field;deco._column_layout(field,data.seed)
 var faces:=PackedVector3Array()
 var surface=field.surfaces.cliff
 for i in range(0,surface.vertices.size(),3):
  if surface.uv[i].y>-.99:continue
  for j in 3:faces.append(surface.vertices[i+j])
 var probes:=0;var layered:=0;var misses:=0;var steep:=0
 for z in range(-6,7):
  for x in range(-16,17):
   var p:=Vector2(x+.137,z+.293);var interior:=true
   for j in 16:
    if field.surface_at(p+Vector2.from_angle(j*TAU/16)*4.0).is_empty():interior=false
   if not interior:continue
   probes+=1;var heights:Array=[]
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,-15,p.y),Vector3.UP,faces[i],faces[i+1],faces[i+2])
    if hit==null or hit.y>=0:continue
    var duplicate:=false
    for h:float in heights:
     if absf(h-hit.y)<.003:duplicate=true
    if duplicate:continue
    heights.append(hit.y)
    var normal:Vector3=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
    if absf(normal.y)<.94:steep+=1
   if heights.is_empty():misses+=1
   if heights.size()>1:layered+=1
 var ok:bool=probes>80 and misses==0 and layered==0 and steep<=probes*.05
 print("SCULPTED BOTTOM COVERAGE: ",JSON.stringify({"probes":probes,"layered":layered,"misses":misses,"steep":steep,"passed":ok}))
 quit(0 if ok else 1)
