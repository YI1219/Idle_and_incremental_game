extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const BASE={"version":1,"seed":7301,"cells":[{"x":0,"z":0,"height":1.5,"water":-1}]}
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize()->void:call_deferred("run")

func reset(editor:Node3D)->void:
	editor.cancel_input()
	editor.data.deserialize(BASE)
	editor.renderer.rebuild_all()

func write_layout(path:String,payload:Dictionary)->String:
	var text:=JSON.stringify(payload,"",true,true)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return text

func run()->void:
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	editor.renderer.set_process(false)
	editor.camera.set_process(false)
	reset(editor)
	var tools:OptionButton=editor.hud.find_child("TerrainTools",true,false)
	var convert:Button=editor.hud.find_child("ConvertRockBase",true,false)
	var disabled:=true
	for index in range(6,12):disabled=disabled and tools.is_item_disabled(index)
	check(disabled,"heightmap HUD disables all six legacy sculpt tools")
	check(convert.disabled,"heightmap HUD disables the legacy base conversion")
	check(not tools.get_item_tooltip(6).is_empty() and not convert.tooltip_text.is_empty(),"disabled sculpt controls explain the unsupported mode")
	var before:Dictionary=editor.data.serialize()
	convert.pressed.emit()
	check(editor.data.serialize()==before and editor.renderer.active_shell=="heightmap","conversion callback cannot change the default mode or terrain")
	reset(editor)

	editor.tool="rock_add"
	editor.radius=.49
	before=editor.data.serialize()
	var revision:int=editor.data.revision
	check(not editor.begin_paint(Vector2(900,400)),"programmatically selected legacy tool cannot start a heightmap stroke")
	check(editor.data.serialize()==before and editor.data.revision==revision and not editor.painting and not editor.data._active,"rejected sculpt input has no data or stroke side effects")
	editor.cancel_input()
	reset(editor)
	before=editor.data.serialize()
	revision=editor.data.revision
	editor.painting=true
	editor.data.begin_stroke()
	editor._sculpt_at(Vector2(920,420),{"position":Vector3(.5,1.5,.5),"normal":Vector3.UP})
	check(editor.data.serialize()==before and editor.data.revision==revision and editor.data._rock_before.is_empty(),"legacy sculpt dispatch cannot mutate samples during an existing stroke")
	editor.cancel_input()
	reset(editor)

	# An injected stale flag must not implicitly select or construct the old base.
	editor.data.sculpt_base_enabled=true
	editor.renderer.rebuild_all()
	check(editor.renderer.active_shell=="heightmap" and editor.renderer._shell==editor.renderer.island,"sculpt flag cannot implicitly select contour in heightmap mode")
	check(editor.data.rocks.base==null and not editor.renderer._build_data.sculpt_base_enabled,"heightmap publication does not construct a legacy sculpt base")
	reset(editor)

	for version in [2,3,4]:
		reset(editor)
		# Retain both undo and redo entries to detect destructive failed loads.
		for stroke in 2:
			editor.data.begin_stroke()
			editor.data.apply_brush(Vector2(.5,.5),.49,"raise",false,1.5,3)
			editor.data.end_stroke()
		editor.data.undo()
		editor.renderer.rebuild_all()
		before=editor.data.serialize()
		var undo_before:Array=editor.data._undo.duplicate(true)
		var redo_before:Array=editor.data._redo.duplicate(true)
		revision=editor.data.revision
		var legacy:Dictionary=BASE.duplicate(true)
		legacy.version=version
		legacy.rocks=[{"x":2,"y":4,"z":2,"density":-.25}] if version==2 else []
		if version>=3:legacy.sculpt_base=true
		if version==4:legacy.sculpt_profile="local"
		var validator:=Data.new()
		check(validator.deserialize(legacy),"v%d sculpt fixture is valid existing data"%version)
		var path:="user://heightmap_mode_v%d.json"%version
		var original:=write_layout(path,legacy)
		check(editor.load_layout(path)==ERR_UNAVAILABLE,"heightmap rejects supported-but-incompatible v%d sculpt layout"%version)
		check(editor.data.serialize()==before and editor.data.revision==revision and editor.data._undo==undo_before and editor.data._redo==redo_before,"rejected v%d load preserves terrain and both history stacks"%version)
		check(FileAccess.get_file_as_string(path)==original,"rejected v%d load preserves the original file"%version)
		check(editor.data.undo() and editor.data.cells[Vector2i.ZERO].height==1.5,"undo still works after rejected v%d load"%version)
		check(editor.data.redo() and editor.data.redo() and editor.data.cells[Vector2i.ZERO].height==2.5,"redo still works after rejected v%d load"%version)
		DirAccess.remove_absolute(path)

	editor.hud._file_status(ERR_UNAVAILABLE,"Loaded")
	check(editor.hud.status.text.contains("塑形") and editor.hud.status.text.contains("未"),"unsupported load status explains that sculpt data was not loaded")
	var plain_path:="user://heightmap_mode_v1.json"
	write_layout(plain_path,BASE)
	check(editor.load_layout(plain_path)==OK and editor.data.serialize()==BASE and editor.renderer.active_shell=="heightmap","ordinary v1 layouts still load through the heightmap path")
	DirAccess.remove_absolute(plain_path)
	# Compatibility is still available when a developer explicitly selects it.
	editor.renderer.use_heightmap_shell=false
	editor.data.sculpt_base_enabled=true
	editor.renderer.rebuild_all()
	check(editor.renderer.active_shell=="contour" and editor.data.rocks.base!=null,"explicit legacy renderer mode retains its sculpt path")
	editor.free()
	print("HEIGHTMAP MODE: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
