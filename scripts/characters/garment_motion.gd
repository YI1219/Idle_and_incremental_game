extends SkeletonModifier3D
## Garment-only deformation after authored animation. No body-joint overrides or cloth solver.
## Integrate bounded angular follow-through at fixed substeps; delta=0 never adds energy.
var actor: CharacterBody3D
var _states: Dictionary = {}
var _rates: Dictionary = {}
var _previous_arms: Dictionary = {}
var _previous_panels: Dictionary = {}
var _previous_hip_y := 0.0
var _previous_velocity := Vector3.ZERO
var _previous_heading := 0.0
var _initialized := false
var _bones: Dictionary = {}

func reset_motion() -> void:
	_states.clear()
	_rates.clear()
	_previous_arms.clear()
	_previous_panels.clear()
	_initialized = false

func _bone(name: String) -> int:
	if not _bones.has(name): _bones[name] = get_skeleton().find_bone(name)
	return _bones[name]

func _spring(name: String, target: Vector3, delta: float, stiffness: float, damping: float, limit: float) -> Vector3:
	var position: Vector3 = _states.get(name, Vector3.ZERO)
	var rate: Vector3 = _rates.get(name, Vector3.ZERO)
	if delta <= 0.0: return position
	var steps := maxi(1, ceili(delta * 120.0))
	var step := delta / steps
	target = target.limit_length(limit)
	for i in steps:
		rate += ((target-position)*stiffness-rate*damping)*step
		position += rate*step
		if position.length() > limit:
			position = position.limit_length(limit)
			rate -= position.normalized()*maxf(rate.dot(position.normalized()),0.0)
	_states[name] = position
	_rates[name] = rate
	return position

func _rotation(vector: Vector3) -> Quaternion:
	return Quaternion(vector.normalized(),vector.length()) if vector.length_squared() > 0.00000001 else Quaternion.IDENTITY

func _angular_velocity(previous: Quaternion, current: Quaternion, delta: float) -> Vector3:
	var change := (current*previous.inverse()).normalized()
	if change.w < 0.0: change = -change
	return change.get_axis()*change.get_angle()/delta if change.get_angle() > .00001 else Vector3.ZERO

func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or actor == null: return
	# Ignore long suspend intervals; relocation explicitly resets the state too.
	if delta > .2: reset_motion()
	delta = clampf(delta,0.0,.05)
	var heading: float = actor.mesh.rotation.y
	if not _initialized:
		_previous_velocity = actor.velocity
		_previous_heading = heading
		_previous_hip_y = sk.get_bone_global_pose(_bone("Hips")).origin.y
		_initialized = true
	var acceleration := Vector3.ZERO
	var yaw_rate := 0.0
	if delta > 0.0:
		acceleration = ((actor.velocity-_previous_velocity)/delta).rotated(Vector3.UP,-heading).limit_length(28.0)
		yaw_rate = clampf(angle_difference(_previous_heading,heading)/delta,-4.0,4.0)
		_previous_velocity = actor.velocity
		_previous_heading = heading
	var speed := actor.velocity.length()
	var hips := sk.get_bone_global_pose(_bone("Hips"))
	var hip_rate := (hips.origin.y-_previous_hip_y)/delta if delta > 0.0 else 0.0
	if delta > 0.0: _previous_hip_y = hips.origin.y
	var directions: Dictionary = {}
	var knee_bends: Dictionary = {}
	for side in ["L","R"]:
		directions[side] = hips.basis.inverse()*sk.get_bone_global_pose(_bone("Thigh."+side)).basis.y.normalized()
		knee_bends[side] = sk.get_bone_global_pose(_bone("Thigh."+side)).basis.y.angle_to(sk.get_bone_global_pose(_bone("Shin."+side)).basis.y)
	var stride:float=directions.L.z-directions.R.z
	var front: Vector3 = directions.L if directions.L.z > directions.R.z else directions.R
	var back: Vector3 = directions.L if directions.L.z < directions.R.z else directions.R
	for panel in ["Front","Back","L","R"]:
		var index := _bone("Skirt."+panel)
		if index < 0: continue
		var rest := sk.get_bone_rest(index)
		var direction: Vector3 = front if panel == "Front" else back if panel == "Back" else directions[panel]
		# A panel follows the outer envelope of its leg, never the average of
		# opposing thighs. The free lower edge gets its own smaller delayed bend.
		var pitch := clampf(atan2(direction.z,-direction.y),-1.1,1.35)
		if panel == "Front": pitch = maxf(.12,pitch+.16)
		if panel == "Back": pitch = minf(-.12,pitch-.16)
		var outward := .24 if panel == "L" else -.24 if panel == "R" else 0.0
		var desired := Vector3(outward,-cos(pitch),sin(pitch)).normalized()
		var local_direction := rest.basis.inverse()*desired
		sk.set_bone_pose_rotation(index,rest.basis.get_rotation_quaternion()*Quaternion(Vector3.UP,local_direction))
		var pitch_rate:float=(pitch-float(_previous_panels.get(panel,pitch)))/delta if delta > 0.0 else 0.0
		if delta > 0.0: _previous_panels[panel]=pitch
		var free_target := Vector3(-acceleration.z*.007-speed*.013+clampf(pitch_rate,-8,8)*.024, -yaw_rate*.05, acceleration.x*.008)
		var offset := _spring("Hem."+panel,free_target,delta,140.0,19.0,.22)
		var hem := _bone("Hem."+panel)
		var knee:float=maxf(knee_bends.L,knee_bends.R) if panel=="Back" else knee_bends.get(panel,0.0)
		# Direct knee clearance plus delayed free motion. Does not move the leg.
		offset.x += maxf(0,knee-.55)*.33
		if hem >= 0: sk.set_bone_pose_rotation(hem,sk.get_bone_rest(hem).basis.get_rotation_quaternion()*_rotation(offset))
	for side in ["L","R"]:
		var arm_rates: Dictionary = {}
		for part in ["UpperArm.","Forearm."]:
			var key: String = part+side
			var orientation := sk.get_bone_global_pose(_bone(key)).basis.get_rotation_quaternion()
			var angular := Vector3.ZERO
			if delta > 0.0:
				if _previous_arms.has(key): angular = _angular_velocity(_previous_arms[key],orientation,delta).limit_length(15.0)
				_previous_arms[key] = orientation
			# Skeleton-global poses omit the actor's turn in world space.
			arm_rates[part] = angular+Vector3.UP*yaw_rate
		for joint in 3:
			var name: String = "Sleeve."+side if joint==0 else "Cuff."+side+"."+str(joint-1)
			var index := _bone(name)
			if index < 0: continue
			var basis := sk.get_bone_global_pose(index).basis
			var gravity := Quaternion(Vector3.UP,(basis.inverse()*Vector3.DOWN).normalized())
			var droop := gravity.get_axis()*gravity.get_angle()*.24
			var angular: Vector3 = arm_rates["UpperArm." if joint==0 else "Forearm."]
			var inertial := basis.inverse()*(-angular)*(.026+.013*joint)
			var target := droop+inertial+Vector3(-acceleration.z*.006,0,acceleration.x*.006)
			var offset := _spring(name,target,delta,130.0-joint*35,17.0-joint*3,.40)
			sk.set_bone_pose_rotation(index,sk.get_bone_rest(index).basis.get_rotation_quaternion()*_rotation(offset))
	for ribbon in ["1","2"]:
		for joint in 3:
			var name: String = "Ribbon."+ribbon+"."+str(joint)
			var index := _bone(name)
			if index < 0: continue
			var side := 1.0 if ribbon == "1" else -1.0
			var target := Vector3(-speed*.032-acceleration.z*.014+clampf(hip_rate,-1,1)*.16,-yaw_rate*(.07+.018*joint)+stride*.035*side,side*acceleration.x*.014+stride*.045)
			# Distal links inherit delayed motion, producing curvature along the ribbon.
			if joint > 0: target = target*.45+Vector3(_states.get("Ribbon."+ribbon+"."+str(joint-1),Vector3.ZERO))*.8
			var offset := _spring(name,target,delta,95.0-joint*20,12.0-joint*1.5,.42)
			sk.set_bone_pose_rotation(index,sk.get_bone_pose_rotation(index)*_rotation(offset))
