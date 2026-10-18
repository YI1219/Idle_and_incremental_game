extends 'res://scripts/terrain_editor/rock_terrain_base.gd'
## Art prototype: a few complete convex polyhedral principal masses. The
## planes constrain entire 3D volumes, not perimeter extrusion or cut pillows.
## Scalar nodes remain the shared skin/support source; no portable profile yet.
var lobes:Array=[]
func smooth_union(a:float,b:float,k:float)->float:
 var t:=clampf(.5+.5*(b-a)/k,0.0,1.0)
 return lerpf(b,a,t)-k*t*(1.0-t)
func configure_style(records:Dictionary,_kind:String,seed_value:int)->bool:
 if not configure(records,'local'):return false
 var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
 for cell:Vector2i in cells:minimum=minimum.min(Vector2(cell));maximum=maximum.max(Vector2(cell)+Vector2.ONE)
 var center:=(minimum+maximum)*.5;var span:=maximum-minimum;var h:float=levels[-1]
 lobes=[
  {'center':Vector3(center.x-span.x*.03,h-1.20,center.y),'radius':Vector3(span.x*.43,2.60,span.y*.43)},
  {'center':Vector3(center.x-span.x*.27,h-1.75,center.y+span.y*.06),'radius':Vector3(span.x*.245,2.70,span.y*.30)},
  {'center':Vector3(center.x+span.x*.23,h-1.45,center.y-span.y*.025),'radius':Vector3(span.x*.29,2.50,span.y*.38)}]
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 for i in lobes.size():
  var planes:Array=[]
  for direction:Vector3 in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:planes.append([direction,1.03])
  for j in 22:
   var y:=1.0-2.0*(float(j)+.5)/22.0
   var radius:=sqrt(1.0-y*y)
   var angle:=float(j)*2.39996323+float(i)*1.29+rng.randf_range(-.13,.13)
   planes.append([Vector3(cos(angle)*radius,y,sin(angle)*radius),rng.randf_range(.94,1.07)])
  lobes[i]['planes']=planes
 surface_cells.clear()
 for z in size.z:
  for x in size.x:
   var px:float=(x+low.x)*STEP;var pz:float=(z+low.z)*STEP
   # Each column shares the horizontal terms of all3Dplanes.
   var columns:Array=[]
   for lobe:Dictionary in lobes:
    var qx:float=(px-lobe.center.x)/lobe.radius.x
    var qz:float=(pz-lobe.center.z)/lobe.radius.z
    var terms:Array=[]
    for plane:Array in lobe.planes:terms.append([plane[0].x*qx+plane[0].z*qz-plane[1],plane[0].y])
    columns.append({'terms':terms,'cy':lobe.center.y,'ry':lobe.radius.y,'scale':minf(lobe.radius.x,minf(lobe.radius.y,lobe.radius.z))})
   for y in size.y:
    var py:float=(y+low.y)*STEP;var value:=100.0
    for column:Dictionary in columns:
     var qy:float=(py-column.cy)/column.ry
     var shape:float=-100.0
     for term:Array in column.terms:shape=maxf(shape,term[0]+term[1]*qy)
     value=smooth_union(value,shape*column.scale,.18)
    value=maxf(value,py-h)
    value=roundf(clampf(value,-AIR,AIR)*100000.0)/100000.0
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
func tag(p:Vector3,n:Vector3)->Dictionary:
 var original:=super.tag(p,n)
 var h:float=levels[-1]
 original.color.r=(1.0-smoothstep(.015,.28,h-p.y))*smoothstep(.20,.72,n.y)
 return original

func principal_normal(p:Vector3)->Vector3:
 var distance:=100.0;var normal:=Vector3.UP
 for lobe:Dictionary in lobes:
  var q:Vector3=(p-lobe.center)/lobe.radius
  var value:float=-100.0;var direction:=Vector3.UP
  for plane:Array in lobe.planes:
   var candidate:float=plane[0].dot(q)-plane[1]
   if candidate>value:value=candidate;direction=(plane[0]/lobe.radius).normalized()
  value*=minf(lobe.radius.x,minf(lobe.radius.y,lobe.radius.z))
  var t:=clampf(.5+.5*(value-distance)/.18,0.0,1.0)
  normal=direction.lerp(normal,t).normalized()
  distance=lerpf(value,distance,t)-.18*t*(1.0-t)
 if p.y>=float(levels[-1])-.025:normal=Vector3.UP
 return normal
