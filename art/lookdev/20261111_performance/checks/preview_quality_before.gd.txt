extends RefCounted
## Keep UI native while adapting high-resolution interactive 3D pixel work.
const BUDGET := Vector2(2560,1440)
const MINIMUM_BUDGET := Vector2(1920,1080)
const SAMPLE_SECONDS: float = .75
var native: bool = false
var viewport: Viewport
var _native_msaa: int = Viewport.MSAA_DISABLED
var _last_size := Vector2i.ZERO
var _last_native: bool = true
var _scale: float = 1.0
var _sample_seconds: float = 0.0
var _sample_count: int = 0

func configure(target: Viewport) -> void:
	viewport = target
	_native_msaa = target.msaa_3d
	refresh()

func set_native(value: bool) -> void:
	native = value
	refresh()

func _budget_scale(budget: Vector2) -> float:
	return minf(1.0, minf(budget.x / maxf(_last_size.x,1), budget.y / maxf(_last_size.y,1)))

func refresh() -> void:
	if not is_instance_valid(viewport):
		return
	var size: Vector2i
	if viewport is SubViewport:
		size = (viewport as SubViewport).size
	else:
		size = Vector2i(viewport.get_texture().get_size())
		if viewport is Window:
			var window_size: Vector2i = (viewport as Window).size
			size = size.max(window_size)
	if size == _last_size and native == _last_native:
		return
	_last_size = size
	_last_native = native
	_sample_seconds = 0.0
	_sample_count = 0
	_scale = 1.0 if native else _budget_scale(BUDGET)
	_apply()

func advance(delta: float) -> void:
	refresh()
	if native or _budget_scale(BUDGET) >= .999 or delta < .004 or delta > .25:
		return
	_sample_seconds += delta
	_sample_count += 1
	if _sample_seconds < SAMPLE_SECONDS:
		return
	var mean: float = _sample_seconds / _sample_count
	_sample_seconds = 0.0
	_sample_count = 0
	var next: float = _scale
	if mean > 1.0/55.0:
		next = maxf(_budget_scale(MINIMUM_BUDGET), _scale*.9)
	elif mean < 1.0/72.0:
		next = minf(_budget_scale(BUDGET), _scale*1.04)
	if absf(next - _scale) > .001:
		_scale = next
		_apply()

func _apply() -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if _scale < .999 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = maxf(.1,_scale)
	viewport.msaa_3d = mini(_native_msaa,Viewport.MSAA_2X) if _scale < .999 else _native_msaa
