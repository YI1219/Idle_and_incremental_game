extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco = preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize() -> void:
	var block := GDScript.new()
	var code: String = FileAccess.get_file_as_string("res://scripts/terrain_editor/block_mantle.gd")
	code = code.replace("var patches:Dictionary={};", "var moved:Dictionary={};var splits:Dictionary={}\n var patches:Dictionary={};")
	code = code.replace("inset.append(p-shared*recess)", "inset.append(p-shared*recess)\n   if moved.has(p) and moved[p].distance_to(inset[-1])>.0001:splits[p]=[moved[p],inset[-1],h,source.uv[i+j] if false else Vector2.ZERO]\n   moved[p]=inset[-1]")
	code = code.replace('return {"backing":backing', 'print("SPLITS ",splits.size()," ",splits)\n return {"backing":backing')
	# No j exists in this loop; keep the generated diagnostic expression simple.
	code = code.replace("source.uv[i+j] if false else Vector2.ZERO", "Vector2.ZERO")
	block.source_code = code
	if block.reload()!=OK:quit(2);return
	var rim := GDScript.new()
	rim.source_code = FileAccess.get_file_as_string("res://scripts/terrain_editor/rim_union.gd").replace('const Surface=', 'static var raw_result: Variant\nconst Surface=').replace('var mantle=preload', 'raw_result=result\n var mantle=preload')
	rim.source_code = rim.source_code.replace('var tucked:Dictionary={}', 'var tucked:Dictionary={};var mapped:Dictionary={};var torn:Dictionary={}')
	rim.source_code = rim.source_code.replace('points.append(tucked[key])', 'points.append(tucked[key])\n   if mapped.has(point) and mapped[point].distance_to(tucked[key])>.0001:torn[point]=[mapped[point],tucked[key]]\n   mapped[point]=tucked[key]')
	rim.source_code = rim.source_code.replace('raw_result=result', 'print("TUCK SPLITS ",torn.size()," ",torn)\n raw_result=result')
	if rim.reload()!=OK:quit(2);return
	# The normal production layout gives the exact source columns; re-run its
	# union on a fresh field to obtain the real mantle input.
	var deco := Deco.new();deco.load_assets()
	for fixture: String in ["initial","lower","raise"]:
		var data:=Data.new(); data.make_preset(0)
		if fixture!="initial":
			var at:=Vector2(-8,-5) if fixture=="lower" else Vector2(13,0)
			for i in 4:
				var h:float=data.cells[Vector2i(at.floor())].height
				data.begin_stroke();data.apply_brush(at,3.8,fixture,false,h,7,h);data.end_stroke()
		var field:=Field.new();field.refresh(data);deco._column_layout(field,data.seed)
		field.refresh(data)
		print("FIXTURE ",fixture)
		rim.apply(field,deco._columns,deco.assets)
		block.build(rim.raw_result,field.rim_regions,data.cells)
	quit()
