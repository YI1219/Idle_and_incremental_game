extends 'res://tests/capture_rim_round.gd'
func bytes_hash(bytes:PackedByteArray)->String:
 var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes);return digest.finish().hex_encode()
func bind_spall(node:Node,texture:Texture2D,seen:Dictionary,strength:float)->void:
 var materials:Array=[]
 if node is GeometryInstance3D:materials.append(node.material_override)
 var mesh:Mesh=node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null)
 if mesh!=null:
  for i in mesh.get_surface_count():materials.append(mesh.surface_get_material(i))
 for material in materials:
  if not material is ShaderMaterial or seen.has(material):continue
  seen[material]=true
  if material.get_shader_parameter('stone_detail_map')==null:continue
  material.set_shader_parameter('stone_detail_map',texture)
  material.set_shader_parameter('stone_relief_strength',strength)
 for child in node.get_children():bind_spall(child,texture,seen,strength)
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
 if args.has('mass'):preload('res://tools/art/author_unified_cliff_mass.gd').author(editor.data)
 if args.has('compactmass'):preload('res://tools/art/author_unified_cliff_mass.gd').author(editor.data,true)
 if args.has('massfinish'):preload('res://tools/art/author_unified_cliff_mass.gd').finish(editor.data)
 if args.has('section'):preload('res://tools/art/author_cliff_section.gd').author(editor.data)
 if args.has('leansection'):preload('res://tools/art/author_cliff_section.gd').author(editor.data,true)
 if args.has('volumesection'):preload('res://tools/art/author_cliff_section.gd').author(editor.data,false,true)
 if args.has('sourcevolume'):preload('res://tools/art/author_cliff_volume_study.gd').author(editor.data)
 if args.has('sourcevolume2'):preload('res://tools/art/author_cliff_volume_study.gd').author(editor.data,'v2')
 if args.has('sourcevolume3'):preload('res://tools/art/author_cliff_volume_study.gd').author(editor.data,'v3')
 if args.has('exposed'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data)
 if args.has('scannedbedrock'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true)
 if args.has('scannedbedrock2'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true,'v2')
 if args.has('scannedbedrock3'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true,'v3')
 if args.has('scannedbouldersingle'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true,'single')
 if args.has('scannedreplace'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true,'replace')
 if args.has('scannedfitcap'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,true,'fitcap')
 if args.has('facereplacement'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'face')
 if args.has('facereplacement2'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'face2')
 if args.has('facescan'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan')
 if args.has('facescan2'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan2')
 if args.has('facescan3'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan3')
 if args.has('facescan4'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan4')
 if args.has('facescan5'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan5')
 if args.has('facescan6'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'facescan6')
 if args.has('renderedbody'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'renderedbody')
 if args.has('renderedclosed'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'renderedclosed')
 if args.has('renderedenvelope'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'renderedenvelope')
 if args.has('renderedenvelopecap'):preload('res://tools/art/author_exposed_bedrock.gd').author(editor.data,false,'renderedenvelopecap')
 if args.has('worn') or args.has('worn2') or args.has('worn3'):
  var source_report:Dictionary=preload('res://tools/art/worn_cliff_sources.gd').install(editor.renderer.decoration,'v3' if args.has('worn3') else ('v2' if args.has('worn2') else 'v1'),args.has('wearsmooth'))
  FileAccess.open(OUT+tag+'_worn_sources.json',FileAccess.WRITE).store_string(JSON.stringify(source_report,'\t'))
  print('WORN CLIFF SOURCES: ',JSON.stringify(source_report))
 editor.renderer.rebuild_all()
 if args.has('actualcap'):
  var report:Dictionary=preload('res://tools/art/actual_sculpt_cap_study.gd').apply(editor.renderer.contours,editor.renderer.decoration.assets,args.has('capfans'))
  FileAccess.open(OUT+tag+'_actual_cap.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
  var chunks:Dictionary={}
  for chunk in editor.renderer.chunks:chunks[chunk]=true
  for chunk in editor.renderer.contours.triangle_chunks:chunks[chunk]=true
  for chunk in chunks:editor.renderer._rebuild(chunk)
  editor.renderer._publish()
  print('ACTUAL CAP STUDY: ',JSON.stringify(report))
 if args.has('grasspatch') or args.has('grasspatch2') or args.has('grasspatch3') or args.has('grassarc') or args.has('grassworld'):
  var field=editor.renderer.contours
  var deco=editor.renderer.decoration
  var crowns:Array=[]
  for col:Dictionary in deco._columns:
   var polygon:=PackedVector2Array()
   for p:Vector2 in deco.assets[col.kind][0].cap_polygon:
    var q:Vector3=col.pose*Vector3(p.x,0,p.y);polygon.append(Vector2(q.x,q.z))
   polygon.append(polygon[0])
   crowns.append({'polygon':polygon,'height':col.pose.origin.y})
  var surface=preload('res://tools/art/rim_grass_patch_study.gd').lip(field.rim_regions,crowns,deco.assets,args.has('grasspatch2') or args.has('grasspatch3'),args.has('grasspatch3'))
  if args.has('grassarc'):surface=preload('res://tools/art/rim_arc_probe_study.gd').lip(field.rim_regions,crowns,deco.assets)
  if args.has('grassworld'):surface=preload('res://tools/art/rim_world_probe_study.gd').lip(field.rim_regions,crowns,deco.assets)
  surface=preload('res://scripts/terrain_editor/rim_outcrops.gd').trim_cover(surface,deco._outcrops,deco.assets)
  field._smooth_normals(surface);field.surfaces.rim_green=surface;field._index_triangles()
  var chunks:Dictionary={}
  for chunk in editor.renderer.chunks:chunks[chunk]=true
  for chunk in field.triangle_chunks:chunks[chunk]=true
  for chunk in chunks:editor.renderer._rebuild(chunk)
  editor.renderer._publish()
  print('GRASS PATCH STUDY: vertices=',surface.vertices.size())
 if args.has('source_return'):
  var study=preload('res://tools/art/source_return_envelope.gd').new()
  var report:Dictionary=study.apply(editor.renderer.contours,editor.renderer.decoration._columns,editor.renderer.decoration.assets)
  print('SOURCE RETURN ENVELOPE: ',JSON.stringify(report))
  FileAccess.open(OUT+tag+'_source_return.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
  var chunks:Dictionary={}
  for chunk in editor.renderer.chunks:chunks[chunk]=true
  for chunk in editor.renderer.contours.triangle_chunks:chunks[chunk]=true
  for chunk in chunks:editor.renderer._rebuild(chunk)
  editor.renderer._publish()
 if args.has('spall') or args.has('spall2') or args.has('spall3'):
  var detail:=Image.load_from_file('res://art/work/stone_spall/2026-10-16/stone_detail_spall_'+('v3' if args.has('spall3') else ('v2' if args.has('spall2') else 'v1'))+'.png')
  assert(detail!=null);detail.generate_mipmaps()
  bind_spall(editor,ImageTexture.create_from_image(detail),{},.25 if args.has('spall3') else (.30 if args.has('spall2') else .20))
 if args.has('neutral'):
  var neutral:=Shader.new()
  neutral.code='shader_type spatial; void fragment(){ALBEDO=mix(vec3(.42),vec3(.66),COLOR.r);ROUGHNESS=.95;SPECULAR=0.0;}'
  editor.renderer.materials.sculpted_terrain.shader=neutral
  editor.renderer.props.hide();editor.renderer.mist.hide()
  for chunk:Node3D in editor.renderer.chunks.values():
   for child:Node3D in chunk.get_children():
    child.visible=child.name=='sculpted_terrain'
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
