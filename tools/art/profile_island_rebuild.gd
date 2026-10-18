extends SceneTree
## Read-only phase/call-count probe on the actual ordinary candidate.
class MeasuredContours:
 extends 'res://scripts/terrain_editor/island_contours.gd'
 var timings:Dictionary={}
 func record(key:String,start:int)->void:timings[key]=timings.get(key,0.0)+(Time.get_ticks_usec()-start)/1000.0
 func refresh(data:Data)->void:
  timings.clear();var start:=Time.get_ticks_usec();super.refresh(data);record('total_refresh',start)
 func _generate_cliff_bands()->void:
  var start:=Time.get_ticks_usec();super._generate_cliff_bands();record('legacy_cliff_bands',start)
 func _cap(surface,loops:Array,height:float,tint:Color,extra_rows:PackedFloat32Array=PackedFloat32Array(),force_sweep:bool=false)->void:
  var start:=Time.get_ticks_usec();super._cap(surface,loops,height,tint,extra_rows,force_sweep);record('legacy_caps',start)
 func _smooth_normals(surface)->void:
  var start:=Time.get_ticks_usec();super._smooth_normals(surface);record('legacy_normal_passes',start)
 func _index_triangles()->void:
  var start:=Time.get_ticks_usec();super._index_triangles();record('index_passes',start)
class CountingField:
 extends 'res://scripts/terrain_editor/rock_sculpt.gd'
 var reads:=0
 func node_value(key:Vector3i)->float:
  reads+=1;return super.node_value(key)
func _initialize():call_deferred('run')
func digest(value:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(value);return h.finish().hex_encode()
func run():
 var editor=load('res://scenes/beautiful_island.tscn').instantiate();root.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false);editor.renderer.animate_edits=false
 var before:Dictionary=editor.data.serialize()
 var expected:PackedByteArray=editor.renderer.contours.surfaces.sculpted_terrain.vertices.to_byte_array()
 var field:=CountingField.new();field.base=editor.data.rocks.base;field.samples=editor.data.rocks.samples.duplicate()
 var start:=Time.get_ticks_usec()
 var skin=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(field)
 var mesh_ms:float=(Time.get_ticks_usec()-start)/1000.0
 assert(skin.vertices.to_byte_array()==expected)
 var measured:=MeasuredContours.new();editor.renderer.contours=measured
 start=Time.get_ticks_usec();editor.renderer.rebuild_all()
 var full_ms:float=(Time.get_ticks_usec()-start)/1000.0
 assert(expected==measured.surfaces.sculpted_terrain.vertices.to_byte_array() and before==editor.data.serialize())
 var label:='before'
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--label='):label=arg.trim_prefix('--label=')
 var report:={label:{'standalone_mesh_ms':mesh_ms,'node_value_reads':field.reads,'full_rebuild_ms':full_ms,'refresh_phases_ms':measured.timings.duplicate(),'vertex_sha256':digest(expected)},'density_records':editor.data.rocks.samples.size(),'processor':OS.get_processor_name(),'scope':'Actual current C0candidate, exact native vertex/data identity asserted. Diagnostic headless CPU timing, not FPS, hardware acceptance or artistic gain.'}
 var out:='res://art/work/retained_island/2026-10-19/'
 DirAccess.make_dir_recursive_absolute(out)
 var file:String=out+('rebuild_profile.json' if label=='before' else 'rebuild_profile_'+label+'.json')
 if FileAccess.file_exists(file):push_error('Preserve existing profile evidence');editor.queue_free();quit(1);return
 FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
 print('ACTUAL ISLAND PROFILE: ',report)
 editor.queue_free();quit()
