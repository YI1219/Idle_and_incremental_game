extends SceneTree
func _initialize():
 var failures:=0
 for path in ["stone_detail.png","ground_detail.png","stone_mineral_v1.png","stone_detail_spall_v3.res"]:
  var texture:Texture2D=load("res://assets/textures/terrain/"+path)
  var ok:=texture.get_image().has_mipmaps()
  print(path," mipmaps=",ok)
  if not ok:failures+=1
 quit(1 if failures else 0)
