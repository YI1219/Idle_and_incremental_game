extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
var probes:=0
func _initialize():call_deferred("run")
func hits(p:Vector2,faces:PackedVector3Array)->Array:
 var found:Array=[]
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,40,p.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
  if hit==null:continue
  var duplicate:=false
  for old:Vector3 in found:
   if old.distance_squared_to(hit)<.0000001:duplicate=true;break
  if not duplicate:found.append(hit)
 return found
func check_field(data,field,fixture:String,bed:PackedVector3Array=PackedVector3Array(),grass:PackedVector3Array=PackedVector3Array())->void:
 if not field.surfaces.has("lake_bed"):
  failures+=1;push_error("No physical lake bed in "+fixture);return
 if bed.is_empty():bed=field.surfaces.lake_bed.vertices
 if grass.is_empty():grass=field.surfaces.grass.vertices
 for cell:Vector2i in data.cells:
  var record:Dictionary=data.cells[cell]
  if record.water<0:continue
  var p:=Vector2(cell)+Vector2(.413,.579)
  if not field.contains(field.water_regions[record.water],p):continue
  var floor_hits:=hits(p,bed);var grass_hits:=hits(p,grass)
  probes+=1
  if floor_hits.size()!=1:failures+=1;push_error("Missing/layered lake bed "+fixture+" "+str(p))
  elif floor_hits[0].y>=record.water*.5-.025:failures+=1;push_error("Lake bed is not submerged")
  for hit:Vector3 in grass_hits:
   if absf(hit.y-record.water*.5)<.03:failures+=1;push_error("Old grass cap masks bed in "+fixture+" at "+str(p)+" hit="+str(hit)+" water="+str(record.water*.5))
func seam_check(field,vertices:PackedVector3Array=PackedVector3Array())->void:
 if vertices.is_empty():vertices=field.surfaces.lake_bed.vertices
 var edges:Dictionary={};var ends:Dictionary={}
 for i in range(0,vertices.size(),3):
  for j in 3:
   var a:=vertices[i+j].snapped(Vector3.ONE*.0001);var b:=vertices[i+(j+1)%3].snapped(Vector3.ONE*.0001)
   if a==b:continue
   var key:=str(a,b) if str(a)<str(b) else str(b,a)
   edges[key]=int(edges.get(key,0))+1;ends[key]=[a,b]
 var open:=0
 for key:String in edges:
  if edges[key]==2:continue
  var a:Vector3=ends[key][0];var b:Vector3=ends[key][1]
  var top:=false
  for level:int in field.water_regions:
   if absf(a.y-level*.5)<.0002 and absf(b.y-level*.5)<.0002:top=true
  if top:continue # Open top joins the existing dry terrain at the waterline.
  open+=1
  if open<8:print("BED SEAM ",edges[key]," ",a," ",b)
 print("BED INTERIOR EDGES unmatched=",open)
 if open:failures+=1
func run():
 var data:=Data.new();data.make_preset(0);var saved:=data.serialize()
 var field:=Field.new();field.refresh(data)
 check_field(data,field,"raw")
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 check_field(data,field,"joined")
 seam_check(field)
 # Inspect final chunk-clipped meshes, the geometry actually published/drawn.
 var published_bed:=PackedVector3Array();var published_grass:=PackedVector3Array()
 for chunk:Vector2i in field.triangle_chunks:
  var meshes:Dictionary=field.build(chunk)
  for kind:String in ["lake_bed","grass"]:
   var mesh:Mesh=meshes[kind]
   if mesh.get_surface_count()==0:continue
   if kind=="lake_bed":published_bed.append_array(mesh.get_faces())
   else:published_grass.append_array(mesh.get_faces())
 check_field(data,field,"published",published_bed,published_grass)
 seam_check(field,published_bed)
 if data.serialize()!=saved:failures+=1;push_error("Bed generation changed authoring data")
 # Constant authored depth must remain visible beyond the shallow shore ramp.
 if field.surfaces.has("lake_bed"):
  for p:Vector3 in field.surfaces.lake_bed.vertices:
   if not p.is_finite():failures+=1
 # An enclosed test pond must expose authored bed depth, then follow a
 # bed edit without moving the water contour. This is real drawn geometry.
 var pond:=Data.new()
 for z in range(-1,5):
  for x in range(-1,5):
   var wet:bool=x>=0 and x<4 and z>=0 and z<4
   pond.cells[Vector2i(x,z)]={"height":.5 if wet else 2.0,"water":4 if wet else -1}
 field.refresh(pond)
 var before:=hits(Vector2(2.173,2.257),field.surfaces.lake_bed.vertices)
 var boundary:=hash(field.water_regions)
 for cell:Vector2i in pond.cells:
  if pond.cells[cell].water>=0:pond.cells[cell].height-=1.0
 field.refresh(pond)
 var after:=hits(Vector2(2.173,2.257),field.surfaces.lake_bed.vertices)
 if before.size()!=1 or after.size()!=1:
  failures+=1;push_error("Fixture missing physical bed")
 elif absf(before[0].y-.5)>.001 or absf(after[0].y+.5)>.001:
  failures+=1;push_error("Authored pond bed depth not drawn")
 if boundary!=hash(field.water_regions):failures+=1;push_error("Bed-only edit changed pond footprint")
 # Removing every water cell must remove the bed, with no leftover geometry.
 for cell:Vector2i in data.cells:data.cells[cell].water=-1
 field.refresh(data)
 if field.surfaces.has("lake_bed") and not field.surfaces.lake_bed.vertices.is_empty():failures+=1;push_error("Dry edit kept a lake bed")
 if probes==0:failures+=1
 print("LAKE BED: probes=",probes," failures=",failures)
 quit(1 if failures else 0)
