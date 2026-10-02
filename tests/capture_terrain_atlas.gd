extends SceneTree
## Real-renderer visual audit of all 47 canonical center-tile blob masks.

const Terrain := preload("res://scripts/world/river_terrain.gd")
const Blob47 := preload("res://scripts/world/blob47.gd")
const COLUMNS := 8
const SPACING := 3.7


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var variants: Array[int] = []
	for raw in 256:
		var mask: int = Blob47.normalize(raw)
		if not variants.has(mask): variants.append(mask)
	variants.sort()
	for index in variants.size():
		_add_pattern(stage, index, variants[index])
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-62, -28, 0)
	light.light_energy = 1.25
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#c8d2cd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dce3dd")
	env.ambient_light_energy = .9
	environment.environment = env
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	camera.position = Vector3(13.0, 28.0, 9.8)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.current = true
	stage.add_child(camera)
	for i in 24: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/review/terrain")
	root.get_texture().get_image().save_png("res://art/review/terrain/blob47_overview.png")
	quit()


func _add_pattern(stage: Node3D, index: int, mask: int) -> void:
	var terrain := Terrain.new()
	var col := index % COLUMNS
	var row := index / COLUMNS
	terrain.position = Vector3(col * SPACING, 0, row * SPACING)
	stage.add_child(terrain)
	var cells: Array[Vector2i] = []
	for x in 3:
		for z in 3: cells.append(Vector2i(x, z))
	terrain.configure(cells)
	terrain.water_cells.clear()
	terrain.water_cells[Vector2i(1, 1)] = true
	for bit: int in Blob47.OFFSETS:
		if mask & bit:
			terrain.water_cells[Vector2i(1, 1) + Blob47.OFFSETS[bit]] = true
	terrain.rebuild()
	var label := Label3D.new()
	label.text = "%02d  %03d" % [index, mask]
	label.font_size = 24
	label.pixel_size = .018
	label.modulate = Color("#24352e")
	label.outline_modulate = Color("#e6ece8")
	label.outline_size = 5
	label.position = Vector3(1.5, .22, 2.68)
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.no_depth_test = true
	terrain.add_child(label)
