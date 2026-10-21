extends RefCounted
## Convex grass overhang outside the exterior crown edge.
## The flat cap stays where it is. The lip is one shallow roll, wide enough
## to read from the game camera, not a second curb.
const ContourTerrain = preload("res://scripts/terrain_editor/contour_terrain.gd")
const SAMPLE_SPACING := 0.36
const MAX_REACH := 0.92
const RING_COUNT := 5

static func _ring_out(ring:int)->float:
	# Most of the width stays nearly level grass. Only the outer third
	# turns down toward the stone, so the lip does not read as a ledge.
	match ring:
		1:return 0.28
		2:return 0.52
		3:return 0.76
		4:return 1.0
	return 0.0

static func _ring_drop(ring:int)->float:
	match ring:
		1:return 0.010
		2:return 0.032
		3:return 0.070
		4:return 0.145
	return 0.0

static func apply(field)->void:
	var surface = field.surfaces.get("grass",null)
	if surface==null or surface.vertices.is_empty():return
	var before:int = surface.vertices.size()
	for key in field.lawn_boundaries:
		var h:float = float(key)
		var loops:Array = field.lawn_boundaries[key]
		for loop:PackedVector2Array in loops:
			if loop.size()<3 or ContourTerrain._area(loop)<=0.0:continue
			_skirt_loop(field,surface,_open_loop(loop),loops,h)
	if surface.vertices.size()>before:
		# Smooth the skirt alone. Averaging it into the cap would tilt large
		# lawn triangles and smear the soften inward across the crown.
		_smooth_skirt(surface,before)

static func _open_loop(loop:PackedVector2Array)->PackedVector2Array:
	if loop.size()>1 and loop[0].distance_squared_to(loop[-1])<0.00000001:
		return loop.slice(0,loop.size()-1)
	return loop

static func _width(p:Vector2)->float:
	# World-anchored, so a closed rim does not kink where the loop index starts.
	return 0.62+0.11*sin(p.x*0.83+p.y*0.57)+0.045*sin(p.x*1.67-p.y*1.21+1.2)

static func _drop(p:Vector2,base:float)->float:
	# Scale the scallop with the drop so the lawn edge itself stays on the cap.
	if base<=0.0:return 0.0
	return base*(1.0+0.08*sin(p.x*1.15+p.y*0.72+0.4))

static func _ring_color(ring:int)->Color:
	# Stay in the grass until the outer third, then warm into soil.
	# A grey outer band on this wider lip would read as a second ring.
	match ring:
		1:return Color(0.99,0.98,0.96,1.0)
		2:return Color(0.97,0.93,0.86,1.0)
		3:return Color(0.92,0.82,0.70,1.0)
		4:return Color(0.84,0.74,0.62,1.0)
	return Color(1,1,1,1)

static func _is_outer(field,loops:Array,a:Vector2,b:Vector2)->bool:
	var length:float = a.distance_to(b)
	if length<0.02:return false
	var tangent:Vector2 = (b-a)/length
	var out:Vector2 = Vector2(tangent.y,-tangent.x)
	var mid:Vector2 = (a+b)*0.5
	# Zero-width overlaps with a higher plateau are not this cap's lip.
	if not ContourTerrain.contains(loops,mid-out*0.16):return false
	var probe:Vector2 = mid+out*0.40
	if ContourTerrain.contains(loops,probe):return false
	return field.surface_at(probe).is_empty()

static func _mouth_weight(field,p:Vector2,h:float)->float:
	var weight:float = 1.0
	for veil:Dictionary in field.fall_veils:
		var lip:Vector3 = veil.lip
		if absf(lip.y-h)>1.8:continue
		var clearance:float = p.distance_to(Vector2(lip.x,lip.z))-float(veil.half_width)
		weight = minf(weight,smoothstep(0.45,1.70,clearance))
	return weight

static func _skirt_loop(field,surface,loop:PackedVector2Array,loops:Array,h:float)->void:
	var count:int = loop.size()
	var edge_outer:Array[bool] = []
	var edge_out:Array[Vector2] = []
	edge_outer.resize(count)
	edge_out.resize(count)
	var outer_count:int = 0
	for i in count:
		var a:Vector2 = loop[i]
		var b:Vector2 = loop[(i+1)%count]
		var length:float = a.distance_to(b)
		var out:Vector2 = Vector2.RIGHT
		if length>0.0001:
			var tangent:Vector2 = (b-a)/length
			out = Vector2(tangent.y,-tangent.x)
		edge_out[i] = out
		var outer:bool = _is_outer(field,loops,a,b)
		edge_outer[i] = outer
		if outer:outer_count += 1
	if outer_count==0:return
	var vert_out:Array[Vector2] = []
	var vert_scale:Array[float] = []
	vert_out.resize(count)
	vert_scale.resize(count)
	for i in count:
		var previous:Vector2 = edge_out[(i-1+count)%count]
		var following:Vector2 = edge_out[i]
		var bisector:Vector2 = previous+following
		var scale:float = 1.0
		if bisector.length_squared()<0.0001:
			bisector = following
		else:
			bisector = bisector.normalized()
			var align:float = bisector.dot(following)
			if align>0.55:
				scale = clampf(1.0/align,1.0,1.12)
			else:
				bisector = following
		vert_out[i] = bisector
		vert_scale[i] = scale
	for edges:Array in _outer_runs(edge_outer):
		_emit_run(field,surface,loop,loops,edges,outer_count==count,edge_out,vert_out,vert_scale,h)

static func _outer_runs(outer:Array[bool])->Array:
	var count:int = outer.size()
	var gap:int = -1
	for i in count:
		if not outer[i]:
			gap = i
			break
	if gap<0:
		var every:Array = []
		for i in count:every.append(i)
		return [every]
	# Start just after a gap so a run that wraps the loop index stays one run.
	var runs:Array = []
	var seen:PackedByteArray = PackedByteArray()
	seen.resize(count)
	var index:int = (gap+1)%count
	var walked:int = 0
	while walked<count:
		walked += 1
		if not outer[index] or seen[index]!=0:
			index = (index+1)%count
			continue
		var edges:Array = []
		while outer[index] and seen[index]==0 and edges.size()<count:
			seen[index] = 1
			edges.append(index)
			index = (index+1)%count
		runs.append(edges)
	return runs

static func _emit_run(field,surface,loop:PackedVector2Array,loops:Array,edges:Array,closed:bool,edge_out:Array[Vector2],vert_out:Array[Vector2],vert_scale:Array[float],h:float)->void:
	var count:int = loop.size()
	var samples:Array = []
	for edge_index in edges.size():
		var edge:int = edges[edge_index]
		var a_index:int = edge
		var b_index:int = (edge+1)%count
		var a:Vector2 = loop[a_index]
		var b:Vector2 = loop[b_index]
		var length:float = a.distance_to(b)
		var steps:int = maxi(1,ceili(length/SAMPLE_SPACING))
		var include_end:bool = (not closed) and edge_index==edges.size()-1
		var limit:int = steps+(1 if include_end else 0)
		for step in limit:
			var t:float = float(step)/float(steps)
			var p:Vector2 = a.lerp(b,t)
			if not samples.is_empty() and (samples[-1].p as Vector2).distance_squared_to(p)<0.00000001:continue
			var out:Vector2 = edge_out[edge]
			var scale:float = 1.0
			if t<=0.22:
				var blend:float = t/0.22
				out = (vert_out[a_index] as Vector2).lerp(out,blend)
				scale = lerpf(vert_scale[a_index],1.0,blend)
			elif t>=0.78:
				var blend:float = (t-0.78)/0.22
				out = out.lerp(vert_out[b_index],blend)
				scale = lerpf(1.0,vert_scale[b_index],blend)
			if out.length_squared()<0.0001:out = edge_out[edge]
			else:out = out.normalized()
			if out.dot(edge_out[edge])<0.2:
				out = edge_out[edge]
				scale = 1.0
			var arc:float = 0.0 if samples.is_empty() else float(samples[-1].arc)+(samples[-1].p as Vector2).distance_to(p)
			# A corner bisector can aim back across a concave crown. Keep only
			# the part of the spill that stays outside the lawn.
			var reach:float = _safe_reach(loops,p,out,_width(p)*scale)
			samples.append({"p":p,"out":out,"reach":reach,"arc":arc,"weight":1.0,"h":h})
	if samples.size()<2:return
	var total:float = float(samples[-1].arc)
	if closed:total += (samples[-1].p as Vector2).distance_to(samples[0].p)
	elif total<0.40:return
	for i in samples.size():
		var fade:float = 1.0
		if not closed:
			var end_distance:float = minf(float(samples[i].arc),total-float(samples[i].arc))
			fade = smoothstep(0.08,1.15,end_distance)
		var at:Vector2 = samples[i].p
		samples[i].weight = fade*_mouth_weight(field,at,h)
	var segments:int = samples.size() if closed else samples.size()-1
	for i in segments:
		var left:Dictionary = samples[i]
		var right:Dictionary = samples[(i+1)%samples.size()]
		if float(left.weight)<0.05 and float(right.weight)<0.05:continue
		var direction:Vector2 = (left.out as Vector2)+(right.out as Vector2)
		if direction.length_squared()<0.0001:direction = left.out
		else:direction = direction.normalized()
		var desired:Vector3 = Vector3(direction.x,0.62,direction.y)
		var upper_left:Vector3 = _ring_point(left,0)
		var upper_right:Vector3 = _ring_point(right,0)
		for ring in range(1,RING_COUNT):
			var lower_left:Vector3 = _escape(loops,_ring_point(left,ring))
			var lower_right:Vector3 = _escape(loops,_ring_point(right,ring))
			_band(surface,upper_left,upper_right,lower_right,lower_left,_ring_color(ring-1),_ring_color(ring),desired)
			upper_left = lower_left
			upper_right = lower_right

static func _closest_boundary(loops:Array,point:Vector2)->Vector2:
	var best:float = INF
	var found:Vector2 = point
	for loop:PackedVector2Array in loops:
		for i in loop.size():
			var a:Vector2 = loop[i]
			var b:Vector2 = loop[(i+1)%loop.size()]
			var candidate:Vector2 = Geometry2D.get_closest_point_to_segment(point,a,b)
			var distance:float = point.distance_squared_to(candidate)
			if distance<best:
				best = distance
				found = candidate
	return found

static func _escape(loops:Array,point:Vector3)->Vector3:
	# A corner ray can cross back into the crown. Snap that sample to the
	# boundary instead of guessing an outward push from a concave corner.
	var xz:Vector2 = Vector2(point.x,point.z)
	if not ContourTerrain.contains(loops,xz):return point
	var closest:Vector2 = _closest_boundary(loops,xz)
	if xz.distance_to(closest)<0.012:return point
	return Vector3(closest.x,point.y,closest.y)

static func _reenters(loops:Array,origin:Vector2,out:Vector2,reach:float)->bool:
	# The tip can sit back outside a concave crown while the span crosses it.
	for step in 6:
		var distance:float = reach*float(step+1)/6.0
		if ContourTerrain.contains(loops,origin+out*distance):return true
	return false

static func _safe_reach(loops:Array,origin:Vector2,out:Vector2,wanted:float)->float:
	var limit:float = minf(maxf(wanted,0.0),MAX_REACH)
	if limit<=0.0 or not _reenters(loops,origin,out,limit):return limit
	var lo:float = 0.0
	var hi:float = limit
	for _step in 6:
		var mid:float = (lo+hi)*0.5
		if _reenters(loops,origin,out,mid):hi = mid
		else:lo = mid
	return lo

static func _ring_point(sample:Dictionary,ring:int)->Vector3:
	var p:Vector2 = sample.p
	var out:Vector2 = sample.out
	var reach:float = float(sample.reach)*float(sample.weight)*_ring_out(ring)
	var down:float = _drop(p,_ring_drop(ring))*float(sample.weight)
	return Vector3(p.x+out.x*reach,float(sample.h)-down,p.y+out.y*reach)

static func _band(surface,a:Vector3,b:Vector3,c:Vector3,d:Vector3,upper:Color,lower:Color,desired:Vector3)->void:
	_triangle(surface,a,b,c,upper,upper,lower,desired)
	_triangle(surface,a,c,d,upper,lower,lower,desired)

static func _triangle(surface,a:Vector3,b:Vector3,c:Vector3,ca:Color,cb:Color,cc:Color,desired:Vector3)->void:
	var normal:Vector3 = -(b-a).cross(c-a)
	if normal.length_squared()<0.00000001:return
	var start:int = surface.vertices.size()
	if normal.dot(desired)<0.0:
		surface.triangle(a,c,b,Color.WHITE)
		if surface.vertices.size()!=start+3:return
		surface.colors[start] = ca
		surface.colors[start+1] = cc
		surface.colors[start+2] = cb
	else:
		surface.triangle(a,b,c,Color.WHITE)
		if surface.vertices.size()!=start+3:return
		surface.colors[start] = ca
		surface.colors[start+1] = cb
		surface.colors[start+2] = cc

static func _smooth_skirt(surface,start:int)->void:
	var sums:Dictionary = {}
	for i in range(start,surface.vertices.size(),3):
		var a:Vector3 = surface.vertices[i]
		var weighted:Vector3 = -(surface.vertices[i+1]-a).cross(surface.vertices[i+2]-a)
		if weighted.length_squared()<0.00000001:continue
		for j in 3:
			var key:Vector3 = (surface.vertices[i+j]*10000.0).round()
			sums[key] = sums.get(key,Vector3.ZERO)+weighted
	for i in range(start,surface.vertices.size()):
		var key:Vector3 = (surface.vertices[i]*10000.0).round()
		var sum:Vector3 = sums.get(key,Vector3.ZERO)
		if sum.length_squared()>0.00000001:
			surface.normals[i] = sum.normalized()
