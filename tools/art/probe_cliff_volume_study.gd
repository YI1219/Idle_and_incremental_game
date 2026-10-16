extends SceneTree
func _initialize():call_deferred('run')
func run():
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0);data.set_sculpt_base(true)
 var args:=OS.get_cmdline_user_args();var version:String=args[0] if not args.is_empty() else 'v1'
 if version!='control':preload('res://tools/art/author_cliff_volume_study.gd').author(data,version)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var surface=field.surfaces.sculpted_terrain
 FileAccess.open('res://art/work/cliff_volume/2026-10-16/volume_'+version+'_skin.bin',FileAccess.WRITE).store_buffer(surface.vertices.to_byte_array())
 print('SOURCE VOLUME SKIN: vertices=',surface.vertices.size(),' samples=',data.rocks.samples.size());quit()
