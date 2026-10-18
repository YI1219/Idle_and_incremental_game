extends SceneTree
## Native main viewport, real live scene/HUD; not a composed mockup.
func _initialize():call_deferred('run')
func run():
 var editor=load('res://scenes/beautiful_island.tscn').instantiate();root.add_child(editor)
 # Let the one-second FPS counter recover from cold scene startup before
 # recording diagnostics; a fixed60frames can finish before it updates.
 var warm_start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-warm_start<2500:await process_frame
 RenderingServer.force_draw(false)
 var output:='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/playable/live_hud.png'
 var error:=root.get_texture().get_image().save_png(output)
 assert(error==OK)
 print('LIVE HUD CAPTURE: ',output,' scene=',editor.scene_file_path,' cells=',editor.data.cells.size(),' panel_bottom=',editor.hud.panel.get_global_rect().end.y)
 quit()
