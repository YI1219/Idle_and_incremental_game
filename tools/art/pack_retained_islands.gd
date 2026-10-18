extends SceneTree
const Preset=preload('res://scripts/terrain_editor/island_preset.gd')
const WORK='res://art/work/retained_island/2026-10-18/'
func _initialize():
 DirAccess.make_dir_recursive_absolute('res://assets/terrain_editor/island_presets')
 for case:String in ['courtyard_7301','courtyard_7319','bay_7301','bay_7319']:
  var folder:String=WORK if case=='courtyard_7301' else WORK+case+'/'
  var file:String=folder+'candidate.layout'
  assert(FileAccess.file_exists(file),file)
  var preset:=Preset.new();preset.layout=JSON.parse_string(FileAccess.get_file_as_string(file))
  assert(preset.layout.version==4 and preset.layout.rocks.size()>1000)
  assert(ResourceSaver.save(preset,'res://assets/terrain_editor/island_presets/'+case+'.res',ResourceSaver.FLAG_COMPRESS)==OK)
  print('PACKED ORDINARY ISLAND: ',case,' records=',preset.layout.rocks.size())
 quit()
