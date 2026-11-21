extends SceneTree
func _initialize() -> void:
 var data := preload("res://scripts/terrain_editor/terrain_data.gd").new()
 data.make_preset(0)
 var field := preload("res://scripts/terrain_editor/contour_terrain.gd").new()
 field.refresh(data)
 var deco := preload("res://scripts/terrain_editor/terrain_decoration.gd").new()
 deco.contours=field
 deco.load_assets()
 for p: Vector2 in [Vector2(-15.6,-3.2), Vector2(-17.4,-7.1), Vector2(-13.8,-8.6),Vector2(-3.8,-7.8),Vector2(15.4,1.8),Vector2(14.8,-.9)]:
  var surf: Dictionary = field.surface_at(p)
  print(p, " surface=",surf," stable=",false if surf.is_empty() else deco._stable(field,p,surf.height,.6))
  for side: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:print("  ",p+side*.6,": ",field.surface_at(p+side*.6))
 var chunks: Dictionary = {}
 for c: Vector2i in data.cells:chunks[data.chunk_of(c)]=true
 for c: Vector2i in chunks:
  var groups: Dictionary = deco.placements(data,c)
  for kind: String in ["tree","tree_b"]:
   for pose: Transform3D in groups[kind]:print(kind," ",pose.origin)
 quit()
