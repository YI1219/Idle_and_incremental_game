extends Node3D
## Artifact-only background separation spike. No source asset edits.
const LAYER: int=1<<19
var editor: Node3D
var view: SubViewport
var camera: Camera3D
var environment: Environment
var original_environment: Environment
var sky_material: ShaderMaterial
var original_sky_material: ShaderMaterial
var quad: MeshInstance3D
var enabled: bool=true
var ratio: float=.5
var _active: bool=false
var _camera_mask: int=0
var _layers: Dictionary={}
var _values: Dictionary={}
var _uniforms: Array=[]
func configure(owner_editor: Node3D) -> void:
 editor=owner_editor
 process_priority=100
 _camera_mask=editor.camera.cull_mask
 original_environment=editor.get_node("WorldEnvironment").environment
 original_sky_material=original_environment.sky.sky_material
 environment=original_environment.duplicate(false)
 var sky: Sky=Sky.new();sky_material=original_sky_material.duplicate(false);sky.sky_material=sky_material;sky.radiance_size=Sky.RADIANCE_SIZE_32;sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
 environment.sky=sky;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.tonemap_exposure=1.0;environment.adjustment_enabled=false
 environment.glow_enabled=false;environment.ssao_enabled=false;environment.ssil_enabled=false;environment.ssr_enabled=false;environment.sdfgi_enabled=false
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.0;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
 _uniforms=original_sky_material.shader.get_shader_uniform_list()
 view=SubViewport.new();view.name="BackgroundViewport";view.world_3d=editor.get_viewport().world_3d;view.use_hdr_2d=true;view.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE;view.msaa_3d=Viewport.MSAA_DISABLED;add_child(view)
 camera=Camera3D.new();camera.environment=environment;camera.cull_mask=LAYER;camera.attributes=CameraAttributesPractical.new();view.add_child(camera);camera.make_current()
 var material: ShaderMaterial=ShaderMaterial.new();var shader: Shader=Shader.new()
 shader.code='shader_type spatial; render_mode unshaded,fog_disabled,shadows_disabled,cull_disabled; uniform sampler2D background_color : filter_linear,repeat_disable; uniform float background_distance=3500.0; void vertex(){vec2 xy=VERTEX.xy;VERTEX=vec3(xy*background_distance,-background_distance);POSITION=PROJECTION_MATRIX*vec4(VERTEX,1.0);POSITION.xy=xy*POSITION.w;} void fragment(){ALBEDO=texture(background_color,SCREEN_UV).rgb;}'
 material.shader=shader;material.set_shader_parameter("background_color",view.get_texture())
 quad=MeshInstance3D.new();quad.name="BackgroundComposite";var mesh: QuadMesh=QuadMesh.new();mesh.size=Vector2(2,2);quad.mesh=mesh;quad.material_override=material;quad.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;quad.layers=1;quad.custom_aabb=AABB(Vector3(-4096,-4096,-4096),Vector3(8192,8192,8192));add_child(quad)
 for node: Node in editor.landscape.get_children():
  if node is MultiMeshInstance3D or (node is MeshInstance3D and node.position.y<=-28.0):_layers[node]=node.layers
 sync()
func sync() -> void:
 var wants: bool=enabled
 if wants!=_active:
  _active=wants
  editor.camera.cull_mask=(_camera_mask & ~LAYER) if wants else _camera_mask
  for node: GeometryInstance3D in _layers:node.layers=LAYER if wants else _layers[node]
  view.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE if wants else SubViewport.UPDATE_DISABLED
  quad.visible=wants
 if not wants:return
 var main: Viewport=editor.get_viewport();var size: Vector2i=Vector2i(main.get_visible_rect().size*main.scaling_3d_scale*ratio)
 view.size=size.max(Vector2i.ONE);view.msaa_3d=main.msaa_3d if ratio>=.999 else Viewport.MSAA_DISABLED
 camera.global_transform=editor.camera.global_transform
 camera.projection=editor.camera.projection;camera.fov=editor.camera.fov;camera.size=editor.camera.size;camera.frustum_offset=editor.camera.frustum_offset;camera.keep_aspect=editor.camera.keep_aspect;camera.near=editor.camera.near;camera.far=editor.camera.far
 quad.material_override.set_shader_parameter("background_distance",camera.far*.99)
 for entry: Dictionary in _uniforms:
  var key: StringName=entry.name;var value: Variant=original_sky_material.get_shader_parameter(key)
  if not _values.has(key) or _values[key]!=value:sky_material.set_shader_parameter(key,value);_values[key]=value
 for key: String in ["fog_enabled","fog_light_color","fog_light_energy","fog_sun_scatter","fog_density","fog_aerial_perspective","fog_sky_affect","fog_height","fog_height_density","fog_depth_curve","fog_depth_begin","fog_depth_end"]:
  environment.set(key,original_environment.get(key))
func _process(_delta: float) -> void:sync()
func _exit_tree() -> void:
 if is_instance_valid(editor) and is_instance_valid(editor.camera):editor.camera.cull_mask=_camera_mask
 for node: GeometryInstance3D in _layers:
  if is_instance_valid(node):node.layers=_layers[node]
