extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var script = load("res://scripts/combat/action_state.gd")
	if script == null:
		check(false, "基础战斗状态尚未实现")
		quit(1)
		return
	var state = script.new()
	check(state.attack(), "待机能攻击")
	check(not state.attack(), "不可在前摇重复触发")
	check(not state.advance(0.1), "前摇不命中")
	check(state.advance(0.2), "跨越发力时刻也命中")
	check(not state.advance(0.1), "同一招只触发一次判定")
	state.advance(0.5)
	check(state.attack() and state.action == "attack_2", "回收后短时按键接第二招")
	state.cancel()
	check(state.dodge(), "待机能闪避")
	check(not state.attack(), "闪避期间不能攻击")
	check(state.is_invulnerable(), "闪避初段有无敌窗口")
	state.advance(0.3)
	check(not state.is_invulnerable(), "闪避收尾无敌结束")
	state.cancel()
	check(state.action == "idle", "转场可清除动作")
	check(script.in_range(Vector3.ZERO, Vector3.FORWARD, Vector3(0,0,-1)), "前方近距离命中")
	check(not script.in_range(Vector3.ZERO, Vector3.FORWARD, Vector3(0,0,1)), "背后不命中")
	check(not script.in_range(Vector3.ZERO, Vector3.FORWARD, Vector3(0,0,-3)), "远处不命中")
	print("COMBAT failures=%d" % failures)
	quit(1 if failures else 0)
