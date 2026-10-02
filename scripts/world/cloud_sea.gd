extends Node3D
## Soft stylized cloud sea under the grotto islands. No distant mountains.
## Built as an opaque vertex-colored mesh so billows still read on software render.

const SEA_Y := -4.85
const SPAN := 80.0
const RES := 48

var _sea: MeshInstance3D
var _wisps: MeshInstance3D


func _ready() -> void:
	name = "CloudSea"
	add_to_group("cloud_sea")
	_sea = MeshInstance3D.new()
	_sea.name = "SeaSheet"
	_sea.mesh = _billow_mesh(SPAN, RES, 2.15, Color("fffaf0"), Color("4e5d68"))
	_sea.position.y = SEA_Y
	_sea.material_override = _solid_vertex()
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	_wisps = MeshInstance3D.new()
	_wisps.name = "WispSheet"
	_wisps.mesh = _billow_mesh(SPAN * 0.48, 28, 1.15, Color("ffffff"), Color("6d7c86"))
	_wisps.position.y = SEA_Y + 1.55
	_wisps.material_override = _solid_vertex()
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wisps)
	_add_puffs()


func follow_islands(_bounds: Array) -> void:
	pass


func _solid_vertex() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _add_puffs() -> void:
	var spots := [
		Vector3(-10.2, -2.55, 8.4), Vector3(11.0, -2.65, 7.6), Vector3(9.2, -2.70, -8.8),
		Vector3(-11.4, -2.60, -7.2), Vector3(2.0, -2.85, 10.6), Vector3(-3.2, -2.90, -10.2),
		Vector3(12.8, -2.75, 1.0), Vector3(-13.4, -2.70, 2.2),
		Vector3(-2.4, -4.25, 1.6), Vector3(2.6, -4.30, -1.4),
	]
	for i in spots.size():
		var puff := MeshInstance3D.new()
		puff.name = "Puff_%d" % i
		var sphere := SphereMesh.new()
		var under := i >= 8
		sphere.radius = (1.25 if under else 1.75) + float(i % 3) * 0.18
		sphere.height = sphere.radius * (1.35 if under else 1.20)
		sphere.radial_segments = 10
		sphere.rings = 6
		puff.mesh = sphere
		puff.position = spots[i]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("fffdf4") if i % 2 == 0 else Color("8f9ea8")
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)


func _billow_mesh(size: float, res: int, height: float, hi: Color, lo: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := size / float(res)
	var origin := -size * 0.5
	for z in res:
		for x in res:
			var p00 := _billow_vertex(origin, step, x, z, height, hi, lo)
			var p10 := _billow_vertex(origin, step, x + 1, z, height, hi, lo)
			var p01 := _billow_vertex(origin, step, x, z + 1, height, hi, lo)
			var p11 := _billow_vertex(origin, step, x + 1, z + 1, height, hi, lo)
			_billow_tri(st, p00, p10, p11)
			_billow_tri(st, p00, p11, p01)
	st.generate_normals()
	return st.commit()


func _billow_vertex(origin: float, step: float, x: int, z: int, height: float, hi: Color, lo: Color) -> Dictionary:
	var px := origin + float(x) * step
	var pz := origin + float(z) * step
	var n := _fbm(Vector2(px, pz) * 0.055)
	var n2 := _fbm(Vector2(px, pz) * 0.12 + Vector2(8.2, 3.1))
	var h := (n * 0.72 + n2 * 0.28 - 0.22) * height
	var color := lo.lerp(hi, clampf(n * 0.55 + n2 * 0.45, 0.0, 1.0))
	return {"p": Vector3(px, h, pz), "c": color}


func _billow_tri(st: SurfaceTool, a: Dictionary, b: Dictionary, c: Dictionary) -> void:
	for item in [a, b, c]:
		st.set_color(item["c"])
		st.set_normal(Vector3.UP)
		st.add_vertex(item["p"])


func _fbm(p: Vector2) -> float:
	var v := 0.0
	var a := 0.5
	var q := p
	for _i in 5:
		v += a * _noise(q)
		q = Vector2(q.x * 2.03 + 11.2, q.y * 2.03 + 3.7)
		a *= 0.52
	return v


func _noise(p: Vector2) -> float:
	var i := Vector2(floorf(p.x), floorf(p.y))
	var f := Vector2(p.x - i.x, p.y - i.y)
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash2(i)
	var b := _hash2(i + Vector2(1, 0))
	var c := _hash2(i + Vector2(0, 1))
	var d := _hash2(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


func _hash2(p: Vector2) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7) * 43758.5453, 1.0)
