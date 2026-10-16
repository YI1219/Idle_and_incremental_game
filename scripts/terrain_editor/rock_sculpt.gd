extends RefCounted
## Authoritative direct sculpt samples. Negative is rock, positive is air.
## Prefab authors and players edit these same samples; no rock instances are
## chosen or scattered by this field. Samples are world anchored for seams.
const STEP:=.25
const AIR:=.5
const MAX_SAMPLES:=160000
var samples:Dictionary[Vector3i,float]={}
var base:RefCounted
var _height_bounds_dirty:=true
var _height_bounds:=Vector2(-16,24)
func node_value(key:Vector3i)->float:return samples[key] if samples.has(key) else (base.node_value(key) if base!=null else AIR)
func value_at(p:Vector3)->float:
 var q:=p/STEP;var key:=Vector3i(q.floor());var f:=q-Vector3(key)
 # Match the mesh's tetrahedral interpolation, including carved concavities.
 var axes:Array[int]=[0,1,2]
 axes.sort_custom(func(a:int,b:int):return f[a]>f[b])
 var first:=key;first[axes[0]]+=1
 var second:=first;second[axes[1]]+=1
 return node_value(key)*(1.0-f[axes[0]])+node_value(first)*(f[axes[0]]-f[axes[1]])+node_value(second)*(f[axes[1]]-f[axes[2]])+node_value(key+Vector3i.ONE)*f[axes[2]]
func gradient(key:Vector3i)->Vector3:
 return Vector3(node_value(key+Vector3i.RIGHT)-node_value(key-Vector3i.RIGHT),node_value(key+Vector3i.UP)-node_value(key-Vector3i.UP),node_value(key+Vector3i.BACK)-node_value(key-Vector3i.BACK)).normalized()
func brush(center:Vector3,radius:float,tool:String,normal:=Vector3.UP)->Dictionary:
 if not center.is_finite() or not is_finite(radius) or radius<.25 or radius>4.0:return {}
 if tool not in ['rock_add','rock_cut','rock_plane','rock_shoulder']:return {}
 if tool in ['rock_plane','rock_shoulder'] and (not normal.is_finite() or normal.length_squared()<.0001):return {}
 var reach:=radius*(1.8 if tool=='rock_shoulder' else 1.0)+AIR
 if absf(center.x)+reach>1024 or absf(center.z)+reach>1024 or center.y-reach< -16 or center.y+reach>24:return {}
 normal=normal.normalized()
 var stone_turn:=Basis(Vector3.UP,-atan2(normal.x,normal.z)) if Vector2(normal.x,normal.z).length_squared()>.0001 else Basis.IDENTITY
 var lo:=Vector3i(((center-Vector3.ONE*reach)/STEP).floor())
 var hi:=Vector3i(((center+Vector3.ONE*reach)/STEP).ceil())
 var next:Dictionary={};var before:Dictionary={};var size:=samples.size()
 for z in range(lo.z,hi.z+1):
  for y in range(lo.y,hi.y+1):
   for x in range(lo.x,hi.x+1):
    var key:=Vector3i(x,y,z);var p:=Vector3(key)*STEP
    var old:=node_value(key);var distance:=p.distance_to(center);var value:=old
    match tool:
     'rock_add':value=minf(old,distance-radius)
     'rock_cut':value=maxf(old,radius-distance)
     'rock_shoulder':value=minf(old,preload('res://scripts/terrain_editor/rock_shoulder_brush.gd').distance(stone_turn*(p-center)/radius)*radius)
     'rock_plane':
      var weight:=1.0-smoothstep(radius*.65,radius,distance)
      value=lerpf(old,maxf(old,(p-center).dot(normal)),weight)
    if value==old:continue
    value=roundf(clampf(value,-AIR,AIR)*100000.0)/100000.0
    # Avoid exact isosurface lattice corners (zero-area tetrahedron faces).
    if absf(value)<.00001:value=.00002
    if value==old:continue
    before[key]=samples.get(key)
    next[key]=null if value==AIR and base==null else value
    if not samples.has(key) and next[key]!=null:size+=1
    elif samples.has(key) and next[key]==null:size-=1
 if size>MAX_SAMPLES:return {}
 restore(next)
 return before
func restore(values:Dictionary)->void:
 _height_bounds_dirty=true
 for key:Vector3i in values:
  if values[key]==null:samples.erase(key)
  else:samples[key]=values[key]
func height_at(p:Vector2)->float:
 if _height_bounds_dirty:
  var bottom:float=base.low.y*STEP-STEP if base!=null else 24.0
  var top:float=(base.low.y+base.size.y)*STEP+STEP if base!=null else -16.0
  for key:Vector3i in samples:
   bottom=minf(bottom,key.y*STEP-STEP);top=maxf(top,key.y*STEP+STEP)
  _height_bounds=Vector2(bottom,top);_height_bounds_dirty=false
 var upper:=_height_bounds.y;var above:=value_at(Vector3(p.x,upper,p.y))
 # At a fixed XZ, a tetrahedron changes when local Y crosses local X or Z.
 # Test each linear segment: a thin ledge can cross twice inside one STEP.
 var fractions:Array[float]=[0.0,fposmod(p.x/STEP,1.0),fposmod(p.y/STEP,1.0)]
 fractions.sort();fractions.reverse()
 while upper>_height_bounds.x:
  var slab_bottom:float=(roundf(upper/STEP)-1.0)*STEP
  for fraction:float in fractions:
   var lower:=slab_bottom+fraction*STEP
   if lower>=upper-.0000001:continue
   var below:=value_at(Vector3(p.x,lower,p.y))
   if above>=0 and below<0:return lerpf(upper,lower,above/(above-below))
   upper=lower;above=below
 return NAN
func records()->Array:
 var result:Array=[];var keys:=samples.keys();keys.sort()
 for key:Vector3i in keys:result.append({'x':key.x,'y':key.y,'z':key.z,'density':samples[key]})
 return result
func load_records(records:Variant)->bool:
 if not records is Array or records.size()>MAX_SAMPLES:return false
 var candidate:Dictionary[Vector3i,float]={}
 for record:Variant in records:
  if not record is Dictionary:return false
  for name in ['x','y','z','density']:
   var value:Variant=record.get(name)
   if not (value is float or value is int) or not is_finite(float(value)):return false
  for name in ['x','y','z']:
   if float(record[name])!=floorf(record[name]):return false
  if absf(record.x)>4096 or absf(record.z)>4096 or record.y< -64 or record.y>96:return false
  if record.density< -AIR or record.density>AIR or absf(record.density)<.00001:return false
  var key:=Vector3i(record.x,record.y,record.z)
  if candidate.has(key):return false
  candidate[key]=record.density
 samples=candidate
 return true
