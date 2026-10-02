extends RefCounted
## Godot's glTF importer retains fabric maps but drops the exported specular extension.
## Apply the intended low cloth reflection to instance materials; preserve source assets.
static func apply(model: Node) -> void:
	var materials: Dictionary = {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source = mesh.get_active_material(surface)
			if not source is BaseMaterial3D or source.resource_name not in ["robe", "ivory", "pants", "teal"]:
				continue
			if not materials.has(source):
				var fabric: BaseMaterial3D = source.duplicate()
				fabric.metallic_specular = 0.18
				materials[source] = fabric
			mesh.set_surface_override_material(surface, materials[source])
