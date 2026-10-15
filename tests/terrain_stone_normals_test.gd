extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred('run')
func run()->void:
 var path:='res://scripts/terrain_editor/stone_normals.gd'
 check(ResourceLoader.exists(path),'Crease-aware stone normal baker exists')
 if failures:quit(1);return
 var softer=load(path)
 var builder=load('res://scripts/terrain_editor/chunk_geometry.gd').Surface.new()
 builder.triangle(Vector3.ZERO,Vector3(1,0,0),Vector3(0,0,1),Color.WHITE)
 builder.triangle(Vector3.ZERO,Vector3(0,0,1),Vector3(-1,.35,0),Color.WHITE)
 var mesh:ArrayMesh=builder.mesh()
 var material:=StandardMaterial3D.new();mesh.surface_set_material(0,material)
 var result:ArrayMesh=softer.soften(mesh,55.0,.85)
 var a:=mesh.surface_get_arrays(0);var b:=result.surface_get_arrays(0)
 for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR]:check(a[slot]==b[slot],'Original geometry/UV/color preserved')
 check(result.surface_get_material(0)==material,'Source material retained')
 var n:PackedVector3Array=b[Mesh.ARRAY_NORMAL]
 check(n[0].angle_to(n[3])<deg_to_rad(5.0),'Shallow fracture reduces the normal break below five degrees')
 check(not n[0].is_equal_approx(a[Mesh.ARRAY_NORMAL][0]),'Normal softening is effective')
 for value:Vector3 in n:check(value.is_finite() and absf(value.length()-1.0)<.001,'Normals finite and normalized')
 var cube:=BoxMesh.new();var box:=ArrayMesh.new();box.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cube.get_mesh_arrays())
 var sharp:ArrayMesh=softer.soften(box,55.0,.85)
 var before:PackedVector3Array=box.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 var after:PackedVector3Array=sharp.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 check(before==after,'Right-angle corner remains sharp')
 check(box.surface_get_arrays(0)[Mesh.ARRAY_INDEX]==sharp.surface_get_arrays(0)[Mesh.ARRAY_INDEX],'Indexed topology preserved')
 print('STONE NORMALS: %d/%d'%[checks-failures,checks]);quit(1 if failures else 0)
