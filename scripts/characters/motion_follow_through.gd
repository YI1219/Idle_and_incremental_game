extends SkeletonModifier3D
## Small delayed turns in cloth and gaze; the authored animation remains the base pose.
var actor: Node3D
var _last_heading := 0.0
var _turn := 0.0
var _cloth_turn := 0.0
var _initialized := false

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or actor == null: return
	var heading: float = actor.mesh.rotation.y
	if not _initialized:
		_last_heading = heading
		_initialized = true
	var delta := maxf(get_process_delta_time(),.001)
	var angular_speed := wrapf(heading-_last_heading,-PI,PI)/delta
	_last_heading = heading
	_turn = lerpf(_turn,clampf(angular_speed,-3,3),1.0-exp(-delta*9))
	_cloth_turn = lerpf(_cloth_turn,_turn,1.0-exp(-delta*4))
	_apply(skeleton,"Chest",Vector3.UP,-_turn*.012)
	_apply(skeleton,"Head",Vector3.UP,_turn*.020)
	for side in ["L","R"]:
		_apply(skeleton,"Skirt."+side,Vector3.UP,-_cloth_turn*.024)
	for side in ["1","2"]:
		for joint in 3:
			_apply(skeleton,"Ribbon."+side+"."+str(joint),Vector3.UP,-_cloth_turn*(.025+.012*joint))

func _apply(skeleton: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(axis,angle))
