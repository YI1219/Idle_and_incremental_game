extends 'res://tests/capture_rim_round.gd'
func bytes_hash(bytes:PackedByteArray)->String:
 var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);return digest.finish().hex_encode()
func run():
 var args:=OS.get_cmdline_user_args();var tag:='base1' if args.is_empty() else args[0]
 OUT='res://art/review/terrain_fidelity/2026-10-16/sculpt_base/'
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 if not args.has('legacy'):editor.data.set_sculpt_base(true)
 if args.has('oldprofile'):
  var old:Dictionary=editor.data.serialize();old.version=3;old.sculpt_base=true;old.rocks=[];old.erase('sculpt_profile')
  editor.data.deserialize(old)
 if args.has('fixedwater'):
  for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:
   editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
 if args.has('authored'):preload('res://tools/art/author_sculpted_cliff.gd').author(editor.data)
 if args.has('curated'):preload('res://tools/art/author_unified_cliff.gd').author(editor.data)
 if args.has('planes'):preload('res://tools/art/author_unified_cliff_planes.gd').author(editor.data)
 if args.has('cutstone'):preload('res://tools/art/author_unified_cliff_cutstone.gd').author(editor.data)
 if args.has('fullshoulder'):preload('res://tools/art/author_unified_cliff_cutstone.gd').full_island(editor.data)
 if args.has('returncuts'):preload('res://tools/art/author_unified_cliff_return.gd').author(editor.data)
 if args.has('liplayers'):preload('res://tools/art/author_unified_cliff_return.gd').lip_study(editor.data)
 if args.has('chisel'):preload('res://tools/art/author_unified_cliff_chisel.gd').author(editor.data)
 if args.has('smooth'):preload('res://tools/art/author_unified_cliff_smooth.gd').author(editor.data)
 if args.has('recess'):preload('res://tools/art/author_unified_cliff_recess.gd').author(editor.data)
 editor.renderer.rebuild_all()
 frame(Vector2(-14,4),8,16,30);await capture(tag+'_close')
 frame(Vector2(0,-1),21,16,27);await capture(tag+'_overview')
 if args.has('details'):
  frame(Vector2(0,-1),32,16,27);await capture(tag+'_far')
  editor.camera.position=Vector3(-12.4,7.1,11.0);editor.camera.look_at(Vector3(-15.0,3.5,3.3));await capture(tag+'_grass')
 frame(Vector2(-14,4),9,-105,28);await capture(tag+'_reverse')
 editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(tag+'_shore')
 editor.camera.position=Vector3(12,-14,21);editor.camera.look_at(Vector3(-2,-1,0));await capture(tag+'_bottom')
 var skin=editor.renderer.contours.surfaces.get('sculpted_terrain')
 FileAccess.open(OUT+tag+'_captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'source':'Actual Godot terrain scene','sculpt_base':editor.data.sculpt_base_enabled,'sculpt_profile':editor.data.sculpt_base_profile,'water_phase':1.25 if args.has('fixedwater') else -1.0,'samples':editor.data.rocks.samples.size(),'data_sha256':JSON.stringify(editor.data.serialize()).sha256_text(),'skin_vertices_sha256':bytes_hash(skin.vertices.to_byte_array()) if skin!=null else '', 'skin_normals_sha256':bytes_hash(skin.normals.to_byte_array()) if skin!=null else '', 'skin_colors_sha256':bytes_hash(skin.colors.to_byte_array()) if skin!=null else '', 'skin_uv_sha256':bytes_hash(skin.uv.to_byte_array()) if skin!=null else ''},'\t'))
 print('SCULPT BASE CAPTURES: ',captures.size(),' samples=',editor.data.rocks.samples.size(),' skin_vertices=',skin.vertices.size() if skin!=null else 0);quit()
