extends SceneTree
## Finite compatibility of the actual study density with ordinary editing.
## Does not accept cap-render overrides, published picking or arbitrary edits.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Contours=preload('res://scripts/terrain_editor/contour_terrain.gd')
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func digest(surface)->String:
 return surface.vertices.to_byte_array().hex_encode().sha256_text()
func _initialize():call_deferred('run')
func run():
 var d=Data.new();d.make_preset(0);var original:Array=d.serialize().cells;d.set_sculpt_base(true)
 var args:=OS.get_cmdline_user_args();var version:='facescan6' if args.is_empty() else args[0]
 preload('res://tools/art/author_exposed_bedrock.gd').author(d,false,version)
 var saved:Dictionary=d.serialize()
 check(saved.version==4 and saved.cells==original,'Study remains the ordinary v4 editable layout, with original cells')
 var copy=Data.new()
 check(copy.deserialize(JSON.parse_string(JSON.stringify(saved))),'Actual study JSON loads')
 copy.ensure_sculpt_base()
 check(copy.serialize()==saved,'Density and layout roundtrip exactly')
 var field=Contours.new();field.refresh(d)
 var before_hash:=digest(field.surfaces.sculpted_terrain)
 var copied_field=Contours.new();copied_field.refresh(copy)
 check(digest(copied_field.surfaces.sculpted_terrain)==before_hash,'Roundtrip rebuilds identical actual skin vertices')
 check(field.surfaces.grass.vertices.is_empty() and field.surfaces.cliff.vertices.is_empty(),'Study has one skin, no hidden old grass/cliff draws')
 var probes:=0;var mismatches:=0
 for x in range(-38,-23):
  for z in range(3,12):
   var p:=Vector2(x*.5,z*.5)
   var hit:Dictionary=field.surface_at(p);var expected:float=d.rocks.height_at(p)
   probes+=1
   if hit.is_empty()!=is_nan(expected):mismatches+=1
   elif not hit.is_empty() and absf(hit.height-expected)>.001:mismatches+=1
 check(probes==135 and mismatches==0,'Actual local indexed support agrees with the sculpted skin height')
 var at:=Vector3(-15.5,3.35,3.3)
 check(d.rocks.value_at(at)<0,'Carve fixture starts inside the actual study')
 d.begin_stroke();var changed:int=d.apply_rock_brush(at,.6,'rock_cut');d.end_stroke()
 var carved:Dictionary=d.serialize()
 check(changed>0 and carved!=saved,'Player brush changes the study data directly')
 field.refresh(d)
 check(digest(field.surfaces.sculpted_terrain)!=before_hash,'Player brush changes the actual study skin')
 check(d.undo() and d.serialize()==saved,'Undo restores the complete original study state')
 field.refresh(d)
 check(digest(field.surfaces.sculpted_terrain)==before_hash,'Undo regenerates identical skin')
 check(d.redo() and d.serialize()==carved,'Redo restores the exact carve')
 var report:Dictionary={'checks':checks,'failures':failures,'support_probes':probes,'support_mismatches':mismatches,'study_samples':saved.rocks.size(),'skin_sha256_hex_algorithm':before_hash,'scope':'Finite ordinary density save/load/support/carve/undo/redo. No actual-cap render override persistence, publication/picking, props, arbitrary sculpture, water routing or performance acceptance.'}
 var path:='res://art/review/terrain_fidelity/2026-10-17/cliff_face_replacement/save_checks.json'
 if version.begins_with('rendered'):path='res://art/work/rendered_island/2026-10-17/save_checks_'+version+'.json'
 if version=='exposedcleft':path='res://art/work/rendered_join/2026-10-17/exposed_cleft/save_checks.json'
 report['study']=version
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('FACE STUDY SAVE: ',checks-failures,'/',checks,' support=',probes,' mismatches=',mismatches)
 quit(1 if failures else 0)
