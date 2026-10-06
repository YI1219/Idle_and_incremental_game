extends SceneTree
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var field=Contours.new()
	var failures:=0
	var largest:=0.0
	# These are actual profile inputs on either side of the narrow-wall
	# limit. A tiny width edit must not jump between unrelated rock fields.
	for sample in [Vector3(3,0,7),Vector3(10,-1,6)]:
		var profile:={"top":3.5,"rock_top":3.5,"bottom":-4.5,"base":true,"water":-1,"inset":.79999}
		var p:=Vector2(sample.x,sample.z)
		var before:Vector3=field._profile_point(p,sample.y,Vector2.RIGHT,profile)
		profile.inset=.80001
		var after:Vector3=field._profile_point(p,sample.y,Vector2.RIGHT,profile)
		var gap:=before.distance_to(after)
		largest=maxf(largest,gap)
		if gap>.002:
			failures+=1
			push_error("Tiny width edit jumps actual cliff profile by %.6f at %s"%[gap,sample])
	print("ROCK WIDTH TRANSITION: 2 samples, %d failures, largest displacement %.8f"%[failures,largest])
	quit(1 if failures else 0)
