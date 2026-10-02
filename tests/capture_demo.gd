extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/review/demo/"+name+".png")
func run() -> void:
	var scene:Node=load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	var player:=get_first_node_in_group("player")
	var rig:=get_first_node_in_group("camera_rig")
	var state:=root.get_node("SpaceState")
	var space:=get_first_node_in_group("space_controller")
	await shot("courtyard")
	rig._distance=6.5
	rig.snap_to_target()
	await shot("character")
	state.player_x=4.3
	state.player_z=1.5
	space.sync_after_relocation()
	rig._distance=10.0
	rig.snap_to_target()
	await shot("river_bridge")
	state.player_x=-3.8
	state.player_z=.55
	space.sync_after_relocation()
	player.mesh.rotation.y=0
	player.set_physics_process(false)
	player._animation.play("attack_1")
	player._animation.seek(.2,true)
	player._animation.pause()
	get_first_node_in_group("combat_arena").strike(player)
	rig._distance=7.5
	rig.snap_to_target()
	await shot("combat")
	player.set_physics_process(true)
	state.player_x=state.home_arrival().x
	state.player_z=state.home_arrival().z
	state.enter("inside")
	await shot("interior")
	quit()
