extends SceneTree
func _initialize():call_deferred('run')
func root_of(parents:Array[int],i:int)->int:
 while parents[i]!=i:
  parents[i]=parents[parents[i]];i=parents[i]
 return i
func run():
 var d=load('res://scripts/terrain_editor/terrain_data.gd').new();d.make_preset(0);var cells=d.cells.duplicate(true)
 d.set_sculpt_base(true);load('res://tools/art/author_unified_cliff_cutstone.gd').full_island(d)
 var skin=load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks)
 var ids:Dictionary={};var parents:Array[int]=[];var edges:Dictionary={}
 for i in range(0,skin.vertices.size(),3):
  var triangle:Array[int]=[]
  for j in 3:
   var p:Vector3=skin.vertices[i+j]
   if not ids.has(p):ids[p]=parents.size();parents.append(parents.size())
   triangle.append(ids[p])
  for j in [1,2]:parents[root_of(parents,triangle[j])]=root_of(parents,triangle[0])
  for j in 3:
   var a:=triangle[j];var b:=triangle[(j+1)%3];var key:=Vector2i(mini(a,b),maxi(a,b));edges[key]=edges.get(key,0)+1
 var components:Dictionary={};var invalid:=0
 for i in parents.size():components[root_of(parents,i)]=true
 for count:int in edges.values():
  if count!=2:invalid+=1
 var ok:bool=components.size()==1 and invalid==0 and d.cells==cells and d.rocks.samples.size()>1000
 print('SHOULDER ISLAND: vertices=',skin.vertices.size(),' components=',components.size(),' invalid_edges=',invalid,' samples=',d.rocks.samples.size(),' same_cells=',d.cells==cells,' passed=',ok)
 quit(0 if ok else 1)
