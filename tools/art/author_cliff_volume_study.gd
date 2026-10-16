extends RefCounted
## Ordinary saved-density authoring study; the player can edit its same skin.
## Not a claim that this offline source operation exists as a player brush.
static func author(data,version:String='v1')->void:
 assert(data.sculpt_base_enabled and data.rocks.samples.is_empty())
 var before:Array=data.serialize().cells
 var path:='res://art/work/cliff_volume/2026-10-16/volume_'+version+'.json'
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(data.deserialize(payload),'Study must pass the ordinary sculpt-save loader')
 data.ensure_sculpt_base()
 assert(data.serialize().cells==before)
 print('SOURCE VOLUME STUDY: ordinary_loader=true samples=',data.rocks.samples.size())
