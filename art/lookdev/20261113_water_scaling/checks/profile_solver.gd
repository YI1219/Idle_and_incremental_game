extends SceneTree
class Old:
 extends "res://art/lookdev/20261113_water_scaling/checks/source_before/water_flow.gd"
 var costs: Dictionary={}
 func _level_existing_basins(excluded: Dictionary={}) -> void:
  var t: int=Time.get_ticks_usec();super._level_existing_basins(excluded);costs.level=float(costs.get("level",0.0))+(Time.get_ticks_usec()-t)/1000.0
 func _rebuild_basins() -> void:
  var t: int=Time.get_ticks_usec();super._rebuild_basins();costs.basins=float(costs.get("basins",0.0))+(Time.get_ticks_usec()-t)/1000.0
class New:
 extends "res://scripts/terrain_editor/water_flow.gd"
 var costs: Dictionary={}
 func _level_existing_basins(excluded: Dictionary={}) -> void:
  var t: int=Time.get_ticks_usec();super._level_existing_basins(excluded);costs.level=float(costs.get("level",0.0))+(Time.get_ticks_usec()-t)/1000.0
 func _rebuild_basins() -> void:
  var t: int=Time.get_ticks_usec();super._rebuild_basins();costs.basins=float(costs.get("basins",0.0))+(Time.get_ticks_usec()-t)/1000.0
func _initialize() -> void:
 for variant: String in ["old","new","new","old"]:
  var data: RefCounted=load("res://scripts/terrain_editor/terrain_data.gd").new();data.make_preset(0)
  var flow: RefCounted=Old.new() if variant=="old" else New.new();flow.configure(data);flow.costs.clear()
  var t: int=Time.get_ticks_usec()
  for i: int in 100:flow.step(.1)
  print(variant," ",Time.get_ticks_usec()-t,"us ",flow.costs," wet ",flow.depths.size())
 quit()
