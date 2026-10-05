extends SceneTree
# Real retained cottage plaster at wall/gable heights must share warm timber treatment.
const Props=preload("res://scripts/terrain_editor/terrain_props.gd")
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func find_mesh(node:Node)->MeshInstance3D:
	if node is MeshInstance3D:return node
	for child in node.get_children():
		var found:=find_mesh(child)
		if found!=null:return found
	return null
func patch(material:Material,center:Vector3)->MeshInstance3D:
	var vertices:=PackedVector3Array()
	for offset in [Vector3(-.65,-.65,0),Vector3(.65,-.65,0),Vector3(-.65,.65,0),Vector3(.65,.65,0)]:vertices.append(center+offset)
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,1,2,3])
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	var instance:=MeshInstance3D.new()
	instance.mesh=mesh
	return instance
func sample(image:Image,camera:Camera3D,center:Vector3,radius:int=12)->Color:
	var p:=Vector2i(camera.unproject_position(center))
	var sum:=Color(0,0,0,0)
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):sum+=image.get_pixel(p.x+x,p.y+y)
	return sum/float((radius*2+1)*(radius*2+1))
func run()->void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene:=Node3D.new()
	viewport.add_child(scene)
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color(.08,.08,.08)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=1.0
	environment.environment=settings
	scene.add_child(environment)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=5.0
	camera.position=Vector3(0,2.3,8)
	scene.add_child(camera)
	camera.current=true
	var source=load("res://assets/buildings/cottage/cottage_tripo.glb").instantiate()
	var mesh:=find_mesh(source)
	var plaster:StandardMaterial3D
	for surface in mesh.mesh.get_surface_count():
		var material:=mesh.get_active_material(surface)
		if material.resource_name=="Plaster_corrected":plaster=material
	check(plaster!=null,"Retained cottage plaster material missing")
	if plaster==null:quit(1);return
	var original_color:=plaster.albedo_color
	var props:=Props.new()
	var centers:=[Vector3(0,1.2,0),Vector3(0,3.3,0)]
	for center:Vector3 in centers:
		var instance:=patch(plaster,center)
		scene.add_child(instance)
		props._roof_detail(instance)
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	var wall:=sample(image,camera,centers[0])
	var gable:=sample(image,camera,centers[1])
	print("COTTAGE MATERIAL SAMPLES wall=",wall," gable=",gable)
	check(wall.r-wall.g>.06,"Wall plaster must receive a warm timber finish")
	check(gable.r-gable.g>.06,"Gable plaster must receive timber, not height-based roof shading")
	check(absf((wall.r-wall.g)-(gable.r-gable.g))<.055,"Wall and gable timber should have consistent warmth")
	check(absf(wall.r-gable.r)<.07,"Plaster gable must not switch to a brighter roof finish above 2.3 metres")
	check(plaster.albedo_color==original_color,"Workshop shading must not modify retained source material")
	# The same panel post must remain on its local coordinates as the view changes.
	var post_point:=Vector3(.385,1.2,0)
	var front:=sample(image,camera,post_point,1)
	camera.position=Vector3(6.928203,2.3,4)
	camera.look_at(Vector3(0,2.3,0))
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var oblique:=sample(viewport.get_texture().get_image(),camera,post_point,1)
	print("COTTAGE PANEL VIEW SAMPLES front=",front," oblique=",oblique)
	check(maxf(absf(front.r-oblique.r),absf(front.g-oblique.g))<.045,"Panel post projection must stay in model space when the camera changes")
	source.free()
	props.free()
	print("COTTAGE MATERIAL CHECKS: ",checks," failures: ",failures)
	quit(0 if failures==0 else 1)
