extends "res://tools/art/capture_lookdev.gd"
var slots: Array[Dictionary] = []
var prototype_ready: bool = false

func clip(poly: Array, y: float, below: bool) -> Array:
	var out: Array = []
	for i: int in poly.size():
		var a: Dictionary = poly[i]
		var b: Dictionary = poly[(i+1)%poly.size()]
		var da: float = (a.p.y-y)*(1 if below else -1)
		var db: float = (b.p.y-y)*(1 if below else -1)
		if da <= .000001: out.append(a)
		if (da < -.000001 and db > .000001) or (db < -.000001 and da > .000001):
			var t: float = da/(da-db)
			out.append({"p":a.p.lerp(b.p,t),"c":a.c.lerp(b.c,t),"uv":a.uv.lerp(b.uv,t)})
	return out

func continuous_mesh(part: Dictionary, tint: Color) -> ArrayMesh:
	var arrays: Array = preload("res://scripts/terrain_editor/chunk_geometry.gd").arrays_of(part.render_mesh)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var s := preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var floor_y: float = part.mesh.get_aabb().position.y
	for i: int in range(0,points.size(),3):
		var tri: Array = []
		for k: int in 3: tri.append({"p":points[i+k],"c":colors[i+k]*tint,"uv":uvs[i+k]})
		for band: int in 3:
			var poly: Array = tri.duplicate(true)
			if band == 0: poly=clip(poly,-.145,false)
			elif band == 1: poly=clip(clip(poly,-.145,true),-.65,false)
			else: poly=clip(poly,-.65,true)
			for item: Dictionary in poly:
				var p: Vector3 = item.p
				var t: float = clampf((-.145-p.y)/.505,0,1) if p.y >= -.65 else clampf((p.y-floor_y)/(-.65-floor_y),0,1)
				item.p=p+Vector3(0,0,.22*t)
			for k: int in range(1,poly.size()-1):
				var start: int = s.vertices.size()
				s.triangle(poly[0].p,poly[k].p,poly[k+1].p,Color.WHITE)
				if s.vertices.size()==start: continue
				var items: Array = [poly[0],poly[k],poly[k+1]]
				for j: int in 3: s.colors[start+j]=items[j].c; s.uv[start+j]=items[j].uv
	var mesh: ArrayMesh = preload("res://scripts/terrain_editor/stone_normals.gd").soften(s.mesh(),55,.65)
	mesh.surface_set_material(0,part.render_mesh.surface_get_material(0))
	return mesh

func prepare() -> void:
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_foot/checks/source_before/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "")
	assert(source.reload() == OK)
	var original: RefCounted = source.new()
	original.assets = editor.renderer.decoration.assets
	var field := preload("res://scripts/terrain_editor/contour_terrain.gd").new()
	field.refresh(editor.data)
	original._column_layout(field, editor.data.seed)
	for mass: Dictionary in editor.renderer.decoration._mass:
		if mass.get("is_interior", false): continue
		var old: Dictionary = {}
		for prior: Dictionary in original._mass:
			if prior.cell == mass.cell and prior.kind == mass.kind and not prior.get("is_interior", false): old = prior; break
		assert(not old.is_empty())
		var parent: Dictionary = {}
		for col: Dictionary in original._columns:
			if col.cell == old.cell and not col.is_step and col.pose.basis.z.normalized().dot(old.pose.basis.z.normalized()) > .97: parent = col; break
		assert(not parent.is_empty())
		var floor_y: float = INF
		for p: Vector3 in original.assets[parent.kind][0].faces: floor_y = minf(floor_y,(parent.pose*p).y)
		for instance: MultiMeshInstance3D in editor.renderer.find_children("*", "MultiMeshInstance3D", true, false):
			if String(instance.name) != mass.kind+"_0": continue
			for index: int in instance.multimesh.instance_count:
				if instance.multimesh.get_instance_transform(index).is_equal_approx(mass.pose):
					var slot: Dictionary = {"mm":instance.multimesh,"index":index,"rejected":mass.pose,"original":old.pose,"out":parent.outward,"part":original.assets[old.kind][0],"floor":floor_y+.25,"parent_pose":parent.pose}
					for main: MultiMeshInstance3D in editor.renderer.find_children("*", "MultiMeshInstance3D", true, false):
						if String(main.name) != parent.kind+"_0": continue
						for mi: int in main.multimesh.instance_count:
							if not main.multimesh.get_instance_transform(mi).is_equal_approx(parent.pose): continue
							slot.parent_mm=main.multimesh; slot.parent_index=mi
							var joined := MeshInstance3D.new()
							joined.mesh=continuous_mesh(original.assets[parent.kind][0],main.multimesh.get_instance_color(mi))
							joined.transform=parent.pose
							joined.visible=false
							editor.renderer.add_child(joined)
							slot.joined=joined
					var shaped := MultiMeshInstance3D.new()
					var mm := MultiMesh.new()
					mm.transform_format=MultiMesh.TRANSFORM_3D
					mm.use_colors=true
					mm.mesh=preload("res://art/lookdev/20261113_cliff_join/checks/join_probe.gd").build(slot.part.mesh,old.pose,original.assets[parent.kind][0].mesh,parent.pose)
					mm.instance_count=1
					mm.set_instance_transform(0,old.pose)
					mm.set_instance_color(0,instance.multimesh.get_instance_color(index))
					shaped.multimesh=mm
					shaped.visible=false
					editor.renderer.add_child(shaped)
					slot.layered=shaped
					slots.append(slot)
	assert(slots.size() == 6)
	prototype_ready = true

func apply_variant(name: String) -> void:
	for slot: Dictionary in slots:
		slot.layered.visible=name=="layered"
		slot.joined.visible=name=="continuous"
		slot.parent_mm.set_instance_transform(slot.parent_index,slot.parent_pose if name!="continuous" else Transform3D(Basis.from_scale(Vector3.ZERO),slot.parent_pose.origin))
		var pose: Transform3D = slot.original
		var part: Dictionary = slot.part
		if name == "rejected": pose = slot.rejected
		elif name in ["plain","continuous","layered"]: pose.basis = Basis.from_scale(Vector3.ZERO)
		elif name != "original":
			var crest_y: float = part.mesh.get_aabb().end.y
			var pivot: Vector3 = pose*Vector3(0,crest_y,0)
			pose.basis = pose.basis.rotated(pose.basis.x.normalized(), .15 if name == "long_tucked" else .23)
			pose.origin += pivot-pose*Vector3(0,crest_y,0)
			pose.origin -= slot.out*(.28 if name == "long_tucked" else .48)
			var fit: float = 1.0
			for p: Vector3 in part.faces:
				var at: Vector3 = pose*Vector3(p.x,crest_y,p.z)
				var drop: float = pose.basis.y.y*(crest_y-p.y)
				if drop > .00001: fit = minf(fit,maxf(0.0,(at.y-float(slot.floor))/drop))
			pose.origin += pose.basis.y*crest_y*(1-fit)
			pose.basis.y *= fit
		slot.mm.set_instance_transform(slot.index,pose)

func _capture(label: String, time_progress: float) -> void:
	if label != "game": return
	if not prototype_ready: prepare()
	for variant: String in ["original","rejected","layered"]:
		apply_variant(variant)
		_frame(Vector2(-2,-1),32,16,30)
		await super._capture(variant+"_whole",time_progress)
		_frame(Vector2(-8,6),13,16,24)
		await super._capture(variant+"_foot",time_progress)
		_frame(Vector2(-2,-1),32,196,30)
		await super._capture(variant+"_reverse",time_progress)
