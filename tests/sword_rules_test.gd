extends SceneTree

var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func close(actual: float, expected: float, label: String, tolerance := 0.001) -> void:
	check(absf(actual - expected) <= tolerance, "%s: got %.4f, expected %.4f" % [label, actual, expected])


func vector_close(actual: Vector3, expected: Vector3, label: String, tolerance := 0.001) -> void:
	check(actual.distance_to(expected) <= tolerance, "%s: got %s, expected %s" % [label, actual, expected])


func _initialize() -> void:
	var ward_path := "res://scripts/combat/ward_state.gd"
	var actions_path := "res://scripts/combat/sword_actions.gd"
	var geometry_path := "res://scripts/combat/combat_geometry.gd"
	var files_exist := true
	for path in [ward_path, actions_path, geometry_path]:
		if not FileAccess.file_exists(path):
			check(false, "required sword rules implementation is missing: %s" % path)
			files_exist = false
	if not files_exist:
		print("SWORD_RULES failures=%d" % failures)
		quit(1)
		return

	var WardState = load(ward_path)
	var SwordActions = load(actions_path)
	var Geometry = load(geometry_path)
	check(WardState != null and SwordActions != null and Geometry != null, "all sword rules scripts load")
	if WardState == null or SwordActions == null or Geometry == null:
		quit(1)
		return

	test_ward(WardState)
	test_geometry(Geometry)
	test_actions(SwordActions)
	print("SWORD_RULES failures=%d" % failures)
	quit(1 if failures else 0)


func test_ward(WardState) -> void:
	var state = WardState.new()
	check(state.health == 100.0 and state.ward == 100.0, "ward state starts with full resources")
	state.ward = 1.0
	var result: Dictionary = state.receive_attack(100.0, 0.0, state.realm)
	close(state.ward, 0.0, "last ward is consumed")
	close(state.health, 80.0, "last ward grants full direct reduction")
	close(result.health_loss, 20.0, "direct health loss is reported")
	close(result.ward_loss, 1.0, "actual clamped ward loss is reported")
	result = state.receive_attack(100.0, 0.0, state.realm)
	close(state.health, 0.0, "unprotected follow-up reaches health and clamps at zero")
	close(result.health_loss, 80.0, "reported health loss is resource-clamped")

	state = WardState.new()
	state.ward = 30.0
	result = state.receive_attack(50.0, 25.0, state.realm)
	close(state.ward, 0.0, "direct block then active spirit consume ward")
	close(state.health, 65.0, "spirit overflow follows reduced direct damage")
	close(result.ward_loss, 30.0, "combined ward loss is reported")
	close(result.health_loss, 35.0, "combined health loss is reported")
	close(state.reduction_against(state.realm), 0.80, "same-realm reduction")
	close(state.reduction_against(state.realm - 10), 0.95, "reduction upper clamp")
	close(state.reduction_against(state.realm + 10), 0.60, "reduction lower clamp")

	state = WardState.new()
	result = state.receive_attack(-10.0, NAN, state.realm)
	check(state.health == 100.0 and state.ward == 100.0, "invalid damage cannot heal or harm")
	check(result.health_loss == 0.0 and result.ward_loss == 0.0, "invalid damage reports zero loss")
	state.ward = 20.0
	state.advance(2.5, 6.0)
	close(state.ward, 5.0, "pressure drains ward without harming health")
	close(state.health, 100.0, "pressure never harms health")
	state.advance(0.5, 20.0)
	close(state.ward, 0.0, "pressure clamps ward at zero")
	state.advance(2.9, 0.0)
	close(state.ward, 0.0, "ward waits for full recovery delay")
	state.advance(0.6, 0.0)
	close(state.ward, 6.0, "only time beyond delay restores ward")
	state.advance(0.5, 1.0)
	close(state.ward, 5.5, "positive pressure interrupts recovery and drains")
	state.advance(3.5, 0.0)
	close(state.ward, 11.5, "pressure restarts the full recovery delay")
	state.advance(-1.0, 10.0)
	close(state.ward, 11.5, "negative delta is ignored")

	state = WardState.new()
	state.ward = 0.0
	state.advance(1.0, -1.0)
	close(state.ward, 0.0, "negative pressure is rejected without restoring ward")
	state = WardState.new()
	state.ward = 0.0
	state.advance(0.1, 1.0)
	state.advance(2.0, NAN)
	state.advance(1.5, 0.0)
	close(state.ward, 0.0, "nonfinite pressure does not advance the recovery timer")


func test_geometry(Geometry) -> void:
	var fallback := Vector3(1.0, 2.0, 0.0)
	vector_close(Geometry.direction_from_ray(Vector3(0, 10, 0), Vector3(0, -1, -1), Vector3.ZERO, fallback), Vector3.FORWARD, "ray aims from actor to ground intersection")
	vector_close(Geometry.direction_from_ray(Vector3.ZERO, Vector3.RIGHT, Vector3.ZERO, fallback), Vector3.RIGHT, "parallel ray uses horizontal fallback")
	vector_close(Geometry.direction_from_ray(Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3.ZERO, fallback), Vector3.RIGHT, "intersection behind ray uses fallback")

	close(Geometry.pressure_from(Vector3.ZERO, Vector3(0.7, 0, 0), 6.0, 2.2, 0.7), 6.0, "pressure is full inside inner radius")
	close(Geometry.pressure_from(Vector3.ZERO, Vector3(1.45, 0, 0), 6.0, 2.2, 0.7), 3.0, "pressure falls linearly in outer radius")
	close(Geometry.pressure_from(Vector3.ZERO, Vector3(3, 0, 0), 6.0, 2.2, 0.7), 0.0, "pressure ends at radius")
	var sources := [
		{"position": Vector3(0.7, 0, 0), "team": 2, "strength": 6.0},
		{"position": Vector3(0, 0, 0.7), "team": 3, "strength": 9.0},
		{"position": Vector3.ZERO, "team": 1, "strength": 99.0},
		{"position": Vector3.ZERO, "team": 2, "strength": 99.0, "active": false},
	]
	close(Geometry.pressure_total(Vector3.ZERO, 1, sources), 15.0, "hostile active pressure sources add while friendlies do not")

	var raw := Vector3.FORWARD
	var target_10_degrees := Vector3(sin(deg_to_rad(10.0)), 4.0, -cos(deg_to_rad(10.0)))
	var assisted: Vector3 = Geometry.aim_direction(Vector3.ZERO, raw, [target_10_degrees], deg_to_rad(12.0), deg_to_rad(6.0), 2.0)
	close(rad_to_deg(raw.angle_to(assisted)), 6.0, "aim assist turn is capped")
	var behind: Vector3 = Geometry.aim_direction(Vector3.ZERO, raw, [Vector3.BACK], deg_to_rad(12.0), deg_to_rad(6.0), 2.0)
	vector_close(behind, raw, "aim assist never locks behind")
	var too_far: Vector3 = Geometry.aim_direction(Vector3.ZERO, raw, [target_10_degrees * 3.0], deg_to_rad(12.0), deg_to_rad(6.0), 2.0)
	vector_close(too_far, raw, "aim assist ignores distant targets")

	var hit: Dictionary = Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(0.2, 7, -1.8), "thrust")
	check(hit.core and not hit.spirit, "thrust hits its inclusive forward edge")
	check(not Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(0.23, 0, -1), "thrust").core, "thrust rejects outside half-width")
	check(Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(1.2, 0, -0.7), "sweep").core, "sweep hits inside radius and angle")
	check(not Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 1), "sweep").core, "sweep rejects behind")
	hit = Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(1.7, 0, -0.7), "charged_slash")
	check(not hit.core and hit.spirit, "charged slash exposes a spiritual outer region")
	hit = Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -1), "charged_slash")
	check(hit.core and hit.spirit, "charged slash may overlap core and spirit for caller deduplication")
	hit = Geometry.in_attack(Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, "unknown")
	check(not hit.core and not hit.spirit, "unknown attack kind hits nothing")


func test_actions(SwordActions) -> void:
	var actions = SwordActions.new()
	check(actions.action == "idle" and actions.charges == 2, "actions start idle with two dodges")
	check(actions.start("attack"), "attack starts from idle")
	check(not actions.start("sweep"), "another action cannot start while busy")
	check(not actions.advance(0.19), "attack does not impact during windup")
	check(actions.advance(0.02), "crossing attack impact emits once")
	check(not actions.advance(0.20), "attack impact does not repeat")
	check(not actions.advance(0.20) and actions.action == "idle", "attack returns to idle after recovery")
	check(not actions.start("bogus"), "unknown action is rejected")

	check(actions.start("counter"), "counter starts")
	actions.advance(0.08)
	check(actions.try_parry(Vector3.FORWARD, Vector3(0, 0, -1)), "counter parries a facing attack during guard window")
	check(not actions.try_parry(Vector3.FORWARD, Vector3(0, 0, -1)), "one counter parries at most once")
	actions.cancel()
	check(actions.start("counter"), "counter can restart after cancel")
	actions.advance(0.10)
	check(not actions.try_parry(Vector3.FORWARD, Vector3(0, 0, 1)), "counter cannot parry behind")
	actions.advance(0.19)
	check(not actions.try_parry(Vector3.FORWARD, Vector3(0, 0, -1)), "counter guard closes after 0.28 seconds")
	actions.cancel()

	check(actions.start("dodge") and actions.charges == 1, "dodge consumes one charge")
	check(not actions.is_invulnerable(), "dodge startup is vulnerable")
	actions.advance(0.04)
	check(actions.is_invulnerable(), "dodge invulnerability opens at 0.04 seconds")
	actions.advance(0.19)
	check(not actions.is_invulnerable(), "dodge invulnerability closes after 0.22 seconds")

	actions = SwordActions.new()
	check(actions.start("dodge") and actions.charges == 1, "recovery fixture consumes first charge")
	actions.cancel()
	check(actions.start("dodge") and actions.charges == 0, "second dodge consumes final charge")
	actions.cancel()
	check(not actions.start("dodge"), "dodge is rejected with no charges")
	actions.advance(2.39)
	check(actions.charges == 0, "first charge has not recovered early")
	actions.advance(0.01)
	check(actions.charges == 1, "first dodge charge recovers at 2.4 seconds")
	actions.advance(2.4)
	check(actions.charges == 2, "charges recover serially")
	actions.advance(20.0)
	check(actions.start("dodge"), "full charge time is not banked")
	actions.cancel()
	actions.advance(0.1)
	check(actions.charges == 1, "banked time cannot instantly restore a spent charge")
	actions.advance(-1.0)
	check(actions.charges == 1, "negative action delta is ignored")

	for fixture in [
		{"kind": "thrust", "before": 0.64, "cross": 0.02},
		{"kind": "sweep", "before": 0.79, "cross": 0.02},
		{"kind": "charged_slash", "before": 1.19, "cross": 0.02},
	]:
		actions.cancel()
		check(actions.start(fixture.kind), "%s starts" % fixture.kind)
		check(not actions.advance(fixture.before), "%s waits through telegraph" % fixture.kind)
		check(actions.advance(fixture.cross), "%s emits once when a frame crosses impact" % fixture.kind)
		check(not actions.advance(0.01), "%s impact does not repeat" % fixture.kind)
