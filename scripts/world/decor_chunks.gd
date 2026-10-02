extends RefCounted
## 1 m chunks for repeated foliage. Only dirty chunks rebuild.

const CHUNK := 1

var signatures: Dictionary = {}
var nodes: Dictionary = {}


func chunk_of(world_xz: Vector2) -> Vector2i:
	return Vector2i(floori(world_xz.x / float(CHUNK)), floori(world_xz.y / float(CHUNK)))


func sync(parent: Node3D, mesh: Mesh, material: Material, items: Array, dirty_world: Array = []) -> int:
	var grouped: Dictionary = {}
	for item in items:
		var at: Vector3 = item["origin"]
		var key := chunk_of(Vector2(at.x, at.z))
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(item)
	var dirty: Dictionary = {}
	if dirty_world.is_empty():
		for key in grouped.keys():
			dirty[key] = true
		for key in signatures.keys():
			if not grouped.has(key):
				dirty[key] = true
	else:
		for cell in dirty_world:
			dirty[chunk_of(Vector2(float(cell.x), float(cell.y)))] = true
	var rebuilt := 0
	for key: Vector2i in dirty.keys():
		var rows: Array = grouped.get(key, [])
		var signature := _signature(rows)
		if signatures.get(key, "") == signature and nodes.has(key):
			continue
		rebuilt += 1
		if rows.is_empty():
			_free_chunk(key)
			signatures.erase(key)
			continue
		var instance: MultiMeshInstance3D = nodes.get(key)
		if instance == null or not is_instance_valid(instance):
			instance = MultiMeshInstance3D.new()
			instance.name = "Decor_%d_%d" % [key.x, key.y]
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
			nodes[key] = instance
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = rows.size()
		for i in rows.size():
			var row: Dictionary = rows[i]
			var xf := Transform3D(Basis(Vector3.UP, float(row.get("yaw", 0.0))), row["origin"])
			var scale := float(row.get("scale", 1.0))
			xf.basis = xf.basis.scaled(Vector3(scale, scale, scale))
			multi.set_instance_transform(i, xf)
		instance.multimesh = multi
		instance.material_override = material
		signatures[key] = signature
	return rebuilt


func clear() -> void:
	for key in nodes.keys():
		_free_chunk(key)
	signatures.clear()


func _free_chunk(key: Vector2i) -> void:
	var node: Node = nodes.get(key)
	if node and is_instance_valid(node):
		node.queue_free()
	nodes.erase(key)


func _signature(rows: Array) -> String:
	var parts: PackedStringArray = []
	for row in rows:
		var at: Vector3 = row["origin"]
		parts.append("%.2f,%.2f,%.2f,%.2f" % [at.x, at.z, float(row.get("yaw", 0.0)), float(row.get("scale", 1.0))])
	parts.sort()
	return ",".join(parts)
