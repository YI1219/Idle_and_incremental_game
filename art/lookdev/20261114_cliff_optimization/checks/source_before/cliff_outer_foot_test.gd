extends SceneTree
## Preserve the long upper slabs; only the heel is cut and seated in its parent.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func bottom(faces: PackedVector3Array, pose: Transform3D) -> float:
	var result: float = INF
	for p: Vector3 in faces: result = minf(result,(pose*p).y)
	return result
func inside(faces: PackedVector3Array, p: Vector3) -> bool:
	var hits: Dictionary = {}
	var direction := Vector3(1,.137,.419).normalized()
	for i: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(p,direction,faces[i],faces[i+1],faces[i+2])
		if hit!=null: hits[roundi(p.distance_to(hit)*10000)]=true
	return hits.size()%2==1
func verify(deco: RefCounted, old: RefCounted, label: String) -> Dictionary:
	var result: Dictionary = {}
	for mass: Dictionary in deco._mass:
		if mass.get("is_interior",false): continue
		var prior: Dictionary = {}
		for candidate: Dictionary in old._mass:
			if candidate.cell==mass.cell and candidate.kind==mass.kind and not candidate.get("is_interior",false): prior=candidate;break
		check(not prior.is_empty(),label+" keeps the original layer anchors")
		if prior.is_empty(): continue
		check(mass.pose==prior.pose,label+" keeps the upper slab pose without compressing its height")
		check(mass.has("mesh"),label+" reshapes the heel instead of scaling the complete source")
		if not mass.has("mesh"): continue
		var mesh: Mesh = mass.mesh
		var faces: PackedVector3Array = Geometry.faces_of(mesh)
		var parent: Dictionary = {}
		for col: Dictionary in deco._columns:
			if col.cell==mass.cell and not col.is_step and col.pose.basis.z.normalized().dot(mass.pose.basis.z.normalized())>.97: parent=col;break
		check(not parent.is_empty(),label+" has a supporting main rock")
		if parent.is_empty(): continue
		var low: float = bottom(faces,mass.pose)
		check(low>bottom(deco.assets[parent.kind][0].faces,parent.pose)+.15,label+" stops above the supporting rock bottom")
		var source: PackedVector3Array = deco.assets[mass.kind][0].faces
		var upper: int = 0
		var kept: bool = true
		for p: Vector3 in source:
			if (mass.pose*p).y<float(mesh.get_meta("join_y"))+.001: continue
			upper += 1
			var found: bool = false
			for q: Vector3 in faces:
				if p.distance_squared_to(q)<.00000001: found=true;break
			kept=kept and found
		check(upper>=18 and kept,label+" preserves all original upper/middle slab vertices")
		var arrays: Array = Geometry.arrays_of(mesh)
		var valid: bool = true
		for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: valid=valid and n.is_finite() and absf(n.length()-1)<.0001
		check(valid,label+" transports finite unit normals through the lower bevel")
		var parent_faces: PackedVector3Array = deco.assets[parent.kind][0].faces
		var parent_inverse: Transform3D = parent.pose.affine_inverse()
		var embedded: bool = true
		var cap_count: int = 0
		var edges: Dictionary = {}
		for i: int in range(0,faces.size(),3):
			for j: int in 3:
				var a: Vector3 = faces[i+j]
				var b: Vector3 = faces[i+(j+1)%3]
				var world: Vector3 = mass.pose*a
				if absf(world.y-float(mesh.get_meta("floor_y")))<.0001:
					cap_count+=1
					embedded=embedded and inside(parent_faces,parent_inverse*world)
				var ka := Vector3i((a*10000).round())
				var kb := Vector3i((b*10000).round())
				if ka==kb: continue
				var key: Array = [ka,kb] if ka<kb else [kb,ka]
				edges[key]=edges.get(key,0)+1
		var closed: bool = true
		for count: int in edges.values(): closed=closed and count==2
		check(cap_count>=9 and embedded,label+" entire cut heel is inside the actual parent volume")
		check(closed,label+" clipped source and buried cap form a closed solid at "+str(mass.cell))
		result[mass.cell]=[mass.pose,faces,arrays[Mesh.ARRAY_NORMAL]]
	check(result.size()>=3,label+" exercises several staggered layers")
	return result
func _initialize() -> void:
	var before := GDScript.new()
	before.source_code=FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_foot/checks/source_before/terrain_decoration.gd").replace("class_name TerrainDecoration\n","")
	if before.reload()!=OK: quit(1);return
	var old: RefCounted = before.new();old.load_assets()
	var deco := Decoration.new();deco.assets=old.assets
	for fixture: Vector2i in [Vector2i(7301,0),Vector2i(2104,0),Vector2i(4242,1),Vector2i(913,2)]:
		var data := Data.new();data.make_preset(fixture.y);data.seed=fixture.x
		var field := Field.new();field.refresh(data)
		var old_field := Field.new();old_field.refresh(data)
		old._column_layout(old_field,data.seed);deco._column_layout(field,data.seed)
		var poses: Dictionary = verify(deco,old,"seed %d" % fixture.x)
		var resources: Dictionary = {}
		for mass: Dictionary in deco._mass:
			if mass.has("mesh"):resources[mass.cell]=mass.mesh
		field.refresh(data);deco._column_layout(field,data.seed)
		check(deco.layout_hits>0,"same seed refresh actually restores unchanged runs")
		var reused: bool = true
		for mass: Dictionary in deco._mass:
			if mass.has("mesh"):reused=reused and resources[mass.cell]==mass.mesh
		check(reused,"unchanged runs reuse their seated heel resources")
		check(verify(deco,old,"warm %d" % fixture.x)==poses,"warm layout restores identical geometry")
		var fresh := Decoration.new();fresh.assets=deco.assets
		var fresh_field := Field.new();fresh_field.refresh(data);fresh._column_layout(fresh_field,data.seed)
		check(verify(fresh,old,"fresh %d" % fixture.x)==poses,"cold and cached joins have identical geometry")
		if fixture.x==7301:
			data.begin_stroke();data.apply_brush(Vector2(-14,4),2.2,"lower",false,3.5,7,3.5);data.end_stroke()
			field.refresh(data);deco._column_layout(field,data.seed)
			data.undo();field.refresh(data);deco._column_layout(field,data.seed)
			check(verify(deco,old,"undo")==poses,"undo restores original layered geometry")
	print("CLIFF OUTER FOOT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
