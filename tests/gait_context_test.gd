extends SceneTree
## Context and distinct-gait regression checks; visual quality is reviewed in captured motion.
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var player=load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var state=root.get_node("SpaceState")
	check(player.has_method("_pace_for_space"),"Scene context chooses walk, courtyard jog, or exploration run")
	if not player.has_method("_pace_for_space"):
		print("GAIT CONTEXT checks=",checks," failures=",failures)
		quit(1)
		return
	check(player._animation.has_animation("gentle_jog"),"Courtyard has a separately authored blend clip, not merely a renamed run")
	for entry in [["inside",.8,"walk"],["outside",2.0,"gentle_jog"],["explore",4.5,"run"]]:
		state.space_id=entry[0]
		player.sync_location()
		check(is_equal_approx(player._pace_for_space(),entry[1]),"Correct speed for "+entry[0])
		player.velocity=Vector3(0,0,entry[1])
		player._update_locomotion(.016)
		check(player._animation.current_animation==entry[2],"Correct visual gait for "+entry[0])
	check(player._animation.get_animation("gentle_jog").length>player._animation.get_animation("run").length,"Jog has a calmer cadence than exploration running")
	var clip:Animation=player._animation.get_animation("gentle_jog")
	for track in clip.get_track_count():
		var first=clip.track_get_key_value(track,0)
		var last=clip.track_get_key_value(track,clip.track_get_key_count(track)-1)
		if first is Quaternion:check(absf(first.dot(last))>.9999,"Gentle jog rotation loops cleanly")
		elif first is Vector3:check(first.distance_to(last)<.002,"Gentle jog translation loops cleanly")
	print("GAIT CONTEXT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
