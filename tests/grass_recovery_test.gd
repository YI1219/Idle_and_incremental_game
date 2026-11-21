extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var recovery: RefCounted = load("res://scripts/terrain_editor/grass_recovery.gd").new()
	var cells: Dictionary = {}
	for z: int in range(-1,2):
		for x: int in range(6):
			cells[Vector2i(x,z)] = {"height":1.5,"water":-1,"water_volume":0.0}
	var before: Dictionary = cells.duplicate(true)
	recovery.sync(cells, {})
	check(recovery.coverage[Vector2i(3,0)] == 1.0, "initial dry grass is fully grown")
	var depths: Dictionary = {}
	for c: Vector2i in cells:
		if c.x > 0:
			depths[c] = .2
	recovery.sync(cells, depths)
	check(recovery.coverage[Vector2i(3,0)] == 1.0, "arriving water starts from the currently visible grass")
	recovery.advance(.3)
	check(recovery.coverage[Vector2i(3,0)] > .1 and recovery.coverage[Vector2i(3,0)] < .9, "submerged grass fades through intermediate coverage")
	recovery.advance(.5)
	check(recovery.coverage[Vector2i(3,0)] == 0.0, "submerged grass finishes disappearing")
	check(recovery.coverage[Vector2i(0,0)] == 1.0, "surrounding dry grass stays present")
	recovery.sync(cells,{})
	check(recovery.coverage[Vector2i(3,0)] == 0.0, "recession does not instantly restore the entire lawn")
	recovery.advance(.5)
	check(recovery.coverage[Vector2i(1,0)] > recovery.coverage[Vector2i(4,0)], "regrowth advances from adjacent surviving lawn")
	recovery.advance(5.0)
	check(recovery.coverage[Vector2i(4,0)] > .95, "the dry interior eventually recovers")
	recovery.sync(cells,depths)
	var current: float = recovery.coverage[Vector2i(1,0)]
	recovery.advance(.1)
	check(recovery.coverage[Vector2i(1,0)] < current and recovery.coverage[Vector2i(1,0)] > 0, "reflooding smoothly interrupts recovery")
	check(cells == before, "visual recovery never edits physical water or terrain")
	recovery.clear()
	var terraces: Dictionary = {Vector2i.ZERO:{"height":0.0},Vector2i.LEFT:{"height":3.5}}
	recovery.sync(terraces,{Vector2i.ZERO:.2})
	recovery.sync(terraces,{})
	recovery.advance(.4)
	check(recovery.coverage[Vector2i.ZERO] > .1,"seeds from the surrounding upper lawn can reach a dry sunken patch")
	print("GRASS RECOVERY ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
