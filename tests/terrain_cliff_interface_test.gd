extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
class Field extends "res://scripts/terrain_editor/contour_terrain.gd":
	var broad_edges:Dictionary={}
	var narrow_points:Dictionary={}
	func _rock_chain(p:Vector2,n:Vector2,profile:Dictionary,top:float,bottom:float)->PackedVector3Array:
		var chain:=super._rock_chain(p,n,profile,top,bottom)
		var key:=Vector4(p.x,p.y,n.x,n.y)
		if not broad_edges.has(key):broad_edges[key]=[]
		broad_edges[key].append(chain)
		return chain
	func _cliff_span(a:Vector2,b:Vector2,na:Vector2,nb:Vector2,pa:Dictionary,pb:Dictionary,top:float,bottom:float)->void:
		super._cliff_span(a,b,na,nb,pa,pb,top,bottom)
		for spec in [[a,na,pa],[b,nb,pb]]:
			var p:Vector2=spec[0]
			var n:Vector2=spec[1]
			var key:=Vector4(p.x,p.y,n.x,n.y)
			if not narrow_points.has(key):narrow_points[key]=[]
			for height:float in [top,bottom]:narrow_points[key].append(_profile_point(p,height,n,spec[2]))
func _initialize()->void:call_deferred("run")
func shared_broad_edges(field:Field)->Array:
	var total:=0
	var misses:=0
	var worst:=0.0
	for key in field.broad_edges:
		var chains:Array=field.broad_edges[key]
		for i in chains.size():
			for j in chains.size():
				if i==j:continue
				var a:PackedVector3Array=chains[i]
				var b:PackedVector3Array=chains[j]
				for point:Vector3 in a:
					if point.y<b[-1].y-.00001 or point.y>b[0].y+.00001:continue
					var distance:=INF
					for k in b.size()-1:distance=minf(distance,point.distance_to(Geometry3D.get_closest_point_to_segment(point,b[k],b[k+1])))
					total+=1
					worst=maxf(worst,distance)
					if distance>.00001:misses+=1
	return [total,misses,worst]
func run()->void:
	var total:=0
	var separated:=0
	var worst:=0.0
	for neck_width in [1,2]:
		var data=Data.new()
		for z in range(-4,5):
			for x in range(-6,7):data.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
		for x in range(7,12):
			for z in neck_width:data.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
		var field=Field.new()
		field.refresh(data)
		for key in field.narrow_points:
			if not field.broad_edges.has(key):continue
			for point:Vector3 in field.narrow_points[key]:
				var distance:=INF
				for chain:PackedVector3Array in field.broad_edges[key]:
					for i in chain.size()-1:distance=minf(distance,point.distance_to(Geometry3D.get_closest_point_to_segment(point,chain[i],chain[i+1])))
				total+=1
				worst=maxf(worst,distance)
				if distance>.00001:separated+=1
	print("CLIFF INTERFACES: ",total," boundary points; ",separated," separated; max=",worst)
	var shared:=0
	var gaps:=0
	var max_gap:=0.0
	# Different elevations split some adjacent contour spans while others
	# merge through them. Compare their actual generated edge polylines.
	for mode in 4:
		var data=Data.new()
		for z in range(-4,5):
			for x in range(-6,7):
				var high:bool=x<0 if mode==0 else (z>0 if mode==1 else x+z<2)
				data.cells[Vector2i(x,z)]={"height":3.5 if high else 1.5,"water":-1}
		if mode==3:data.cells[Vector2i(0,4)].height=1.0
		var field=Field.new()
		field.refresh(data)
		var report:=shared_broad_edges(field)
		shared+=report[0]
		gaps+=report[1]
		max_gap=maxf(max_gap,report[2])
	print("MULTI-ELEVATION CLIFF EDGES: ",shared," points; ",gaps," separated; max=",max_gap)
	quit(0 if total>=50 and separated==0 and shared>=200 and gaps==0 else 1)
