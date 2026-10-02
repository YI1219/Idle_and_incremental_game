extends RefCounted
## Tiny Y-fork: left token, right note, mist fail. No combat, no per-loot nodes.

const LOOT_CELL := Vector2i(-2, 4)
const NOTE_CELL := Vector2i(2, 6)
const DANGER_CELL := Vector2i(-2, 6)
const NOTE_TOPIC := "cloud_sign|basic"

var cells: Dictionary = {} ## Vector2i -> true
var active := false
var loot_present := true
var note_seen := false
var outcome := ""
var pending_fail := false
var last_event := ""


func _init() -> void:
	reset_map()


func reset_map() -> void:
	cells.clear()
	for c in [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
		Vector2i(-1, 3), Vector2i(1, 3),
		Vector2i(-2, 3), Vector2i(-2, 4), Vector2i(-2, 5), Vector2i(-2, 6),
		Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6),
	]:
		cells[c] = true
	active = false
	loot_present = true
	note_seen = false
	outcome = ""
	pending_fail = false
	last_event = ""


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


func cell_count() -> int:
	return cells.size()


func begin() -> void:
	active = true
	loot_present = true
	note_seen = false
	outcome = ""
	pending_fail = false
	last_event = ""


func branch_of(c: Vector2i) -> String:
	if c.x < 0:
		return "left"
	if c.x > 0:
		return "right"
	return "stem"


func touch(host: RefCounted, c: Vector2i) -> String:
	if not active:
		return ""
	if not has_cell(c):
		return "void"
	if c == DANGER_CELL:
		fail(host)
		return "fail"
	if c == NOTE_CELL:
		observe(host)
		return "observe"
	if c == LOOT_CELL:
		return pickup(host)
	last_event = ""
	return ""


func observe(host: RefCounted) -> void:
	note_seen = true
	(host.knowledge.get("discovered", {}) as Dictionary)[NOTE_TOPIC] = true
	last_event = "observe"


func pickup(host: RefCounted) -> String:
	if not loot_present:
		last_event = "gone"
		return "gone"
	var placed: String = host.try_overhead_sample()
	if placed != "ok":
		last_event = placed
		return placed
	loot_present = false
	last_event = "pickup"
	return "pickup"


func withdraw() -> String:
	if not active:
		return outcome if outcome != "" else "idle"
	active = false
	outcome = "withdrawn"
	last_event = "withdrawn"
	return "withdrawn"


func fail(host: RefCounted) -> PackedStringArray:
	var lost: PackedStringArray = host.expedition_fail()
	active = false
	outcome = "failed"
	pending_fail = true
	last_event = "fail"
	return lost


func consume_fail() -> bool:
	if not pending_fail:
		return false
	pending_fail = false
	return true


func note_in_journal(host: RefCounted) -> bool:
	return bool((host.knowledge.get("discovered", {}) as Dictionary).get(NOTE_TOPIC, false))


func questions(host: RefCounted) -> PackedStringArray:
	var now := "两手空空，走回入口也能撤离"
	if last_event == "overhead_full":
		now = "头顶满了，先入包再捡"
	elif not loot_present:
		now = "已经拿到浮空石"
	if note_in_journal(host):
		now += "；云气征兆已在手记"
	else:
		now += "；征兆还没记下"
	now += "；头顶 %d/%d" % [host.items.overhead.size(), host.items.overhead_k]
	return PackedStringArray([
		"此行：左路带回能研究的浮空石，右路记下云气征兆",
		"现在回去：%s" % now,
		"再往前：左路尽头是雾，会护体回村，只丢随身",
	])


func to_dict() -> Dictionary:
	return {
		"active": active,
		"loot_present": loot_present,
		"note_seen": note_seen,
		"outcome": outcome,
		"last_event": last_event,
	}


func from_dict(data: Dictionary) -> void:
	reset_map()
	active = bool(data.get("active", false))
	loot_present = bool(data.get("loot_present", true))
	note_seen = bool(data.get("note_seen", false))
	outcome = String(data.get("outcome", ""))
	last_event = String(data.get("last_event", ""))
	pending_fail = false
