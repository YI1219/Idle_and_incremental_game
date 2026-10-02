extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
 for i in n: await process_frame
func shot(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://art/review/sword/runtime/"+name+".png")
func run() -> void:
 var scene = load("res://scenes/play.tscn").instantiate()
 root.add_child(scene)
 await frames(20)
 var p = get_first_node_in_group("player")
 var state = root.get_node("SpaceState")
 var space = get_first_node_in_group("space_controller")
 var rig = get_first_node_in_group("camera_rig")
 state.player_x=-3.8
 state.player_z=.55
 space.sync_after_relocation()
 p.mesh.rotation.y=0
 p.set_physics_process(false)
 get_first_node_in_group("combat_arena").set_process(false)
 rig._distance=6.0
 rig.snap_to_target()
 await frames(10)
 await shot("idle")
 for kind in ["attack","counter"]:
  for at in [.10,.20,.36]:
   p.actions.cancel()
   p.actions.start(kind)
   p.actions.advance(at)
   p._animation.play("attack_1")
   p._animation.seek(at*.5/(.8 if kind=="counter" else .55),true)
   p._animation.pause()
   await frames(2)
   await shot(kind+str(roundi(at*100)))
 quit()
