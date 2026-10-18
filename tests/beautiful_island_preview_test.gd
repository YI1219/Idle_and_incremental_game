extends SceneTree
## Actual candidate + public screen editing + isolated preview file boundary.
var checks:=0;var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func bytes(editor)->PackedByteArray:return editor.renderer.contours.surfaces.sculpted_terrain.vertices.to_byte_array()
func run():
 var scene_path:='res://scenes/beautiful_island.tscn'
 check(ResourceLoader.exists(scene_path),'candidate has a separately launchable real editor preview')
 if not ResourceLoader.exists(scene_path):quit(1);return
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;root.add_child(viewport)
 var editor=load(scene_path).instantiate();viewport.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false);editor.renderer.animate_edits=false
 await process_frame;await process_frame
 var panel_fits:bool=editor.hud.panel.get_global_rect().end.y<=720
 check(panel_fits,'preview controls including file/history/layout actions fit a 720p window')
 if not panel_fits:editor.queue_free();viewport.queue_free();quit(1);return
 var cjk_ok:=true
 for control:Node in editor.hud.find_children('*','Control',true,false):
  if not (control is Label or control is Button):continue
  var texts:Array=[control.text]
  if control is OptionButton:
   for i in control.item_count:texts.append(control.get_item_text(i))
  for text:String in texts:
   for character:String in text:
    if character.unicode_at(0)>127 and not control.get_theme_font('font').has_char(character.unicode_at(0)):cjk_ok=false
 check(cjk_ok,'preview font contains the Chinese interface glyphs')
 if not cjk_ok:editor.queue_free();viewport.queue_free();quit(1);return
 check(editor.data.sculpt_base_enabled and editor.data.rocks.samples.size()>1000,'preview loads the real ordinary source-derived volume')
 var home:=InputEventKey.new();home.keycode=KEY_HOME;home.pressed=true
 editor._unhandled_input(home)
 var home_ok:bool=editor.camera._center_goal==Vector2(-11,-5)
 check(home_ok,'preview Home key recenters its actual island')
 if not home_ok:editor.queue_free();viewport.queue_free();quit(1);return
 var before:Dictionary=editor.data.serialize();var original:=bytes(editor)
 check(editor.renderer.decoration._columns.is_empty(),'preview contains no hidden source wall instances')
 var screen:Vector2=editor.camera.unproject_position(Vector3(-12,3.5,-2))
 var hit:Dictionary=editor._pointer(screen)
 check(not hit.is_empty() and absf(hit.position.y-3.5)<.01,'live preview camera screen ray picks the actual shared cap')
 var tools=editor.hud.find_child('TerrainTools',true,false)
 tools.select(7);tools.item_selected.emit(7);editor.radius=.8
 check(editor.begin_paint(screen),'actual player screen route begins a rock cut')
 editor.continue_paint(screen);editor.cancel_input()
 while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
 var after:Dictionary=editor.data.serialize();var cut:=bytes(editor)
 hit=editor._pointer(screen)
 check(cut!=original and not hit.is_empty() and absf(editor.data.rocks.value_at(hit.position))<.002 and hit.position.y<3.5,'published cut is visible and picked without a stale top overlay')
 check(editor.renderer.contours.cover_report.vertex_bytes_unchanged,'top-color cover is rebuilt from current geometry during editing')
 check(editor.data.undo() and editor.data.serialize()==before,'preview player stroke is undoable')
 editor.renderer.rebuild_all();check(bytes(editor)==original,'preview undo restores original published geometry')
 check(editor.data.redo() and editor.data.serialize()==after,'preview stroke is redoable')
 editor.renderer.rebuild_all();check(bytes(editor)==cut,'preview redo restores carved published geometry')
 var path:='user://terrain_editor/layout.json'
 var preview_path:String=editor.PREVIEW_SAVE
 var preview_existed:=FileAccess.file_exists(preview_path)
 var preview_bytes:=FileAccess.get_file_as_bytes(preview_path) if preview_existed else PackedByteArray()
 var legacy:=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
 var legacy_existed:=FileAccess.file_exists(path)
 check(editor.save_layout(path)==OK,'preview normal Save action succeeds')
 check(FileAccess.file_exists(path)==legacy_existed and (not legacy_existed or FileAccess.get_file_as_bytes(path)==legacy),'preview Save preserves the normal workshop save')
 check(editor.load_layout(path)==OK and bytes(editor)==cut,'preview normal Load action restores its own exact geometry')
 if preview_existed:FileAccess.open(preview_path,FileAccess.WRITE).store_buffer(preview_bytes)
 else:DirAccess.remove_absolute(preview_path)
 check(editor.hud.find_child('TerrainPresets',true,false).item_count==4,'preview offers two contours and two fixed seeds')
 var before_place:Dictionary=editor.data.serialize()
 tools.select(2);tools.item_selected.emit(2);editor.build_height=3.5;editor.radius=.49;editor.snap=true
 var placed_cell:=Vector2i(-3,-5)
 var place_screen:Vector2=editor.camera.unproject_position(Vector3(-2.5,3.5,-4.5))
 check(not editor.data.cells.has(placed_cell) and editor.begin_paint(place_screen),'player pointer route can place land outside the current contour')
 editor.cancel_input()
 while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
 check(editor.data.cells.has(placed_cell) and not editor.renderer.contours.surface_at(Vector2(-2.5,-4.5)).is_empty(),'new land is published from the same authoritative edited cells')
 check(editor.data.undo() and editor.data.serialize()==before_place,'land placement undoes without losing sculpt records')
 editor.queue_free();viewport.queue_free()
 print('BEAUTIFUL ISLAND PREVIEW: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
