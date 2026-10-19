extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	create_timer(30.).timeout.connect(func() -> void: push_error('Module source test timed out'); quit(1))
	call_deferred('run')
func run() -> void:
	var path := 'res://tools/art/volume_module_document.gd'
	if not ResourceLoader.exists(path):
		check(false,'Existing-module editable document is not implemented'); quit(1); return
	var doc: RefCounted = load(path).new()
	check(doc.load_preset(),'Assembled source loads independently')
	var saved: Dictionary = doc.serialize()
	var copy: RefCounted = load(path).new()
	check(copy.deserialize(JSON.parse_string(JSON.stringify(saved))) and copy.serialize()==saved,'Assembly source-bound data roundtrips')
	var old = load('res://tools/art/volume_refined_document.gd').new()
	old.load_preset()
	var old_saved: Dictionary = old.serialize()
	check(not old.deserialize(saved) and old.serialize()==old_saved,'Prior mother rejects assembly edits atomically')
	check(not doc.deserialize(old_saved) and doc.serialize()==saved,'Assembly rejects prior-mother edits atomically')
	check(doc.lake_status().valid,'Same authored pond remains a closed actual basin on this assembly')
	doc.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: doc.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	doc.end_stroke()
	check(doc.field.value_at(Vector3(1.,.8,0))>0 and doc.field.value_at(Vector3(1.,2.,0))<0,'Assembly is one arbitrary-sculpt solid with a real tunnel and roof')
	check(doc.undo() and doc.serialize()==saved,'Undo restores assembly data exactly')
	print('VOLUME MODULE SOURCE: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
