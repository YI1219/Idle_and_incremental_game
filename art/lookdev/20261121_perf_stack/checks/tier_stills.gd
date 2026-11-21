extends "res://tools/art/capture_lookdev.gd"
## Matched stills of candidate quality settings in one live scene: same frame,
## camera, light and clock values, only the listed settings differ.
## Usage: godot --path . --script <this> -- --out=res://dir [--size=2560x1440] [--progress=0.29]
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

const CAMERAS: Array[Dictionary] = [
	{"name": "whole", "center": Vector2(-2, -1), "height": 32.0, "yaw": 16.0, "pitch": 30.0},
	{"name": "game", "center": Vector2(0, -1), "height": 21.0, "yaw": 16.0, "pitch": 27.0},
	{"name": "close", "center": Vector2(-10, -5), "height": 13.0, "yaw": 16.0, "pitch": 30.0},
	{"name": "cliff_close", "center": Vector2(-8, 6), "height": 10.0, "yaw": 16.0, "pitch": 20.0},
	{"name": "foot_reverse", "center": Vector2(-2, -1), "height": 17.0, "yaw": 196.0, "pitch": 18.0},
]
const VARIANTS: Array[String] = ["balanced", "smaa", "smaa_noil", "light", "light_noao_keepil"]
var px := Vector2i(2560, 1440)
var day: float = .29

func _use(variant: String) -> void:
	var env: Environment = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	var attributes: CameraAttributesPractical = editor.camera.attributes as CameraAttributesPractical
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	env.ssao_enabled = true
	env.ssil_enabled = true
	attributes.dof_blur_far_enabled = true
	if variant != "balanced":
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	if variant == "smaa_noil":
		env.ssil_enabled = false
	if variant == "light":
		env.ssao_enabled = false
		env.ssil_enabled = false
		attributes.dof_blur_far_enabled = false
	if variant == "light_noao_keepil":
		env.ssao_enabled = false
		attributes.dof_blur_far_enabled = false

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			px = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--progress="):
			day = float(arg.trim_prefix("--progress="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.title = "画质对照 · 自动关闭"
	root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = px
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.preview_quality = FixedQuality.new()
	editor.preview_quality.configure(viewport)
	editor.preview_quality._scale = 1.0
	editor.preview_quality._apply()
	editor.hud.hide()
	editor.gameplay.time_system.set_progress(day, editor)
	for index: int in 60:
		await process_frame
	while editor.renderer.has_pending_updates():
		await process_frame
	# Freeze everything that moves so variants differ only by their settings.
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	for camera: Dictionary in CAMERAS:
		_frame(camera.center, camera.height, camera.yaw, camera.pitch)
		editor.background_view.sync()
		for variant: String in VARIANTS:
			_use(variant)
			for index: int in 12:
				await process_frame
			var image: Image = viewport.get_texture().get_image()
			image.save_png(output.path_join("%s_%s.png" % [camera.name, variant]))
			print("STILL ", camera.name, " ", variant, " ", image.get_size())
	_use("balanced")
	editor.free()
	viewport.free()
	quit()
