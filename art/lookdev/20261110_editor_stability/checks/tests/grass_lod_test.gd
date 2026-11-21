extends SceneTree
const Grass=preload("res://scripts/terrain_editor/grass_field.gd")
var checks:int=0
var failures:int=0
var view:SubViewport
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func primitive_count(distance:float)->int:
	camera.position=Vector3(0,.16+distance*.3,distance)
	camera.look_at(Vector3(0,.12,0))
	for i in 5:RenderingServer.force_draw(false);await process_frame
	return view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
func run()->void:
	if DisplayServer.get_name()=="headless":push_error("LOD rendering test requires native renderer");quit(1);return
	view=SubViewport.new();view.size=Vector2i(160,160);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var mesh:ArrayMesh=Grass.clump_mesh()
	var before:GDScript=load("res://art/lookdev/20261110_editor_stability/checks/source_before/scripts/terrain_editor/grass_field.gd")
	var original:ArrayMesh=before.clump_mesh()
	var a:Array=mesh.surface_get_arrays(0);var b:Array=original.surface_get_arrays(0)
	check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX] and a[Mesh.ARRAY_NORMAL]==b[Mesh.ARRAY_NORMAL],"full grass positions and normals remain exact")
	check(a[Mesh.ARRAY_COLOR]==b[Mesh.ARRAY_COLOR] and a[Mesh.ARRAY_TEX_UV]==b[Mesh.ARRAY_TEX_UV],"grass pigments and leaf coordinates remain exact")
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=1;mm.set_instance_transform(0,Transform3D.IDENTITY)
	var instance:=MultiMeshInstance3D.new();instance.multimesh=mm;instance.custom_aabb=AABB(Vector3(-.5,-.1,-.5),Vector3(1,1,1))
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;instance.material_override=material
	view.add_child(instance);camera=Camera3D.new();camera.near=.01;view.add_child(camera)
	var near_count:int=await primitive_count(.6)
	var far_count:int=await primitive_count(25)
	check(near_count>0 and far_count>0,"grass remains rendered at near and far distances")
	check(far_count<near_count*.65,"distant grass uses fewer real triangles instead of drawing invisible detail")
	print("GRASS LOD ",near_count," -> ",far_count,"; ",checks," checks, ",failures," failures")
	view.free();quit(1 if failures else 0)
