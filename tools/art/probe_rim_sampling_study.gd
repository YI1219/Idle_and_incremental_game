extends SceneTree
## The same visible boundary must keep its grass roots when triangulation
## introduces collinear edge vertices. Tests actual retained grass geometry.
var Detail=preload('res://tools/art/rim_world_probe_study.gd')
func _initialize():call_deferred('run')
func roots(surface)->Dictionary:
 var result:Dictionary={}
 for i in surface.uv2.size():
  var p:Vector2=surface.uv2[i].snapped(Vector2.ONE*.001)
  var key:=str(Vector3(p.x,surface.uv[i].x,p.y))
  result[key]=result.get(key,0)+1
 return result
func left_roots(surface,angle:float)->Dictionary:
 var result:Dictionary={}
 for i in surface.uv2.size():
  var p:Vector2=surface.uv2[i].snapped(Vector2.ONE*.001)
  if p.rotated(-angle).x>= -3.6:continue
  var key:=str(Vector3(p.x,surface.uv[i].x,p.y))
  result[key]=result.get(key,0)+1
 return result
func run():
 var args:=OS.get_cmdline_user_args()
 if args.has('baseline'):Detail=preload('res://scripts/terrain_editor/rim_surface_detail.gd')
 if args.has('arc'):Detail=preload('res://tools/art/rim_arc_probe_study.gd')
 var models=preload('res://scripts/terrain_editor/terrain_models.gd').new();models.load_assets()
 var failures:=0
 for angle:float in [0.0,.37]:
  if not fixture(models,angle):failures+=1
 print('RIM SAMPLING FIXTURES: ',2-failures,'/2')
 quit(1 if failures else 0)
func fixture(models,angle:float)->bool:
 var loop:=PackedVector2Array([Vector2(-4,-2),Vector2(4,-2),Vector2(4,2),Vector2(-4,2)])
 for i in loop.size():loop[i]=loop[i].rotated(angle)
 var dense:=PackedVector2Array()
 for i in loop.size():
  for j in 200:dense.append(loop[i].lerp(loop[(i+1)%loop.size()],float(j)/200))
 var rotated:=PackedVector2Array([loop[2],loop[3],loop[0],loop[1]])
 var crown:=loop.duplicate();crown.append(loop[0])
 var crowns:Array=[{'polygon':crown,'height':3.5}]
 var coarse=Detail.lip({3.5:[loop]},crowns,models.assets)
 var fine=Detail.lip({3.5:[dense]},crowns,models.assets)
 var shifted=Detail.lip({3.5:[rotated]},crowns,models.assets)
 var expanded:=PackedVector2Array([Vector2(-4,-2),Vector2(6,-2),Vector2(6,2),Vector2(-4,2)])
 for i in expanded.size():expanded[i]=expanded[i].rotated(angle)
 var expanded_crown:=expanded.duplicate();expanded_crown.append(expanded[0])
 var edited=Detail.lip({3.5:[expanded]},[{'polygon':expanded_crown,'height':3.5}],models.assets)
 var expected:=roots(coarse);var retessellated:=roots(fine);var different_start:=roots(shifted)
 var stable_left:bool=left_roots(coarse,angle)==left_roots(edited,angle) and not left_roots(coarse,angle).is_empty()
 var same:bool=expected==retessellated and expected==different_start and expected.size()>20 and stable_left
 print('RIM SAMPLING: angle=',angle,' coarse_roots=',expected.size(),' retessellated_roots=',retessellated.size(),' shifted_roots=',different_start.size(),' untouched_left_stable=',stable_left,' stable=',same)
 return same
