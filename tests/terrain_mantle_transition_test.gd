extends SceneTree
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
func _initialize():
 var args:=OS.get_cmdline_user_args()
 var mantle=load(args[0] if not args.is_empty() else "res://scripts/terrain_editor/block_mantle.gd")
 var source:=Surface.new()
 source.quad(Vector3(-8,-1,0),Vector3(-8,-3,0),Vector3(8,-3,0),Vector3(8,-1,0),Color.WHITE)
 for i in source.uv.size():source.uv[i]=Vector2(1.5,0)
 var result:Dictionary=mantle.build(source)
 var ok:bool=result.bodies.is_empty() and result.backing.vertices.size()==source.vertices.size()
 print("MANTLE TRANSITION: lower plates=",result.bodies.size()," backing retained=",result.backing.vertices.size()==source.vertices.size())
 quit(0 if ok else 1)
