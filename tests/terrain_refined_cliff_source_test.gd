extends SceneTree
const PATH='res://assets/nature/refined/cliff_main_v4.glb'
const TALL_PATH='res://assets/nature/refined/cliff_tall_v2.glb'
var failures:=0
func _initialize()->void:
 if not FileAccess.file_exists(PATH):push_error('Refined retained main cliff source is missing');quit(1);return
 var models=load('res://scripts/terrain_editor/terrain_models.gd').new()
 if not FileAccess.file_exists(TALL_PATH):push_error('Refined retained tall cliff source is missing');quit(1);return
 var source:Array=models._load(PATH,'cliff_rock')
 if source.is_empty():push_error('Refined main cliff source cannot load');quit(1);return
 var merged:Dictionary=models._merge(source)
 var faces:PackedVector3Array=merged.mesh.get_faces()
 if faces.size()/3<=244 or faces.size()/3>1500:failures+=1
 for spec:Array in [[23,.72],[41,.62]]:
  var expected:Dictionary=load('res://scripts/terrain_editor/source_stone_crown.gd').build(merged.mesh,.68,spec[1])
  var actual:Array=models._rock_body_models(spec[0])
  var want:PackedVector3Array=expected.render_mesh.get_faces()
  var got:PackedVector3Array=actual[0].render_mesh.get_faces()
  var mismatch:=want.size()!=got.size()
  if not mismatch:
   for i in want.size():
    if want[i].distance_squared_to(got[i])>1e-12:mismatch=true;break
  if mismatch:failures+=1
  print('REFINED CLIFF PROFILE ',spec[0],': expected_faces=',want.size()/3,' actual_faces=',got.size()/3,' mismatch=',mismatch)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/review/terrain_fidelity/2026-10-15/cliff_refinement/refinement_manifest.json'))
 for file:Dictionary in manifest.source_files:
  if FileAccess.get_sha256('res://'+file.source)!=file.sha256:failures+=1
 print('REFINED CLIFF SOURCE: triangles=',faces.size()/3,' failures=',failures)
 var tall:Dictionary=models._merge(models._load(TALL_PATH,'cliff_rock'))
 for spec:Array in [[11,.72],[37,.86]]:
  var expected:Dictionary=load('res://scripts/terrain_editor/source_stone_crown.gd').build(tall.mesh,.68,spec[1])
  var actual:Array=models._rock_body_models(spec[0])
  var want:PackedVector3Array=expected.render_mesh.get_faces()
  var got:PackedVector3Array=actual[0].render_mesh.get_faces()
  var mismatch:=want.size()!=got.size()
  if not mismatch:
   for i in want.size():
    if want[i].distance_squared_to(got[i])>1e-12:mismatch=true;break
  if mismatch:failures+=1
  print('REFINED TALL PROFILE ',spec[0],': expected_faces=',want.size()/3,' actual_faces=',got.size()/3,' mismatch=',mismatch)
 quit(1 if failures else 0)
