extends SceneTree
## The old closed cuff was intentionally removed: only retained source leaves
## may form rim cover. Missing leaves must not leave manufactured green pads.
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var cover=field.surfaces.rim_green;var pads:=0;var invalid:=0
 for i in cover.vertices.size():
  if cover.colors[i].b<.99:pads+=1
  if not cover.vertices[i].is_finite() or not cover.normals[i].is_finite() or absf(cover.normals[i].length()-1.0)>.002:invalid+=1
 if cover.vertices.is_empty() or pads>0 or invalid>0:
  failures+=1;push_error("Rim cover must contain finite source blades without solid cuff pads")
 var bare_field:=Field.new();bare_field.refresh(data)
 var bare:=Deco.new();bare.load_assets();bare.assets.erase("grass");bare._column_layout(bare_field,data.seed)
 var manufactured:int=bare_field.surfaces.rim_green.vertices.size()
 if manufactured>0:
  failures+=1;push_error("Missing source leaves leave manufactured rim pads")
 print("RIM SOURCE COVER: vertices=",cover.vertices.size()," cuff_vertices=",pads," invalid=",invalid," missing_source_vertices=",manufactured," failures=",failures)
 quit(1 if failures else 0)
