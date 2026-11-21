extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_native.gd"

func show_kind(prefix: String, enabled: bool) -> void:
	for chunk: Node3D in editor.renderer.chunks.values():
		for child: Node3D in chunk.get_children():
			if String(child.name)==prefix or String(child.name).begins_with(prefix+"_"):
				child.visible=enabled

func run() -> void:
	output="res://art/lookdev/20261110_editor_stability/checks/crack_hole_guard"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport=SubViewport.new()
	viewport.size=SIZE
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.process_mode=Node.PROCESS_MODE_DISABLED
	editor.renderer.threaded_builds=false
	var key:=InputEventKey.new()
	key.keycode=KEY_F11
	key.pressed=true
	editor.gameplay.handle_unhandled_input(key)
	editor.gameplay.shihai_hud.tick_ui(4,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,editor.gameplay.wallpaper_mode)
	editor.water_view.reset(editor.data)
	editor.water_view.tick(.1)
	editor.water_view.flush()
	_freeze_node(editor)
	for i: int in 4:
		lower(Vector2(-8,-5),3.8)
		editor.renderer._process(1.0)
	editor.renderer.decoration=load("res://art/lookdev/20261110_editor_stability/checks/probe_decoration_without_hole_columns.gd").new()
	editor.renderer.rebuild_all()
	_freeze_node(editor)
	_frame(Vector2(-8,-5),8.0,196,55)
	await _capture("00_full",.29)
	FileAccess.open(output.path_join("diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"errors":errors,"morph":editor.renderer.morph_progress},"\t"))
	editor.free()
	quit()
