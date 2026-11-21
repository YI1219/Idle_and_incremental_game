extends RefCounted
## Visual grass coverage, separate from conserved physical water.
const FADE_SECONDS: float = .65
const GROW_SECONDS: float = .85
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var coverage: Dictionary = {}
var _wet: Dictionary = {}
var _heights: Dictionary = {}
var _water_heights: Dictionary = {}
var _dry_age: Dictionary = {}
var _changing: Dictionary = {}
var _fringe_owners: Dictionary = {}
var rect := Rect2(Vector2.ZERO, Vector2.ONE)
var image: Image
var texture: ImageTexture

func clear() -> void:
	coverage.clear()
	_wet.clear()
	_heights.clear()
	_dry_age.clear()
	_changing.clear()
	image = null
	_fringe_owners.clear()

func sync(cells: Dictionary, depths: Dictionary, water_heights: Dictionary = {}) -> void:
	var next: Dictionary = {}
	var rebuild_layout: bool = image == null or cells.size() != _heights.size()
	if not rebuild_layout:
		for cell: Vector2i in cells:
			if not _heights.has(cell) or _heights[cell] != float(cells[cell].height):
				rebuild_layout = true
				break
	_wet.clear()
	_heights.clear()
	_water_heights = water_heights.duplicate()
	_changing.clear()
	var low := Vector2i.ZERO
	var high := Vector2i.ZERO
	if not cells.is_empty():
		low = cells.keys()[0]
		high = low
	for cell: Vector2i in cells:
		low = low.min(cell)
		high = high.max(cell)
		var wet: bool = float(depths.get(cell, 0.0)) > .0005
		_wet[cell] = wet
		_heights[cell] = float(cells[cell].height)
		next[cell] = coverage.get(cell, 0.0 if wet else 1.0)
		if wet:
			_dry_age[cell] = 0.0
		if (wet and next[cell] > 0.0) or (not wet and next[cell] < 1.0):
			_changing[cell] = true
	coverage = next
	for cell: Vector2i in _dry_age.keys():
		if not coverage.has(cell):
			_dry_age.erase(cell)
	rect = Rect2(Vector2(low - Vector2i.ONE), Vector2(high - low + Vector2i(3,3)))
	_write_image(rebuild_layout)

func advance(delta: float) -> bool:
	if _changing.is_empty() or delta <= 0.0 or not is_finite(delta):
		return false
	# Fixed small steps make the spreading front independent of frame rate.
	var any_changed := false
	var remaining: float = minf(delta, 5.0)
	while remaining > .000001:
		var step: float = minf(remaining, 1.0/30.0)
		var next: Dictionary = {}
		for cell: Vector2i in _changing:
			var value: float = coverage[cell]
			if _wet[cell]:
				next[cell] = maxf(0.0, value - step/FADE_SECONDS)
				continue
			_dry_age[cell] = float(_dry_age.get(cell, 0.0)) + step
			var neighbour: float = 0.0
			var boundary := false
			for side: Vector2i in SIDES:
				var adjacent: Vector2i = cell + side
				if not coverage.has(adjacent):
					boundary = true
				elif not bool(_wet[adjacent]):
					neighbour = maxf(neighbour, float(coverage[adjacent]))
			# A completely submerged island can reseed along its exposed outer
			# shore after a pause. Interior cells still grow in from neighbours.
			if boundary and float(_dry_age[cell]) > 3.0:
				neighbour = 1.0
			var growth: float = smoothstep(.25, .9, neighbour)
			next[cell] = minf(1.0, value + step*growth/GROW_SECONDS)
		for cell: Vector2i in next:
			any_changed = any_changed or not is_equal_approx(float(coverage[cell]),float(next[cell]))
			coverage[cell] = next[cell]
			if (_wet[cell] and next[cell] <= 0.0) or (not _wet[cell] and next[cell] >= 1.0):
				_changing.erase(cell)
		remaining -= step
	if any_changed:
		_write_image()
	return any_changed

func _write_image(rebuild: bool = false) -> void:
	var size := Vector2i(rect.size)
	if rebuild:
		image = Image.create(size.x,size.y,false,Image.FORMAT_RGBAF)
		image.fill(Color(1.0,0.0,0.0,0.0))
		_fringe_owners.clear()
		# Rim roots overhang their authoritative cell. Reuse the highest
		# adjacent crown for the one-cell border around land and holes.
		for cell: Vector2i in coverage:
			for dz: int in range(-1,2):
				for dx: int in range(-1,2):
					var adjacent := cell + Vector2i(dx,dz)
					if coverage.has(adjacent):
						continue
					if not _fringe_owners.has(adjacent) or float(_heights[cell]) > float(_heights[_fringe_owners[adjacent]]):
						_fringe_owners[adjacent] = cell
	for cell: Vector2i in coverage:
		image.set_pixelv(cell-Vector2i(rect.position),Color(coverage[cell],_heights[cell],_water_heights.get(cell,_heights[cell]),1.0))
	for cell: Vector2i in _fringe_owners:
		var owner: Vector2i = _fringe_owners[cell]
		image.set_pixelv(cell-Vector2i(rect.position),Color(coverage[owner],_heights[owner],_water_heights.get(owner,_heights[owner]),1.0))
	if texture != null and Vector2i(texture.get_size()) == size:
		texture.update(image)
	else:
		texture = ImageTexture.create_from_image(image)
