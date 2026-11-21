extends RefCounted
## Locally bevel safe pond corners; exposed mouths keep their original edges.
const VERSION:int=1
static func refine(field,loop:PackedVector2Array,height:float)->PackedVector2Array:
 var result:=PackedVector2Array()
 var protected:Dictionary={}
 var flow:Array=field._flow_edges(loop,height+.045)
 for i:int in flow.size():
  if not flow[i].spill:continue
  # Fall normals use the vertex before and after each outlet edge. Retain
  # those complete corners as well, including their original neighbors.
  for offset:int in [-1,0,1,2]:protected[posmod(i+offset,loop.size())]=true
 for i:int in loop.size():
  var p:=loop[i];var previous:=loop[(i-1+loop.size())%loop.size()];var next:=loop[(i+1)%loop.size()]
  var incoming:=p-previous;var outgoing:=next-p
  var normal:=Vector2(next.y-previous.y,previous.x-next.x).normalized()
  var safe:bool=not protected.has(i) and incoming.length()>.05 and outgoing.length()>.05 and absf(incoming.angle_to(outgoing))>.15
  for probe:Vector2 in [p,p.lerp(previous,.25),p.lerp(next,.25)]:
   var outside:Dictionary=field.surface_at(probe+normal*1.4)
   safe=safe and not outside.is_empty() and outside.get('water',0)<0 and absf(float(outside.get('height',INF))-height)<.01 and field.shore_support(probe,normal,height,.8)
  if not safe:result.append(p);continue
  var a:=p.lerp(previous,.4);var b:=p.lerp(next,.4)
  for t:float in [0.0,.5,1.0]:result.append(a*(1.0-t)*(1.0-t)+p*2.0*t*(1.0-t)+b*t*t)
 return result
