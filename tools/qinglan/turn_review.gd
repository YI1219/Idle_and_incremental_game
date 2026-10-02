extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("bcc9c5");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.2;light.shadow_enabled=true;world.add_child(light)
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;camera.position=Vector3(0,1.75,5);camera.look_at(Vector3(0,.6,0));camera.current=true
	var floor_node:=MeshInstance3D.new();floor_node.mesh=PlaneMesh.new();floor_node.scale=Vector3.ONE*20;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("96aa9f");floor_node.material_override=mat;floor_node.position.y=-.005;world.add_child(floor_node)
	var library:AnimationLibrary=load("res://assets/characters/qinglan/turn_motion.tres")
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/qinglan/turn_motion.json"))
	for clip in meta.clips:
		var models:Array[Node3D]=[]
		for i in 3:
			var model:Node3D=load("res://assets/characters/qinglan/qinglan_clothed_v04.glb").instantiate();world.add_child(model);models.append(model);model.position.x=(i-1)*1.1
			var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false);player.add_animation_library("turns",library);player.play("turns/"+clip);var time:float=float(meta.clips[clip].seconds)*i/2.;player.seek(time,true);player.pause()
			var curve:Array=meta.clips[clip].root_curve;var row:Array=curve[roundi(float(curve.size()-1)*i/2.)];model.rotation.y=float(row[1])
			var label:=Label3D.new();model.add_child(label);label.top_level=true;label.position=Vector3(model.position.x,1.3,0);label.text="%.2fs"%time;label.font_size=24;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=.002;label.modulate=Color("24352e")
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/review/turn_motion/"+clip+".png")
		for model in models:model.queue_free()
		await process_frame
	quit()
