extends SceneTree
## Real saved islands: exact prior mesh attributes + explicit operation budget.
## This bounds redundant scalar work without brittle wall-clock thresholds.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Mesher=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
class Counter:
 extends 'res://scripts/terrain_editor/rock_sculpt.gd'
 var reads:=0
 func node_value(key:Vector3i)->float:reads+=1;return super.node_value(key)
class TagCounter:
 extends 'res://scripts/terrain_editor/rock_terrain_base.gd'
 var tags:=0
 func tag(p:Vector3,n:Vector3)->Dictionary:tags+=1;return super.tag(p,n)
var checks:=0;var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func digest(bytes:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func _initialize():call_deferred('run')
func run():
 var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://tests/fixtures/island_mesher_baseline.json'))
 for case:String in baseline.cases:
  var data:=Data.new();var preset:Resource=load('res://assets/terrain_editor/island_presets/'+case+'.res')
  check(data.deserialize(preset.layout) and data.ensure_sculpt_base(),case+': actual ordinary preset loads')
  var base:=TagCounter.new();base.configure(data.cells,data.sculpt_base_profile)
  var field:=Counter.new();field.samples=data.rocks.samples.duplicate();field.base=base
  var surface=Mesher.build(field)
  for attribute:String in ['vertices','normals','colors','uv']:
   check(digest(surface.get(attribute).to_byte_array())==baseline.cases[case].attributes[attribute],case+': prior '+attribute+' bytes unchanged')
  check(field.reads<=1000000,case+': dense ordinary preset meshing stays within one million node lookups')
  check(base.tags<=surface.vertices.size()/2,case+': material tagging avoids duplicate work on shared surface crossings')
  print('ACTUAL MESH WORK: ',case,' node_reads=',field.reads,' baseline=',baseline.cases[case].node_value_reads,' tags=',base.tags,' vertex_occurrences=',surface.vertices.size())
 print('TERRAIN MESHER WORK: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
