extends SceneTree
func _initialize():call_deferred('run')
func run():
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0);data.set_sculpt_base(true)
 var args:=OS.get_cmdline_user_args();var scanned:bool=args.has('scanned')
 var version:='fitcap' if args.has('fitcap') else ('replace' if args.has('replace') else ('single' if args.has('single') else ('v3' if args.has('v3') else ('v2' if args.has('v2') else 'v1'))))
 preload('res://tools/art/author_exposed_bedrock.gd').author(data,scanned,version)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var surface=field.surfaces.sculpted_terrain
 var path:='res://art/work/polyhaven_rocks/2026-10-17/scanned_'+version+'_skin.bin' if scanned else 'res://art/work/exposed_bedrock/2026-10-17/exposed_skin.bin'
 FileAccess.open(path,FileAccess.WRITE).store_buffer(surface.vertices.to_byte_array())
 print('BEDROCK RAW SKIN: vertices=',surface.vertices.size(),' samples=',data.rocks.samples.size());quit()
