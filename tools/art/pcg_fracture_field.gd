extends RefCounted
## Disposable full3D partition experiment. Pair planes are shared exactly.
## Ordinary density records remain the only data consumed by the game.
const Guide=preload('res://tools/art/pcg_cliff_field.gd')
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const STEP:=.25
const TOP:=3.5
var guide=Guide.new()
var sites:Array=[]
var pair_planes:Array=[]
var center:=Vector2.ZERO
var perimeter:=0.0
var construction:Dictionary={}
func fixture()->Dictionary:return guide.fixture()
func horizontal(p:Vector2)->Dictionary:return guide.horizontal(p)
func cap_height(distance:float,arc:float)->float:
 var phase:=arc/maxf(perimeter,.01)*TAU
 return TOP-(.10+.16*pow(.5+.5*sin(phase*3.0+.7*sin(phase*5)),2))*(1-smoothstep(.0,.65,-distance))
static func smin(a:float,b:float,k:float)->float:
 var h:=maxf(k-absf(a-b),0)/k
 return minf(a,b)-h*h*k*.25
func prepare(records:Dictionary,seed_value:int)->void:
 guide.prepare(records,seed_value);perimeter=guide.perimeter;sites.clear();pair_planes.clear()
 var lo:=Vector2i(4096,4096);var hi:=-lo;center=Vector2.ZERO
 for cell:Vector2i in records:
  lo=lo.min(cell);hi=hi.max(cell+Vector2i.ONE);center+=(Vector2(cell)+Vector2.ONE*.5)/records.size()
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 # Unlayered anisotropic Poisson sites: tall unequal cells, with oblique
 # shared fracture planes. No horizontal rows or perimeter sectors.
 for attempt:int in 800:
  if sites.size()>=19:break
  var p:=Vector3(rng.randf_range(lo.x+.5,hi.x-.5),rng.randf_range(-2.2,2.8),rng.randf_range(lo.y+.5,hi.y-.5))
  if horizontal(Vector2(p.x,p.z)).distance>.2:continue
  var clear:=true
  for site:Dictionary in sites:
   var d:Vector3=p-site.p;d.y*=.65
   if d.length()<2.65:clear=false;break
  if not clear:continue
  var h:=horizontal(Vector2(p.x,p.z));var at:Vector2=guide.point_at(h.arc)
  var tangent:Vector2=guide.tangent_at(h.arc);var out:=Vector2(tangent.y,-tangent.x)
  if Geometry2D.is_point_in_polygon(at+out*.1,guide.loops[0]):out=-out
  sites.append({'p':p,'weight':rng.randf_range(-.7,.7),'at':at,'out':out,'tangent':tangent,
   'lean':rng.randf_range(-.20,.26),'turn':rng.randf_range(-.18,.18),'offset':rng.randf_range(-.25,.20),
   'foot':rng.randf_range(-4.4,-3.0),'foot_x':rng.randf_range(-.20,.20),'foot_z':rng.randf_range(-.20,.20),
   'seam':rng.randf_range(.08,.14)})
 # Plane convention: dot(normal,p)-offset <=0 belongs to i. j uses
 # exactly the negated plane, never independently jittered boundaries.
 for i:int in sites.size():
  var row:Array=[]
  for j:int in sites.size():
   if i==j:row.append(Vector4.ZERO);continue
   var delta:Vector3=sites[j].p-sites[i].p;delta.y*=.4225
   var a:Vector3=sites[i].p;var b:Vector3=sites[j].p;a.y*=.65;b.y*=.65
   var offset:float=(b.length_squared()-sites[j].weight-a.length_squared()+sites[i].weight)*.5
   row.append(Vector4(delta.x,delta.y,delta.z,offset)/delta.length())
  pair_planes.append(row)
 var serialized:Array=[]
 for s:Dictionary in sites:
  serialized.append({'point':[s.p.x,s.p.y,s.p.z],'weight':s.weight,'lean':s.lean,'turn':s.turn,'offset':s.offset,
   'foot':s.foot,'foot_slopes':[s.foot_x,s.foot_z],'seam':s.seam})
 construction={'version':1,'kind':'full3D weighted partition; shared pair planes; exterior-only open seams',
  'seed':seed_value,'sites':serialized,'pair_plane_count':sites.size()*(sites.size()-1)/2,
  'scope':'Tool recipe only. Editable density saves are ordinary v2. No production feature-constraint editor or lossless recipe migration.'}
func common_distance(p:Vector3,h:Dictionary)->float:
 var depth:=maxf(TOP-p.y,0)
 var inset:=.025+.025*depth+.055*pow(maxf(depth-2.2,0),1.4)
 var q:=Vector2(p.x,p.z)-center
 return maxf(maxf(h.distance+inset,p.y-cap_height(h.distance,h.arc)),-5.1+.025*q.length_squared()-p.y)
func density(p:Vector3,h:Dictionary)->float:
 var outer:=common_distance(p,h)
 var candidates:Array=[]
 for i:int in sites.size():
  var offset:Vector3=p-sites[i].p;offset.y*=.65
  var d:float=offset.length_squared()-sites[i].weight
  if candidates.size()<4:candidates.append([d,i]);candidates.sort_custom(func(a,b):return a[0]<b[0])
  elif d<candidates[-1][0]:candidates[-1]=[d,i];candidates.sort_custom(func(a,b):return a[0]<b[0])
 var value:=INF
 for candidate:Array in candidates:
  var i:int=candidate[1];var s:Dictionary=sites[i]
  var partition:=-INF
  for j:int in sites.size():
   if i==j:continue
   var plane:Vector4=pair_planes[i][j]
   var gap:float=(s.seam+sites[j].seam)*.5
   # Fractures open only in the exposed shell; deeper rock stays joined.
   var opening:float=gap-1.7*smoothstep(.18,1.45,-outer)
   partition=maxf(partition,Vector3(plane.x,plane.y,plane.z).dot(p)-plane.w+opening)
  var delta:Vector2=Vector2(p.x,p.z)-s.at
  var local_face:float=delta.dot(s.out)+s.lean*(p.y-s.p.y)+s.turn*delta.dot(s.tangent)-s.offset
  var foot:float=s.foot+s.foot_x*(p.x-s.p.x)+s.foot_z*(p.z-s.p.z)-p.y
  var returning:float=delta.dot(s.out)-.78*p.y-2.2+s.turn*delta.dot(s.tangent)
  var block:=maxf(maxf(maxf(outer,local_face),returning),foot)
  value=minf(value,maxf(block,partition))
 # Soil is a physical, shallow mantle. It closes only small upper clefts,
 # while deep/oblique fractures still meet the broken cap edge.
 var roof:=cap_height(h.distance,h.arc)
 var soil:float=maxf(maxf(h.distance+.035,p.y-roof),roof-.26-p.y)
 return smin(value,soil,.10)
func generate(seed_value:int,control:bool=false,records:Dictionary={}):
 if control:return guide.generate(seed_value,true,records)
 var data=Data.new();data.cells.assign(fixture() if records.is_empty() else records);data.seed=seed_value
 prepare(data.cells,seed_value)
 var lo:=Vector2i(4096,4096);var hi:=-lo
 for cell:Vector2i in data.cells:lo=lo.min(cell);hi=hi.max(cell+Vector2i.ONE)
 for z:int in range(lo.y*4-4,hi.y*4+5):
  for x:int in range(lo.x*4-4,hi.x*4+5):
   var h:=horizontal(Vector2(x,z)*STEP)
   for y:int in range(-24,18):
    var key:=Vector3i(x,y,z)
    var value:float=roundf(clampf(density(Vector3(key)*STEP,h),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value<.5:data.rocks.samples[key]=value
 assert(data.rocks.samples.size()<data.rocks.MAX_SAMPLES)
 data.rocks._height_bounds_dirty=true
 return data
