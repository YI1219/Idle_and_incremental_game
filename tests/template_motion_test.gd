extends SceneTree
## Integration checks only: human appeal is judged using the source/target motion review.
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var player=load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var metadata=load("res://assets/characters/qinglan/template_motion.gd")
	for name in metadata.CLIPS:
		var animation=player._animation.get_animation(name)
		check(animation!=null,"Source-derived clip exists: "+name)
		check(absf(animation.length-metadata.CLIPS[name].seconds)<.002,"Template timing preserved: "+name)
	for modifier in player._find_skeleton(player.mesh).find_children("*","SkeletonModifier3D",true,false):
		check(modifier.get_script()==null or modifier.get_script()==preload("res://scripts/characters/garment_motion.gd"),"Only the isolated garment modifier may follow template playback")
	player.velocity=Vector3(0,0,2.0)
	player._update_locomotion(.016)
	check(player._animation.current_animation=="gentle_jog","Courtyard travel selects the gentle human-template blend")
	check(player._animation.speed_scale>.95 and player._animation.speed_scale<1.2,"Jog is not heavily accelerated")
	player.velocity=Vector3(0,0,.58)
	player._update_locomotion(.016)
	check(player._animation.current_animation=="walk","Slow travel uses a separate walking template")
	check(absf(player._animation.speed_scale-1.0)<.03,"Walking near native source speed retains authored cadence")
	player._animation.seek(.5,true)
	player.velocity=Vector3(0,0,1.6)
	player._update_locomotion(.016)
	check(player._animation.current_animation=="gentle_jog","Rising travel selects jog beyond the hysteresis boundary")
	check(absf(player._animation.current_animation_position/player._animation.current_animation_length-.5/metadata.CLIPS.walk.seconds)<.002,"Gait switching preserves stride phase")
	player.velocity=Vector3(0,0,1.35)
	player._update_locomotion(.016)
	check(player._animation.current_animation=="gentle_jog","Small speed changes do not toggle gaits repeatedly")
	player.velocity=Vector3.ZERO
	player._update_locomotion(.016)
	check(player._animation.current_animation=="idle","Stopped travel uses source idle")
	for kind in ["attack","counter","dodge"]:
		player.actions.cancel()
		player.actions.charges=2
		player.actions.start(kind)
		player._play_action(kind)
		check(player._animation.speed_scale==1.0,"Action is not accelerated to fit an unrelated timer: "+kind)
		player.actions.cancel()
		player._update_locomotion(.016)
		check(player._animation.current_animation==("attack_1" if kind=="attack" else "dodge_recovery" if kind=="dodge" else kind),"Stationary visual recovery is preserved: "+kind)
	player.velocity=Vector3(0,0,2.0)
	player._update_locomotion(.016)
	check(player._animation.current_animation=="gentle_jog","Movement can interrupt visual recovery")
	print("TEMPLATE MOTION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
