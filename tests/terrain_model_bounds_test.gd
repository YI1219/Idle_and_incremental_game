extends SceneTree
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func leaf_mesh(unused:bool)->MeshInstance3D:
 var node:=MeshInstance3D.new()
 var arrays:Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 var points:=PackedVector3Array([Vector3(-1,2,-1),Vector3(1,2,-1),Vector3(0,4,1),Vector3(0,2,1)])
 if unused:points.append(Vector3(20,-20,20))
 arrays[Mesh.ARRAY_VERTEX]=points
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3,1,3,2,0,3,1])
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new()
 material.resource_name="leafsGreen"
 mesh.surface_set_material(0,material)
 node.mesh=mesh
 return node
func run()->void:
 var model:=Models.new()
 for kind in ["tree_leaf","bush","vine"]:
  var plain:=leaf_mesh(false)
  var padded:=leaf_mesh(true)
  var first:Array=[]
  var second:Array=[]
  model._extract(plain,Transform3D.IDENTITY,first,kind)
  model._extract(padded,Transform3D.IDENTITY,second,kind)
  check(first.size()==1 and second.size()==1,"leaf surface extracted for "+kind)
  var a:PackedVector3Array=first[0].mesh.get_faces()
  var b:PackedVector3Array=second[0].mesh.get_faces()
  var identical:=a.size()==b.size()
  for i in a.size():
   if not a[i].is_equal_approx(b[i]):identical=false
  check(identical,"unused non-leaf vertices cannot distort active leaf geometry for "+kind)
  check(first[0].pose.is_equal_approx(second[0].pose),"unused vertices cannot change leaf anchoring for "+kind)
  plain.free();padded.free()
 print("TERRAIN MODEL BOUNDS: %d/%d passed"%[checks-failures,checks])
 quit(1 if failures else 0)
