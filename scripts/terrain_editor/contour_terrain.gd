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
var _rock_relief_cache:Dictionary={}
var _land_winding_signs:Dictionary={}

func refresh(data:Data)->void:
	source=data
	_profiles.clear()
	_rock_relief_cache.clear()
	_land_winding_signs.clear()
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
		var signs:=PackedInt32Array()
		for loop:PackedVector2Array in land_regions[h]:signs.append(1 if _area(loop)>0 else -1)
		_land_winding_signs[h]=signs
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
	_smooth_normals(surfaces.cliff)
	_smooth_normals(surfaces.bank)
	_smooth_normals(surfaces.waterfall)
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

static func contains(loops:Array,p:Vector2,signs:PackedInt32Array=PackedInt32Array())->bool:
	var winding:=0
	for i in loops.size():
		var loop:PackedVector2Array=loops[i]
		if Geometry2D.is_point_in_polygon(p,loop):winding+=signs[i] if signs.size()==loops.size() else (1 if _area(loop)>0 else -1)
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
	var rock_top:float=top
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
	var water:int=inside.get("water",-1)
	# A curved mouth's dry-side tangent can miss the nearby pond. Use the
	# authoritative wet support around the bend to protect its rock shoulders.
	if water<0:
		var cell:=Vector2i(p.floor())
		for z in range(-2,3):
			for x in range(-2,3):
				var nearby:=cell+Vector2i(x,z)
				var record:Dictionary=source.cells.get(nearby,{})
				var level:int=record.get("water",-1)
				if level<0 or level*.5>top+.05:continue
				if p.distance_squared_to(Vector2(nearby)+Vector2.ONE*.5)>1.6*1.6:continue
				# An intact dry bank separates enclosed ponds from the outer
				# cliff. Only neighboring water with an exposed drop can spill.
				for direction:Vector2i in Legacy.SIDES:
					var receiver:Dictionary=source.cells.get(nearby+direction,{})
					var height:float=receiver.water*.5 if receiver.get("water",-1)>=0 else receiver.get("height",BOTTOM)
					if height<level*.5-.1:water=maxi(water,level);break
	var profile:={"top":top,"rock_top":rock_top,"bottom":bottom,"base":outside.is_empty(),"inset":_inset_limit(p,normal,top) if outside.is_empty() else 0.0,"water":water}
	_profiles[key]=profile
	return profile

func _profile_point(p:Vector2,y:float,normal:Vector2,profile:Dictionary)->Vector3:
	var depth:float=maxf(.001,profile.top-profile.bottom)
	var edge_weight:=clampf((profile.top-y)*2,0,1)*clampf((y-profile.bottom)*2,0,1)
	var broad_weight:=clampf((profile.inset-.35)/.45,0,1) if profile.base else .5
	y+=sin(p.x*1.17+p.y*.91+y*1.73)*lerpf(.16,.06,broad_weight)*edge_weight
	var f:=clampf((profile.top-y)/depth,0,1)
	var rounded:=0.0
	if not profile.base or profile.inset>.35:
		var key:=Vector3(p.x,y,p.y)
		if not _rock_relief_cache.has(key):_rock_relief_cache[key]=_rock_relief(key)
		rounded=_rock_relief_cache[key]
	var rock_depth:float=depth
	var rock_f:=f
	# Both exposed terrace edges stay pinned to their cap contours.
	# Only the wall above the neighboring lower terrace gets a new envelope.
	if profile.rock_top>profile.top+.001 and y>profile.top:
		rock_depth=profile.rock_top-profile.top
		rock_f=clampf((profile.rock_top-y)/rock_depth,0,1)
	var point:=_rock_point(p,y,f,profile.base,minf(1.0,rock_depth/2.2),normal,profile.inset,rounded,rock_f)
	if profile.water>=0 and point.y<=profile.water*.5+.045:
		# Exposed wet walls sit behind the shared stream envelope. Limit only
		# protruding shoulders; inland and dry cliff masses keep their full relief.
		var water_y:float=profile.water*.5+.045
		var stream:=_fall_point(p,normal,water_y,point.y)
		var clearance:float=.50*clampf((water_y-point.y)*2.0,0.0,1.0)
		var excess:float=(Vector2(point.x-stream.x,point.z-stream.z)).dot(normal)+clearance
		if excess>0.0:point-=Vector3(normal.x,0,normal.y)*excess
	return point

func _cliffs(loop:PackedVector2Array,top:float,bottom:float)->void:
	for i in loop.size():
		var a:=loop[i]
		var b:=loop[(i+1)%loop.size()]
		# refresh already selected the occupied outline for this height row.
		# Upper contours are smoothed independently and can cross a lower one;
		# sampling them here incorrectly removes an authoritative boundary wall.
		var before:=loop[(i-1+loop.size())%loop.size()]
		var after:=loop[(i+2)%loop.size()]
		var normal_a:=Vector2(b.y-before.y,before.x-b.x).normalized()
		var normal_b:=Vector2(after.y-a.y,a.x-after.x).normalized()
		var profile_a:=_cliff_profile(a,normal_a)
		var profile_b:=_cliff_profile(b,normal_b)
		# Keep the authoritative cap contour, but resolve rock shoulders within
		# each stable span. Narrow necks retain their proven unsplit profile.
		var broad:bool=(not profile_a.base or profile_a.inset>.8) and (not profile_b.base or profile_b.inset>.8)
		var columns:=maxi(1,ceili(a.distance_to(b)/.65)) if broad else 1
		var left:=a
		var left_normal:=normal_a
		var left_profile:=profile_a
		for column in columns:
			var weight:float=float(column+1)/columns
			var right:=a.lerp(b,weight)
			var right_normal:=normal_a.lerp(normal_b,weight).normalized()
			var right_profile:Dictionary=profile_b if column==columns-1 else _cliff_profile(right,right_normal)
			var p:=_profile_point(left,top,left_normal,left_profile)
			var q:=_profile_point(right,top,right_normal,right_profile)
			var r:=_profile_point(right,bottom,right_normal,right_profile)
			var s:=_profile_point(left,bottom,left_normal,left_profile)
			surfaces.cliff.quad(p,s,r,q,Color("a8aba8"))
			left=right
			left_normal=right_normal
			left_profile=right_profile

func _inset_limit(p:Vector2,normal:Vector2,height:float)->float:
	# Measure the same filled outline that owns the cap and cliff boundary.
	# Raw cell corners can be empty beneath a broad smoothed edge; treating
	# those as thin land creates untapered blades between neighboring shoulders.
	var loops:Array=land_regions.get(height,[])
	var signs:PackedInt32Array=_land_winding_signs.get(height,PackedInt32Array())
	for step in range(1,45):
		var distance:=step*.125
		if not contains(loops,p-normal*distance,signs):return minf(1.5,distance*.28)
	return 1.5

static func _rock_point(p:Vector2,y:float,f:float,base:bool,relief:float=1.0,normal:Vector2=Vector2.ZERO,inset_limit:float=1.5,rounded_relief:float=NAN,rock_fraction:float=NAN)->Vector3:
	var inset:=normal*(inset_limit*pow(f,1.5) if base else 0.0)
	var width_weight:=clampf((inset_limit-.35)/.45,0.0,1.0) if base else .5
	var noise:=sin(p.x*1.91+p.y*2.17+f*7.9)*lerpf(.38,.04,width_weight)*sin(PI*f)
	var vertical_noise:=sin(p.x*.91+p.y*1.47)*(lerpf(.62,.09,width_weight)*sin(PI*f)+(lerpf(.22,.02,width_weight)*pow(f,4.0) if base else 0.0))
	# Rounded rock shoulders share a world-anchored field with the material.
	# Preserve the proven narrow-wall profile and fade relief at true boundaries.
	if is_nan(rounded_relief):rounded_relief=_rock_relief(Vector3(p.x,y,p.y)) if width_weight>0.0 else 0.0
	# Keep shoulders above, then settle into a compact base instead of deep
	# scallops. The lower envelope reaches the foot with a finite slope.
	var shoulder_f:=f if is_nan(rock_fraction) else rock_fraction
	# Nearby lower land controls base taper, not the upper rock shoulders.
	var envelope:=pow(maxf(0.0,sin(PI*shoulder_f)),lerpf(lerpf(.65,.32,width_weight),1.0,smoothstep(.50,.85,shoulder_f)))
	if base:envelope*=lerpf(1.0,.25,smoothstep(.55,.95,shoulder_f))
	var ledge:=rounded_relief*envelope*relief*width_weight
	return Vector3(p.x-inset.x+noise+normal.x*ledge,y+vertical_noise*relief,p.y-inset.y+noise*.7+normal.y*ledge)

static func _rock_relief(point:Vector3)->float:
	# Oblique world coordinates stagger joints through elevation instead of
	# forming horizontal courses. The material uses the same linear frame.
	var frame:=Vector3(point.x+point.y*.16,point.y+point.x*.28+point.z*.19,point.z-point.y*.12)
	var p:=frame/Vector3(2.2,1.8,2.2)
	var cell:=p.floor()
	var f:=p-cell
	var nearest:=10.0
	for z in range(-1,2):
		for y in range(-1,2):
			for x in range(-1,2):
				var offset:=Vector3(x,y,z)
				var delta:=offset+_rock_hash(cell+offset)*.72+Vector3.ONE*.14-f
				var axis:Vector3=delta.abs()
				# A clipped octahedron gives each shoulder planar faces rather
				# than a smooth mound. Minimum distance keeps site joins continuous.
				var distance:=maxf(maxf(axis.x,maxf(axis.y,axis.z)),(axis.x+axis.y+axis.z)*.57)
				nearest=minf(nearest,distance)
	return .75*clampf((.76-nearest)/.55,0.0,1.0)-.10

static func _rock_hash(point:Vector3)->Vector3:
	var q:=point*Vector3(.123,.117,.139)
	q-=q.floor()
	q+=Vector3.ONE*q.dot(Vector3(q.z,q.x,q.y)+Vector3.ONE*19.19)
	var value:=Vector3((q.x+q.y)*q.z,(q.y+q.z)*q.x,(q.z+q.x)*q.y)
	return value-value.floor()

func _falls(loop:PackedVector2Array,water_y:float)->void:
	if _area(loop)<0:return
	var flow_edges:=_flow_edges(loop,water_y)
	for i in loop.size():
		var a:=loop[i]
		var b:=loop[(i+1)%loop.size()]
		var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
		var sample:Dictionary=flow_edges[i].sample
		var low:float=sample.get("height",-12.0)
		if low>=water_y-.1:continue
		var before:=loop[(i-1+loop.size())%loop.size()]
		var after:=loop[(i+2)%loop.size()]
		var normal_a:=Vector2(b.y-before.y,before.x-b.x).normalized()
		var normal_b:=Vector2(after.y-a.y,a.x-after.x).normalized()
		# Fixed world-height rows preserve joins over different receiver heights.
		var rows:Array=[]
		var height:=floorf(water_y*2)*.5
		while height>low+.07:
			rows.append(height)
			height-=.5
		rows.append(low+.07)
		# Subdivide long outlets laterally so physical folds survive triangulation.
		var columns:=maxi(1,ceili(a.distance_to(b)/.32))
		for column in columns:
			var t0:=float(column)/columns
			var t1:=float(column+1)/columns
			var a0:=a.lerp(b,t0)
			var b0:=a.lerp(b,t1)
			var n0:=normal_a.lerp(normal_b,t0).normalized()
			var n1:=normal_a.lerp(normal_b,t1).normalized()
			var p:=_fall_point(a0,n0,water_y,water_y)
			var q:=_fall_point(b0,n1,water_y,water_y)
			surfaces.water.quad(Vector3(a0.x,water_y,a0.y),Vector3(b0.x,water_y,b0.y),q,p,Color.WHITE,true)
			var previous_a:=p
			var previous_b:=q
			for y:float in rows:
				var current_a:=_fall_point(a0,n0,water_y,y)
				var current_b:=_fall_point(b0,n1,water_y,y)
				var start:int=surfaces.waterfall.vertices.size()
				surfaces.waterfall.quad(previous_b,previous_a,current_a,current_b,Color.WHITE)
				var width:float=flow_edges[i].width
				if width>0:
					for index in range(start,surfaces.waterfall.vertices.size()):
						var vertex:Vector3=surfaces.waterfall.vertices[index]
						var t:float=t0 if vertex==previous_a or vertex==current_a else t1
						var across:float=(flow_edges[i].start+a.distance_to(b)*t)/width
						# Linear run coordinates and world drop survive triangle clipping.
						# Alpha zero marks metadata; legacy/closed-ring white stays valid.
						surfaces.waterfall.colors[index]=Color(across,clampf((water_y-vertex.y)/16,0,1),1.0/(1.0+width),0)
				previous_a=current_a
				previous_b=current_b
			var back:=Vector3(out.x,0,out.y)*.09
			var crest_start:int=surfaces.bank.vertices.size()
			surfaces.bank.quad(p-back+Vector3(0,.012,0),q-back+Vector3(0,.012,0),q+Vector3(0,.012,0),p+Vector3(0,.012,0),Color.WHITE,true)
			# Blue zero marks crest foam; landing foam retains its original white.
			for index in range(crest_start,surfaces.bank.vertices.size()):surfaces.bank.colors[index]=Color(1,1,0,1)
		var r:=_fall_point(b,normal_b,water_y,low+.07)
		var s:=_fall_point(a,normal_a,water_y,low+.07)
		if not sample.is_empty() and sample.water>=0:
			var center:=(r+s)*.5+Vector3(out.x*.24,.015,out.y*.24)
			_splash(center,out,i)

func _flow_edges(loop:PackedVector2Array,water_y:float)->Array:
	var result:Array=[]
	var stop:=-1
	for i in loop.size():
		var a:=loop[i];var b:=loop[(i+1)%loop.size()]
		var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
		var sample:=surface_at((a+b)*.5+out*.25)
		var spill:bool=float(sample.get("height",-12.0))<water_y-.1
		result.append({"sample":sample,"spill":spill,"start":0.0,"width":0.0,"length":a.distance_to(b)})
		if not spill:stop=i
	# A fully exposed closed perimeter has no lateral ends to fade.
	if stop<0:return result
	var run:Array=[]
	var width:=0.0
	for step in range(1,loop.size()+1):
		var i:=(stop+step)%loop.size()
		if result[i].spill:
			result[i].start=width
			width+=float(result[i].length)
			run.append(i)
		else:
			for index:int in run:result[index].width=width
			run.clear()
			width=0.0
	return result

func _splash(center:Vector3,out:Vector2,phase:int)->void:
	var rings:Array=[]
	var tangent:=Vector3(out.y,0,-out.x)
	var forward:=Vector3(out.x,0,out.y)
	for ring in 2:
		var points:=PackedVector3Array()
		for j in 16:
			var angle:=j*TAU/16.0
			var size:=.62+.11*sin(phase*3.7+j*2.9)
			var radius:=.55 if ring==0 else 1.0
			var rise:=.10+.09*pow(.5+.5*sin(j*2.1+phase*1.3),3) if ring==0 else 0.0
			points.append(center+tangent*cos(angle)*size*radius+forward*sin(angle)*size*radius+Vector3(0,rise,0))
		rings.append(points)
	var peak:=center+Vector3(0,.24+.05*sin(phase*2.7),0)
	for j in 16:
		var k:=(j+1)%16
		_foam_triangle(peak,rings[0][j],rings[0][k],center.y)
		_foam_triangle(rings[0][j],rings[1][j],rings[1][k],center.y)
		_foam_triangle(rings[0][j],rings[1][k],rings[0][k],center.y)

func _foam_triangle(a:Vector3,b:Vector3,c:Vector3,base:float)->void:
	var start:int=surfaces.bank.vertices.size()
	surfaces.bank.triangle(a,b,c,Color.WHITE,true)
	for i in range(start,surfaces.bank.vertices.size()):
		var opacity:=clampf((surfaces.bank.vertices[i].y-base)/.10,0.0,1.0)
		surfaces.bank.colors[i]=Color(1,1,1,opacity)

static func _fall_point(p:Vector2,normal:Vector2,water_y:float,y:float)->Vector3:
	var lower:=floorf(y*2)*.5
	var offset:=lerpf(_fall_offset(water_y,lower)+_fall_fold(p,water_y,lower),_fall_offset(water_y,lower+.5)+_fall_fold(p,water_y,lower+.5),(y-lower)*2)
	return Vector3(p.x+normal.x*offset,y,p.y+normal.y*offset)

static func _fall_fold(p:Vector2,water_y:float,y:float)->float:
	var drop:=maxf(0,water_y-y)
	return .12*sin(p.x*6.2+p.y*4.3+drop*.18)*(1-exp(-drop*4.0))

static func _fall_offset(water_y:float,y:float)->float:
	var drop:=maxf(0,water_y-y)
	return .36+.13*(1-exp(-drop*.8))+.08*sin(drop*1.5)*minf(1,drop)

func _smooth_normals(surface)->void:
	# Smooth generated cliff, foam and waterfall surfaces. Embedded stone models retain their
	# original flat facets. Shared positions also join normals across chunks.
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

static func _interpolated_color(point:Vector3,a:Vector3,b:Vector3,c:Vector3,ca:Color,cb:Color,cc:Color)->Color:
	var ab:=b-a
	var ac:=c-a
	var ap:=point-a
	var denominator:=ab.dot(ab)*ac.dot(ac)-ab.dot(ac)*ab.dot(ac)
	if absf(denominator)<.00000001:return ca
	var u:float=(ac.dot(ac)*ap.dot(ab)-ab.dot(ac)*ap.dot(ac))/denominator
	var v:float=(ab.dot(ab)*ap.dot(ac)-ab.dot(ac)*ap.dot(ab))/denominator
	return ca*(1-u-v)+cb*u+cc*v

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
				if kind in ["bank","waterfall"]:
					for index in range(before,local.vertices.size()):
						local.colors[index]=_interpolated_color(local.vertices[index],vertices[i],vertices[i+1],vertices[i+2],colors[i],colors[i+1],colors[i+2])
				if kind in ["cliff","bank","waterfall"]:
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
