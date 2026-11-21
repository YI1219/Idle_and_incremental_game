extends RefCounted
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")

static func section_points(faces: PackedVector3Array, pose: Transform3D, y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var seen: Dictionary = {}
	for i: int in range(0,faces.size(),3):
		for k: int in 3:
			var a: Vector3 = pose*faces[i+k]
			var b: Vector3 = pose*faces[i+(k+1)%3]
			if (a.y-y)*(b.y-y) < 0:
				var p: Vector3 = a.lerp(b,(y-a.y)/(b.y-a.y))
				var key := Vector2i((Vector2(p.x,p.z)*100000).round())
				if not seen.has(key): points.append(Vector2(key)/100000.0);seen[key]=true
	return points

static func section(faces: PackedVector3Array, pose: Transform3D, y: float) -> PackedVector2Array:
	var points: PackedVector2Array = section_points(faces,pose,y)
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size()>1: hull.remove_at(hull.size()-1)
	return hull

static func clip(poly: Array, y: float, below: bool) -> Array:
	var out: Array = []
	for i: int in poly.size():
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i+1)%poly.size()]
		var da: float = (a.p.y-y)*(1 if below else -1)
		var db: float = (b.p.y-y)*(1 if below else -1)
		if da <= .000001: out.append(a)
		if (da < -.000001 and db > .000001) or (db < -.000001 and da > .000001):
			var t: float = da/(da-db)
			var p: Vector3 = a.p.lerp(b.p,t)
			p=Vector3(roundf(p.x*100000)/100000.0,y,roundf(p.z*100000)/100000.0)
			out.append({"p":p,"n":a.n.lerp(b.n,t).normalized(),"c":a.c.lerp(b.c,t),"uv":a.uv.lerp(b.uv,t)})
	return out

static func emit(s: RefCounted, items: Array, pose_inverse: Transform3D, normal_inverse: Basis) -> void:
	var start: int = s.vertices.size()
	s.triangle(pose_inverse*items[0].p,pose_inverse*items[1].p,pose_inverse*items[2].p,Color.WHITE)
	if s.vertices.size() == start: return
	for k: int in 3:
		s.normals[start+k]=(normal_inverse*items[k].n).normalized()
		s.colors[start+k]=items[k].c
		s.uv[start+k]=items[k].uv

static func build(source: Mesh, pose: Transform3D, parent: Mesh, parent_pose: Transform3D) -> ArrayMesh:
	var parent_faces: PackedVector3Array = Geometry.faces_of(parent)
	var parent_bottom: float = INF
	var parent_top: float = -INF
	for p: Vector3 in parent_faces:
		var y: float = (parent_pose*p).y
		parent_bottom=minf(parent_bottom,y);parent_top=maxf(parent_top,y)
	var arrays: Array = Geometry.arrays_of(source)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var source_bottom: float = INF
	var source_top: float = -INF
	for p: Vector3 in points:
		var y: float = (pose*p).y
		source_bottom=minf(source_bottom,y);source_top=maxf(source_top,y)
	var floor_y: float = maxf(source_bottom+.01,parent_bottom+maxf(.18,(parent_top-parent_bottom)*.055))
	var join_y: float = minf(source_top-.20,floor_y+maxf(1.0,(parent_top-parent_bottom)*.12))
	var support: PackedVector2Array = section(parent_faces,parent_pose,floor_y)
	var foot: PackedVector2Array = section(points,pose,floor_y)
	assert(support.size()>=3 and foot.size()>=3 and join_y>floor_y)
	var target := Vector2.ZERO
	var center := Vector2.ZERO
	for p: Vector2 in support: target+=p
	target/=support.size()
	for p: Vector2 in foot: center+=p
	center/=foot.size()
	var scale: float = 1.0
	for i: int in support.size():
		var a: Vector2 = support[i]
		var b: Vector2 = support[(i+1)%support.size()]
		var edge: Vector2 = b-a
		var n := Vector2(edge.y,-edge.x).normalized()
		var space: float = n.dot(a-target)-.08
		for p: Vector2 in foot:
			var reach: float = n.dot(p-center)
			if reach>.00001: scale=minf(scale,space/reach)
	scale=clampf(scale,.02,1.0)
	var span: float = floor_y-join_y
	var k: float = (1.0/scale-1.0)/span
	var lean: Vector2 = (target/scale-center)/span
	var depth_scale: float = 1.0/scale
	var normal_matrix: Basis = pose.basis.inverse().transposed()
	var normal_inverse: Basis = pose.basis.transposed()
	var pose_inverse: Transform3D = pose.affine_inverse()
	var s := Geometry.Surface.new()
	for i: int in range(0,points.size(),3):
		var tri: Array = []
		for j: int in 3: tri.append({"p":pose*points[i+j],"n":(normal_matrix*normals[i+j]).normalized(),"c":colors[i+j],"uv":uvs[i+j]})
		tri=clip(tri,floor_y,false)
		for lower: bool in [false,true]:
			var poly: Array = clip(tri.duplicate(true),join_y,lower)
			if lower:
				for item: Dictionary in poly:
					var p: Vector3 = item.p
					var d: float = p.y-join_y
					var w: float = 1.0+k*d
					var jacobian := Basis(Vector3(1.0/w,0,0),Vector3((lean.x-k*p.x)/(w*w),depth_scale/(w*w),(lean.y-k*p.z)/(w*w)),Vector3(0,0,1.0/w))
					item.p=Vector3((p.x+lean.x*d)/w,join_y+depth_scale*d/w,(p.z+lean.y*d)/w)
					item.n=(jacobian.inverse().transposed()*item.n).normalized()
			for j: int in range(1,poly.size()-1): emit(s,[poly[0],poly[j],poly[j+1]],pose_inverse,normal_inverse)
	# The new cap is buried within the support polygon.
	var boundary: Array = []
	for p: Vector2 in section_points(points,pose,floor_y): boundary.append(p)
	boundary.sort_custom(func(a: Vector2,b: Vector2) -> bool: return (a-center).angle()<(b-center).angle())
	var cap := PackedVector2Array()
	for p: Vector2 in boundary: cap.append(target+(p-center)*scale)
	for i: int in cap.size():
		var items: Array = []
		for p: Vector2 in [target,cap[i],cap[(i+1)%cap.size()]]:
			items.append({"p":Vector3(p.x,floor_y,p.y),"n":Vector3.DOWN,"c":colors[0],"uv":Vector2(.22,0)})
		if -((items[1].p-items[0].p).cross(items[2].p-items[0].p)).y>0: items.reverse()
		emit(s,items,pose_inverse,normal_inverse)
	var mesh: ArrayMesh = s.mesh()
	mesh.surface_set_material(0,source.surface_get_material(0))
	mesh.set_meta("join_y",join_y)
	mesh.set_meta("floor_y",floor_y)
	return mesh
