extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var path := 'res://tools/art/volume_refined_document.gd'
	if not ResourceLoader.exists(path):
		check(false,'Existing-source refined document is not implemented')
		quit(1)
		return
	var doc = load(path).new()
	check(doc.load_preset(),'Refined source loads as an independently bound editable document')
	var original = load('res://scripts/terrain_volume/patch_document.gd').new()
	original.load_preset()
	var old: Dictionary = original.serialize()
	var saved: Dictionary = doc.serialize()
	check(doc.lake_status().valid,'Refined mother and designed shore enclose the water')
	check(saved.source_sha256 != old.source_sha256,'Save binding distinguishes refined geometry from the original')
	var restored = load(path).new()
	check(restored.deserialize(JSON.parse_string(JSON.stringify(saved))) and restored.serialize()==saved,'Refined data roundtrips against its own immutable source')
	check(not original.deserialize(saved) and original.serialize()==old,'Original rejects refined source data atomically')
	check(not doc.deserialize(old) and doc.serialize()==saved,'Refined source rejects original-bound edits atomically')
	doc.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: doc.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	doc.end_stroke()
	check(doc.field.value_at(Vector3(1.,.8,0))>0. and doc.field.value_at(Vector3(1.,2.,0))<0.,'Actual tunnel preserves the roof in the refined solid')
	check(doc.undo() and doc.serialize()==saved,'Undo restores source, shore and override data exactly')
	print('VOLUME REFINED SOURCE: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
