extends "res://art/lookdev/20261121_perf_stack/checks/probe_ablate.gd"
## probe_ablate.gd in a GPU-bound setup. On this Mac an idle window presents at
## about 85 frames a second (see probe_scale.gd / probe_cpu.gd), so a single
## 1080p viewport is clipped by the display path and feature costs vanish.
## Here the scene is drawn into K identical viewports sharing one world; every
## variant is mirrored onto all of them and the frame time is divided by K.
## Extra option: --k=3 (default). All other options as probe_ablate.gd.
var k: int = 3
var clones: Array[SubViewport] = []
var clones_ready: bool = false

func _make_clones() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--k="):
			k = int(arg.trim_prefix("--k="))
	for index: int in k - 1:
		var extra := SubViewport.new()
		extra.size = viewport.size
		extra.world_3d = viewport.find_world_3d()
		extra.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var eye := Camera3D.new()
		var source: Camera3D = editor.camera
		eye.fov = source.fov
		eye.near = source.near
		eye.far = source.far
		eye.attributes = source.attributes
		extra.add_child(eye)
		root.add_child(extra)
		eye.global_transform = source.global_transform
		eye.current = true
		clones.append(extra)
	clones_ready = true
	print("CLONES k=", k)

func _sync_clones() -> void:
	for extra: SubViewport in clones:
		extra.msaa_3d = viewport.msaa_3d
		extra.scaling_3d_mode = viewport.scaling_3d_mode
		extra.scaling_3d_scale = viewport.scaling_3d_scale
		extra.debug_draw = viewport.debug_draw
		extra.screen_space_aa = viewport.screen_space_aa
		extra.use_debanding = viewport.use_debanding

func _apply(variant: String) -> void:
	if not clones_ready:
		_make_clones()
	var rest: PackedStringArray = []
	for part: String in variant.split("&"):
		if not _apply_extra(part):
			rest.append(part)
	super._apply("&".join(rest) if not rest.is_empty() else "base")
	_sync_clones()

func _restore() -> void:
	super._restore()
	_sync_clones()

func _sample() -> Dictionary:
	var row: Dictionary = await super._sample()
	row["frame_ms"] = row.ms
	row["k"] = k
	row.ms = float(row.ms) / float(k)
	row.fps = 1000.0 / float(row.ms)
	return row

## Extra variant parts handled here (all others go to probe_ablate.gd):
##   smaa / fxaa      screen-space anti-aliasing on every viewport (combine with msaa0)
##   shadow2k         2048 directional shadow atlas
##   splits2          two shadow splits instead of four
##   grassshadow0     grass blades do not cast shadows
##   foliageshadow0   foliage cards do not cast shadows
func _apply_extra(part: String) -> bool:
	if part == "smaa" or part == "fxaa":
		var old: int = viewport.screen_space_aa
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if part == "smaa" else Viewport.SCREEN_SPACE_AA_FXAA
		_undo.append(func() -> void: viewport.screen_space_aa = old)
		return true
	if part == "shadow2k":
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		_undo.append(func() -> void: RenderingServer.directional_shadow_atlas_set_size(4096, true))
		return true
	if part == "splits2":
		var mode: int = _sun.directional_shadow_mode
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_undo.append(func() -> void: _sun.directional_shadow_mode = mode)
		return true
	if part == "grassshadow0" or part == "foliageshadow0":
		var wanted: String = "grass_blades.gdshader" if part == "grassshadow0" else "foliage_cards.gdshader"
		var touched: Dictionary = {}
		for node: Node in _geometry():
			if _shader_of(node) == wanted:
				touched[node] = (node as GeometryInstance3D).cast_shadow
				(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		print("SHADOW OFF ", wanted, " on ", touched.size(), " nodes")
		_undo.append(func() -> void:
			for node: Node in touched:
				if is_instance_valid(node):
					(node as GeometryInstance3D).cast_shadow = touched[node])
		return true
	return false
