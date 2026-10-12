extends SceneTree
func _initialize():
 var failures:=0
 for path in ["stone_detail","ground_detail"]:
  var texture:Texture2D=load("res://assets/textures/terrain/"+path+".png")
  var ok:=texture.get_image().has_mipmaps()
  print(path," mipmaps=",ok)
  if not ok:failures+=1
 quit(1 if failures else 0)
