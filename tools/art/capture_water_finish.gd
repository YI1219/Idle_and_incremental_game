extends 'res://tests/capture_rim_round.gd'
func run():
 var args:=OS.get_cmdline_user_args();var tag:='water_before' if args.is_empty() else args[0]
 OUT='res://art/review/terrain_fidelity/2026-10-16/water_surface/'
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:
  editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
 editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(tag+'_shore')
 editor.camera.position=Vector3(-4,5,9);editor.camera.look_at(Vector3(-3,3.5,0));await capture(tag+'_grazing')
 editor.camera.position=Vector3(14,7,12);editor.camera.look_at(Vector3(7,1.5,3));await capture(tag+'_lower')
 editor.camera.position=Vector3(5,6.2,9);editor.camera.look_at(Vector3(0,2.4,1.5));await capture(tag+'_cascade')
 editor.camera.position=Vector3(17,1,17);editor.camera.look_at(Vector3(10.5,-.4,8));await capture(tag+'_outer_fall')
 editor.camera.position=Vector3(-4,9,-12);editor.camera.look_at(Vector3(-3,3.5,0));await capture(tag+'_reverse')
 frame(Vector2(0,-1),21,16,27);await capture(tag+'_overview')
 FileAccess.open(OUT+tag+'_captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'source':'Actual Godot default island, unchanged layout/lighting','water_phase':1.25},'\t'))
 print('WATER FINISH CAPTURES: ',captures.size());quit()
