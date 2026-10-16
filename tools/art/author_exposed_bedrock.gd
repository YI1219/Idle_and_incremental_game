extends RefCounted
## An ordinary editable save, not a runtime source-model overlay.
static func author(data,scanned:bool=false,version:String='v1')->void:
 assert(data.sculpt_base_enabled and data.rocks.samples.is_empty())
 var before:Array=data.serialize().cells
 var path:='res://art/work/polyhaven_rocks/2026-10-17/scanned_bedrock_'+version+'.json' if scanned else 'res://art/work/exposed_bedrock/2026-10-17/exposed_v1.json'
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(data.deserialize(payload));data.ensure_sculpt_base()
 assert(data.serialize().cells==before)
 print('EXPOSED BEDROCK: ordinary_loader=true samples=',data.rocks.samples.size())
