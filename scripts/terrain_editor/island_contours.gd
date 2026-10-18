extends 'res://scripts/terrain_editor/contour_terrain.gd'
## Preview-specific finish runs after every real rebuild, including partial
## edit publication and load. Old workshop rendering keeps its current rule.
var cover_report:Dictionary={}
func refresh(data:Data)->void:
 super.refresh(data)
 cover_report={}
 if data.sculpt_base_enabled:
  cover_report=preload('res://scripts/terrain_editor/terrain_top_cover.gd').apply(self,data.rocks)
