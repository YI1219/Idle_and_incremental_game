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
	var path := 'res://tools/art/volume_plane_document.gd'
	if not ResourceLoader.exists(path):
		check(false,'Plane-source study document is not implemented')
		quit(1)
		return
	var paths: Array[String] = ['res://scripts/terrain_volume/patch_document.gd','res://tools/art/volume_refined_document.gd',path]
	var documents: Array[RefCounted] = []
	for p: String in paths:
		var doc: RefCounted = load(p).new()
		check(doc.load_preset(),'Source loads: '+p)
		documents.append(doc)
	for i: int in documents.size():
		var saved: Dictionary = documents[i].serialize()
		var copy: RefCounted = load(paths[i]).new()
		check(copy.deserialize(JSON.parse_string(JSON.stringify(saved))) and copy.serialize()==saved,'Source-bound roundtrip: '+paths[i])
		for j: int in documents.size():
			if i==j: continue
			check(not documents[i].deserialize(documents[j].serialize()) and documents[i].serialize()==saved,'Cross-source replay rejected atomically')
	var candidate := documents[2]
	var before: Dictionary = candidate.serialize()
	check(candidate.lake_status().valid,'Existing designed bank stays closed on the new side planes')
	candidate.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: candidate.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	candidate.end_stroke()
	check(candidate.field.value_at(Vector3(1.,.8,0))>0 and candidate.field.value_at(Vector3(1.,2.,0))<0,'New side planes retain arbitrary tunnel and supported roof')
	check(candidate.undo() and candidate.serialize()==before,'Undo restores new-source document exactly')
	print('VOLUME PLANE SOURCE: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
