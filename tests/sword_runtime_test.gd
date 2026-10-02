extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/play.tscn").instantiate()
 root.add_child(scene)
 for i in 8: await physics_frame
 var p = get_first_node_in_group("player")
 check(p.get("ward_state") != null, "护体规则接入角色")
 check(p.find_child("StarterSword",true,false) != null, "Tripo 剑绑定角色")
 if p.get("ward_state") == null:
  quit(1)
  return
 p.set_physics_process(false)
 p.ward_state.health = 100
 p.ward_state.ward = 1
 p.receive_attack(100,0,0,p.global_position+p.facing())
 check(is_equal_approx(p.ward_state.health,80),"最后一点护体仍提供完整减伤")
 check(is_zero_approx(p.ward_state.ward),"被减免部分扣除护体并归零")
 p.actions.cancel()
 p.actions.start("counter")
 p.actions.advance(.1)
 var hp: float = p.ward_state.health
 p.receive_attack(10,0,0,p.global_position+p.facing())
 check(p.ward_state.health == hp,"正面拆招拦截一次攻击")
 p.receive_attack(10,0,0,p.global_position-p.facing())
 check(p.ward_state.health < hp,"背面来袭不能被同一次拆招挡住")
 p.actions.cancel()
 p.actions.charges = 2
 p.actions.start("dodge")
 p.actions.advance(.1)
 hp = p.ward_state.health
 p.receive_attack(100,100,0,p.global_position+p.facing())
 check(p.ward_state.health == hp,"身法无敌窗口躲避主动伤害")
 var arena = get_first_node_in_group("combat_arena")
 p.global_position = arena.target_position()+Vector3(0,0,-.8)
 p.ward_state.ward = 30
 p._physics_process(.05)
 check(p.ward_state.ward < 30,"身法期间近身灵压仍消耗护体")
 p.actions.cancel()
 p.actions.charges = 0
 check(not p.actions.start("dodge"),"身法次数耗尽不能无限闪避")
 print("SWORD RUNTIME failures=",failures)
 quit(1 if failures else 0)
