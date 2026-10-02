extends SceneTree
## Regression coverage for interruption and blocked captured foot placements.
var failures:=0
var checks:=0
var player:CharacterBody3D
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func release()->void:
	for key in ["move_left","move_right","move_forward","move_back"]:Input.action_release(key)
func reset()->void:
	release()
	player.position=Vector3.ZERO
	player.mesh.rotation.y=0
	player.sync_location()
func step()->void:
	player._physics_process(1.0/60)
	player._animation.advance(1.0/60)
func run()->void:
	root.get_node("SpaceState").space_id="outside"
	player=load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player._animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for angle in [-179.0,-120.0,-60.0,60.0,120.0,179.0]:
		reset()
		player._begin_turn(deg_to_rad(angle))
		var duration:float=player._turn_data[player._turn_clip].seconds
		var previous_yaw:=0.0
		for i in ceili(duration*60):
			player._advance_turn(1.0/60)
			player._animation.advance(1.0/60)
			check(absf(angle_difference(previous_yaw,player.mesh.rotation.y))<.10,"Adapted turn heading has no frame snap")
			previous_yaw=player.mesh.rotation.y
		check(absf(angle_difference(player.mesh.rotation.y,deg_to_rad(angle)))<.001,"Adapted corner reaches requested direction")
	reset()
	Input.action_press("move_right")
	for i in 20:step()
	check(not player._turn_clip.is_empty(),"Turn starts with captured steps")
	release()
	var stopped_after:=0.0
	for i in 60:
		step()
		if player._turn_clip.is_empty() and player.velocity.length()<.001:
			stopped_after=(i+1)/60.0
			break
	check(stopped_after>0 and stopped_after<.5,"Released turn settles at support transition within half a second")
	reset()
	Input.action_press("move_right")
	for i in 20:step()
	release()
	Input.action_press("move_left")
	for i in 25:step()
	check(player._turn_start_yaw+player._turn_angle<0,"New direction replaces old target at a planted transition")
	reset()
	player._begin_turn(deg_to_rad(60.0))
	for i in 12:
		player._advance_turn(1.0/60)
		player._animation.advance(1.0/60)
	var previous_name: String = player._turn_clip
	var skeleton: Skeleton3D = player._find_skeleton(player.mesh)
	var thigh := skeleton.find_bone("Thigh.L")
	var previous_pose := skeleton.get_bone_pose_rotation(thigh)
	player._begin_turn(deg_to_rad(120.0))
	check(player._turn_clip==previous_name,"Same-side redirect exercises same-name turn restart")
	check(skeleton.get_bone_pose_rotation(thigh).angle_to(previous_pose)<.02,"Same-name restart blends from its current thigh pose")
	# Collision blocks a real captured step near a wall, not only ordinary straight travel.
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	var shape:=CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(4,3,.1)
	wall.add_child(shape)
	wall.position=Vector3(0,0,.30)
	root.add_child(wall)
	await physics_frame
	reset()
	Input.action_press("move_right")
	var obstruction_seen:=false
	var exceeded_wall:=false
	for i in 150:
		step()
		obstruction_seen=obstruction_seen or is_finite(player._obstructed_turn_yaw)
		exceeded_wall=exceeded_wall or player.position.z>.08
	check(obstruction_seen,"A blocked captured step ends instead of letting its feet keep sliding")
	check(not exceeded_wall,"Turn root motion respects the physical wall")
	check(player.position.x>1 and player.facing().x>.99,"Held direction can move away after an obstructed step")
	wall.free()
	reset()
	Input.action_press("move_right")
	for i in 20:step()
	player._play_action("attack")
	check(player._turn_clip.is_empty(),"New actions cancel the turn state")
	reset()
	Input.action_press("move_right")
	for i in 20:step()
	player.sync_location()
	check(player._turn_clip.is_empty() and player.velocity==Vector3.ZERO,"Relocation clears turn motion")
	release()
	print("TURN TRANSITION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
