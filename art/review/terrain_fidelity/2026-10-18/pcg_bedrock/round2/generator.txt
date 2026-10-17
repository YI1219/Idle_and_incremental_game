extends RefCounted
## Goal round2: 3D oblique face chains, with no vertical contour clamp.
## Domains are analytic density constraints, never placed runtime rock assets.
const Guide=preload('res://tools/art/pcg_cliff_field.gd')
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const STEP:=.25
const TOP:=3.5
var guide=Guide.new()
var sectors:Array=[]
var perimeter:=0.0
var center:=Vector2.ZERO
func fixture()->Dictionary:return guide.fixture()
func horizontal(p:Vector2)->Dictionary:return guide.horizontal(p)
func cap_height(distance:float,arc:float)->float:
 var phase:=arc/maxf(perimeter,.01)*TAU
 return TOP+.035*sin(phase*3)-(.07+.055*sin(phase*5))*(1.0-smoothstep(.02,.60,-distance))
static func smin(a:float,b:float,k:float)->float:
 var h:=maxf(k-absf(a-b),0.0)/k
 return minf(a,b)-h*h*k*.25
static func smax(a:float,b:float,k:float)->float:return -smin(-a,-b,k)
func lower_height(p:Vector2)->float:
 var q:=p-center
 return -4.1+.035*(q.x*q.x+.65*q.y*q.y)+.07*q.x-.06*q.y
func prepare(records:Dictionary,seed_value:int)->void:
 guide.prepare(records,seed_value);perimeter=guide.perimeter
 center=Vector2.ZERO
 for cell:Vector2i in records:center+=(Vector2(cell)+Vector2.ONE*.5)/records.size()
 sectors.clear()
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var arc:=0.0
 while arc<perimeter:
  var width:=rng.randf_range(3.25,4.75)
  if perimeter-arc<width*1.45:width=perimeter-arc
  var at:=guide.point_at(arc+width*.5)
  var tangent:=guide.tangent_at(arc+width*.5)
  var out:=Vector2(tangent.y,-tangent.x)
  if Geometry2D.is_point_in_polygon(at+out*.1,guide.loops[0]):out=-out
  var shoulder:=rng.randf_range(2.05,2.85)
  var belly:=rng.randf_range(-.15,.65)
  var ankle:=rng.randf_range(-2.55,-1.75)
  var projection:=rng.randf_range(.24,.46)
  var belly_projection:=rng.randf_range(.60,.88)
  var foot_projection:=rng.randf_range(-.65,-.30)
  var upper_slope:float=projection/(TOP-shoulder)
  var middle_slope:float=(belly_projection-projection)/(shoulder-belly)
  var lower_slope:float=(belly_projection-foot_projection)/(belly-ankle)
  var return_slope:=rng.randf_range(.85,1.18)
  # Four full 3D planes meet along real oblique edges. The side widens
  # beneath its shoulder, then turns inward twice; there is no upright
  # rectangle cut off by a separate bottom surface.
  var planes:Array[Vector4]=[
   Vector4(rng.randf_range(-.10,.10),upper_slope,1.0,upper_slope*TOP+.035),
   Vector4(rng.randf_range(-.10,.10),middle_slope,1.0,projection+middle_slope*shoulder),
   Vector4(rng.randf_range(-.08,.08),-lower_slope,1.0,belly_projection-lower_slope*belly),
   Vector4(rng.randf_range(-.08,.08),-return_slope,1.0,foot_projection-return_slope*ankle),
   Vector4(-1.0,.09,.04,width*.53+.09*TOP),
   Vector4(1.0,.07,.04,width*.52+.07*TOP),
   Vector4(-.65,.12,.76,width*.31+.12*TOP),
   Vector4(.61,.08,.79,width*.30+.08*TOP),
   Vector4(-.52,-.48,.31,width*.43+1.12),
   Vector4(.58,-.43,.27,width*.41+1.15),
   Vector4(0,0,-1.0,3.5+width*.22),
   Vector4(.08,-1,-.12,3.8)
  ]
  for i in planes.size():
   var plane:=planes[i];var length:=Vector3(plane.x,plane.y,plane.z).length();planes[i]=plane/length
  sectors.append({'arc':arc,'width':width,'at':at,'tangent':tangent,'outward':out,'planes':planes})
  arc+=width
func rock_distance(p:Vector3,h:Dictionary)->float:
 var horizontal_position:=Vector2(p.x,p.z)
 # Interior support is part of the same geological solid. It is behind the
 # exposed domains, not an independent decorative lower skin.
 var depth:=maxf(0.0,TOP-p.y)
 var value:=maxf(h.distance+.72+.48*maxf(0.0,depth-2.0),p.y-3.12)
 for sector:Dictionary in sectors:
  var delta:Vector2=horizontal_position-sector.at
  var q:=Vector3(delta.dot(sector.tangent),p.y,delta.dot(sector.outward))
  var distance:=-INF
  for plane:Vector4 in sector.planes:distance=maxf(distance,q.x*plane.x+q.y*plane.y+q.z*plane.z-plane.w)
  value=smin(value,distance,.18)
 # Preserve the authored cap while leaving lower oblique planes free to
 # form actual shoulders. The first trial's fixed .30 contour clamp erased
 # their projection and made another upright wall.
 var guard:=.045+.95*(1.0-smoothstep(1.25,3.5,p.y))
 return maxf(maxf(value,h.distance-guard),p.y-cap_height(h.distance,h.arc)+.025)
func soil_distance(p:Vector3,h:Dictionary)->float:
 var roof:=cap_height(h.distance,h.arc)
 var phase:float=h.arc/maxf(perimeter,.01)*TAU
 var thickness:=.32+.18*(.5+.5*sin(phase*4+.6*sin(phase*7)))
 var depth:=clampf((roof-p.y)/thickness,0,1)
 var side:float=h.distance+.13*depth*depth
 return smax(smax(side,p.y-roof,.10),roof-thickness-p.y,.10)
func density(p:Vector3,h:Dictionary)->float:
 var solid:=smin(rock_distance(p,h),soil_distance(p,h),.12)
 return smax(solid,lower_height(Vector2(p.x,p.z))-p.y,.16)
func generate(seed_value:int,control:bool=false,records:Dictionary={}):
 if control:return guide.generate(seed_value,true,records)
 var data=Data.new();data.cells.assign(fixture() if records.is_empty() else records);data.seed=seed_value
 prepare(data.cells,seed_value)
 var lo:=Vector2i(4096,4096);var hi:=-lo
 for cell:Vector2i in data.cells:lo=lo.min(cell);hi=hi.max(cell+Vector2i.ONE)
 for z in range(lo.y*4-4,hi.y*4+5):
  for x in range(lo.x*4-4,hi.x*4+5):
   var h:=horizontal(Vector2(x,z)*STEP)
   for y in range(-20,19):
    var key:=Vector3i(x,y,z)
    var value:=roundf(clampf(density(Vector3(key)*STEP,h),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value<.5:data.rocks.samples[key]=value
 assert(data.rocks.samples.size()<data.rocks.MAX_SAMPLES)
 data.rocks._height_bounds_dirty=true
 return data
