extends "res://tools/art/capture_lookdev.gd"
func run() -> void:
 output="res://art/lookdev/20261113_background_foliage/motion_sky";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 viewport=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.set_native_preview(false);editor.hud.hide();editor.brush.hide();Engine.max_fps=0
 editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_freeze_node(editor)
 var split: Node3D=load("res://art/lookdev/20261113_background_foliage/checks/background_sky_prototype.gd").new();editor.add_child(split);split.configure(editor);split.ratio=1.0
 for step: int in 16:
  _frame(Vector2(-2+step*.8,-1+sin(step*.4)*3),13.0+step*2.0,16+step*5,25+step)
  editor.landscape.position=Vector3(editor.camera._center.x,0,editor.camera._center.y)
  split.enabled=false;split.sync();await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(output.path_join("%02d_before.png"%step))
  split.enabled=true;split.sync();await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(output.path_join("%02d_first.png"%step))
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(output.path_join("%02d_second.png"%step))
 editor.free();viewport.free();quit()
