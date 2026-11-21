extends SceneTree
var count: int = 0
var nodes: int = 0

func _initialize() -> void:
	call_deferred("run")

func collect(node: Node) -> void:
	if node is MultiMeshInstance3D and node.name == "grass_blades":
		count += node.multimesh.instance_count
		nodes += 1
	for child in node.get_children():
		collect(child)

func run() -> void:
	var editor = load("res://scenes/terrain_editor.tscn").instantiate()
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(editor)
	collect(editor.renderer)
	var baseline: int = 9465
	var delta: int = count - baseline
	print("GRASS FIELD 20 COUNT: ", JSON.stringify({"scene": "res://scenes/terrain_editor.tscn", "seed": editor.data.seed, "preset": 0, "nodes": nodes, "before": baseline, "after": count, "delta": delta, "ratio": float(count) / baseline, "increase_percent": 100.0 * delta / baseline, "fps_measured": false}))
	editor.free()
	quit(0)
