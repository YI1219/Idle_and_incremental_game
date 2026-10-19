extends 'res://tests/capture_rim_round.gd'
## Read-only native baseline. Does not load or write any user save.
const Scene=preload('res://scenes/terrain_editor.tscn')

func run()->void:
	OUT='res://art/review/terrain_fidelity/2026-10-19/authored_island/baseline/'
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport=SubViewport.new()
	viewport.size=Vector2i(1671,941)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=Scene.instantiate()
	viewport.add_child(editor)
	editor.hud.hide();editor.brush.hide()
	editor.set_process(false);editor.camera.set_process(false)
	editor.renderer.animate_edits=false
	var before:String=JSON.stringify(editor.data.serialize(),'',true,true)
	frame(Vector2(-2,-1),32,16,30);await capture('whole')
	frame(Vector2(-10,-5),13,16,30);await capture('play')
	frame(Vector2(-13,2),8,16,30);await capture('close')
	editor.camera.position=Vector3(-31,8,-20)
	editor.camera.look_at(Vector3(-7,2,-3));await capture('reverse')
	editor.camera.position=Vector3(24,-4,22)
	editor.camera.look_at(Vector3(4,1,2));await capture('low')
	var same:bool=before==JSON.stringify(editor.data.serialize(),'',true,true)
	var valid:bool=same and captures.size()==5
	for item:Dictionary in captures:valid=valid and item.error==OK
	var cottage:Node3D=editor.renderer.props.get_node('ReferenceCottage')
	var record:Dictionary={
		'scene':'res://scenes/terrain_editor.tscn',
		'purpose':'Current formal default, not the compact old comparison or earliest historical screenshot.',
		'data_unchanged':same,'captures':captures,'capture_success':valid,
		'resolution':[1671,941],'godot':Engine.get_version_info().string,
		'adapter':RenderingServer.get_video_adapter_name(),
		'cottage_source':'res://assets/buildings/cottage/cottage_tripo.glb',
		'cottage_display_scale':str(cottage.scale),
		'cottage_scope':'Original GLB plus current nonuniform instance scale, roof shader and added door detail; none changed by this capture.',
		'art_accepted':false,'save_access':'No user save loaded or written.'}
	FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify(record,'\t',true,true))
	print('AUTHORED BASELINE: ',valid,'; frames=',captures.size(),'; unchanged=',same)
	editor.queue_free();await process_frame
	quit(0 if valid else 1)
