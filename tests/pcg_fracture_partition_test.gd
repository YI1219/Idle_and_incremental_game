extends SceneTree
var failures:=0
var checks:=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred('run')
func run():
 var compiler=preload('res://tools/art/pcg_fracture_field.gd').new()
 compiler.prepare(compiler.fixture(),7301)
 var opposite:=true;var normalized:=true;var ties:=true
 for i:int in compiler.sites.size():
  for j:int in range(i+1,compiler.sites.size()):
   var plane:Vector4=compiler.pair_planes[i][j]
   opposite=opposite and (plane+compiler.pair_planes[j][i]).length()<.00001
   var n:=Vector3(plane.x,plane.y,plane.z)
   normalized=normalized and absf(n.length()-1)<.00001
   var p:=n*plane.w
   var a:Vector3=p-compiler.sites[i].p;var b:Vector3=p-compiler.sites[j].p
   a.y*=.65;b.y*=.65
   ties=ties and absf(a.length_squared()-compiler.sites[i].weight-b.length_squared()+compiler.sites[j].weight)<.001
 check(opposite,'each pair shares exactly opposed halfspaces')
 check(normalized,'fracture distances use unit world-space normals')
 check(ties,'each fracture plane is an equal-power locus under the declared anisotropic metric')
 check(compiler.sites.size()>=8 and compiler.construction.pair_plane_count==compiler.sites.size()*(compiler.sites.size()-1)/2,'bounded3D partition exports all shared plane constraints')
 print('FRACTURE PARTITION: ',checks-failures,'/',checks,' passed');quit(1 if failures else 0)
