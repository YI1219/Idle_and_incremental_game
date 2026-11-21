class_name GrassCompressionMap
extends RefCounted
## Lightweight world-space grass compression mask driving TerrainRenderer.set_grass_compression().

const GRID_WIDTH: int = 144
const GRID_HEIGHT: int = 120
const WORLD_RECT := Rect2(-36.0, -30.0, 72.0, 60.0)
const UPLOAD_INTERVAL: float = 0.065
const DECAY_PER_SEC: float = 0.14

var image: Image
var texture: ImageTexture
var _values: PackedFloat32Array = PackedFloat32Array()
var _dirty: bool = false
var _upload_timer: float = 0.0
var _active_pixels: bool = false

func _init() -> void:
	_values.resize(GRID_WIDTH * GRID_HEIGHT)
	_values.fill(0.0)
	image = Image.create(GRID_WIDTH, GRID_HEIGHT, false, Image.FORMAT_RF)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	texture = ImageTexture.create_from_image(image)

func bind_to_renderer(renderer: Node3D) -> void:
	if renderer != null and renderer.has_method("set_grass_compression"):
		renderer.call("set_grass_compression", texture, WORLD_RECT)

func sample_at(world_xz: Vector2) -> float:
	var uv: Vector2 = (world_xz - WORLD_RECT.position) / WORLD_RECT.size
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return 0.0
	var gx: float = clampf(uv.x * float(GRID_WIDTH) - 0.5, 0.0, float(GRID_WIDTH - 1))
	var gy: float = clampf(uv.y * float(GRID_HEIGHT) - 0.5, 0.0, float(GRID_HEIGHT - 1))
	var x0: int = floori(gx)
	var y0: int = floori(gy)
	var x1: int = mini(x0 + 1, GRID_WIDTH - 1)
	var y1: int = mini(y0 + 1, GRID_HEIGHT - 1)
	var fx: float = gx - float(x0)
	var fy: float = gy - float(y0)
	var v00: float = _values[y0 * GRID_WIDTH + x0]
	var v10: float = _values[y0 * GRID_WIDTH + x1]
	var v01: float = _values[y1 * GRID_WIDTH + x0]
	var v11: float = _values[y1 * GRID_WIDTH + x1]
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fy)

func stamp_circle(world_xz: Vector2, radius: float, max_strength: float) -> void:
	if radius <= 0.05 or max_strength <= 0.001:
		return
	var cell_w: float = WORLD_RECT.size.x / float(GRID_WIDTH)
	var cell_h: float = WORLD_RECT.size.y / float(GRID_HEIGHT)
	var min_x: int = clampi(floori((world_xz.x - radius - WORLD_RECT.position.x) / cell_w), 0, GRID_WIDTH - 1)
	var max_x: int = clampi(ceili((world_xz.x + radius - WORLD_RECT.position.x) / cell_w), 0, GRID_WIDTH - 1)
	var min_y: int = clampi(floori((world_xz.y - radius - WORLD_RECT.position.y) / cell_h), 0, GRID_HEIGHT - 1)
	var max_y: int = clampi(ceili((world_xz.y + radius - WORLD_RECT.position.y) / cell_h), 0, GRID_HEIGHT - 1)
	for py: int in range(min_y, max_y + 1):
		var wy: float = WORLD_RECT.position.y + (float(py) + 0.5) * cell_h
		for px: int in range(min_x, max_x + 1):
			var wx: float = WORLD_RECT.position.x + (float(px) + 0.5) * cell_w
			var dist: float = world_xz.distance_to(Vector2(wx, wy))
			if dist > radius:
				continue
			var falloff: float = 1.0 - smoothstep(0.0, radius, dist)
			var target: float = max_strength * falloff
			var idx: int = py * GRID_WIDTH + px
			if target > _values[idx] + 0.005:
				_values[idx] = target
				image.set_pixel(px, py, Color(target, 0.0, 0.0, 1.0))
				_dirty = true
				_active_pixels = true

func tick(delta: float) -> void:
	if delta <= 0.0 or not _active_pixels:
		return
	var decay: float = DECAY_PER_SEC * delta
	var still_active: bool = false
	for idx: int in _values.size():
		var v: float = _values[idx]
		if v <= 0.001:
			continue
		var nv: float = maxf(0.0, v - decay)
		_values[idx] = nv
		var px: int = idx % GRID_WIDTH
		var py: int = idx / GRID_WIDTH
		image.set_pixel(px, py, Color(nv, 0.0, 0.0, 1.0))
		_dirty = true
		if nv > 0.001:
			still_active = true
	_active_pixels = still_active
	_upload_timer += delta
	if _dirty and (_upload_timer >= UPLOAD_INTERVAL or not _active_pixels):
		_upload_timer = 0.0
		_dirty = false
		texture.update(image)

func flush_now() -> void:
	if _dirty:
		_dirty = false
		_upload_timer = 0.0
		texture.update(image)
