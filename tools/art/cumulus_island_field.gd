extends 'res://scripts/terrain_editor/rock_terrain_base.gd'
## Whole-object sculptural prototype. Few 3D primary volumes, not contour rings
## or a perimeter row of independent stones. Native density is authoritative;
## portable profile/cell-edit regeneration remains a later integration stage.
var lobes:Array=[]
func union_smooth(a:float,b:float,k:float)->float:
 var t:=clampf(.5+.5*(b-a)/k,0.0,1.0)
 return lerpf(b,a,t)-k*t*(1.0-t)
func configure_style(records:Dictionary,_kind:String,seed_value:int)->bool:
 var faceted:=_kind=='cumulus_facets'
 if not configure(records,'local'):return false
 var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
 for cell:Vector2i in cells:minimum=minimum.min(Vector2(cell));maximum=maximum.max(Vector2(cell)+Vector2.ONE)
 var center:=(minimum+maximum)*.5;var span:=maximum-minimum
 var h:float=levels[-1]
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var turn:=rng.randf_range(-.10,.10)
 # Three deliberately unequal principal masses; the whole is visible, not
 # four front-facing shields attached to a separate common plinth.
 lobes=[
  {'center':Vector3(center.x-span.x*.03,h-1.20,center.y),'radius':Vector3(span.x*.40,2.40,span.y*.42)},
  {'center':Vector3(center.x-span.x*.27,h-1.75,center.y+span.y*(.06+turn)),'radius':Vector3(span.x*.245,2.7,span.y*.30)},
  {'center':Vector3(center.x+span.x*.23,h-1.45,center.y-span.y*(.025-turn*.5)),'radius':Vector3(span.x*.29,2.5,span.y*.38)}]
 surface_cells.clear()
 for z in size.z:
  for x in size.x:
   var px:float=(x+low.x)*STEP;var pz:float=(z+low.z)*STEP
   for y in size.y:
    var py:float=(y+low.y)*STEP;var value:=100.0
    for lobe:Dictionary in lobes:
     var q:Vector3=(Vector3(px,py,pz)-lobe.center)/lobe.radius
     var d:float=(q.length()-1.0)*minf(lobe.radius.x,minf(lobe.radius.y,lobe.radius.z))
     if faceted:
      var index:float=float(lobes.find(lobe))
      var a:=.32+index*1.64
      var cut1:=q.x*sin(a)+q.z*cos(a)+q.y*.22-.83
      var cut2:=-q.x*cos(a+.25)+q.z*sin(a+.25)-q.y*.28-.89
      d=maxf(d,maxf(cut1,cut2)*minf(lobe.radius.x,minf(lobe.radius.y,lobe.radius.z)))
     value=union_smooth(value,d,.48 if faceted else .65)
    # A broad flat playable top is deliberately clipped into the complete
    # sculptural object. The curved lower envelope comes from its 3D masses.
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
 # The true flat top gets cover; the rounded side remains stone. This is
 # source-geometry contact, not grass painted at a fixed old wall height.
 original.color.r=(1.0-smoothstep(.02,.32,h-p.y))*smoothstep(.1,.75,n.y)
 return original
