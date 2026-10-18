extends SceneTree
## Freeze actual pre-optimization attributes from all4tracked saved presets.
## Refuse to overwrite a baseline; visual changes need their own evidence.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Mesher=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
class Counter:
 extends 'res://scripts/terrain_editor/rock_sculpt.gd'
 var reads:=0
 func node_value(key:Vector3i)->float:reads+=1;return super.node_value(key)
func digest(bytes:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func _initialize():call_deferred('run')
func run():
 var path:='res://tests/fixtures/island_mesher_baseline.json'
 if FileAccess.file_exists(path):push_error('Preserve existing source baseline');quit(1);return
 var report:={'mesher_source_sha256':FileAccess.get_sha256('res://scripts/terrain_editor/rock_sculpt_mesh.gd'),'scope':'Actual pre-optimization mesh attributes from four ordinary tracked presets. Counter records algorithmic density reads, not wall-time/target-device acceptance.','cases':{}}
 for case:String in ['courtyard_7301','courtyard_7319','bay_7301','bay_7319']:
  var data:=Data.new();var preset:Resource=load('res://assets/terrain_editor/island_presets/'+case+'.res')
  assert(data.deserialize(preset.layout) and data.ensure_sculpt_base())
  var field:=Counter.new();field.samples=data.rocks.samples.duplicate();field.base=data.rocks.base
  var start:=Time.get_ticks_usec();var surface=Mesher.build(field)
  var elapsed:float=(Time.get_ticks_usec()-start)/1000.0
  var hashes:Dictionary={}
  for attribute:String in ['vertices','normals','colors','uv']:hashes[attribute]=digest(surface.get(attribute).to_byte_array())
  report.cases[case]={'attributes':hashes,'vertex_occurrences':surface.vertices.size(),'node_value_reads':field.reads,'elapsed_ms':elapsed}
  print('PRE-OPT MESH BASELINE: ',case,' reads=',field.reads,' ms=',elapsed)
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true));quit()
