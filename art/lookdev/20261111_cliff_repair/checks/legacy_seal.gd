extends RefCounted
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
static func apply(field,columns:Array,assets:Dictionary)->void:
	# A dry interior wall owns both authoritative cap endpoints. A neighboring
	# wet endpoint may clamp the sculpted backing to its bed, and its normal
	# recession can fold a short span away once source cladding is removed.
	# Generate the whole uncovered span continuously after that backing pass.
	var crowns:Dictionary={}
	for column:Dictionary in columns:
		var height:float=column.pose.origin.y
		var polygon:=PackedVector2Array()
		for p:Vector2 in assets[column.kind][0].cap_polygon:
			var point:Vector3=column.pose*Vector3(p.x,0.0,p.y)
			polygon.append(Vector2(point.x,point.z))
		if not crowns.has(height):crowns[height]=[]
		crowns[height].append(polygon)
	var seal:=Surface.new()
	for height:float in field.land_regions:
		for loop:PackedVector2Array in field.land_regions[height]:
			for i:int in loop.size():
				var a:Vector2=loop[i]
				var b:Vector2=loop[(i+1)%loop.size()]
				var mid:Vector2=(a+b)*.5
				var direction:Vector2=(b-a).normalized()
				var outward:=Vector2(direction.y,-direction.x)
				var upper:Dictionary=field.surface_at(mid-outward*.25)
				var receiver:Dictionary=field.surface_at(mid+outward*.30)
				if upper.is_empty() or receiver.is_empty() or int(upper.water)>=0 or int(receiver.water)>=0:continue
				var bottom:float=receiver.height
				if absf(float(upper.height)-height)>.01 or height-bottom<.4:continue
				var covered:=false
				for crown:PackedVector2Array in crowns.get(height,[]):
					if Geometry2D.is_point_in_polygon(mid,crown):covered=true;break
				if covered:continue
				var start:int=seal.vertices.size()
				seal.quad(Vector3(a.x,height,a.y),Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,height,b.y),Color(.78,.78,.78))
				for j:int in range(start,seal.vertices.size()):seal.uv[j]=Vector2(height,1.0)
	if seal.vertices.is_empty():return
	field._smooth_normals(seal)
	field.surfaces.cliff.vertices.append_array(seal.vertices)
	field.surfaces.cliff.normals.append_array(seal.normals)
	field.surfaces.cliff.colors.append_array(seal.colors)
	field.surfaces.cliff.uv.append_array(seal.uv)

