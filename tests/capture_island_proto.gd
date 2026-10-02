extends SceneTree
## Four views of the standalone island prototype.

const OUT := "res://art/review/island_proto/2026-10-02"
const ARTIFACTS := "/opt/cursor/artifacts"


func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for _i in n:
		await process_frame


func shot(path: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	var dest := ARTIFACTS + "/" + String(path).get_file()
	img.save_png(dest)
	print("wrote ", path)


func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ARTIFACTS)
	var scene: Node3D = load("res://scenes/proto/island_proto.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	scene.flush_dress()
	await frames(4)
	var box: AABB = scene.bounds()
	var mid := Vector3(box.position.x + box.size.x * 0.5, box.position.y + box.size.y, box.position.z + box.size.z * 0.5)
	var r := maxf(box.size.x, box.size.z) * 0.5
	var cam := scene.get_node("Camera3D") as Camera3D
	print("bounds ", box, " r ", r, " grass ", mid)

	cam.fov = 40.0
	_look(cam, mid + Vector3(r * 0.85, r * 1.25, r * 1.35), mid + Vector3(0.0, -0.9, 0.0))
	await shot(OUT + "/overview.png")

	_look(cam, mid + Vector3(r * 1.75, 0.45, r * 0.22), mid + Vector3(0.0, -1.65, 0.0))
	await shot(OUT + "/low_side.png")

	_look(cam, mid + Vector3(r * 1.15, -4.8, r * 1.05), mid + Vector3(0.0, -2.4, 0.0))
	await shot(OUT + "/underside.png")

	_look(cam, mid + Vector3(r * 1.55, -2.15, r * 1.45), mid + Vector3(0.0, -1.7, 0.0))
	await shot(OUT + "/three_quarter_below.png")

	print("PROTO_CAPTURE done")
	quit()


func _look(cam: Camera3D, eye: Vector3, at: Vector3) -> void:
	cam.position = eye
	cam.look_at(at, Vector3.UP)
