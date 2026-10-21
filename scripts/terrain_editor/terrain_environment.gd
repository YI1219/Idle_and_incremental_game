extends RefCounted
## Shared CURRENT environment, extracted without palette/render-route changes.
static func setup(parent:Node3D,landscape:Node3D,sunlight_energy:float=1.18,fill_energy:float=.19,ambient_energy:float=.45,background_haze:float=.65)->void:
	# Warm front-right sunlight opens the plaster and foliage toward the courtyard view.
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-42,40,0)
	sun.light_color=Color("ffe7c9")
	sun.light_energy=sunlight_energy
	# Keeps the low sun's reflection on the lakes from clipping to a white patch.
	sun.light_specular=.28
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=90
	sun.light_angular_distance=2.2
	sun.shadow_opacity=1.0
	sun.shadow_bias=.06
	sun.shadow_normal_bias=1.4
	sun.directional_shadow_blend_splits=true
	parent.add_child(sun)
	landscape.set_sun_direction(sun.transform.basis.z)
	# Cool diffuse bounce keeps shaded cliff planes readable. No extra shadow map.
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-45,-28,0)
	fill.light_color=Color("cedbe5")
	fill.light_energy=fill_energy
	fill.shadow_enabled=false
	parent.add_child(fill)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new()
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=load("res://shaders/terrain_editor/sky.gdshader")
	sky_material.set_shader_parameter("haze",background_haze)
	var backdrop:Texture2D=load("res://assets/terrain_editor/cloud_backdrop_v01.png")
	var bitmap:=backdrop.get_image()
	if bitmap.generate_mipmaps()==OK:backdrop=ImageTexture.create_from_image(bitmap)
	sky_material.set_shader_parameter("cloud_backdrop",backdrop)
	sky.sky_material=sky_material
	sky.process_mode=Sky.PROCESS_MODE_QUALITY
	env.environment.sky=sky
	var settings:=env.environment
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("b8c9db")
	settings.ambient_light_energy=ambient_energy
	# Linear keeps the authored palettes; Filmic/AgX compress the warm sky
	# and haze toward grey. Only the sun core and water glints exceed 1.0.
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	settings.ssao_enabled=true
	settings.ssao_radius=1.3
	settings.ssao_intensity=1.3
	settings.ssao_power=1.6
	settings.ssao_detail=.5
	settings.ssao_light_affect=.25
	# Glow blooms only near-white values: the sun disc and bright water glints.
	settings.glow_enabled=true
	settings.glow_intensity=.55
	settings.glow_bloom=0.0
	settings.glow_hdr_threshold=.92
	settings.glow_blend_mode=Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for level in 7:settings.set_glow_level(level,[0.0,0.0,.6,1.0,.8,.5,0.0][level])
	# Thin cool haze over the island; distant mountains and cloud decks fade
	# into the sky colour in their own shaders and ignore this fog.
	# Gentle grade restores island contrast and colour lost to the bright
	# backdrop; warmth comes from the sun, sky and fog colours, not a tint.
	settings.adjustment_enabled=true
	settings.adjustment_contrast=1.04
	settings.adjustment_saturation=1.0
	settings.fog_enabled=true
	settings.fog_mode=Environment.FOG_MODE_EXPONENTIAL
	settings.fog_light_color=Color("c2d2df")
	settings.fog_light_energy=1.0
	settings.fog_sun_scatter=.30
	settings.fog_density=.0004
	settings.fog_sky_affect=0.0
	parent.add_child(env)
