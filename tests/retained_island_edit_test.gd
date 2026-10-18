extends SceneTree
## Integration evidence for the actual retained-island candidate, not a tiny
## substitute. Native editor loader/saver, real public carve and mesh replay.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
var WORK:='res://art/work/retained_island/2026-10-18/'
var checks:Array=[];var failures:=0
func check(ok:bool,label:String)->void:
 checks.append({'label':label,'passed':ok})
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func vertices(editor)->PackedByteArray:
 return editor.renderer.contours.surfaces.sculpted_terrain.vertices.to_byte_array()
func run():
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--work='):WORK=arg.trim_prefix('--work=')
 var editor=load('res://scenes/terrain_editor.tscn').instantiate();root.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false);editor.renderer.animate_edits=false
 check(editor.load_layout(WORK+'candidate.layout')==OK,'real editor loads the generated ordinary candidate')
 var data=editor.data;var before:Dictionary=data.serialize();var original:PackedByteArray=vertices(editor)
 check(data.sculpt_base_enabled and data.sculpt_base_profile=='local' and data.rocks.samples.size()>1000,'candidate uses ordinary unified base plus saved density overrides')
 var captured:String=WORK+'output_geometry/playable.bin'
 check(original==FileAccess.get_file_as_bytes(captured),'real loaded editor reproduces captured source vertex bytes')
 check(editor.renderer.decoration._columns.is_empty(),'no retained wall props hide behind the editable surface')
 var hit:=Vector3.ZERO;var best:=-INF
 for key:Vector3i in data.rocks.samples:
  if key.y<3 or key.y>9 or data.rocks.node_value(key)>-.1 or data.rocks.base.node_value(key)<.1:continue
  if key.z>best:best=key.z;hit=Vector3(key)*.25
 check(is_finite(best),'probe lies in a source rock extension outside the old baseline solid')
 var edit_start:=Time.get_ticks_usec()
 data.begin_stroke();var count:int=data.apply_rock_brush(hit,.9,'rock_cut',Vector3.FORWARD);data.end_stroke()
 var brush_ms:float=(Time.get_ticks_usec()-edit_start)/1000.0
 edit_start=Time.get_ticks_usec()
 editor.renderer.rebuild_all()
 var publish_ms:float=(Time.get_ticks_usec()-edit_start)/1000.0
 var after:Dictionary=data.serialize();var carved:PackedByteArray=vertices(editor)
 check(count>0 and data.rocks.value_at(hit)>0 and carved!=original,'public carve removes actual source-derived rock and changes visible geometry')
 check(data.undo() and data.serialize()==before,'ordinary undo restores exact source records')
 editor.renderer.rebuild_all();check(vertices(editor)==original,'ordinary undo restores captured geometry bytes')
 check(data.redo() and data.serialize()==after,'ordinary redo restores exact carved records')
 editor.renderer.rebuild_all();check(vertices(editor)==carved,'ordinary redo restores actual carved geometry bytes')
 var path:='user://tests/retained_island_edit.layout'
 var saved_ok:bool=editor.save_layout(path)==OK and editor.load_layout(path)==OK
 var reloaded:Dictionary=data.serialize()
 var differences:Array=[]
 var densities_before:=PackedFloat32Array();var densities_after:=PackedFloat32Array();var max_error:=0.0
 var keys_equal:bool=reloaded.rocks.size()==after.rocks.size()
 for i in after.rocks.size():
  densities_before.append(after.rocks[i].density);densities_after.append(reloaded.rocks[i].density)
  for key:String in ['x','y','z']:keys_equal=keys_equal and after.rocks[i][key]==reloaded.rocks[i][key]
  max_error=maxf(max_error,absf(float(reloaded.rocks[i].density)-float(after.rocks[i].density)))
  if reloaded.rocks[i]!=after.rocks[i]:
   differences.append({'before':after.rocks[i],'after':reloaded.rocks[i],'delta':float(reloaded.rocks[i].density)-float(after.rocks[i].density)})
 FileAccess.open(WORK+'save_differences.json',FileAccess.WRITE).store_string(JSON.stringify({'rock_differences':differences,'other_fields_equal':after.cells==reloaded.cells and after.seed==reloaded.seed},'\t',true,true))
 # Godot's JSON parser can differ by one float64 ULP even with 17-digit
 # output. Require every native float32 density bit plus all keys/cell data,
 # bounded double error and the actual final vertex bytes below.
 check(saved_ok and keys_equal and after.cells==reloaded.cells and after.seed==reloaded.seed and densities_before.to_byte_array()==densities_after.to_byte_array() and max_error<1e-15,'actual file roundtrip preserves all native density bits and cells (float64 parser error bounded)')
 check(vertices(editor)==carved,'editor file reload reproduces actual carved geometry bytes')
 FileAccess.open(WORK+'output_geometry/retained_carved.bin',FileAccess.WRITE).store_buffer(carved)
 var report:={'checks':checks,'passed':checks.size()-failures,'total':checks.size(),'brush_ms':brush_ms,'full_publish_ms':publish_ms,'timing_scope':'Headless real editor on development CPU; no live finish/top-cover overhead here. Full rebuild latency, not interactive FPS.','file_maximum_float64_error':max_error,'file_native_float32_density_bits_equal':densities_before.to_byte_array()==densities_after.to_byte_array(),'operation':{'center':str(hit),'radius':.9,'tool':'rock_cut','changed':count},'source_samples':before.rocks.size(),'edited_samples':after.rocks.size(),'geometry_gate_not_established_by_history':true,'art_accepted':false,'scope':'One actual candidate; direct public edit and real editor file roundtrip. Float64 JSON parsing may shift one ULP; native float32 densities and geometry must be bit identical. Not pointer/placement/full support/layout/seed/device or user-art acceptance.'}
 FileAccess.open(WORK+'edit_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
 editor.queue_free()
 print('RETAINED ISLAND EDIT: ',checks.size()-failures,'/',checks.size(),' actual source extension ',hit,' changed=',count)
 quit(1 if failures else 0)
