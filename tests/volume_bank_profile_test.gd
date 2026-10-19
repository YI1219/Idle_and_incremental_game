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
	var path := 'res://tools/art/volume_bank_profile.gd'
	if not ResourceLoader.exists(path):
		check(false,'Designed bank-profile study is not implemented')
		quit(1)
		return
	var original = load('res://scripts/terrain_volume/patch_document.gd').new()
	original.load_preset()
	var before: Dictionary = original.serialize()
	var doc: RefCounted = load(path).make()
	check(doc != null,'Bank study creates an independent editable document')
	if doc == null:
		quit(1)
		return
	check(doc.lake_status().valid,'Raised water remains enclosed in the actual three-dimensional basin')
	check(absf(doc.field.height_at(Vector2(-.8,0))-2.55)<.04,'Lake floor is explicitly designed rather than a spherical cut')
	check(doc.field.height_at(Vector2(-.3,0))<float(doc.lake.level),'Inner bank remains submerged')
	check(doc.field.height_at(Vector2(.4,0))>float(doc.lake.level),'Outer bank has a dry supported shoulder')
	check(doc.field.height_at(Vector2(2,0))==original.field.height_at(Vector2(2,0)),'Dry land outside the pond preserves its original height')
	check(original.serialize()==before,'Constructing the study leaves the original document untouched')
	var copy = load('res://scripts/terrain_volume/patch_document.gd').new()
	var saved: Dictionary = doc.serialize()
	check(copy.deserialize(JSON.parse_string(JSON.stringify(saved,'',true,true))) and copy.serialize()==saved,'New bank is ordinary source-bound v5 editable data')
	doc.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]:
		doc.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	doc.end_stroke()
	check(not doc.lake_status().valid,'Cutting through the designed bank invalidates unsupported water')
	check(doc.undo() and doc.serialize()==saved and doc.lake_status().valid,'Undo restores the designed shore and water together')
	print('VOLUME BANK PROFILE: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
