extends "res://tools/art/capture_lookdev.gd"
var split: Node3D
func run() -> void:
 output="res://art/lookdev/20261113_background_foliage/prototype_sky";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 viewport=SubViewport.new();viewport.size=SIZE;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.set_native_preview(false);editor.hud.hide();editor.brush.hide();Engine.max_fps=0
 editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
 split=load("res://art/lookdev/20261113_background_foliage/checks/background_sky_prototype.gd").new();editor.add_child(split);split.configure(editor)
 for name: String in ["before","full","half"]:
  split.enabled=name!="before";split.ratio=1.0 if name=="full" else .5;split.sync()
  for i: int in 30:split.sync();await RenderingServer.frame_post_draw
  var image: Image=viewport.get_texture().get_image();image.save_png(output.path_join(name+".png"))
  print(name," target=",split.view.size," hdr=",split.view.get_texture().get_image().get_format()," main=",image.get_size())
  if name=="full":split.view.get_texture().get_image().save_exr(output.path_join("background.exr"))
 editor.free();viewport.free();quit()
