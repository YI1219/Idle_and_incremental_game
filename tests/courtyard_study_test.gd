extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(ResourceLoader.exists("res://scenes/courtyard_study.tscn"), "Independent courtyard study must exist")
	if failures:
		quit(1)
		return
	var study = load("res://scenes/courtyard_study.tscn").instantiate()
	root.add_child(study)
	await process_frame
	for id in [0, 1, 0]:
		study.set_layout(id)
		await process_frame
		check(study.terrain.water_cells.is_empty(),"Both layouts are dry")
		check(study.path_points.size() >= 3,"Door-connected path supplied")
		check(study.path_points[0].distance_to(study.house.to_global(Vector3(0,0,2.2)))<0.001,"Path entrance follows moved/rotated house")
		check(study.art.models.has("RockPath_Round_Thin"),"Real licensed path module is loaded")
		check(study.art.get_node("NatureCommunities").get_child_count()>5,"Groups exist after layout reset")
		for sample in study.plant_roots:
			check(study.clear_for_plant(sample,0.1),"Plant placement preserves door and path clearance")
		for i in range(9):
			var at: Vector3 = study.house.to_global(Vector3(0,0,2.2+i*.3))
			check(study.terrain.is_walkable(at),"Door approach remains on dry land")
		check(study.art.ground_material != null,"Study ground material attached")
	check(load("res://scenes/play.tscn") != null,"Original demo remains loadable")
	print("COURTYARD STUDY checks=",checks," failures=",failures)
	study.queue_free()
	await process_frame
	quit(1 if failures else 0)
