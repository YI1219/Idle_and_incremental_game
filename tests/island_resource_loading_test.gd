extends SceneTree
## Resource portability and side-effect-free debug assertions. Native debug
## checks cannot substitute for a release export (templates not installed).
func _initialize():
 var failures:=0
 var texture:Texture2D=load('res://assets/textures/terrain/stone_painted_v1.png')
 if texture==null or texture.get_width()<512:
  failures+=1;push_error('Island albedo must load as an imported Texture2D resource')
 var source:=FileAccess.get_file_as_string('res://scripts/terrain_editor/island_editor.gd')
 var forbidden:=RegEx.new();forbidden.compile('assert\\([^\\n]*\\.deserialize\\(')
 if forbidden.search(source)!=null:
  failures+=1;push_error('Deserialization must execute outside debug-only assertions')
 print('ISLAND RESOURCE LOADING: ',2-failures,'/2; release export still untested')
 quit(1 if failures else 0)
