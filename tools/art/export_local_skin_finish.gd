extends SceneTree
## Actual local-lead skin attributes for source-plane/contact diagnosis.
func _initialize():call_deferred('run')
func run():
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0);data.set_sculpt_base(true)
 preload('res://tools/art/author_exposed_bedrock.gd').author(data,false,'exposedcleft')
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets()
 var cap:Dictionary=preload('res://tools/art/actual_sculpt_cap_study.gd').apply(field,deco.assets,true)
 var smooth:Dictionary=preload('res://tools/art/field_gradient_normals.gd').apply(field,data.rocks)
 var dir:='res://art/work/cliff_finish/2026-10-17/'
 DirAccess.make_dir_recursive_absolute(dir)
 if OS.get_cmdline_user_args().has('clusters'):
  var cluster:Dictionary=preload('res://tools/art/shoulder_grass_clusters.gd').apply(field,deco.assets)
  FileAccess.open(dir+'cluster_anchors.json',FileAccess.WRITE).store_string(JSON.stringify(cluster,'\t'))
 var surface=field.surfaces.sculpted_terrain
 for spec in [['vertices',surface.vertices],['normals',surface.normals],['colors',surface.colors],['uv',surface.uv]]:
  FileAccess.open(dir+spec[0]+'.bin',FileAccess.WRITE).store_buffer(spec[1].to_byte_array())
 var grey_area:=0.0;var green_area:=0.0;var below_cap_area:=0.0
 var grey_triangles:=0
 for i in range(0,surface.vertices.size(),3):
  var a:Vector3=surface.vertices[i];var b:Vector3=surface.vertices[i+1];var c:Vector3=surface.vertices[i+2]
  var p:Vector3=(a+b+c)/3.0
  if p.x< -22 or p.x> -8 or p.z< -3 or p.z>9 or p.y<3.0 or p.y>3.501:continue
  var cross:=-(b-a).cross(c-a);var normal:=cross.normalized()
  if normal.y<.55:continue
  var area:=cross.length()*.5
  var cover:float=(surface.colors[i].r+surface.colors[i+1].r+surface.colors[i+2].r)/3.0
  if cover>.5:green_area+=area
  else:
   grey_area+=area;grey_triangles+=1
   if p.y<3.49:below_cap_area+=area
 var report:Dictionary={'vertices':surface.vertices.size(),'cap':cap,'normal':smooth,'upward_grey_area':grey_area,'upward_green_area':green_area,'grey_below_cap_area':below_cap_area,'grey_triangles':grey_triangles,'scope':'Actual local-lead upper skin with cap/fan and field-normal diagnostics; upward facesY3.0..3.501, normalY>=.55, boundedXZ. No production change.'}
 FileAccess.open(dir+'skin_report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('LOCAL SKIN FINISH:',JSON.stringify(report));quit()
