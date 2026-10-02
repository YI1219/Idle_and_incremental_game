extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/play.tscn").instantiate()
	root.add_child(game)
	for i in 8: await process_frame
	var art = game.get_node("Homestead/CourtyardArt")
	var island = get_first_node_in_group("island_shell")
	var space = get_first_node_in_group("space_controller")
	var state = root.get_node("SpaceState")
	var environment: Environment = game.get_node("WorldEnvironment").environment
	check(art.models.size()==8,"All licensed nature modules load")
	check(art.get_node("NatureCommunities").get_child_count()==6,"Default nature consists of six independent editable props")
	check(environment.background_mode==Environment.BG_SKY,"Courtyard uses atmospheric sky")
	art.position=Vector3(2,0,1)
	art.rotation.y=.4
	var probe_position := Vector3(-5,0,-4.5)
	var probe = art.add_model("Rock_Medium_1",probe_position,.4,.8)
	check(probe.global_position.distance_to(probe_position)<.0001,"World placement survives a transformed art parent")
	check(absf(probe.global_rotation.y-.8)<.0001,"World yaw survives a transformed art parent")
	probe.free()
	art.transform=Transform3D.IDENTITY
	var ground_material = island.terrain.get_node("LandSurface").material_override
	island.rebuild_instances()
	check(island.terrain.get_node("LandSurface").material_override==ground_material,"Ground art survives building refresh")
	for destination in ["inside","explore","outside"]:
		state.space_id=destination
		space.sync_after_relocation()
		check(art.visible==(destination=="outside"),"Nature visibility follows space: "+destination)
		check(environment.background_mode==(Environment.BG_SKY if destination=="outside" else Environment.BG_COLOR),"Sky does not leak into other spaces: "+destination)
	print("SCENE ART INTEGRATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
