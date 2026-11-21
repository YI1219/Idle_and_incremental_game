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
var _last_frame_limit: int = -1
var _recovery_seconds: float = 0.0
var _ssao_settings: Dictionary = {}
var _ssil_settings: Dictionary = {}
var _native_dof_quality: int = 1
var _native_dof_jitter: bool = false

func configure(target: Viewport) -> void:
	viewport = target
	_native_msaa = target.msaa_3d
	for key: String in ["quality", "half_size", "adaptive_target", "blur_passes", "fadeout_from", "fadeout_to"]:
		_ssao_settings[key] = ProjectSettings.get_setting("rendering/environment/ssao/" + key)
		_ssil_settings[key] = ProjectSettings.get_setting("rendering/environment/ssil/" + key)
	_native_dof_quality = ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_bokeh_quality")
	_native_dof_jitter = ProjectSettings.get_setting("rendering/camera/depth_of_field/depth_of_field_use_jitter")
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
	_recovery_seconds = 0.0
	_scale = 1.0 if native else _budget_scale(BUDGET)
	_apply()

func advance(delta: float, frame_limit: int = 0) -> void:
	refresh()
	if frame_limit != _last_frame_limit:
		_last_frame_limit = frame_limit
		_sample_seconds = 0.0
		_sample_count = 0
		_recovery_seconds = 0.0
	if frame_limit > 0 and frame_limit <= 5:
		return
	if native or _budget_scale(BUDGET) >= .999 or delta < .004 or delta > .25:
		return
	_sample_seconds += delta
	_sample_count += 1
	if _sample_seconds < SAMPLE_SECONDS:
		return
	var elapsed: float = _sample_seconds
	var mean: float = elapsed / _sample_count
	_sample_seconds = 0.0
	_sample_count = 0
	var next: float = _scale
	# Frame pacing sleep is intentional work reduction, not GPU overload.
	var slow_fps: float = minf(55.0, float(frame_limit) * .9) if frame_limit > 0 else 55.0
	var fast_fps: float = minf(72.0, float(frame_limit) * 1.2) if frame_limit > 0 else 72.0
	if mean > 1.0 / slow_fps:
		_recovery_seconds = 0.0
		next = maxf(_budget_scale(MINIMUM_BUDGET), _scale*.9)
	elif mean < 1.0 / fast_fps:
		_recovery_seconds = 0.0
		next = minf(_budget_scale(BUDGET), _scale*1.04)
	elif frame_limit > 0 and mean <= 1.04 / float(frame_limit):
		# A limiter masks spare GPU time. Probe upward slowly instead of
		# requiring an impossible above-cap FPS to regain lost resolution.
		_recovery_seconds += elapsed
		if _recovery_seconds >= 5.0:
			_recovery_seconds = 0.0
			next = minf(_budget_scale(BUDGET), _scale*1.04)
	else:
		_recovery_seconds = 0.0
	if absf(next - _scale) > .001:
		_scale = next
		_apply()

func _apply() -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if _scale < .999 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = maxf(.1,_scale)
	viewport.msaa_3d = _native_msaa if native else mini(_native_msaa,Viewport.MSAA_2X)
	# Preserve the high-quality reference as an explicit reversible option.
	RenderingServer.directional_shadow_atlas_set_size(8192 if native else 4096, true)

	RenderingServer.environment_set_ssao_quality(int(_ssao_settings.quality), bool(_ssao_settings.half_size) if native else true,
		float(_ssao_settings.adaptive_target), int(_ssao_settings.blur_passes), float(_ssao_settings.fadeout_from), float(_ssao_settings.fadeout_to))
	# Indirect light is gathered at half size and blurred four times. Its cheapest
	# gather stays within 6/255 of the project default at 1080p, 2K and 4K, so
	# only the explicit native reference pays for the denser one.
	RenderingServer.environment_set_ssil_quality(int(_ssil_settings.quality) if native else RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, bool(_ssil_settings.half_size),
		float(_ssil_settings.adaptive_target), int(_ssil_settings.blur_passes), float(_ssil_settings.fadeout_from), float(_ssil_settings.fadeout_to))
	RenderingServer.camera_attributes_set_dof_blur_quality(_native_dof_quality if native else RenderingServer.DOF_BLUR_QUALITY_VERY_LOW, _native_dof_jitter)
	# Cliff micro-relief: mean change under 0.13/255 in stills, so only the native
	# reference pays its four noises and six taps per stone fragment.
	RenderingServer.global_shader_parameter_set("stone_fine_relief", 1.0 if native else 0.0)
