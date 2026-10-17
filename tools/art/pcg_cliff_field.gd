extends RefCounted
## Bounded art prototype. Compiles coherent contour sectors into ordinary
## RockSculpt samples, not a renderer-only mesh or a scatter of rock assets.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Contour=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Base=preload('res://scripts/terrain_editor/rock_terrain_base.gd')
const STEP:=.25
const TOP:=3.5
const BOTTOM:=-4.5
var loops:Array=[]
var edges:Array=[]
var sectors:Array=[]
var perimeter:=0.0
var source_cells:Dictionary={}
var source_origin:=Vector2i(-15,1)
var center:=Vector2.ZERO
var ring_points:Array=[]
func fixture()->Dictionary:
 var original=Data.new();original.make_preset(0)
 var result:Dictionary={}
 for cell:Vector2i in original.cells:
  if cell.x>=-21 and cell.x<=-10 and cell.y>=-3 and cell.y<=7 and original.cells[cell].height==TOP and original.cells[cell].water<0:
   result[cell-source_origin]=original.cells[cell].duplicate()
 return result
func prepare(records:Dictionary,seed_value:int)->void:
 source_cells=records.duplicate(true);loops=Contour._outlines(records)
 edges.clear();sectors.clear();perimeter=0.0
 assert(loops.size()==1,'Fixture must be one connected contour')
 var contour:PackedVector2Array=loops[0]
 for i in contour.size():
  var a:=contour[i];var b:=contour[(i+1)%contour.size()];var length:=a.distance_to(b)
  if length<.00001:continue
  edges.append({'a':a,'b':b,'s':perimeter,'length':length});perimeter+=length
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var start:=0.0
 while start<perimeter:
  var width:=rng.randf_range(2.1,3.8)
  if perimeter-start<width*1.5:width=perimeter-start
  sectors.append({'start':start,'width':width,'lean':rng.randf_range(.025,.095),'shoulder':rng.randf_range(1.7,3.5),'return':rng.randf_range(1.5,2.65),'joint':rng.randf_range(.22,.48),'turn':rng.randf_range(-.18,.18)})
  start+=width
 for i in sectors.size():
  sectors[i]['left_joint']=(sectors[i].joint+sectors[posmod(i-1,sectors.size())].joint)*.5
  sectors[i]['right_joint']=(sectors[i].joint+sectors[(i+1)%sectors.size()].joint)*.5
 center=Vector2.ZERO
 for p:Vector2 in contour:center+=p/contour.size()
 ring_points.clear()
 for i in sectors.size():
  var sector:Dictionary=sectors[i]
  for t:float in [0.0,.13,.68,.89]:
   var arc:float=sector.start+sector.width*t
   var p:=point_at(arc);var tangent:=tangent_at(arc);var out:=Vector2(tangent.y,-tangent.x)
   if Geometry2D.is_point_in_polygon(p+out*.08,loops[0]):out=-out
   # Main faces have unequal heights and shears. The narrow joint has its
   # own two near vertices, rather than a smooth radial flute.
   ring_points.append({'p':p,'tangent':tangent,'out':out,'t':t,'sector':i,'knee':.65+sector.shoulder*.48,'lower':3.2+sector.shoulder*.65,'shear':sector.turn*3.5,'joint':sector.left_joint if t==0.0 else 0.0})
func point_at(arc:float)->Vector2:
 for edge:Dictionary in edges:
  if arc<=edge.s+edge.length:return edge.a.lerp(edge.b,clampf((arc-edge.s)/edge.length,0,1))
 return edges[-1].b
func tangent_at(arc:float)->Vector2:
 return (point_at(fposmod(arc+.08,perimeter))-point_at(fposmod(arc-.08,perimeter))).normalized()
func ring_at(y:float)->PackedVector2Array:
 var depth:=clampf(TOP-y,0,TOP-BOTTOM)
 var ring:=PackedVector2Array()
 for point:Dictionary in ring_points:
  var d:float=point.knee;var lower:float=point.lower
  var a:=clampf(depth/d,0,1)
  var b:=clampf((depth-d)/(lower-d),0,1)
  var c:=clampf((depth-lower)/(TOP-BOTTOM-lower),0,1)
  var sector:Dictionary=sectors[point.sector]
  var scale:float=1.0+.025*a-(.10+sector.lean)*b-(.24+.025*sector['return'])*c
  var shear:float=point.shear*(a*.45+b*.55)*(1.0-c)
  var joint:float=point.joint*clampf(depth/.55,0,1)*(1.0-c)
  # Oblique secondary facet shares an actual edge with the broad main face.
  var facet:float=(.40 if point.t==.13 else .14 if point.t==.68 else -.20 if point.t==.89 else 0.0)*a*(1-c)
  # Keep the ordered contour rays. Independent tangential movement can
  # invert the narrow joint at a convex corner and create an orphan lobe.
  var radial:Vector2=point.p-center
  var turn:=Transform2D(.018*depth*(1.0-depth/(TOP-BOTTOM)),Vector2.ZERO)
  ring.append(center+turn*(radial*scale+radial.normalized()*(facet-joint+shear*.28)))
 return ring
func ring_distance(ring:PackedVector2Array,p:Vector2)->float:
 var distance:=INF
 for i in ring.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,ring[i],ring[(i+1)%ring.size()])))
 return -distance if Geometry2D.is_point_in_polygon(p,ring) else distance
func horizontal(p:Vector2)->Dictionary:
 var distance:=INF;var arc:=0.0
 for edge:Dictionary in edges:
  var delta:Vector2=edge.b-edge.a
  var t:=clampf((p-edge.a).dot(delta)/delta.length_squared(),0,1)
  var d:=p.distance_to(edge.a+delta*t)
  if d<distance:distance=d;arc=edge.s+edge.length*t
 if Geometry2D.is_point_in_polygon(p,loops[0]):distance=-distance
 return {'distance':distance,'arc':arc}
func cap_height(distance:float,arc:float)->float:
 # A real rolled top, rather than a separate green collar on the stone wall.
 var phase:=arc/perimeter*TAU
 var root_depth:=.08+.32*pow(.5+.5*sin(phase*7+.6*sin(phase*3)),2)
 return TOP-root_depth*(1.0-smoothstep(.04,.8,-distance))
func generate(seed_value:int,control:bool=false,records:Dictionary={}):
 var data=Data.new();data.cells.assign(fixture() if records.is_empty() else records);data.seed=seed_value
 prepare(data.cells,seed_value)
 var lo:=Vector2i(4096,4096);var hi:=-lo
 for cell:Vector2i in data.cells:lo=lo.min(cell);hi=hi.max(cell+Vector2i.ONE)
 var base
 if control:base=Base.new();assert(base.configure(data.cells,'local'))
 var rings:Dictionary={}
 if not control:
  for y in range(-20,17):rings[y]=ring_at(y*STEP)
 for z in range(lo.y*4-3,hi.y*4+4):
  for x in range(lo.x*4-3,hi.x*4+4):
   var horizontal_data:=horizontal(Vector2(x,z)*STEP)
   for y in range(-20,17):
    var key:=Vector3i(x,y,z)
    var value:float
    if control:value=base.node_value(key)
    else:
     var side:=ring_distance(rings[y],Vector2(x,z)*STEP)
     value=maxf(maxf(side,y*STEP-cap_height(horizontal_data.distance,horizontal_data.arc)),BOTTOM-y*STEP)
    value=roundf(clampf(value,-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value<.5:data.rocks.samples[key]=value
 assert(data.rocks.samples.size()<data.rocks.MAX_SAMPLES)
 data.rocks._height_bounds_dirty=true
 return data
