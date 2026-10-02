extends "res://scripts/world/courtyard_art.gd"
## Isolated overrides; original shared resources and game art stay untouched.
const EXTRA_MODELS := ["CommonTree_4", "CommonTree_5", "RockPath_Round_Wide", "RockPath_Round_Thin", "RockPath_Round_Small_1"]
func _load_models() -> void:
	super._load_models()
	for id in EXTRA_MODELS:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(SOURCE_DIR + id + ".gltf", state) != OK:
			push_error("Cannot load study module " + id)
			continue
		var source := doc.generate_scene(state)
		_refine_materials(source)
		var packed := PackedScene.new()
		if packed.pack(source) == OK: models[id] = packed
		source.free()
func _refine_materials(node: Node) -> void:
	super._refine_materials(node)
	_adjust(node)
func _adjust(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var original := node.mesh.surface_get_material(i) as StandardMaterial3D
			if original == null: continue
			var label := original.resource_name.to_lower()
			var mat: Material = node.get_active_material(i)
			if mat is ShaderMaterial and ("leaves" in label or "grass" in label):
				mat.set_shader_parameter("shade_color", Color("456957"))
				mat.set_shader_parameter("sun_color", Color("a0b56f"))
				mat.set_shader_parameter("wind_strength", 0.03)
			elif "rock" in label or "path" in label:
				var stone := ShaderMaterial.new()
				stone.shader = preload("res://shaders/studies/stone.gdshader")
				stone.set_shader_parameter("tint",Color("8d948a") if "path" in label else Color("858d82"))
				node.set_surface_override_material(i,stone)
			elif mat is StandardMaterial3D:
				mat.albedo_color=Color("c7c7af")
				mat.normal_enabled=false
				mat.metallic_specular=0.12
	for child in node.get_children(): _adjust(child)
