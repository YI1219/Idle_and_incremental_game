class_name ContourTerrain
extends RefCounted
## One shared outline per elevation. Caps, cliffs, water and picking use these outlines.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Legacy = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const BOTTOM := -4.5
var land_regions:Dictionary={}
var water_regions:Dictionary={}
var levels:Array=[]
var surfaces:Dictionary={}
var source:Data
var triangle_chunks:Dictionary={}
var _profiles:Dictionary={}

func refresh(data:Data)->void:
	source=data
	_profiles.clear()
	land_regions.clear()
	water_regions.clear()
	levels.clear()
	surfaces.clear()
	for kind in ["grass","cliff","bank","water","waterfall"]:surfaces[kind]=Legacy.Surface.new()
	var wet:Dictionary={}
	for cell:Vector2i in data.cells:
		var record:Dictionary=data.cells[cell]
		var h:float=record.water*.5 if record.water>=0 else record.height
		if not levels.has(h):levels.append(h)
		if record.water>=0:
			if not wet.has(record.water):wet[record.water]={}
			wet[record.water][cell]=true
	levels.sort()
	for h:float in levels:
		var occupied:Dictionary={}
		for cell:Vector2i in data.cells:
			var record:Dictionary=data.cells[cell]
			var top:float=record.water*.5 if record.water>=0 else record.height
			if top>=h:occupied[cell]=true
		land_regions[h]=_outlines(occupied)
	var water_levels:=wet.keys()
	water_levels.sort()
	for level:int in water_levels:water_regions[level]=_outlines(wet[level])
	for i in levels.size():
		var h:float=levels[i]
		var exposed:Array=land_regions[h].duplicate()
		if i+1<levels.size():
			for loop:PackedVector2Array in land_regions[levels[i+1]]:
				var subtract:=loop.duplicate()
				subtract.reverse()
				exposed.append(subtract)
		_cap(surfaces.grass,exposed,h,Color.WHITE)
	# Fixed vertical samples keep remote cliff geometry stable when an edit adds
	# an elevation. Reuse the shared outline of the next occupied threshold.
	for step in range(-8,25):
		var height:=step*.5
		for h:float in levels:
			if h<height:continue
			for loop:PackedVector2Array in land_regions[h]:_cliffs(loop,height,height-.5)
			break
	for level:int in water_regions:
		_cap(surfaces.water,water_regions[level],level*.5+.045,Color.WHITE)
		for loop:PackedVector2Array in water_regions[level]:_falls(loop,level*.5+.045)
	_smooth_cliff_normals()
	_index_triangles()

static func _area(p:PackedVector2Array)->float:
	var area:=0.0
	for i in p.size():area+=p[i].cross(p[(i+1)%p.size()])
	return area*.5

static func _outlines(occupied:Dictionary)->Array:
	var edges:Dictionary={}
	var keys:=occupied.keys()
	keys.sort_custom(func(a:Vector2i,b:Vector2i):return a.x<b.x or (a.x==b.x and a.y<b.y))
	for cell:Vector2i in keys:
		for side in 4:
			if occupied.has(cell+Legacy.SIDES[side]):continue
			var edge:Array[Vector3]=Legacy._edge(cell,side)
			var a:=Vector2i(int(edge[0].x),int(edge[0].z))
			var b:=Vector2i(int(edge[1].x),int(edge[1].z))
			if not edges.has(a):edges[a]=[]
			edges[a].append(b)
	var loops:Array=[]
	while not edges.is_empty():
		var start:Vector2i=edges.keys()[0]
		var current:=start
		var previous:=start-Vector2i.RIGHT
		var points:=PackedVector2Array()
		var safety:=edges.size()*4+4
		while safety>0:
			safety-=1
			points.append(Vector2(current))
			if not edges.has(current):break
			var options:Array=edges[current]
			var next:Vector2i=options[0]
			var best:=-INF
			var incoming:=Vector2(current-previous)
			for candidate:Vector2i in options:
				var outgoing:=Vector2(candidate-current)
				var turn:=atan2(incoming.cross(outgoing),incoming.dot(outgoing))
				if turn>best:best=turn;next=candidate
			options.erase(next)
			if options.is_empty():edges.erase(current)
			previous=current
			current=next
			if current==start:break
		if points.size()>=3:loops.append(_smooth(points))
	return loops

static func _smooth(raw:PackedVector2Array)->PackedVector2Array:
	var p:=raw
	for pass_index in 3:
		var next:=PackedVector2Array()
		for i in p.size():
			next.append(p[i].lerp(p[(i+1)%p.size()],.25))
			next.append(p[i].lerp(p[(i+1)%p.size()],.75))
		p=next
	# Sample at world-anchored lattice crossings. An edit changes only nearby points;
	# global arc-length sampling would move remote borders and open chunk seams.
	var result:=PackedVector2Array()
	const SPACING:=1.55
	for i in p.size():
		var a:=p[i]
		var b:=p[(i+1)%p.size()]
		var cuts:Array=[]
		for axis in 2:
			var start:=floori(a[axis]/SPACING)
			var end:=floori(b[axis]/SPACING)
			if start==end or absf(a[axis]-b[axis])<.000001:continue
			var line:float=(start+1 if end>start else start)*SPACING
			cuts.append((line-a[axis])/(b[axis]-a[axis]))
		cuts.sort()
		for weight:float in cuts:
			var point:=a.lerp(b,weight)
			if result.is_empty() or result[-1].distance_squared_to(point)>.000001:result.append(point)
	if result.size()<6:
		result.clear()
		for i in range(0,p.size(),4):result.append(p[i])
	if result.size()>1 and result[0].distance_squared_to(result[-1])<.000001:result.remove_at(result.size()-1)
	return result

static func contains(loops:Array,p:Vector2)->bool:
	var winding:=0
	for loop:PackedVector2Array in loops:
		if Geometry2D.is_point_in_polygon(p,loop):winding+=1 if _area(loop)>0 else -1
	return winding>0

func surface_at(p:Vector2)->Dictionary:
	for i in range(levels.size()-1,-1,-1):
		var h:float=levels[i]
		if not contains(land_regions[h],p):continue
		for water:int in water_regions:
			if water*.5>=h-.001 and contains(water_regions[water],p):return {"height":water*.5,"water":water}
		return {"height":h,"water":-1}
	return {}

func _cap(surface,loops:Array,height:float,tint:Color)->void:
	var has_holes:=false
	for loop:PackedVector2Array in loops:
		if _area(loop)<0:has_holes=true
	if not has_holes:
		for loop:PackedVector2Array in loops:surface.polygon(loop,height,tint)
		return
	# Decompose the filled region into scanline trapezoids. Clipping a triangle
	# around a wholly enclosed hole returns separate rings, which a simple polygon
	# triangulator fills again. This sweep preserves every interior opening.
	var heights:Array=[]
	for loop:PackedVector2Array in loops:
		for point in loop:heights.append(point.y)
	heights.sort()
	var rows:Array=[]
	for y:float in heights:
		if rows.is_empty() or absf(rows[-1]-y)>.00001:rows.append(y)
	for index in rows.size()-1:
		var lo:float=rows[index]
		var hi:float=rows[index+1]
		var middle:float=(lo+hi)*.5
		var crossings:Array=[]
		for loop:PackedVector2Array in loops:
			for i in loop.size():
				var a:=loop[i]
				var b:=loop[(i+1)%loop.size()]
				if (a.y>middle)==(b.y>middle):continue
				var slope:float=(b.x-a.x)/(b.y-a.y)
				crossings.append(Vector4(a.x+(middle-a.y)*slope,a.x+(lo-a.y)*slope,a.x+(hi-a.y)*slope,1 if a.y>b.y else -1))
		crossings.sort_custom(func(a:Vector4,b:Vector4):return a.x<b.x)
		var winding:=0
		var left:=Vector4.ZERO
		for right:Vector4 in crossings:
			var next:=winding+int(right.w)
			if winding<=0 and next>0:left=right
			elif winding>0 and next<=0:
				surface.polygon(PackedVector2Array([Vector2(left.y,lo),Vector2(right.y,lo),Vector2(right.z,hi),Vector2(left.z,hi)]),height,tint)
			winding=next

func _cliff_profile(p:Vector2,normal:Vector2)->Dictionary:
	var key:=Vector4(p.x,p.y,normal.x,normal.y)
	if _profiles.has(key):return _profiles[key]
	var inside:=surface_at(p-normal*.25)
	var outside:=surface_at(p+normal*.30)
	var top:float=inside.get("height",levels[0])
	var bottom:float=outside.get("height",BOTTOM)
	if outside.is_empty():
		# The outer body stays vertical through nearby terrace joins, then tapers
		# below their lowest local surface. This closes the foot of a step cliff.
		var cell:=Vector2i(p.floor())
		for z in range(-2,3):
			for x in range(-2,3):
				var record:Dictionary=source.cells.get(cell+Vector2i(x,z),{})
				if record.is_empty():continue
				var height:float=record.water*.5 if record.water>=0 else record.height
				top=minf(top,height)
	var profile:={"top":top,"bottom":bottom,"base":outside.is_empty(),"inset":_inset_limit(p,normal,top) if outside.is_empty() else 0.0}
	_profiles[key]=profile
	return profile

func _profile_point(p:Vector2,y:float,normal:Vector2,profile:Dictionary)->Vector3:
	var depth:float=maxf(.001,profile.top-profile.bottom)
	var edge_weight:=clampf((profile.top-y)*2,0,1)*clampf((y-profile.bottom)*2,0,1)
	y+=sin(p.x*1.17+p.y*.91+y*1.73)*.16*edge_weight
	var f:=clampf((profile.top-y)/depth,0,1)
	return _rock_point(p,y,f,profile.base,minf(1.0,depth/2.2),normal,profile.inset)

func _cliffs(loop:PackedVector2Array,top:float,bottom:float)->void:
	for i in loop.size():
		var a:=loop[i]
		var b:=loop[(i+1)%loop.size()]
		var outward:=Vector2(b.y-a.y,a.x-b.x).normalized()
		var middle:=(a+b)*.5
		var inside:=surface_at(middle-outward*.25)
		if inside.is_empty() or inside.height<top-.01:continue
		var outside:=surface_at(middle+outward*.30)
		if outside.get("height",BOTTOM)>=top-.01:continue
		var before:=loop[(i-1+loop.size())%loop.size()]
		var after:=loop[(i+2)%loop.size()]
		var normal_a:=Vector2(b.y-before.y,before.x-b.x).normalized()
		var normal_b:=Vector2(after.y-a.y,a.x-after.x).normalized()
		var profile_a:=_cliff_profile(a,normal_a)
		var profile_b:=_cliff_profile(b,normal_b)
		var p:=_profile_point(a,top,normal_a,profile_a)
		var q:=_profile_point(b,top,normal_b,profile_b)
		var r:=_profile_point(b,bottom,normal_b,profile_b)
		var s:=_profile_point(a,bottom,normal_a,profile_a)
		# The supporting mass stays joined and un-ribbed. Its material supplies
		# broad anchored facets; occasional embedded models supply silhouette relief.
		surfaces.cliff.quad(p,s,r,q,Color("a8aba8"))

func _inset_limit(p:Vector2,normal:Vector2,height:float)->float:
	# Keep opposing walls apart on single cells and narrow editable necks.
	for step in range(1,45):
		var distance:=step*.125
		var cell:=Vector2i((p-normal*distance).floor())
		var record:Dictionary=source.cells.get(cell,{})
		var top:float=record.get("water",-1)*.5 if record.get("water",-1)>=0 else record.get("height",-99.0)
		if top<height:return minf(1.5,distance*.28)
	return 1.5

static func _rock_point(p:Vector2,y:float,f:float,base:bool,relief:float=1.0,normal:Vector2=Vector2.ZERO,inset_limit:float=1.5)->Vector3:
	var inset:=normal*(inset_limit*pow(f,1.5) if base else 0.0)
	var noise:=sin(p.x*1.91+p.y*2.17+f*7.9)*.38*sin(PI*f)
	var vertical_noise:=sin(p.x*.91+p.y*1.47)*(.62*sin(PI*f)+(.22*pow(f,4.0) if base else 0.0))
	# Physical shoulders vary along the contour and at world heights. Their
	# relief fades to zero at true boundaries, preserving joined caps and steps.
	var ledge:float=(sin(y*1.7+p.x*.41+p.y*.57)*.32+sin(y*.6-p.x*.9+p.y*.43)*.16)*sin(PI*f)*relief
	# Narrow necks already spend their available width on taper and noise.
	# Fade extra shoulders out before they can push opposing walls together.
	ledge*=clampf((inset_limit-.35)/.45,0.0,1.0) if base else .5
	return Vector3(p.x-inset.x+noise+normal.x*ledge,y+vertical_noise*relief,p.y-inset.y+noise*.7+normal.y*ledge)

func _falls(loop:PackedVector2Array,water_y:float)->void:
	if _area(loop)<0:return
	for i in loop.size():
		var a:=loop[i]
		var b:=loop[(i+1)%loop.size()]
		var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
		var sample:=surface_at((a+b)*.5+out*.25)
		var low:float=sample.get("height",-12.0)
		if low>=water_y-.1:continue
		var before:=loop[(i-1+loop.size())%loop.size()]
		var after:=loop[(i+2)%loop.size()]
		var normal_a:=Vector2(b.y-before.y,before.x-b.x).normalized()
		var normal_b:=Vector2(after.y-a.y,a.x-after.x).normalized()
		var apron_a:=Vector3(a.x,water_y,a.y)
		var apron_b:=Vector3(b.x,water_y,b.y)
		var p:=_fall_point(a,normal_a,water_y,water_y)
		var q:=_fall_point(b,normal_b,water_y,water_y)
		var r:=_fall_point(b,normal_b,water_y,low+.07)
		var s:=_fall_point(a,normal_a,water_y,low+.07)
		surfaces.water.quad(apron_a,apron_b,q,p,Color.WHITE,true)
		# Both curtains sample the same world-height lattice. Terminal points
		# interpolate that lattice too, so different landing heights cannot slit
		# their common edge or move the upper flow when a receiver is edited.
		var rows:Array=[]
		var height:=floorf(water_y*2)*.5
		while height>low+.07:
			rows.append(height)
			height-=.5
		rows.append(low+.07)
		var previous_a:=p
		var previous_b:=q
		for y:float in rows:
			var current_a:=_fall_point(a,normal_a,water_y,y)
			var current_b:=_fall_point(b,normal_b,water_y,y)
			surfaces.waterfall.quad(previous_b,previous_a,current_a,current_b,Color.WHITE)
			previous_a=current_a
			previous_b=current_b
		var back:=Vector3(out.x,0,out.y)*.18
		surfaces.bank.quad(p-back+Vector3(0,.012,0),q-back+Vector3(0,.012,0),q+Vector3(0,.012,0),p+Vector3(0,.012,0),Color.WHITE,true)
		if not sample.is_empty() and sample.water>=0:
			var center:=(r+s)*.5+Vector3(out.x*.24,.015,out.y*.24)
			for j in 14:
				var angle:=j*TAU/14.0
				var angle2:=(j+1)*TAU/14.0
				var size:=.54+.18*sin(i*3.7+j*2.9)
				var v:=center+Vector3(cos(angle)*size,0,sin(angle)*size)
				var w:=center+Vector3(cos(angle2)*size,0,sin(angle2)*size)
				surfaces.bank.triangle(center,v,w,Color.WHITE,true)

static func _fall_point(p:Vector2,normal:Vector2,water_y:float,y:float)->Vector3:
	var lower:=floorf(y*2)*.5
	var offset:=lerpf(_fall_offset(water_y,lower),_fall_offset(water_y,lower+.5),(y-lower)*2)
	return Vector3(p.x+normal.x*offset,y,p.y+normal.y*offset)

static func _fall_offset(water_y:float,y:float)->float:
	var drop:=maxf(0,water_y-y)
	return .36+.13*(1-exp(-drop*.8))+.08*sin(drop*1.5)*minf(1,drop)

func _smooth_cliff_normals()->void:
	# Smooth only the supporting cliff body. Embedded stone models retain their
	# flat facets, while construction strips no longer form horizontal stripes.
	var surface=surfaces.cliff
	var sums:Dictionary={}
	for i in range(0,surface.vertices.size(),3):
		var a:Vector3=surface.vertices[i]
		var b:Vector3=surface.vertices[i+1]
		var c:Vector3=surface.vertices[i+2]
		var weighted:=-(b-a).cross(c-a)
		for point in [a,b,c]:
			var key:Vector3=(point*10000.0).round()
			sums[key]=sums.get(key,Vector3.ZERO)+weighted
	for i in surface.vertices.size():
		var key:Vector3=(surface.vertices[i]*10000.0).round()
		surface.normals[i]=sums[key].normalized()

static func _interpolated_normal(point:Vector3,a:Vector3,b:Vector3,c:Vector3,na:Vector3,nb:Vector3,nc:Vector3)->Vector3:
	var ab:=b-a
	var ac:=c-a
	var ap:=point-a
	var denominator:=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)*ab.dot(ac)
	if absf(denominator)<.00000001:return na
	var u:float=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/denominator
	var v:float=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/denominator
	return (na*(1-u-v)+nb*u+nc*v).normalized()

func _index_triangles()->void:
	triangle_chunks.clear()
	for kind in surfaces:
		var vertices:PackedVector3Array=surfaces[kind].vertices
		for i in range(0,vertices.size(),3):
			var lo:=vertices[i]
			var hi:=lo
			for j in [1,2]:lo=lo.min(vertices[i+j]);hi=hi.max(vertices[i+j])
			for z in range(floori(lo.z/8),floori(hi.z/8)+1):
				for x in range(floori(lo.x/8),floori(hi.x/8)+1):
					var chunk:=Vector2i(x,z)
					if not triangle_chunks.has(chunk):triangle_chunks[chunk]={}
					if not triangle_chunks[chunk].has(kind):triangle_chunks[chunk][kind]=[]
					triangle_chunks[chunk][kind].append(i)

func build(chunk:Vector2i)->Dictionary:
	var result:Dictionary={}
	for kind in surfaces:
		var local:=Legacy.Surface.new()
		var vertices:PackedVector3Array=surfaces[kind].vertices
		var colors:PackedColorArray=surfaces[kind].colors
		var normals:PackedVector3Array=surfaces[kind].normals
		for i:int in triangle_chunks.get(chunk,{}).get(kind,[]):
			var polygon:Array[Vector3]=[vertices[i],vertices[i+1],vertices[i+2]]
			for plane in 4:
				polygon=_clip(polygon,plane,chunk)
				if polygon.size()<3:break
			for j in range(1,polygon.size()-1):
				var before:=local.vertices.size()
				local.triangle(polygon[0],polygon[j],polygon[j+1],colors[i],kind in ["grass","water","bank"])
				if kind=="cliff":
					for index in range(before,local.vertices.size()):
						local.normals[index]=_interpolated_normal(local.vertices[index],vertices[i],vertices[i+1],vertices[i+2],normals[i],normals[i+1],normals[i+2])
				if kind=="waterfall" and local.vertices.size()>before:
					var normal:Vector3=normals[i]
					var axis:=0 if absf(normal.z)>=absf(normal.x) else 2
					for index in range(before,local.vertices.size()):local.uv[index]=Vector2(local.vertices[index][axis],local.vertices[index].y)
		result[kind]=local.mesh()
	return result

static func _clip(polygon:Array[Vector3],plane:int,chunk:Vector2i)->Array[Vector3]:
	var result:Array[Vector3]=[]
	if polygon.is_empty():return result
	var axis:=0 if plane<2 else 2
	var limit:float=(chunk.x if plane<2 else chunk.y)*8+(8 if plane%2 else 0)
	var sign_value:=1.0 if plane%2==0 else -1.0
	var previous:Vector3=polygon[-1]
	var before:float=(previous[axis]-limit)*sign_value
	for current:Vector3 in polygon:
		var after:float=(current[axis]-limit)*sign_value
		if (before>=0)!=(after>=0):result.append(previous.lerp(current,before/(before-after)))
		if after>=0:result.append(current)
		previous=current
		before=after
	return result
