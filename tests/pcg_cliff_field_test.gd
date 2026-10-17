extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred('run')
func run()->void:
 var path:='res://tools/art/pcg_cliff_field.gd'
 check(ResourceLoader.exists(path),'PCG compiler exists')
 if failures:print('PCG CLIFF: ',checks-failures,'/',checks,' passed');quit(1);return
 var compiler=load(path).new()
 var first=compiler.generate(7301)
 var second=compiler.generate(7301)
 check(first.serialize()==second.serialize(),'same cells/seed regenerate identical ordinary saves')
 var other=compiler.generate(7319)
 check(first.cells==other.cells and first.rocks.records()!=other.rocks.records(),'seed varies rock structure while retaining authored cells')
 var changed_cells:Dictionary=compiler.fixture()
 for cell:Vector2i in changed_cells.keys():
  if cell.x>=4:changed_cells.erase(cell)
 var layout=compiler.generate(7301,false,changed_cells)
 check(layout.cells==changed_cells and layout.cells!=first.cells and layout.rocks.records()!=first.rocks.records(),'changed authored outline regenerates a distinct volume')
 check(not first.sculpt_base_enabled and first.rocks.base==null,'output is explicit editable records, no hidden PCG base')
 check(first.rocks.samples.size()>1000 and first.rocks.samples.size()<first.rocks.MAX_SAMPLES,'bounded ordinary field capacity')
 var finite:=true
 for v:float in first.rocks.samples.values():finite=finite and is_finite(v) and absf(v)<=.5
 check(finite,'all densities finite and bounded')
 var loaded=preload('res://scripts/terrain_editor/terrain_data.gd').new()
 check(loaded.deserialize(first.serialize()),'ordinary production save can load PCG density records')
 check(loaded.serialize()==first.serialize(),'density field and cells survive save/reload exactly')
 var before:Dictionary=first.serialize()
 first.begin_stroke()
 var count:int=first.apply_rock_brush(Vector3(0,1.25,2.25),1.1,'rock_cut',Vector3.FORWARD)
 first.end_stroke()
 check(count>0,'production public carve modifies generated field')
 var edited:Dictionary=first.serialize()
 check(first.undo() and first.serialize()==before,'production undo restores original PCG samples')
 check(first.redo() and first.serialize()==edited,'production redo restores edited samples')
 check(loaded.deserialize(edited) and loaded.serialize()==edited,'edited PCG samples reload exactly')
 var cap_changes:=0
 var original=compiler.generate(7301)
 for key:Vector3i in first.rocks.samples:
  if key.y*.25>=3.0 and first.rocks.node_value(key)!=original.rocks.node_value(key):cap_changes+=1
 check(cap_changes==0,'bounded below-cap cut does not alter cap nodes')
 print('PCG CLIFF: ',checks-failures,'/',checks,' passed')
 quit(1 if failures else 0)
