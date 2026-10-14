extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var path:="res://scripts/terrain_editor/textured_nature.gd"
 check(ResourceLoader.exists(path),"Material-preserving nature loader must exist")
 if failures:quit(1);return
 var loader=load(path)
 for spec in [["CommonTree_5",4.15],["Bush_Common",.65],["Flower_3_Group",.3],["Grass_Wispy_Short",.2]]:
  var part:Dictionary=loader.build(spec[0],spec[1])
  var mesh:ArrayMesh=part.mesh
  var box:=mesh.get_aabb()
  check(absf(box.position.y)<.001,"Retained asset roots grounded: "+spec[0])
  check(absf(box.size.y-spec[1])<.001,"Common authored height across material parts: "+spec[0])
  check(part.pose==Transform3D.IDENTITY,"Transforms baked for support and instancing")
  check(mesh.get_surface_count()>=1,"Retained surfaces present")
  for surface in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(surface)
   check(arrays[Mesh.ARRAY_TEX_UV]!=null and arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Source UVs retained")
   var mat:ShaderMaterial=mesh.surface_get_material(surface)
   check(mat!=null and mat.get_shader_parameter("albedo_tex")!=null,"Each source material has its texture")
   check(mat.get_shader_parameter("albedo_tex").get_image().has_mipmaps(),"Nature textures have mip chains for stable distant leaves")
   var index:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   check(not index.is_empty(),"Source topology retained")
  if spec[0]=="CommonTree_5":
   check(mesh.get_surface_count()==2,"Bark and leaf surfaces remain distinct")
   check(mesh.surface_get_material(0).get_shader_parameter("is_leaf")!=mesh.surface_get_material(1).get_shader_parameter("is_leaf"),"Bark must not receive leaf alpha/normal treatment")
 check_source_shape()
 print("TEXTURED NATURE: %d/%d passed"%[checks-failures,checks])
 quit(1 if failures else 0)

# Independently walk the retained source. Both bark and canopy must undergo
# exactly the same similarity transform: no branch/leaf drift or missing faces.
func collect_source(node:Node,parent:Transform3D,triangles:Array)->void:
 var pose:=parent
 if node is Node3D:pose=parent*node.transform
 if node is MeshInstance3D:
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var index:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var points:=PackedVector3Array()
   for i in index:points.append(pose*vertices[i])
   triangles.append(points)
 for child in node.get_children():collect_source(child,pose,triangles)
func check_source_shape()->void:
 var source=load("res://assets/nature/quaternius/CommonTree_5.gltf").instantiate()
 var expected:Array=[]
 collect_source(source,Transform3D.IDENTITY,expected)
 var lo:=Vector3(INF,INF,INF);var hi:=-lo
 for surface:PackedVector3Array in expected:
  for p:Vector3 in surface:lo=lo.min(p);hi=hi.max(p)
 var foot:=Vector3((lo.x+hi.x)*.5,lo.y,(lo.z+hi.z)*.5)
 var scale3:=4.15/(hi.y-lo.y)
 var model=load("res://scripts/terrain_editor/terrain_models.gd").new();model.load_assets()
 var mesh:ArrayMesh=model.assets.tree[0].mesh
 check(mesh.get_surface_count()==expected.size(),"Runtime tree retains all source surfaces")
 for surface in mini(mesh.get_surface_count(),expected.size()):
  var arrays:=mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var index:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  check(index.size()==expected[surface].size(),"Runtime tree retains all source triangles")
  var max_error:=0.0
  for i in mini(index.size(),expected[surface].size()):max_error=maxf(max_error,vertices[index[i]].distance_to((expected[surface][i]-foot)*scale3))
  check(max_error<.0001,"Bark and leaves preserve their source relation after grounding")
 source.free()
