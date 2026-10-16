extends RefCounted
## Immutable derived solid from the same authored cells, not decorative land.
## Horizontal contour distances are shared down each column; no model scatter.
const STEP:=.25
const AIR:=.5
const MAX_GRID_NODES:=2000000
var cells:Dictionary={}
var levels:Array=[]
var regions:Dictionary={}
var low:=Vector3i.ZERO
var size:=Vector3i.ZERO
var values:=PackedFloat32Array()
var surface_cells:Array[Vector3i]=[]
func configure(records:Dictionary)->bool:
 if not fits(records):return false
 cells=records.duplicate(true)
 if cells.is_empty():return true
 var lo:=Vector2i(4096,4096);var hi:=-lo
 for cell:Vector2i in cells:
  var h:float=cells[cell].height
  if not levels.has(h):levels.append(h)
  lo=lo.min(cell);hi=hi.max(cell+Vector2i.ONE)
 levels.sort()
 # Runtime load avoids the TerrainData -> contour -> TerrainData preload cycle.
 var contours=load('res://scripts/terrain_editor/contour_terrain.gd')
 for h:float in levels:
  var occupied:Dictionary={}
  for cell:Vector2i in cells:
   if cells[cell].height>=h:occupied[cell]=true
  regions[h]=contours._outlines(occupied)
 low=Vector3i(lo.x*4-3,floori(minf(-4.9,float(levels[0])-1.8)/STEP),lo.y*4-3)
 var high:=Vector3i(hi.x*4+3,ceili((float(levels[-1])+AIR)/STEP),hi.y*4+3)
 size=high-low+Vector3i.ONE
 values.resize(size.x*size.y*size.z)
 for z in size.z:
  for x in size.x:
   var p:=Vector2(x+low.x,z+low.z)*STEP
   var distances:Array[float]=[]
   for h:float in levels:distances.append(_distance(regions[h],p))
   var floor_y:=minf(-4.5,float(levels[0])-1.4)+.12*sin(p.x*.37+p.y*.17)+.07*sin(p.y*.46-p.x*.13)
   for y in size.y:
    var py:float=(y+low.y)*STEP;var value:=AIR
    for i in levels.size():
     var h:float=levels[i]
     var inset:=maxf(0.0,h-py-1.4)*.55
     value=minf(value,maxf(maxf(distances[i]+inset,py-h),floor_y-py))
    value=clampf(value,-AIR,AIR)
    if absf(value)<.00001:value=.00002
    values[(z*size.y+y)*size.x+x]=value
 for z in range(size.z-1):
  for y in range(size.y-1):
   for x in range(size.x-1):
    var start:=(z*size.y+y)*size.x+x
    var smallest:=AIR;var largest:=-AIR
    for offset:int in [0,1,size.x,size.x+1,size.x*size.y,size.x*size.y+1,size.x*size.y+size.x,size.x*size.y+size.x+1]:
     smallest=minf(smallest,values[start+offset]);largest=maxf(largest,values[start+offset])
    if smallest<0 and largest>=0:surface_cells.append(low+Vector3i(x,y,z))
 return true
static func fits(records:Dictionary,extra_lo:=Vector2(INF,INF),extra_hi:=Vector2(-INF,-INF),lower:float=0.0,upper:float=0.0,target_height:float=NAN)->bool:
 if records.is_empty() and not extra_lo.is_finite():return true
 var lo:=extra_lo;var hi:=extra_hi;var minimum:=INF;var maximum:=-INF
 for cell:Vector2i in records:
  lo=lo.min(Vector2(cell));hi=hi.max(Vector2(cell)+Vector2.ONE)
  minimum=minf(minimum,records[cell].height);maximum=maxf(maximum,records[cell].height)
 if minimum==INF:minimum=0.0;maximum=0.0
 if is_finite(target_height):minimum=minf(minimum,target_height);maximum=maxf(maximum,target_height)
 minimum+=lower;maximum+=upper
 var nx:=ceili((hi.x-lo.x)/STEP)+7
 var nz:=ceili((hi.y-lo.y)/STEP)+7
 var ny:=ceili((maximum+AIR-minf(-4.9,minimum-1.8))/STEP)+1
 return nx>0 and nz>0 and ny>0 and float(nx)*nz*ny<=MAX_GRID_NODES
func node_value(key:Vector3i)->float:
 var p:=key-low
 if p.x<0 or p.y<0 or p.z<0 or p.x>=size.x or p.y>=size.y or p.z>=size.z:return AIR
 return values[(p.z*size.y+p.y)*size.x+p.x]
func record_at(p:Vector2)->Dictionary:
 var cell:=Vector2i(p.floor())
 if cells.has(cell):return cells[cell]
 var best:=1.1;var result:Dictionary={}
 for z in range(-1,2):
  for x in range(-1,2):
   var key:=cell+Vector2i(x,z)
   if not cells.has(key):continue
   var d:=p.distance_to(Vector2(key)+Vector2.ONE*.5)
   if d<best:best=d;result=cells[key]
 return result
func tag(p:Vector3,n:Vector3)->Dictionary:
 var record:=record_at(Vector2(p.x,p.z));var h:float=record.get('height',p.y-2.0)
 var water:float=float(record.get('water',-1))*.5 if record.get('water',-1)>=0 else -1.0
 var grass:=0.0
 if not record.is_empty() and water<0:
  grass=(1.0-smoothstep(.025,.10,absf(p.y-h)))*smoothstep(.05,.45,n.y)
 return {'color':Color(grass,0,0,1),'uv':Vector2(h,water)}
static func _distance(loops:Array,p:Vector2)->float:
 var distance:=INF;var winding:=0
 for loop:PackedVector2Array in loops:
  if Geometry2D.is_point_in_polygon(p,loop):
   var area:=0.0
   for i in loop.size():area+=loop[i].cross(loop[(i+1)%loop.size()])
   winding+=1 if area>0 else -1
  for i in loop.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[i],loop[(i+1)%loop.size()])))
 return -distance if winding>0 else distance
