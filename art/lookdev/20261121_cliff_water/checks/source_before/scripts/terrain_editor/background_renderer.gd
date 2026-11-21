extends Node3D
## Render only distant unlit scenery at half internal resolution. The courtyard,
## waist clouds, primary sky radiance and final postprocessing stay in the main pass.
const BACKGROUND_LAYER: int = 1 << 19
const ENABLE_PIXELS: int = 2700000
const DISABLE_PIXELS: int = 2300000
const FOG_PROPERTIES: Array[StringName] = [&"fog_enabled", &"fog_light_color", &"fog_light_energy", &"fog_sun_scatter", &"fog_density", &"fog_aerial_perspective", &"fog_sky_affect", &"fog_height", &"fog_height_density"]
var enabled: bool = true
var view: SubViewport
var camera: Camera3D
var _editor: Node3D
var _environment: Environment
var _original_environment: Environment
var _original_sky: Sky
var _original_material: ShaderMaterial
var _adapter: ShaderMaterial
var _background_material: ShaderMaterial
var _uniforms: Array[StringName] = []
var _values: Dictionary = {}
var _layers: Dictionary = {}
var _camera_mask: int = 0
var _active: bool = false
var _suspended: bool = false
var _pixel_budget: bool = false
var _supported: bool = false
var _ready_image: bool = false
var _warm_callback: Callable
var _bounds_dirty: bool = true
var _bounds: AABB
var _has_bounds: bool = false
var _clear_radius: float = INF
var _far_cloud_height: float = -INF
var _near_cloud_radius: float = 0.0

func configure(owner_editor: Node3D) -> void:
 _editor = owner_editor
 process_priority = 100 # after editor lighting and camera movement
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
  return
 _original_environment = _editor.get_node("WorldEnvironment").environment
 _original_sky = _original_environment.sky
 if _original_sky == null or not _original_sky.sky_material is ShaderMaterial:
  return
 _original_material = _original_sky.sky_material
 if _original_material.shader == null or _original_material.shader.resource_path != "res://shaders/terrain_editor/sky.gdshader":
  return
 _camera_mask = _editor.camera.cull_mask
 for entry: Dictionary in _original_material.shader.get_shader_uniform_list():
  _uniforms.append(StringName(entry.name))
 for node: Node in _editor.landscape.get_children():
  if node is MultiMeshInstance3D:
   _layers[node] = node.layers
   var mesh_box: AABB = node.multimesh.mesh.get_aabb()
   for i: int in node.multimesh.instance_count:
    var pose: Transform3D = node.transform * node.multimesh.get_instance_transform(i)
    _clear_radius = minf(_clear_radius, _horizontal_clearance(pose, mesh_box))
  elif node is MeshInstance3D:
   if node.position.y <= -28.0:
    _layers[node] = node.layers
    _far_cloud_height = maxf(_far_cloud_height, node.position.y)
   elif node.material_override is ShaderMaterial:
    var fade: Variant = node.material_override.get_shader_parameter("fade_radius")
    if fade != null: _near_cloud_radius = maxf(_near_cloud_radius, float(fade))
 _supported = not _layers.is_empty() and is_finite(_clear_radius) and _near_cloud_radius < _clear_radius
 _editor.renderer.terrain_published.connect(_invalidate_bounds)
 sync()

func _horizontal_clearance(pose: Transform3D, box: AABB) -> float:
 # These mountain instances rotate around Y only. Preserve the oriented
 # rectangle: an enclosing world AABB reaches much closer to the courtyard.
 if absf(pose.basis.y.x) > .00001 or absf(pose.basis.y.z) > .00001: return 0.0
 var polygon := PackedVector2Array()
 for corner: Vector3 in [box.position, Vector3(box.end.x, box.position.y, box.position.z), Vector3(box.end.x, box.position.y, box.end.z), Vector3(box.position.x, box.position.y, box.end.z)]:
  var point: Vector3 = pose * corner
  polygon.append(Vector2(point.x, point.z))
 if Geometry2D.is_point_in_polygon(Vector2.ZERO, polygon): return 0.0
 var distance: float = INF
 for i: int in 4:
  distance = minf(distance, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, polygon[i], polygon[(i + 1) % 4]).length())
 return distance

func _invalidate_bounds() -> void:
 _bounds_dirty = true

func _safe_ordering() -> bool:
 if _bounds_dirty:
  _has_bounds = false
  for box: AABB in _editor.renderer._pick_bounds.values():
   _bounds = _bounds.merge(box) if _has_bounds else box
   _has_bounds = true
  _bounds_dirty = false
 var center: Vector2 = Vector2(_editor.landscape.position.x, _editor.landscape.position.z)
 var eye: Vector3 = _editor.to_local(_editor.camera.global_position)
 if eye.y <= _far_cloud_height or Vector2(eye.x, eye.z).distance_to(center) >= _clear_radius:
  return false
 if not _has_bounds: return true
 if _bounds.position.y <= _far_cloud_height: return false
 # A conservative courtyard cylinder remains inside every distant mountain's
 # bounding box. Nearby props/branches receive 16m extra horizontal margin.
 var low: Vector2 = Vector2(_bounds.position.x, _bounds.position.z) - Vector2.ONE * 16.0
 var high: Vector2 = Vector2(_bounds.end.x, _bounds.end.z) + Vector2.ONE * 16.0
 for point: Vector2 in [low, high, Vector2(low.x, high.y), Vector2(high.x, low.y)]:
  if point.distance_to(center) >= _clear_radius: return false
 return true

func _ensure_resources() -> void:
 if view != null: return
 _environment = _original_environment.duplicate(false)
 var sky := Sky.new()
 _background_material = _original_material.duplicate(false)
 sky.sky_material = _background_material
 sky.radiance_size = Sky.RADIANCE_SIZE_32
 sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
 _environment.sky = sky
 _environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 _environment.tonemap_exposure = 1.0
 _environment.adjustment_enabled = false
 _environment.glow_enabled = false
 _environment.ssao_enabled = false
 _environment.ssil_enabled = false
 _environment.ssr_enabled = false
 _environment.sdfgi_enabled = false
 _environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 _environment.ambient_light_energy = 0.0
 _environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 view = SubViewport.new()
 view.name = "DistantBackground"
 view.world_3d = _editor.get_viewport().find_world_3d()
 view.use_hdr_2d = true
 view.msaa_3d = Viewport.MSAA_DISABLED
 view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(view)
 camera = Camera3D.new()
 camera.environment = _environment
 camera.cull_mask = BACKGROUND_LAYER
 camera.attributes = CameraAttributesPractical.new()
 view.add_child(camera)
 camera.make_current()
 _adapter = _original_material.duplicate(false)
 _adapter.shader = preload("res://shaders/terrain_editor/background_sky.gdshader")
 _adapter.set_shader_parameter("background_color", view.get_texture())
 _copy_parameters(_original_material, _adapter)

func _copy_parameters(source: ShaderMaterial, target: ShaderMaterial) -> void:
 for key: StringName in _uniforms:
  target.set_shader_parameter(key, source.get_shader_parameter(key))

func _set_active(value: bool) -> void:
 if value == _active: return
 if value:
  _copy_parameters(_original_material, _adapter)
  _original_sky.sky_material = _adapter
  _editor.camera.cull_mask = _camera_mask & ~BACKGROUND_LAYER
  for node: GeometryInstance3D in _layers:
   if is_instance_valid(node): node.layers = BACKGROUND_LAYER
  view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
 else:
  _copy_parameters(_adapter, _original_material)
  _original_sky.sky_material = _original_material
  _editor.camera.cull_mask = _camera_mask
  for node: GeometryInstance3D in _layers:
   if is_instance_valid(node): node.layers = _layers[node]
  view.render_target_update_mode = SubViewport.UPDATE_DISABLED
 _active = value
 # Shader replacement also requests complete initial radiance, without
 # changing the shared sky-color/cubemap math or the light parameters.
 if _editor.gameplay != null: _editor.gameplay.time_system.apply_to_scene(_editor)

func _cancel_warmup() -> void:
 if _warm_callback.is_valid() and RenderingServer.frame_post_draw.is_connected(_warm_callback):
  RenderingServer.frame_post_draw.disconnect(_warm_callback)
 _warm_callback = Callable()

func _image_drawn() -> void:
 _warm_callback = Callable()
 _ready_image = true

func _begin_warmup() -> void:
 _cancel_warmup()
 _ready_image = false
 # Keep both cameras able to see these objects for this one warm-up draw.
 # The main camera still uses the original sky until the image is ready.
 for node: GeometryInstance3D in _layers:
  if is_instance_valid(node): node.layers = int(_layers[node]) | BACKGROUND_LAYER
 view.render_target_update_mode = SubViewport.UPDATE_ONCE
 _warm_callback = _image_drawn
 RenderingServer.frame_post_draw.connect(_warm_callback, CONNECT_ONE_SHOT)

func set_suspended(value: bool) -> void:
 if value == _suspended: return
 _suspended = value
 sync()

func is_active() -> bool:
 return _active

func sync() -> void:
 if not _supported or not is_instance_valid(_editor): return
 var main: Viewport = _editor.get_viewport()
 var internal: Vector2 = main.get_visible_rect().size * main.scaling_3d_scale
 var pixels: float = internal.x * internal.y
 if _pixel_budget and pixels < DISABLE_PIXELS: _pixel_budget = false
 elif not _pixel_budget and pixels >= ENABLE_PIXELS: _pixel_budget = true
 var wants: bool = enabled and not _suspended and not _editor.preview_quality.native and _pixel_budget
 wants = wants and _original_environment.background_mode == Environment.BG_SKY and is_equal_approx(_original_environment.background_energy_multiplier, 1.0)
 wants = wants and _editor.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and not main.use_xr and _safe_ordering()
 # Do not enable during retirement of a potentially larger old foreground.
 if not _active and _editor.renderer.morph_progress < 1.0: wants = false
 if not wants:
  _cancel_warmup()
  _set_active(false)
  if view != null: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
  _ready_image = false
  for node: GeometryInstance3D in _layers:
   if is_instance_valid(node): node.layers = _layers[node]
  return
 _ensure_resources()
 var size: Vector2i = Vector2i(internal * .5).max(Vector2i.ONE)
 if view.size != size:
  _set_active(false)
  view.size = size
  _begin_warmup()
 elif not _active and not _ready_image and not _warm_callback.is_valid():
  _begin_warmup()
 camera.global_transform = _editor.camera.global_transform
 camera.projection = _editor.camera.projection
 camera.fov = _editor.camera.fov
 camera.size = _editor.camera.size
 camera.frustum_offset = _editor.camera.frustum_offset
 camera.keep_aspect = _editor.camera.keep_aspect
 camera.near = _editor.camera.near
 camera.far = _editor.camera.far
 var source: ShaderMaterial = _original_sky.sky_material
 for key: StringName in _uniforms:
  var value: Variant = source.get_shader_parameter(key)
  if not _values.has(key) or _values[key] != value:
   _background_material.set_shader_parameter(key, value)
   _values[key] = value
 for key: StringName in FOG_PROPERTIES:
  var value: Variant = _original_environment.get(key)
  var cache_key: StringName = StringName("fog/" + String(key))
  if not _values.has(cache_key) or _values[cache_key] != value:
   _environment.set(key, value)
   _values[cache_key] = value
 if _ready_image: _set_active(true)

func _process(_delta: float) -> void:
 sync()

func _exit_tree() -> void:
 _cancel_warmup()
 if _active and is_instance_valid(_editor) and is_instance_valid(_editor.camera):
  _copy_parameters(_adapter, _original_material)
  _original_sky.sky_material = _original_material
  _editor.camera.cull_mask = _camera_mask
 for node: GeometryInstance3D in _layers:
  if is_instance_valid(node): node.layers = _layers[node]
