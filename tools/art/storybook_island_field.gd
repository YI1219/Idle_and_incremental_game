extends 'res://scripts/terrain_editor/rock_terrain_base.gd'
## Experimental beauty-first derived data. Same authoritative cells and scalar
## nodes feed the production skin, support and brushes. Not a portable save
## profile yet: experimental recipes are marked explicitly in capture metadata.
var style:String='soft'
var style_seed:int=7301
var phase:float=0.0
var lobes:Array=[]
func rounded_intersection(a:float,b:float,r:float)->float:
 var q:=Vector2(a+r,b+r)
 return q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0.0)-r
func configure_style(records:Dictionary,kind:String,seed_value:int)->bool:
 if kind not in ['soft','graphic','terraced']:return false
 if not configure(records,'local'):return false
 style=kind;style_seed=seed_value;phase=float(seed_value%251)*.037
 prepare_lobes()
 var floor_y:=minf(-1.7,float(levels[0])-1.6)
 if style=='graphic':floor_y-=.8
 elif style=='terraced':floor_y+=.35
 var top_radius:=.42 if style=='soft' else (.18 if style=='graphic' else .28)
 var bottom_radius:=.8 if style=='soft' else .22
 surface_cells.clear()
 for z in size.z:
  for x in size.x:
   var p:=Vector2(x+low.x,z+low.z)*STEP
   var h:=_body_height(p)
   var horizontal:=horizontal_distances[0][z*size.x+x]
   var authored_ceiling:=float(levels[0])
   for i in levels.size():
    if horizontal_distances[i][z*size.x+x]<=.08:authored_ceiling=float(levels[i])
   var local_lobes:Array=[]
   for lobe:Dictionary in lobes:
    var delta:Vector2=p-lobe.at
    var qx:float=delta.dot(lobe.tangent)/lobe.radius.x
    var qz:float=delta.dot(lobe.out)/lobe.radius.z
    if absf(qx)<1.3 and absf(qz)<1.3:local_lobes.append([qx,qz,lobe.center_y,lobe.radius.y,minf(lobe.radius.x,minf(lobe.radius.y,lobe.radius.z))])
   var wave:=.12*sin(p.x*.47+p.y*.31+phase)+.08*sin(p.y*.71-p.x*.12+phase*.7)
   for y in size.y:
    var py:float=(y+low.y)*STEP
    var depth:=maxf(0.0,h-py)
    var inset:=.075*maxf(depth-.55,0.0)+.028*pow(maxf(depth-.55,0.0),2)
    if style=='graphic':inset=.025*depth+.15*maxf(depth-1.3,0.0)+.45*maxf(depth-3.6,0.0)
    elif style=='terraced':inset=.04*depth+.35*smoothstep(.8,1.3,depth)+.42*smoothstep(2.3,2.85,depth)+.16*maxf(depth-3.6,0.0)
    var broad_shape:=wave*smoothstep(.3,1.2,depth)*(1.0-smoothstep(3.0,5.5,depth))
    var cap:=AIR
    for i in levels.size():
     var edge:float=horizontal_distances[i][z*size.x+x]
     cap=minf(cap,rounded_intersection(edge,py-float(levels[i]),top_radius))
    var side:=horizontal+inset+broad_shape
    # Deliberately quiet, compact common underside rather than tall hanging
    # individual rocks. Non-geological stylization is an explicit art choice.
    var underside:=floor_y+.5*exp(minf(horizontal,0.0)*.45)-py
    var value:=maxf(cap,rounded_intersection(side,underside,bottom_radius))
    for lobe:Array in local_lobes:
     var qy:float=(py-lobe[2])/lobe[3]
     var shape_distance:float=sqrt(lobe[0]*lobe[0]+lobe[1]*lobe[1]+qy*qy)-1.0
     if style=='graphic':
      shape_distance=maxf(maxf(.82*absf(lobe[0])+.45*absf(lobe[1]),.82*absf(lobe[1])+.40*absf(qy)),.86*absf(qy)+.28*absf(lobe[0]))-.98
     shape_distance*=float(lobe[4])
     # Keep the source padding positive and prevent an outboard turf shelf.
     shape_distance=maxf(shape_distance,horizontal-.45)
     var blend:=clampf(.5+.5*(shape_distance-value)/.48,0.0,1.0)
     value=lerpf(shape_distance,value,blend)-.48*blend*(1.0-blend)
    # Rock shoulders may enrich the rim but cannot raise the authored flat
    # playground. This preserves existing prop footprints instead of hiding
    # displaced props or force-moving them onto an uneven artificial hill.
    value=maxf(value,py-authored_ceiling)
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
 var record:=record_at(Vector2(p.x,p.z))
 if not record.is_empty() and record.get('water',-1)<0:
  var cover:=1.0-smoothstep(.015,.35,maxf(0.0,float(record.height)-p.y))
  cover*=smoothstep(.18,.70,n.y)
  cover*=1.0-smoothstep(.06,.23,_cover_distance(Vector2(p.x,p.z),float(record.height)))
  original.color=Color(cover,original.color.g,0,1)
 return original

func prepare_lobes()->void:
 lobes.clear()
 if style=='terraced':return
 var rng:=RandomNumberGenerator.new();rng.seed=style_seed
 for loop:PackedVector2Array in regions[levels[0]]:
  var edges:Array=[];var total:=0.0
  for i in loop.size():
   var a:=loop[i];var b:=loop[(i+1)%loop.size()];var length:=a.distance_to(b)
   if length>.001:edges.append([a,b,total,length]);total+=length
  var arc:=rng.randf_range(.8,2.3)
  while arc<total:
   for edge:Array in edges:
    if arc<edge[2] or arc>edge[2]+edge[3]:continue
    var at:Vector2=edge[0].lerp(edge[1],(arc-edge[2])/edge[3])
    var tangent:Vector2=(edge[1]-edge[0]).normalized()
    var out:=Vector2(tangent.y,-tangent.x)
    if Geometry2D.is_point_in_polygon(at+out*.1,loop):out=-out
    var record:=record_at(at-out*.6)
    if not record.is_empty() and record.get('water',-1)<0 and rng.randf()<.82:
     var height:float=record.height
     var ry:=rng.randf_range(1.5,2.15)
     lobes.append({'at':at-out*.65,'tangent':tangent,'out':out,'center_y':height-ry+rng.randf_range(-.18,.22),'radius':Vector3(rng.randf_range(1.8,2.9),ry,rng.randf_range(.9,1.2))})
    break
   arc+=rng.randf_range(4.5,7.0)
