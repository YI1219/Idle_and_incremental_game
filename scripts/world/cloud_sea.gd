extends Node3D
## Soft stylized cloud sea under the grotto islands. No distant mountains.
## Built as an opaque vertex-colored mesh so billows still read on software render.

const SEA_Y := -3.55
const SPAN := 72.0
const RES := 48

var _sea: MeshInstance3D
var _wisps: MeshInstance3D


func _ready() -> void:
	name = "CloudSea"
	add_to_group("cloud_sea")
	_sea = MeshInstance3D.new()
	_sea.name = "SeaSheet"
	_sea.mesh = _billow_mesh(SPAN, RES, 2.8, Color("fff8ec"), Color("6a7b86"))
	_sea.position.y = SEA_Y
	_sea.material_override = _solid_vertex()
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	_wisps = MeshInstance3D.new()
	_wisps.name = "WispSheet"
	_wisps.mesh = _billow_mesh(SPAN * 0.55, 28, 1.35, Color("fffdf6"), Color("8b9aa3"))
	_wisps.position.y = SEA_Y + 1.15
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
		Vector3(-7.5, -2.15, 6.5), Vector3(8.2, -2.35, 5.8), Vector3(6.4, -2.55, -7.2),
		Vector3(-8.8, -2.45, -5.4), Vector3(1.2, -3.05, 8.6), Vector3(-2.4, -3.2, -8.0),
		Vector3(10.5, -2.7, 0.6), Vector3(-11.0, -2.6, 1.8), Vector3(0.4, -3.6, 0.2),
	]
	for i in spots.size():
		var puff := MeshInstance3D.new()
		puff.name = "Puff_%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 2.1 + float(i % 3) * 0.45
		sphere.height = 1.35 + float(i % 4) * 0.22
		sphere.radial_segments = 10
		sphere.rings = 6
		puff.mesh = sphere
		puff.position = spots[i]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("fff6e4") if i % 2 == 0 else Color("c5d0d4")
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
