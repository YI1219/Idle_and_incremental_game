extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/water_shore_field.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func impact(field: Dictionary, cell: Vector2i) -> float:
	var pixel := cell-Vector2i(field.origin)
	return field.texture.get_image().get_pixel(pixel.x,pixel.y).b
func _initialize() -> void:
	var data := Data.new()
	data.cells[Vector2i(0,0)] = {"height":3.0,"water":7}
	for x in range(1,9): data.cells[Vector2i(x,0)] = {"height":1.0,"water":3}
	var field := Field.build(data)
	check(impact(field,Vector2i(1,0))>.99,"lower receiver must be locally disturbed")
	check(impact(field,Vector2i(2,0))>impact(field,Vector2i(3,0)),"disturbance must fade along receiving water")
	check(impact(field,Vector2i(8,0))<.01,"distant lower lake stays calm")
	check(impact(field,Vector2i(0,0))<.01,"upper source lake stays calm")
	data.cells.erase(Vector2i(0,0))
	field = Field.build(data)
	check(impact(field,Vector2i(1,0))<.01,"regeneration removes effects after the source is deleted")
	data.cells[Vector2i(0,0)] = {"height":3.5,"water":-1}
	field = Field.build(data)
	check(impact(field,Vector2i(1,0))<.01,"dry cliffs must not create false waterfall impacts")
	data.cells[Vector2i(0,0)] = {"height":3.0,"water":7}
	data.cells[Vector2i(2,1)] = {"height":3.0,"water":7}
	data.cells[Vector2i(9,9)] = {"height":1.0,"water":3}
	field = Field.build(data)
	check(impact(field,Vector2i(2,1))<.01,"receiving turbulence cannot propagate back into an adjacent upper level")
	check(impact(field,Vector2i(9,9))<.01,"disconnected water at the same level stays calm")
	print("WATER IMPACT: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
