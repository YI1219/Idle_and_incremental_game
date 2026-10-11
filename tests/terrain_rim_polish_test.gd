extends SceneTree
const Stone=preload("res://scripts/terrain_editor/procedural_stone.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 for seed_value in [11,23,37,41,101,203]:
  var stone:Dictionary=Stone.build(seed_value)
  var arrays:Array=stone.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
  var cap_area:=0.0;var bevel_area:=0.0;var deepest_bevel:=0.0
  var cap_low:=0.0;var cap_high:=0.0;var color_low:=1.0;var color_high:=0.0
  var warm:=false;var cool:=false;var bare_edge:=false;var covered_center:=false
  for i in range(0,vertices.size(),3):
   var normal:=-(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
   var area:=normal.length()*.5
   var up:=normal.normalized().y
   if up>.999:
    cap_area+=area
    for j in 3:
     cap_low=minf(cap_low,vertices[i+j].y);cap_high=maxf(cap_high,vertices[i+j].y)
     bare_edge=bare_edge or uv[i+j].x<.001
     covered_center=covered_center or uv[i+j].x>.15
   elif up>.35 and maxf(vertices[i].y,maxf(vertices[i+1].y,vertices[i+2].y))>-.0001:
    bevel_area+=area
    for j in 3:deepest_bevel=minf(deepest_bevel,vertices[i+j].y)
   for j in 3:
    var tint:=colors[i+j]
    color_low=minf(color_low,tint.get_luminance());color_high=maxf(color_high,tint.get_luminance())
    warm=warm or tint.r>tint.b+.01;cool=cool or tint.b>tint.r+.01
  check(cap_area>.35 and cap_high-cap_low<.0001,"crown %s has a broad planar top"%seed_value)
  check(bevel_area>.01 and deepest_bevel>-.09,"crown %s has a shallow calm shoulder, not deep sawteeth"%seed_value)
  check(bare_edge and covered_center,"crown %s reserves a bare stone lip around its grass interior"%seed_value)
  check(warm and cool and color_high-color_low>.07 and color_high-color_low<.25,"crown %s has restrained warm/cool face albedo"%seed_value)
 print("RIM POLISH: ",checks-failures,"/",checks," passed")
 quit(1 if failures else 0)
