extends SceneTree
func _init():
	var rng := RandomNumberGenerator.new()
	rng.seed = 721035
	const RING_COUNTS := [30, 34, 38]
	const RING_RADII := [460.0, 740.0, 1060.0]
	var out := []
	for variant in 3:
		var count: int = RING_COUNTS[variant]
		var base_r: float = RING_RADII[variant]
		for i in count:
			var u := float(i) / float(count)
			var cluster_wave := sin(u * TAU * 3.0 + float(variant) * 1.8)
			var angle := TAU * u + cluster_wave * .042 + variant * .27 + rng.randf_range(-.032, .032)
			var radius := base_r + rng.randf_range(-38.0, 44.0)
			var presence := clampf(.52 + .48 * sin(angle * 3.0 - .4 + variant * 1.9) * cos(angle * 2.0 + variant * .7), .18, 1.0)
			var scale_factor := radius / 210.0
			var right_lift := lerpf(0.92, 1.36, clampf((sin(angle) + .12) / 1.12, 0.0, 1.0))
			var height := rng.randf_range(31.0, 45.0) * scale_factor * lerpf(.84, 1.24, presence) * right_lift
			var span_w := rng.randf_range(68.0, 102.0) * scale_factor * lerpf(.92, 1.24, presence)
			var span_d := rng.randf_range(28.0, 42.0) * scale_factor
			var base_y := minf(-162.0, -radius * rng.randf_range(.28, .40)) - height * rng.randf_range(.16, .24)
			var at := Vector3(sin(angle) * radius, base_y, cos(angle) * radius)
			var yaw := angle + PI + rng.randf_range(-.32, .32)
			var flip_x := -1.0 if rng.randf() < .5 else 1.0
			var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(span_w * flip_x, height, span_d))
			out.append([variant, basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z, at.x, at.y, at.z])
	var f := FileAccess.open("/tmp/tsw_godot/mountain_poses.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"note": "distant_landscape.gd ring poses (rng seed 721035): variant, basis x, y, z columns, origin", "poses": out}))
	f.close()
	print("POSES ", out.size())
	quit()
