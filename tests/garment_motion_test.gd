extends SceneTree
## Checks garment response and humanoid-pose isolation, not aesthetic acceptance.
var failures := 0
var checks := 0
func check(ok:bool, message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var player=load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var sk:Skeleton3D=player._find_skeleton(player.mesh)
	var cloth=sk.get_node_or_null("GarmentMotion")
	check(cloth!=null,"Player has garment-only secondary motion")
	if cloth==null:
		print("GARMENT MOTION checks=",checks," failures=",failures);quit(1);return
	player._animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sk.modifier_callback_mode_process=Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var humanoid_names:Array[String]=[]
	for i in sk.get_bone_count():
		var name:=sk.get_bone_name(i)
		if not name.begins_with("Skirt.") and not name.begins_with("Hem.") and not name.begins_with("Ribbon.") and not name.begins_with("Cuff.") and not name.begins_with("Sleeve."):
			humanoid_names.append(name)
	var sample:Dictionary={}
	var humanoid_poses:Dictionary={}
	cloth.modification_processed.connect(func():
		for name in ["Sleeve.L","Sleeve.R","Cuff.L.0","Cuff.L.1","Cuff.R.0","Cuff.R.1","Ribbon.1.2","Hem.Front"]+humanoid_names:
			sample[name]=sk.get_bone_pose_rotation(sk.find_bone(name))
		for name in humanoid_names:
			humanoid_poses[name]=sk.get_bone_pose(sk.find_bone(name)))
	var settled:Dictionary={}
	var driven:Dictionary={}
	for hz in [30,60,120]:
		cloth.reset_motion()
		player.velocity=Vector3.ZERO
		player.mesh.rotation.y=0
		player._animation.play("idle")
		for frame in hz:
			player._animation.advance(1.0/hz);sk.advance(1.0/hz)
			await process_frame
		settled=sample.duplicate()
		var max_delta:=0.0
		for frame in hz:
			player.velocity=Vector3(0,0,minf(frame*14.0/hz,4.5))
			player.mesh.rotation.y=float(frame)/hz
			player._animation.advance(1.0/hz)
			var humanoid:Dictionary={}
			for name in humanoid_names:humanoid[name]=sk.get_bone_pose_rotation(sk.find_bone(name))
			sk.advance(1.0/hz)
			await process_frame
			for name in humanoid:check(absf(sample[name].dot(humanoid[name]))>.999999,"Humanoid pose preserved at %s Hz: %s"%[hz,name])
			max_delta=maxf(max_delta,settled["Ribbon.1.2"].angle_to(sample["Ribbon.1.2"]))
			for name in sample:check(sample[name].is_finite(),"Finite garment/pose state")
		check(max_delta>.06,"Ribbon reacts visibly to acceleration/turn at %s Hz"%hz)
		driven[hz]=sample.duplicate()
		player.velocity=Vector3.ZERO
		cloth.reset_motion()
		player._animation.advance(0);sk.advance(0)
		await process_frame
		check(cloth._states.is_empty(),"Reset clears inherited motion on relocation")
	check(driven[30]["Ribbon.1.2"].angle_to(driven[120]["Ribbon.1.2"])<.08,"Response stable across 30/120 Hz")
	await check_blocked_settling(player,sk,cloth,sample)
	await check_root_turn(player,sk,cloth,sample)
	await check_action_pose_isolation(player,sk,cloth,humanoid_names,humanoid_poses)
	player.queue_free()
	print("GARMENT MOTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func check_blocked_settling(player,sk:Skeleton3D,cloth,sample:Dictionary)->void:
	# A reset inside every blocked controller tick used to hold the cuffs near rest.
	# Use the real menu input gate, while the test owns the simulation clock.
	var menu=load("res://scripts/preview_menu.gd").new()
	root.add_child(menu)
	menu.open_menu()
	paused=false
	check(player._blocked(),"Open preview menu blocks the actual player controller")
	player.mesh.rotation.y=0
	player._animation.play("idle")
	player._animation.seek(0,true)
	cloth.reset_motion()
	var initial:Dictionary={}
	var origin:Vector3=player.global_position
	for frame in 120:
		player.velocity=Vector3(0,0,2)
		player._physics_process(1.0/60)
		sk.advance(1.0/60)
		await process_frame
		check(player.velocity.is_zero_approx() and player.global_position.is_equal_approx(origin),"Blocked controller stops translation while garments settle")
		if frame==0:initial=sample.duplicate()
	for name in ["Sleeve.L","Sleeve.R","Cuff.L.0","Cuff.R.0"]:
		check(initial[name].angle_to(sample[name])>.10,"Blocked input allows continued settling: "+name)
	menu.resume()
	menu.queue_free()
	await process_frame
	check(not player._blocked(),"Closing the real menu releases the input gate")

func check_root_turn(player,sk:Skeleton3D,cloth,sample:Dictionary)->void:
	# With the authored arm pose held and no translation, only actor yaw can
	# drive this difference. Omitting world turn velocity must fail this test.
	var stationary:Dictionary={}
	player.velocity=Vector3.ZERO
	for turning in [false,true]:
		player.mesh.rotation.y=0
		player._animation.play("idle")
		player._animation.seek(0,true)
		cloth.reset_motion()
		for frame in 120:
			if turning:player.mesh.rotation.y=float(frame)*3.5/60.0
			sk.advance(1.0/60)
			await process_frame
		if not turning:
			stationary=sample.duplicate()
		else:
			for name in ["Sleeve.L","Sleeve.R","Cuff.L.0","Cuff.L.1","Cuff.R.0","Cuff.R.1"]:
				check(sample[name].is_finite(),"Finite stationary-turn garment pose: "+name)
				check(stationary[name].angle_to(sample[name])>.03,"Actor root turn drives garment with held arms: "+name)

func check_action_pose_isolation(player,sk:Skeleton3D,cloth,names:Array[String],sample:Dictionary)->void:
	# Compare complete local poses before and inside the actual modifier signal;
	# changing body position/scale must fail just as changing rotation would.
	for clip in ["walk","gentle_jog","run","turn_left_90","turn_right_90","turn_left_180","turn_right_180","attack_1","counter","dodge","dodge_recovery"]:
		player.mesh.rotation.y=0
		player.velocity=Vector3(0,0,6.2 if clip=="dodge" else 4.5 if clip=="run" else 2.0 if clip=="gentle_jog" else .8 if clip=="walk" else 0.0)
		player._animation.play(clip)
		player._animation.seek(0,true)
		cloth.reset_motion()
		var duration:float=player._animation.current_animation_length
		var frames:int=maxi(1,ceili(duration*60.0))
		for frame in frames+1:
			var delta:float=0.0 if frame==0 else duration/frames
			player._animation.advance(delta)
			var authored:Dictionary={}
			for name in names:authored[name]=sk.get_bone_pose(sk.find_bone(name))
			sample.clear()
			sk.advance(delta)
			await process_frame
			check(sample.size()==names.size(),"Fresh post-modifier sample for %s frame %s"%[clip,frame])
			for name in names:
				if not sample.has(name):continue
				check(sample[name].is_finite(),"Finite humanoid pose in %s: %s"%[clip,name])
				check(sample[name].is_equal_approx(authored[name]),"Authored humanoid transform preserved in %s frame %s: %s"%[clip,frame,name])
