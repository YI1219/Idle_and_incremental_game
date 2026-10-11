extends SceneTree
## Upper-terrace feet can lie above -1.7 m. The skirt and wall must still
## share their exact boundary after mantle backing recession.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const Mantle=preload("res://scripts/terrain_editor/block_mantle.gd")
func _initialize():
 var failed:=0;var checked:=0;var worst:=0.0
 for y in [-2.8,-1.7,-1.54,-1.34,-1.12]:
  var source:=Surface.new()
  var left:=Vector3(0,y,0);var right:=Vector3(3,y,0)
  source.triangle(Vector3(1.5,3.5,0),left,right,Color.WHITE)
  for j in 3:source.uv[j]=Vector2(3.5,0)
  source.triangle(right,left,Vector3(1.5,-2.1,2),Color.WHITE)
  for j in range(3,6):source.uv[j]=Vector2(1.5,-1)
  var backing= Mantle.build(source).backing
  for j in 6:
   if source.vertices[j]!=left and source.vertices[j]!=right:continue
   checked+=1
   var distance:float=source.vertices[j].distance_to(backing.vertices[j])
   worst=maxf(worst,distance)
   if distance>.00001:failed+=1
 print("BOTTOM SEAM: ",JSON.stringify({"shared_vertices":checked,"split_vertices":failed,"maximum_separation":worst,"passed":failed==0}))
 quit(0 if failed==0 else 1)
