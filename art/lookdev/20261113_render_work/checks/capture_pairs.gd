extends "res://tools/art/capture_lookdev.gd"
var capture_variant: String="before"
func _source_hashes() -> Dictionary:
 var hashes: Dictionary=super._source_hashes()
 var path: String="res://scripts/gameplay/systems/time_solar_system.gd"
 hashes[path]=FileAccess.get_file_as_string(path).sha256_text()
 return hashes
func _capture(label: String, time_progress: float) -> void:
 editor.gameplay.time_system.set_progress(time_progress, editor)
 for index: int in 24:
  if index == 2: editor.gameplay.time_system.apply_to_scene(editor, capture_variant == "before")
  RenderingServer.force_draw(false)
  await process_frame
 RenderingServer.force_draw(false)
 var expected: Dictionary = editor.gameplay.time_system.current_blended_preset()
 var grass_material: ShaderMaterial = editor.renderer.materials.grass_blades
 var grass_base: Color = grass_material.get_shader_parameter("grass_base")
 var grass_highlight: Color = grass_material.get_shader_parameter("grass_highlight")
 if not grass_base.is_equal_approx(expected.grass_base) or not grass_highlight.is_equal_approx(expected.grass_highlight):
  errors.append("Grass palette changed while rendering: " + label)
 var image: Image = viewport.get_texture().get_image()
 var result: Error = image.save_png(output.path_join(label + ".png"))
 if result != OK:
  errors.append("PNG save failed: %s (%d)" % [label, result])
 if image.get_size() != SIZE:
  errors.append("Non-native resolution: " + label)
 if not _hud_clear():
  errors.append("Wallpaper HUD not clear: " + label)
 var sun: DirectionalLight3D = editor.get_node("SunLight")
 var fill: DirectionalLight3D = editor.get_node("FillLight")
 var env: Environment = editor.get_node("WorldEnvironment").environment
 captures.append({
  "file": label + ".png", "save_error": result, "sky_mode": env.sky.process_mode, "radiance_size": env.sky.radiance_size,
  "viewport_msaa": viewport.msaa_3d, "render_scale": viewport.scaling_3d_scale,
  "shadow_atlas_size": shadow_atlas_size, "ssao_half_size": ssao_half_size, "dof_blur_quality": dof_blur_quality,
  "position": _vector(editor.camera.position), "rotation_degrees": _vector(editor.camera.rotation_degrees),
  "fov": editor.camera.fov, "dof": _dof_settings(editor.camera), "day_progress": time_progress,
  "grass_base": _color(grass_base), "grass_highlight": _color(grass_highlight),
  "shichen": editor.gameplay.time_system.shichen_label(), "wallpaper_hud_clear": _hud_clear(),
  "sun_rotation": _vector(sun.rotation_degrees), "sun_energy": sun.light_energy,
  "sun_color": _color(sun.light_color), "fill_rotation": _vector(fill.rotation_degrees),
  "fill_energy": fill.light_energy, "ambient_energy": env.ambient_light_energy,
  "ssil_enabled": env.ssil_enabled, "ssil_intensity": env.ssil_intensity,
  "fog_color": _color(env.fog_light_color), "fog_density": env.fog_density,
  "sun_angular":sun.light_angular_distance,"shadow_opacity":sun.shadow_opacity,
  "shadow_bias": sun.shadow_bias, "shadow_normal_bias": sun.shadow_normal_bias,
  "tonemap_mode":env.tonemap_mode,"tonemap_exposure":env.tonemap_exposure,
  "volumetric_fog":env.volumetric_fog_enabled,"volumetric_density":env.volumetric_fog_density,
  "ssao_intensity":env.ssao_intensity,"ssao_radius":env.ssao_radius,
 })
 print("LOOKDEV saved: ", output.path_join(label + ".png"))

func run() -> void:
 output="res://art/lookdev/20261113_render_work/pairs"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.renderer.animate_edits=false
 editor.set_native_preview(false);Engine.max_fps=0;shadow_atlas_size=4096;ssao_half_size=true;dof_blur_quality=0
 editor.gameplay.set_wallpaper_mode(true);editor.gameplay.shihai_hud.tick_ui(4.0,editor.gameplay.state,editor.gameplay.time_system,editor.gameplay.fishing,editor.data.cells.size(),editor.gameplay.stance,true)
 _freeze_node(editor)
 var hashes: Dictionary=_source_hashes()
 for layout: Array in [[7301,0],[2104,0],[4242,1],[913,2]]:
  editor.data.seed=layout[0];editor.data.make_preset(layout[1]);editor.renderer.rebuild_all();editor.motes.rebuild_from_data(editor.data);editor.water_view.reset(editor.data);editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
  for v: String in ["before","after"]:
   capture_variant=v
   for angle: String in ["whole","reverse","close"]:
    _frame(Vector2(-10,-5) if angle=="close" else Vector2(-2,-1),13 if angle=="close" else 32,196 if angle=="reverse" else 16,30)
    await _capture("%d_%s_%s"%[layout[0],v,angle],.29)
   if layout[0]==7301:
    _frame(Vector2(-8,6),10,16,20);await _capture("7301_"+v+"_low",.29)
    _frame(Vector2(-2,-1),32,16,30);await _capture("7301_"+v+"_night",0.0)
    await _capture("7301_"+v+"_dusk",.76)
 FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"sources_unchanged":hashes==_source_hashes(),"errors":errors,"notes":"same live scene/state/phase;only sky radiance QUALITY vs INCREMENTAL settled24frames;actual native2K balanced;shader/colour/light constants identical"},"\t"))
 print("PAIRS ",captures.size()," errors ",errors);editor.free();viewport.queue_free();quit(1 if not errors.is_empty() else 0)
