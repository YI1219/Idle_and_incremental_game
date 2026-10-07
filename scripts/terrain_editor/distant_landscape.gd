class_name DistantLandscape
extends Node3D
## Distant, non-interactive mountain scenery. It never supplies courtyard land.
## Three mesh resources in cullable angular sectors; no shadows or colliders.
func _ready()->void:
 var rng:=RandomNumberGenerator.new()
 rng.seed=721035
 var material:=ShaderMaterial.new()
 material.shader=load("res://shaders/terrain_editor/distant_mountain.gdshader")
 for variant in 3:
  var mesh:=_mountain(variant)
  mesh.surface_set_material(0,material)
  var poses:Array[Transform3D]=[]
  for i in 100:
   var angle:=TAU*(float(i)/100.0)+variant*.071+rng.randf_range(-.045,.045)
   var radius:=400.0+variant*200.0+rng.randf_range(-14,18)
   var height:=rng.randf_range(15,32)*(radius/170.0)
   var width:=rng.randf_range(10,16)*(radius/170.0)
   var at:=Vector3(sin(angle)*radius,-radius*rng.randf_range(.22,.86)-height*.5,cos(angle)*radius)
   var basis:=Basis(Vector3.UP,rng.randf()*TAU).scaled_local(Vector3(width,height,width*rng.randf_range(.70,1.1)))
   poses.append(Transform3D(basis,at))
  # One all-around MultiMesh has a huge AABB and submits mountains behind the
  # camera. Angular sectors preserve all poses while allowing ordinary culling.
  for sector in 8:
   var start:=sector*100/8
   var finish:=(sector+1)*100/8
   var mm:=MultiMesh.new()
   mm.transform_format=MultiMesh.TRANSFORM_3D
   mm.mesh=mesh
   mm.instance_count=finish-start
   for i in range(start,finish):mm.set_instance_transform(i-start,poses[i])
   var instance:=MultiMeshInstance3D.new()
   instance.multimesh=mm
   instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(instance)
func _mountain(variant:int)->ArrayMesh:
 var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
 const SIDES=12
 const LEVELS=10
 for spur in 5:
  var rings:Array[PackedVector3Array]=[]
  var turn:=spur*2.4+variant
  var offset:=Vector2(cos(turn),sin(turn))*(.0 if spur==0 else .42)
  var tall:=1.0 if spur==0 else .50+.30*sin(spur*1.7+variant)
  var wide:=.66 if spur==0 else .43
  for level in LEVELS+1:
   var ring:=PackedVector3Array()
   var t:=float(level)/LEVELS
   for i in SIDES:
    var a:=TAU*i/SIDES
    var flute:=.86+.12*sin(a*5+variant*2.1)+.10*sin(a*9+spur)
    var radius:=pow(maxf(.0001,1.0-t),.40)*flute*wide*(1+.11*sin(t*33+a*4+variant))
    var center:=offset+Vector2(sin(t*2.5+variant)*.10*t,cos(t*3.1+variant)*.10*t)
    var y:=(t+sin(a*7+variant+t*13)*.030*sin(PI*t))*tall
    ring.append(Vector3(cos(a)*radius+center.x,y,sin(a)*radius+center.y))
   rings.append(ring)
  if spur<3:
   for level in [7,9]:
    for i in range(0,SIDES,2):
     if sin(i*4.1+spur*1.3+variant)<-.25:continue
     _ridge_crown(surface,rings[level][i]+Vector3(0,.012,0),.035+.008*sin(i*1.7))
  for j in LEVELS:
   for i in SIDES:
    var n:=(i+1)%SIDES
    var tint:=Color(.65+.12*sin(i*3.1+j*4.7+variant),.70,.65,1)
    surface.triangle(rings[j][i],rings[j][n],rings[j+1][i],tint)
    surface.triangle(rings[j][n],rings[j+1][n],rings[j+1][i],tint)
 return surface.mesh()

func _ridge_crown(surface,center:Vector3,radius:float)->void:
 for i in 6:
  var a:=TAU*i/6.0
  var b:=TAU*(i+1)/6.0
  var p:=center+Vector3(cos(a)*radius,0,sin(a)*radius)
  var q:=center+Vector3(cos(b)*radius,0,sin(b)*radius)
  surface.triangle(center+Vector3(0,radius*.65,0),q,p,Color(1,.7,.5),true)
  surface.triangle(center-Vector3(0,radius*.35,0),p,q,Color(1,.7,.5))
