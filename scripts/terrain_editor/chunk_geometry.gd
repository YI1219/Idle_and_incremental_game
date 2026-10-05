class_name ChunkGeometry
extends RefCounted
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Blob = preload("res://scripts/world/blob47.gd")
const BOTTOM := -6.0
const SIDES := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

class Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	func triangle(a: Vector3,b: Vector3,c: Vector3,color:Color,up:bool=false) -> void:
		var normal := (b-a).cross(c-a).normalized()
		if up and normal.y<0.0:
			var temp := b
			b=c
			c=temp
			normal=-normal
		for v in [a,b,c]:
			vertices.append(v)
			normals.append(normal)
			colors.append(color)
			uv.append(Vector2(v.x+v.z,v.y))
	func quad(a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color,up:bool=false) -> void:
		triangle(a,b,c,color,up)
		triangle(a,c,d,color,up)
	func polygon(points:PackedVector2Array,height:float,color:Color)->void:
		var indices := Geometry2D.triangulate_polygon(points)
		for i in range(0,indices.size(),3):
			var a := points[indices[i]]
			var b := points[indices[i+1]]
			var c := points[indices[i+2]]
			triangle(Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(c.x,height,c.y),color,true)
	func mesh()->ArrayMesh:
		var result := ArrayMesh.new()
		if vertices.is_empty(): return result
		var arrays:Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_TEX_UV]=uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result

static func water_polygon(mask:int)->PackedVector2Array:
	# Clockwise outline: each quarter distinguishes convex, straight and concave bank.
	var corners := [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]
	var previous := [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
	var following := [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
	var card_before := [Blob.W,Blob.N,Blob.E,Blob.S]
	var card_after := [Blob.N,Blob.E,Blob.S,Blob.W]
	var diagonal := [Blob.NW,Blob.NE,Blob.SE,Blob.SW]
	var result := PackedVector2Array()
	for i in 4:
		var corner:Vector2=corners[i]
		var prev:Vector2=previous[i]
		var next:Vector2=following[i]
		var a:bool=(mask & card_before[i])!=0
		var b:bool=(mask & card_after[i])!=0
		if a and b and (mask & diagonal[i])!=0:
			result.append(corner)
		elif a and b:
			for j in 5:
				var angle := j*PI/8.0
				result.append(corner+0.22*(prev*cos(angle)+next*sin(angle)))
		elif not a and not b:
			var center := corner+(prev+next)*0.23
			for j in 5:
				var angle := j*PI/8.0
				result.append(center-0.23*(next*cos(angle)+prev*sin(angle)))
		else:
			result.append(corner+(next*0.12 if not a else prev*0.12))
	return result

static func _world_polygon(local:PackedVector2Array,cell:Vector2i)->PackedVector2Array:
	var result := PackedVector2Array()
	for p in local: result.append(p+Vector2(cell))
	return result

static func build(data:Data,chunk:Vector2i)->Dictionary:
	var surfaces := {"grass":Surface.new(),"cliff":Surface.new(),"bank":Surface.new(),"water":Surface.new(),"waterfall":Surface.new()}
	for z in range(chunk.y*8,chunk.y*8+8):
		for x in range(chunk.x*8,chunk.x*8+8):
			var cell := Vector2i(x,z)
			if not data.cells.has(cell): continue
			var record:Dictionary=data.cells[cell]
			var height:float=record.height
			var square := PackedVector2Array([Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)])
			var tint := Color.WHITE * (0.92 + 0.08*sin(x*7.13+z*3.91))
			tint.a=1.0
			if record.water<0:
				surfaces.grass.polygon(square,height,tint)
			else:
				var surface_y:float=record.water*0.5
				var water_shape := _world_polygon(water_polygon(data.water_mask(cell)),cell)
				surfaces.water.polygon(water_shape,surface_y,Color.WHITE)
				for bank:PackedVector2Array in Geometry2D.clip_polygons(square,water_shape):
					surfaces.bank.polygon(bank,surface_y+0.018,Color.WHITE)
			for side in 4:
				var neighbor:Vector2i=cell+SIDES[side]
				var neighbor_height:float=data.cells[neighbor].height if data.cells.has(neighbor) else BOTTOM
				var ends := _edge(cell,side)
				var a:Vector3=ends[0]
				var b:Vector3=ends[1]
				if height>neighbor_height:
					_cliff(surfaces.cliff,a,b,height,neighbor_height,cell,side)
				if record.water<0: continue
				var water_y:float=record.water*0.5
				var target_y:=BOTTOM
				var spill:=not data.cells.has(neighbor)
				if data.cells.has(neighbor) and data.cells[neighbor].water>=0:
					target_y=data.cells[neighbor].water*0.5
					spill=target_y<water_y
				if spill:
					var out := Vector3(SIDES[side].x,0,SIDES[side].y)
					var left:=a.lerp(b,0.19)+out*0.018
					var right:=a.lerp(b,0.81)+out*0.018
					left.y=water_y
					right.y=water_y
					var inner_left:=left-out*0.26
					var inner_right:=right-out*0.26
					surfaces.water.quad(inner_left,inner_right,right,left,Color.WHITE,true)
					var bottom_left:=left+out*0.14
					var bottom_right:=right+out*0.14
					bottom_left.y=target_y+0.03
					bottom_right.y=target_y+0.03
					surfaces.waterfall.quad(left,right,bottom_right,bottom_left,Color.WHITE)
	var result := {}
	for key in surfaces: result[key]=surfaces[key].mesh()
	return result

static func _edge(cell:Vector2i,side:int)->Array[Vector3]:
	var x:=float(cell.x)
	var z:=float(cell.y)
	match side:
		0:return [Vector3(x,0,z),Vector3(x+1,0,z)]
		1:return [Vector3(x+1,0,z),Vector3(x+1,0,z+1)]
		2:return [Vector3(x+1,0,z+1),Vector3(x,0,z+1)]
	return [Vector3(x,0,z+1),Vector3(x,0,z)]

static func _cliff(surface:Surface,a:Vector3,b:Vector3,top:float,bottom:float,cell:Vector2i,side:int)->void:
	var bands:=maxi(1,ceili((top-bottom)/1.2))
	var out:=Vector3(SIDES[side].x,0,SIDES[side].y)
	for band in bands:
		var y1:=lerpf(top,bottom,float(band)/bands)
		var y2:=lerpf(top,bottom,float(band+1)/bands)
		var p:=Vector3(a.x,y1,a.z)
		var q:=Vector3(b.x,y1,b.z)
		var r:=Vector3(b.x,y2,b.z)
		var s:=Vector3(a.x,y2,a.z)
		var center:Vector3=(p+q+r+s)*0.25+out*(0.04+0.09*absf(sin(cell.x*5.0+cell.y*8.0+band)))
		var tint:=Color("92958c")*(0.88+0.13*sin(cell.x*2.1+cell.y*3.2+band*4.9))
		tint.a=1
		surface.triangle(p,q,center,tint)
		surface.triangle(q,r,center,tint*0.96)
		surface.triangle(r,s,center,tint*0.89)
		surface.triangle(s,p,center,tint*1.04)
