extends Node3D
## Soft stylized cloud sea under the grotto islands. No distant mountains.

const SEA_Y := -6.15
const SPAN := 80.0
const RES := 48

var _sea: MeshInstance3D
var _wisps: MeshInstance3D


func _ready() -> void:
	name = "CloudSea"
	add_to_group("cloud_sea")
	_sea = MeshInstance3D.new()
	_sea.name = "SeaSheet"
	_sea.mesh = _billow_mesh(SPAN, RES, 1.55, Color("f7f9fb"), Color("e6eef3"))
	_sea.position.y = SEA_Y
	_sea.material_override = _sheet_mat()
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	_wisps = MeshInstance3D.new()
	_wisps.name = "WispSheet"
	_wisps.mesh = _billow_mesh(SPAN * 0.48, 28, 0.85, Color("ffffff"), Color("f0f4f8"))
	_wisps.position.y = SEA_Y + 1.55
	_wisps.material_override = _sheet_mat()
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wisps)
	_add_puffs()


func follow_islands(_bounds: Array) -> void:
	pass


func _sheet_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/cloud_sea.gdshader")
	return mat


func _puff_mat(alpha: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/world/cloud_puff.gdshader")
	mat.set_shader_parameter("tint", Color(0.97, 0.98, 0.99, alpha))
	return mat


func _add_puffs() -> void:
	var spots := [
		Vector3(-9.4, -3.15, 7.6), Vector3(10.2, -3.25, 6.8), Vector3(8.6, -3.40, -7.8),
		Vector3(-10.6, -3.20, -6.4), Vector3(1.6, -3.55, 9.4), Vector3(-2.8, -3.60, -9.2),
		Vector3(11.8, -3.45, 0.6), Vector3(-12.2, -3.35, 1.8),
		Vector3(-3.8, -4.55, 2.2), Vector3(3.4, -4.65, -2.0),
		Vector3(6.2, -4.10, 3.4), Vector3(-5.8, -4.20, -3.2),
		Vector3(0.4, -5.15, 4.8), Vector3(4.2, -5.05, -4.6),
		Vector3(-7.2, -2.85, 3.0), Vector3(7.8, -2.90, -2.4),
		Vector3(-1.2, -2.70, 8.2), Vector3(2.4, -2.75, -8.6),
	]
	for i in spots.size():
		var centre: Vector3 = spots[i]
		for k in 4:
			var puff := MeshInstance3D.new()
			puff.name = "Puff_%d_%d" % [i, k]
			var sphere := SphereMesh.new()
			sphere.radius = 1.65 + float((i + k) % 3) * 0.42 + float(k) * 0.22
			sphere.height = sphere.radius * 1.35
			sphere.radial_segments = 16
			sphere.rings = 9
			puff.mesh = sphere
			var jitter := Vector3(float(k - 1) * 0.85, float(k) * 0.18 - 0.08, float((i + k) % 3) * 0.55 - 0.40)
			puff.position = centre + jitter
			puff.material_override = _puff_mat(0.72 if k == 0 else 0.48)
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
