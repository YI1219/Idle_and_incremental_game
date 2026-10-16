extends RefCounted
## An ordinary editable save, not a runtime source-model overlay.
static func author(data,scanned:bool=false,version:String='v1')->void:
 assert(data.sculpt_base_enabled and data.rocks.samples.is_empty())
 var before:Array=data.serialize().cells
 var path:='res://art/work/polyhaven_rocks/2026-10-17/scanned_bedrock_'+version+'.json' if scanned else 'res://art/work/exposed_bedrock/2026-10-17/exposed_v1.json'
 if version=='face':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_v1.json'
 if version=='face2':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_v2.json'
 if version=='facescan':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan.json'
 if version=='facescan2':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan2.json'
 if version=='facescan3':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan3.json'
 if version=='facescan4':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan4.json'
 if version=='facescan5':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan5.json'
 if version=='facescan6':path='res://art/work/cliff_face_replacement/2026-10-17/face_replacement_scan6.json'
 if version=='renderedbody':path='res://art/work/rendered_island/2026-10-17/rendered_body_v1.json'
 if version=='renderedclosed':path='res://art/work/rendered_island/2026-10-17/rendered_body_closed.json'
 if version=='renderedenvelope':path='res://art/work/rendered_island/2026-10-17/rendered_body_envelope.json'
 if version=='renderedenvelopecap':path='res://art/work/rendered_island/2026-10-17/rendered_body_envelopecap.json'
 if version=='renderedcomplete':path='res://art/work/rendered_island/2026-10-17/complete/rendered_body_complete.json'
 if version=='retainedreturn':path='res://art/work/rendered_island/2026-10-17/complete/retained_return_v1.json'
 if version=='cliffgroup':path='res://art/work/cliff_group_volume/2026-10-17/group_volume_v1.json'
 if version=='cliffgroup2':path='res://art/work/cliff_group_volume/2026-10-17/group_volume_v2.json'
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(data.deserialize(payload));data.ensure_sculpt_base()
 assert(data.serialize().cells==before)
 print('EXPOSED BEDROCK: ordinary_loader=true samples=',data.rocks.samples.size())
