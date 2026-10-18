extends 'res://tools/art/capture_storybook_island.gd'
## Whole-scene proportion experiment: compress only terrain in saved density
## data; retain house/tree sizes and XZ placements. Not a renderer transform.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
var camera_shift:=0.0
func photo(target:Vector3,distance:float,yaw:float,pitch:float)->void:
 super.photo(target+Vector3.UP*camera_shift,distance,yaw,pitch)
func compressed_data()->Dictionary:
 var source:=Data.new();assert(source.deserialize(editor.data.serialize()) and source.ensure_sculpt_base())
 var payload:Dictionary=source.serialize();payload.rocks=[]
 for cell:Dictionary in payload.cells:cell.height=1.5
 assert(editor.data.deserialize(payload) and editor.data.ensure_sculpt_base())
 var base=editor.data.rocks.base
 var lo:Vector3i=base.low;var hi:Vector3i=base.low+base.size-Vector3i.ONE
 for key:Vector3i in source.rocks.samples:
  lo.x=mini(lo.x,key.x);lo.z=mini(lo.z,key.z);hi.x=maxi(hi.x,key.x);hi.z=maxi(hi.z,key.z)
 var samples:Dictionary[Vector3i,float]={};var guarded:=0
 var start:=Time.get_ticks_usec()
 for z in range(lo.z,hi.z+1):
  for y in range(lo.y,hi.y+1):
   for x in range(lo.x,hi.x+1):
    var key:=Vector3i(x,y,z);var p:=Vector3(key)*.25
    p.y=3.5+(p.y-1.5)/.52
    var old:float=source.rocks.value_at(p)
    # Preserve distant-air saturation rather than fill the whole AABB with
    # needless positive overrides. Near the surface use the transformed field.
    var value:float=.5 if old>=.499999 else clampf(old*.52,-.5,.5)
    value=roundf(value*100000.0)/100000.0
    if absf(value)<.0002:value=-.0002 if value<0 else .0002;guarded+=1
    if value!=base.node_value(key):samples[key]=value
 assert(samples.size()<=editor.data.rocks.MAX_SAMPLES)
 editor.data.rocks.samples=samples;editor.data.rocks._height_bounds_dirty=true
 editor.data._invalidate_rocks(samples.keys());editor.renderer.rebuild_all()
 return {'method':'Ordinary saved field samples F_new(x,y,z)=.52*F_old(x,3.5+(y-1.5)/.52,z); distant saturated air stays+.5; five-decimal values and sign-preserving tiny-value guards. Same XZcells, new cellheight1.5. No scene geometry transform/hidden body.','records':samples.size(),'construction_ms':(Time.get_ticks_usec()-start)/1000.0,'near_zero_guards':guarded,'scope':'Tools-only native whole-scene art experiment. Reconstructed geometry/source fidelity/support/editor/preset adoption require fresh checks if selected.'}
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-19/island_proportion/'
 layout_kind='courtyard';quiet_backdrop=true
 var work:='res://art/work/retained_island/2026-10-19/proportion/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(work)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 for style:String in ['control','shallow']:
  editor=load('res://scenes/beautiful_island.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false);editor.camera.reparent(editor,true)
  camera_shift=0;var rule:Dictionary={}
  if style=='shallow':rule=compressed_data();camera_shift=-2.0
  var before:Dictionary=editor.data.serialize()
  var points:PackedVector3Array=editor.renderer.contours.surfaces.sculpted_terrain.vertices
  FileAccess.open(work+style+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
  FileAccess.open(work+style+'.layout',FileAccess.WRITE).store_string(JSON.stringify(before,'',true,true))
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  reports[style]={'rule':rule,'triangles':points.size()/3,'vertex_sha256':digest(points.to_byte_array()),'records':editor.data.rocks.samples.size(),'cells':editor.data.cells.size(),'props':props,'camera_vertical_shift':camera_shift,'same_camera_relative_to_ground':true,'art_accepted':false}
  await views(style);assert(before==editor.data.serialize())
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'stages':reports,'captures':captures,'scope':'Native whole-island vertical proportion comparison; actual source data differs. Terrain surface3.5→1.5, all five cameras translate down2m to retain same ground-relative angles/distances. Existing house/tree geometry and XZplacements stay. Tools-only, not default/adopted or user art acceptance.'},'\t',true,true))
 print('NATIVE ISLAND PROPORTION: ',captures.size(),' frames');quit()
