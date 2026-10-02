extends Node3D
## Reversible scene dressing using unchanged CC0 Quaternius Standard meshes.
## Call attach(terrain, cottage), set_paths(points), then add_community(...).
## Visual assembly only: the caller owns placement, collision, and entrance logic.

const SOURCE_DIR := "res://assets/nature/quaternius/"
const FOLIAGE := preload("res://shaders/world/courtyard_foliage.gdshader")
const GROUND := preload("res://shaders/world/courtyard_ground.gdshader")
const CLIFF := preload("res://shaders/world/island_cliff.gdshader")
const RockKit := preload("res://scripts/world/rock_kit.gd")
const COTTAGE_SHADER := preload("res://shaders/world/courtyard_cottage.gdshader")
const WATER := preload("res://shaders/world/courtyard_water.gdshader")
const SKY_SHADER := preload("res://shaders/world/courtyard_sky.gdshader")
const MODEL_IDS := ["CommonTree_1", "CommonTree_3", "Rock_Medium_1", "Rock_Medium_2", "Grass_Common_Short", "Bush_Common", "Grass_Wispy_Short", "Flower_3_Group"]
var terrain: Node3D
var cottage: Node3D
var ground_material: ShaderMaterial
var models: Dictionary = {}
var _patches: Array[Vector4] = []
var _communities: Node3D
var _original_materials: Dictionary = {}
var _original_cottage_materials: Dictionary = {}
var _canopies: Array[Vector3] = []

func attach(to_terrain: Node3D, to_cottage: Node3D) -> void:
	if _communities != null:
		push_error("CourtyardArt.attach may only be called once per helper.")
		return
	terrain = to_terrain
	cottage = to_cottage
	name = "CourtyardArt"
	_communities = Node3D.new()
	_communities.name = "NatureCommunities"
	add_child(_communities)
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND
	_override("LandSurface", ground_material)
	var water := ShaderMaterial.new()
	water.shader = WATER
	_override("JadeWater", water)
	_override("RiverBank", ground_material)
	RockKit.ensure()
	if RockKit.rock_material:
		_override("IslandCliff", RockKit.rock_material)
	else:
		var cliff := ShaderMaterial.new()
		cliff.shader = CLIFF
		_override("IslandCliff", cliff)
	_load_models()
	_refine_cottage(cottage)

func _refine_cottage(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original := node.get_active_material(index) as StandardMaterial3D
			if original and original.resource_name.begins_with("tripo_mat") and original.albedo_texture:
				if not _original_cottage_materials.has(node):
					_original_cottage_materials[node] = {}
				_original_cottage_materials[node][index] = node.get_surface_override_material(index)
				var material := ShaderMaterial.new()
				material.shader = COTTAGE_SHADER
				material.set_shader_parameter("original_texture", original.albedo_texture)
				node.set_surface_override_material(index, material)
	for child in node.get_children():
		_refine_cottage(child)

func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

func _override(node_name: String, material: Material) -> void:
	var mesh := terrain.get_node_or_null(node_name) as MeshInstance3D
	if mesh:
		_original_materials[mesh] = mesh.material_override
		mesh.material_override = material

func restore_terrain() -> void:
	for mesh in _original_materials:
		if is_instance_valid(mesh):
			mesh.material_override = _original_materials[mesh]
	_original_materials.clear()
	for mesh in _original_cottage_materials:
		if is_instance_valid(mesh):
			for index in _original_cottage_materials[mesh]:
				mesh.set_surface_override_material(index, _original_cottage_materials[mesh][index])
	_original_cottage_materials.clear()

func _exit_tree() -> void:
	restore_terrain()

func _load_models() -> void:
	for id in MODEL_IDS:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(SOURCE_DIR + id + ".gltf", state) != OK:
			push_error("Courtyard art cannot read " + id)
			continue
		var source := document.generate_scene(state)
		_refine_materials(source)
		var packed := PackedScene.new()
		if packed.pack(source) == OK:
			models[id] = packed
		source.free()

func _refine_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original := node.get_active_material(index) as StandardMaterial3D
			if original == null:
				continue
			var label := original.resource_name.to_lower()
			if "leaves" in label or "grass" in label or "flowers" in label:
				var material := ShaderMaterial.new()
				material.shader = FOLIAGE
				material.set_shader_parameter("leaf_texture", original.albedo_texture)
				material.set_shader_parameter("wind_strength", 0.055 if "leaves" in label else 0.08)
				if "flowers" in label:
					material.set_shader_parameter("preserve_color", 0.85)
				if "grass" in label:
					material.set_shader_parameter("shade_color", Color("586943"))
					material.set_shader_parameter("sun_color", Color("9caa62"))
				node.set_surface_override_material(index, material)
			else:
				var material := original.duplicate() as StandardMaterial3D
				material.roughness = 0.94
				material.normal_scale = 0.45
				material.albedo_color = Color("b6bfb9") if "bark" in label else Color("b5c7c3")
				node.set_surface_override_material(index, material)
	for child in node.get_children():
		_refine_materials(child)

func _bounds(node: Node3D, parent_transform := Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var current: Transform3D = parent_transform * node.transform
	if node is MeshInstance3D:
		result = current * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_box := _bounds(child, current)
			if child_box.size != Vector3.ZERO:
				result = child_box if result.size == Vector3.ZERO else result.merge(child_box)
	return result

func add_model(id: String, at: Vector3, height: float, yaw: float = 0.0, parent: Node3D = null) -> Node3D:
	if not models.has(id):
		return null
	var model := (models[id] as PackedScene).instantiate() as Node3D
	var box := _bounds(model)
	var factor := height / maxf(box.size.y, 0.001)
	var pivot := Node3D.new()
	(parent if parent else _communities).add_child(pivot)
	pivot.name = id
	pivot.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	pivot.add_child(model)
	model.scale *= factor
	model.position.y -= box.position.y * factor
	return pivot

func clear_communities() -> void:
	for child in _communities.get_children():
		child.free()
	_patches.clear()
	_canopies.clear()
	if grass_chunks:
		grass_chunks.clear()
	_sync_contacts()

func _point_allowed(at: Vector3, padding: float = 0.2) -> bool:
	if not terrain.is_walkable(at):
		return false
	# Reject ground cover that hangs over a logical water/land edge.
	for offset in [Vector3(padding,0,0), Vector3(-padding,0,0), Vector3(0,0,padding), Vector3(0,0,-padding)]:
		if not terrain.is_walkable(at + offset):
			return false
	if cottage:
		var local := cottage.to_local(at)
		if absf(local.x) < 3.8 and local.z > -2.8 and local.z < 2.7:
			return false
		# Preserve the approach in cottage-local coordinates after relocation/rotation.
		if absf(local.x) < 1.25 and local.z >= 2.2 and local.z < 5.4:
			return false
	return true

func add_community(origin: Vector3, variant: int = 0, scale_factor: float = 1.0, yaw: float = 0.0, with_tree: bool = true) -> bool:
	if not _point_allowed(origin, 0.48 * scale_factor):
		return false
	if with_tree:
		for canopy in _canopies:
			if Vector2(origin.x-canopy.x, origin.z-canopy.y).length() < 1.6*scale_factor+canopy.z:
				return false
		_canopies.append(Vector3(origin.x, origin.z, 1.6*scale_factor))
	var community := Node3D.new()
	community.name = "Community_%d" % _communities.get_child_count()
	_communities.add_child(community)
	var transform := Transform3D(Basis(Vector3.UP, yaw), origin)
	var place := func(id: String, local: Vector3, height: float, angle: float) -> void:
		var at: Vector3 = transform * (local * scale_factor)
		if _point_allowed(at, 0.12 if height < 0.5 else 0.30):
			add_model(id, at, height*scale_factor, yaw+angle, community)
	if with_tree:
		place.call("CommonTree_1" if variant%2==0 else "CommonTree_3", Vector3.ZERO, 3.7 if variant%2==0 else 3.4, 0.3)
	place.call("Rock_Medium_1", Vector3(-0.75,0,0.55), 0.66, 0.5)
	place.call("Rock_Medium_2", Vector3(-1.16,0,0.8), 0.32, 2.4)
	place.call("Bush_Common", Vector3(0.67,0,0.15), 1.0, 1.6)
	place.call("Bush_Common", Vector3(0.13,0,-0.7), 0.76, 0.4)
	# Authored arcs and tapered outer tufts form a community rather than random scatter.
	for i in 24:
		var angle := -0.35 + float(i) * 0.245
		var radius := 0.75 + float(i%4)*0.23
		var offset := Vector3(cos(angle)*radius,0,sin(angle)*radius*0.72)
		place.call("Grass_Wispy_Short" if i%3==0 else "Grass_Common_Short", offset, 0.29+float(i%4)*0.037, angle)
	for i in 3:
		place.call("Flower_3_Group", Vector3(0.7+i*0.24,0,0.67-i*0.14), 0.27+i*0.025, i*1.7)
	_patches.append(Vector4(origin.x,origin.z,1.65*scale_factor,0.60))
	_sync_contacts()
	return true

func _sync_contacts() -> void:
	var patches: Array[Vector4] = _patches.duplicate()
	patches.resize(32)
	ground_material.set_shader_parameter("contact_patches", patches)
	ground_material.set_shader_parameter("contact_count", mini(_patches.size(),32))

func set_paths(points: PackedVector3Array) -> void:
	var segments: Array[Vector4] = []
	for i in clampi(points.size()-1,0,8):
		segments.append(Vector4(points[i].x,points[i].z,points[i+1].x,points[i+1].z))
	var count := segments.size()
	segments.resize(8)
	ground_material.set_shader_parameter("path_segments", segments)
	ground_material.set_shader_parameter("path_count",count)

func dress_default() -> void:
	clear_communities()
	for item in [[Vector3(-5.0,0,-4.5),0,0.88,0.3],[Vector3(-5.0,0,1.7),1,0.82,-0.5],[Vector3(5.7,0,-4.6),0,0.82,2.0]]:
		add_community(item[0],item[1],item[2],item[3])
	var door := cottage.to_global(Vector3(0,0,2.2))
	set_paths(PackedVector3Array([door,door+cottage.global_basis.z*1.5,Vector3(0,0,2.6)]))

const DecorChunks := preload("res://scripts/world/decor_chunks.gd")
var grass_chunks := DecorChunks.new()
var _grass_mesh: Mesh

func sync_grass_chunks(items: Array, dirty: Array = []) -> void:
	if _communities == null:
		return
	if _grass_mesh == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.34, 0.28)
		_grass_mesh = quad
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE
	material.set_shader_parameter("shade_color", Color("586943"))
	material.set_shader_parameter("sun_color", Color("9caa62"))
	grass_chunks.sync(_communities, _grass_mesh, material, items, dirty)

static func apply_atmosphere(world_environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	# Caller can retain the original Environment resource to restore its prior look.
	var environment := world_environment.environment.duplicate() as Environment
	world_environment.environment = environment
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7e94a0")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 8.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.06
	environment.fog_enabled = true
	environment.fog_light_color = Color("9aabb4")
	environment.fog_density = 0.0011
	environment.fog_sky_affect = 0.08
	environment.fog_height = -8.4
	environment.fog_height_density = 0.012
	environment.ssao_enabled = true
	environment.ssao_radius = 0.22
	environment.ssao_intensity = 1.35
	environment.ssao_power = 1.4
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment.glow_hdr_threshold = 1.35
	sun.rotation_degrees = Vector3(-42,-28,0)
	sun.light_color = Color("f7e6c4")
	sun.light_energy = 1.05
	sun.light_angular_distance = 2.4
	sun.shadow_blur = 2.2
