extends RefCounted
## Unaccepted local form study, authored into the ordinary saved sculpt samples.
## No runtime mesh overlay, new base profile, model scatter or locked terrain.
## The complete section shares one field from dry cap to the common underside.
const Base=preload('res://scripts/terrain_editor/rock_terrain_base.gd')
const BREAKS=[-23.0,-19.6,-16.4,-13.7,-9.0]
const RETURNS=[2.8,1.7,3.15,2.25]

static func author(data,lean:bool=false,volumetric:bool=false)->void:
 data.ensure_sculpt_base()
 var base=data.rocks.base
 var payload:Dictionary=data.serialize()
 var cells_before:Array=payload.cells.duplicate(true)
 var records:Array=payload.rocks
 assert(records.is_empty(),'This study starts from the unmodified unified base')
 var maximum_delta:=0.0
 for z in range(-8,37):
  for x in range(-92,-31):
   var p:=Vector2(x,z)*.25
   var weight:=smoothstep(-23.0,-20.5,p.x)*(1.0-smoothstep(-10.5,-8.0,p.x))*smoothstep(-2.0,-.25,p.y)
   if weight<=0:continue
   var distances:Array[float]=[]
   for h:float in base.levels:distances.append(Base._distance(base.regions[h],p))
   if distances[0]>1.0 or distances[0]< -6.0:continue
   var height:float=base._body_height(p)
   for y in range(base.low.y,ceili((height+.5)*4.0)+1):
    var key:=Vector3i(x,y,z);var py:float=y*.25
    var u:float=maxf(0.0,height-py)
    # Oblique, unequal broad faces. Clefts fade into one lower mass; they
    # are not repeated pillars terminating above a separate backing wall.
    var along:float=p.x+.19*u
    var segment:=0
    for i in range(BREAKS.size()-1):
     if along>=BREAKS[i]:segment=i
    segment=mini(segment,RETURNS.size()-1)
    var t:float=clampf((along-BREAKS[segment])/(BREAKS[segment+1]-BREAKS[segment]),0,1)
    var ridge:float=.34 if segment%2==0 else .61
    var flank:float=(ridge-t)/ridge if t<ridge else (t-ridge)/(1.0-ridge)
    var cleft:float=.72*flank if lean else .72*flank*flank
    var shoulder:float=RETURNS[segment]+.28*(t-.5)
    var upper:float=.035*u+cleft*(1.0-smoothstep(3.4,6.4,u))
    var middle:float=(.92 if lean else .70)*(u-shoulder)+cleft*.25
    var lower:float=(1.15 if lean else 1.14)*(u-(2.7 if lean else 4.35))
    var inset:float=maxf(upper,maxf(middle,lower))
    var candidate:=.5
    for i in base.levels.size():candidate=minf(candidate,maxf(distances[i],py-float(base.levels[i])))
    var floor_y:float=minf(-4.5,float(base.levels[0])-1.4)+.12*sin(p.x*.37+p.y*.17)+.07*sin(p.y*.46-p.x*.13)
    candidate=maxf(maxf(candidate,distances[0]+inset),floor_y-py)
    if volumetric:
     # Two authored volumes use the existing geological brush profile.
     # Unlike a shoreline extrusion, their ridges turn in all three axes.
     # This is a prefab density study, not a player-UI transform feature.
     var top_distance:=.5
     for i in base.levels.size():top_distance=minf(top_distance,maxf(distances[i],py-float(base.levels[i])))
     candidate=maxf(maxf(top_distance,distances[0]+maxf(1.22*u,2.3*(u-1.4))),floor_y-py)
     for spec in [
      [Vector3(-17.1,.75,.8),Vector3(2.6,3.2,2.8),Vector3(.12,-.30,.18)],
      [Vector3(-13.7,.40,2.2),Vector3(1.95,2.55,2.55),Vector3(-.16,.25,-.22)]]:
      var local:Vector3=Basis.from_euler(spec[2]).inverse()*(Vector3(p.x,py,p.y)-spec[0])
      local/=spec[1]
      var rock:float=preload('res://scripts/terrain_editor/rock_shoulder_brush.gd').distance(local)*1.9
      var blend:float=.42*(1.0-smoothstep(2.7,4.0,py))
      if blend>.00001:
       var join:float=clampf(.5+.5*(rock-candidate)/blend,0,1)
       candidate=lerpf(rock,candidate,join)-blend*join*(1.0-join)
      else:candidate=minf(candidate,rock)
    var old:float=base.node_value(key)
    var value:float=roundf(lerpf(old,clampf(candidate,-.5,.5),weight)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value==old:continue
    maximum_delta=maxf(maximum_delta,absf(value-old))
    records.append({'x':x,'y':y,'z':z,'density':value})
 assert(data.deserialize(payload),'Study must pass the ordinary sculpt save loader')
 data.ensure_sculpt_base()
 assert(data.serialize().cells==cells_before,'Authored land footprint and heights stay intact')
 print('COMPLETE SECTION: samples=',records.size(),' max_density_change=',maximum_delta)
