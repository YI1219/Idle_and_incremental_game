extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Flow = preload("res://scripts/terrain_editor/water_flow.gd")
const Water = preload("res://scripts/terrain_editor/water_renderer.gd")
func _initialize()->void:
	var data:=Data.new()
	data.make_preset(0)
	var flow:=Flow.new()
	flow.configure(data)
	flow.step(.1)
	var field:=Water.FlowField.new()
	field.build_live(data,flow)
	for veil:Dictionary in field.fall_veils:print("VEIL ",veil)
	for key:Variant in field.water_regions:
		field._basin=int(key)
		for loop:PackedVector2Array in field.water_regions[key]:
			loop=field._subdivide_outline(loop)
			var edges:Array=field._flow_edges(loop,float(flow.basins[int(key)].height)+.045)
			for i:int in loop.size():
				if edges[i].spill or (key==1 and loop[i].x>3.0 and loop[i].y>=0.0 and loop[i].y<1.1):print("EDGE ",key," ",loop[i]," -> ",loop[(i+1)%loop.size()]," ",edges[i]," outside=",field.surface_at((loop[i]+loop[(i+1)%loop.size()])*.5+Vector2((loop[(i+1)%loop.size()]-loop[i]).y,-(loop[(i+1)%loop.size()]-loop[i]).x).normalized()*.28))
	quit()
