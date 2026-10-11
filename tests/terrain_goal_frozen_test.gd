extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco.contours=field;deco._column_layout(field,data.seed)
 var report:={"cells":hash(data.serialize()),"rim":hash(field.rim_regions),"water":hash(field.surfaces.water.vertices),"falls":hash(field.surfaces.waterfall.vertices)}
 # Recorded by this same fixture before production edits at f39052c.
 var expected:={"cells":3214587788,"rim":3647164281,"water":440449048,"falls":3181142195}
 var ok:bool=report==expected
 print("FROZEN: ",JSON.stringify({"baseline":"f39052c","before":expected,"after":report,"identical":ok}))
 quit(0 if ok else 1)
