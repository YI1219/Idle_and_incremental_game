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
	_sea.mesh = _billow_mesh(SPAN, RES, 2.15, Color("f4f7fa"), Color("d5dee6"))
	_sea.position.y = SEA_Y
	_sea.material_override = _sheet_mat()
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	_wisps = MeshInstance3D.new()
	_wisps.name = "WispSheet"
	_wisps.mesh = _billow_mesh(SPAN * 0.42, 28, 1.05, Color("ffffff"), Color("e8eef3"))
	_wisps.position.y = SEA_Y + 1.35
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
	mat.set_shader_parameter("tint", Color(0.95, 0.97, 0.98, alpha))
	return mat


func _add_puffs() -> void:
	var spots := [
		Vector3(-10.2, -4.15, 8.4), Vector3(11.0, -4.25, 7.6), Vector3(9.2, -4.30, -8.8),
		Vector3(-11.4, -4.20, -7.2), Vector3(2.0, -4.45, 10.6), Vector3(-3.2, -4.50, -10.2),
		Vector3(12.8, -4.35, 1.0), Vector3(-13.4, -4.30, 2.2),
		Vector3(-2.4, -5.55, 1.6), Vector3(2.6, -5.60, -1.4),
		Vector3(4.8, -5.20, 2.2), Vector3(5.6, -5.35, 1.0), Vector3(-0.4, -5.25, 0.6),
		Vector3(5.2, -5.00, 2.5), Vector3(5.8, -5.10, 2.0),
	]
	for i in spots.size():
		var centre: Vector3 = spots[i]
		for k in 3:
			var puff := MeshInstance3D.new()
			puff.name = "Puff_%d_%d" % [i, k]
			var sphere := SphereMesh.new()
			sphere.radius = 0.85 + float((i + k) % 3) * 0.22 + float(k) * 0.12
			sphere.height = sphere.radius * 1.55
			sphere.radial_segments = 14
			sphere.rings = 8
			puff.mesh = sphere
			var jitter := Vector3(float(k - 1) * 0.45, float(k) * 0.12, float((i + k) % 2) * 0.35 - 0.18)
			puff.position = centre + jitter
			puff.material_override = _puff_mat(0.42 if k == 0 else 0.28)
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
