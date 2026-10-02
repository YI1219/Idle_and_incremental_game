extends SceneTree
## Loop integrity only; runtime template integration is checked separately.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model = load("res://assets/characters/qinglan/qinglan_garment_v06.glb").instantiate()
	root.add_child(model)
	var animation: AnimationPlayer = model.find_child("AnimationPlayer",true,false)
	check(animation != null,"Refined model exposes animation clips")
	for name in preload("res://assets/characters/qinglan/template_motion.gd").LOOPS:
		var clip := animation.get_animation(name)
		check(clip != null,"Required clip: "+name)
		for track in clip.get_track_count():
			var count := clip.track_get_key_count(track)
			if count < 2: continue
			var first = clip.track_get_key_value(track,0)
			var last = clip.track_get_key_value(track,count-1)
			if first is Quaternion:
				check(absf(first.dot(last)) > .9999,name+": rotation settles at "+str(clip.track_get_path(track)))
			elif first is Vector3:
				check(first.distance_to(last)<.002,name+": position/scale settles at "+str(clip.track_get_path(track)))
	model.queue_free()
	print("ANIMATION LOOP INTEGRITY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
