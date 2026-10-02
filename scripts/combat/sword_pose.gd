extends SkeletonModifier3D
## Continuous wrist arcs and a relaxed carry pose layered onto the authored cloth motion.
var actor: Node

func _envelope(u: float, peak: float) -> float:
	return smoothstep(0.0, peak, u) * (1.0-smoothstep(peak, 1.0, u))

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or actor == null: return
	var arm := skeleton.find_bone("UpperArm.R")
	var fore := skeleton.find_bone("Forearm.R")
	if arm < 0 or fore < 0: return
	var swing := 0.0
	var guard := 0.0
	var u := 0.0
	if actor.actions.action == "attack":
		u = clampf(actor.actions.elapsed / actor.actions.ACTION_TIMES.attack.y, 0, 1)
		swing = _envelope(u, .37)
	elif actor.actions.action == "counter":
		u = clampf(actor.actions.elapsed / actor.actions.ACTION_TIMES.counter.y, 0, 1)
		guard = _envelope(u, .32)
	skeleton.set_bone_pose_rotation(arm, skeleton.get_bone_pose_rotation(arm) * Quaternion(Vector3.RIGHT,-.14-.30*guard) * Quaternion(Vector3.UP,-.35*swing))
	skeleton.set_bone_pose_rotation(fore, skeleton.get_bone_pose_rotation(fore) * Quaternion(Vector3.RIGHT,-.12-.35*guard))

	# Anticipation, cut, and recovery join the same carry pose without a wrist snap.
	var hand := skeleton.find_bone("Hand.R")
	if hand < 0 or actor._sword == null: return
	var yaw := -.35
	var elevation := .18
	if actor.actions.action == "attack":
		if u < .20:
			yaw = lerpf(-.35,-.92,smoothstep(0.0,.20,u))
		elif u < .50:
			yaw = lerpf(-.92,.72,smoothstep(.20,.50,u))
		else:
			yaw = lerpf(.72,-.35,smoothstep(.50,1.0,u))
		elevation += .20*swing
	elif actor.actions.action == "counter":
		yaw -= .30*guard
		elevation += .56*guard
	var blade_world: Vector3 = actor.facing().rotated(Vector3.UP,yaw)+Vector3.UP*elevation
	var up: Vector3 = (skeleton.global_basis.inverse()*blade_world).normalized()
	var reference: Vector3 = skeleton.global_basis.inverse()*Vector3.UP
	var right := up.cross(reference).normalized()
	var desired := Basis(right,up,right.cross(up))
	var bone_global: Basis = desired * actor._sword.basis.orthonormalized().inverse()
	var parent := skeleton.get_bone_parent(hand)
	var local: Basis = skeleton.get_bone_global_pose(parent).basis.inverse()*bone_global
	var rotation: Basis = skeleton.get_bone_rest(hand).basis.inverse()*local
	skeleton.set_bone_pose_rotation(hand,rotation.orthonormalized().get_rotation_quaternion())
