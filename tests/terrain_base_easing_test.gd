extends SceneTree
## The broad side approaches the bottom with a flattening tangent, not a
## constant diagonal wedge ending in an abrupt horizontal floor.
func _initialize():
 var args:=OS.get_cmdline_user_args()
 var field=load(args[0] if not args.is_empty() else "res://scripts/terrain_editor/contour_terrain.gd")
 var slopes:Array=[]
 for f:float in [.80,.97]:
  var a:Vector3=field._rock_point(Vector2.ZERO,-f*5.0,f,true,0.0,Vector2.RIGHT,2.8,0.0)
  var b:Vector3=field._rock_point(Vector2.ZERO,-(f+.02)*5.0,f+.02,true,0.0,Vector2.RIGHT,2.8,0.0)
  slopes.append(absf((b.x-a.x)/(b.y-a.y)))
 var ratio:float=slopes[1]/slopes[0]
 print("BASE EASING: tangent ratio=",ratio)
 quit(0 if ratio>2.0 else 1)
