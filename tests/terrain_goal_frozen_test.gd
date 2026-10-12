extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():
 var data:=Data.new();data.make_preset(0);var original:=hash(data.serialize());var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco.contours=field;deco._column_layout(field,data.seed)
 var report:={"cells":hash(data.serialize()),"rim":hash(field.rim_regions),"water":hash(field.surfaces.water.vertices),"falls":hash(field.surfaces.waterfall.vertices)}
 # The renderer may reshape its rim, but must not mutate authoritative data.
 var ok:bool=hash(data.serialize())==original
 print("SOURCE PRESERVATION: ",JSON.stringify({"generated":report,"source_unchanged":ok}))
 quit(0 if ok else 1)
