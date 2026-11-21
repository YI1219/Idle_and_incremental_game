class_name CultivationState
extends RefCounted
## Pure typed progression state for the Sea of Consciousness (识海修行与扩界数据层).

signal state_changed
signal realm_breakthrough(new_realm_index: int, realm_name: String)
signal catch_logged(item_name: String, quality: String)

const EXPAND_QI_COST: float = 1.5
const CONTRACT_QI_REFUND: float = 1.2
const WATER_QI_COST: float = 0.8
const INITIAL_FREE_MARGIN: int = 64

const REALMS: Array[Dictionary] = [
	{
		"name": "炼气一层",
		"subtitle": "初窥识海",
		"bonus_cells": 0,
		"max_water_level": 7,
		"insight_target": 100.0,
		"qi_cap": 300.0,
		"base_qi_rate": 2.6,
	},
	{
		"name": "炼气圆满",
		"subtitle": "灵泉初辟",
		"bonus_cells": 90,
		"max_water_level": 7,
		"insight_target": 240.0,
		"qi_cap": 620.0,
		"base_qi_rate": 4.2,
	},
	{
		"name": "筑基初成",
		"subtitle": "神识开疆",
		"bonus_cells": 210,
		"max_water_level": 7,
		"insight_target": 520.0,
		"qi_cap": 1200.0,
		"base_qi_rate": 6.8,
	},
	{
		"name": "金丹大道",
		"subtitle": "洞天自成",
		"bonus_cells": 400,
		"max_water_level": 7,
		"insight_target": 1050.0,
		"qi_cap": 2400.0,
		"base_qi_rate": 10.5,
	},
	{
		"name": "元婴化神",
		"subtitle": "太虚壶天",
		"bonus_cells": 720,
		"max_water_level": 7,
		"insight_target": 2200.0,
		"qi_cap": 5000.0,
		"base_qi_rate": 16.0,
	},
]

var realm_index: int = 0
var spirit_qi: float = 160.0
var dao_insight: float = 0.0
var baseline_cells: int = 720
var total_fish_caught: int = 0
var perfect_catches: int = 0
var meditation_seconds: float = 0.0
var resonance_multiplier: float = 1.0
var active_resonances: Array[String] = []
var discoveries: Dictionary = {}

func sync_baseline(initial_cell_count: int) -> void:
	baseline_cells = maxi(initial_cell_count, 320)
	spirit_qi = clampf(spirit_qi, 0.0, current_qi_cap())
	state_changed.emit()

func realm_data() -> Dictionary:
	return REALMS[clampi(realm_index, 0, REALMS.size() - 1)]

func realm_title() -> String:
	var r: Dictionary = realm_data()
	return "%s · %s" % [String(r["name"]), String(r["subtitle"])]

func max_land_cells() -> int:
	var r: Dictionary = realm_data()
	return baseline_cells + INITIAL_FREE_MARGIN + int(r["bonus_cells"])

func max_water_level() -> int:
	var r: Dictionary = realm_data()
	return int(r["max_water_level"])

func current_qi_cap() -> float:
	var r: Dictionary = realm_data()
	return float(r["qi_cap"])

func current_insight_target() -> float:
	var r: Dictionary = realm_data()
	return float(r["insight_target"])

func base_qi_rate() -> float:
	var r: Dictionary = realm_data()
	return float(r["base_qi_rate"]) * resonance_multiplier

func is_max_realm() -> bool:
	return realm_index >= REALMS.size() - 1

func can_breakthrough() -> bool:
	return not is_max_realm() and dao_insight >= current_insight_target()

func try_breakthrough() -> bool:
	if not can_breakthrough():
		return false
	var cost: float = current_insight_target()
	dao_insight = maxf(0.0, dao_insight - cost)
	realm_index += 1
	spirit_qi = minf(current_qi_cap(), spirit_qi + current_qi_cap() * 0.35)
	realm_breakthrough.emit(realm_index, realm_title())
	state_changed.emit()
	return true

func add_qi(amount: float) -> void:
	if amount <= 0.0:
		return
	spirit_qi = clampf(spirit_qi + amount, 0.0, current_qi_cap())

func spend_qi(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if spirit_qi + 0.0001 < amount:
		return false
	spirit_qi = maxf(0.0, spirit_qi - amount)
	return true

func add_insight(amount: float) -> void:
	if amount <= 0.0:
		return
	var cap: float = current_insight_target() * 1.5
	dao_insight = clampf(dao_insight + amount, 0.0, cap)

func tick_passive(delta: float, time_qi_bonus: float = 1.0) -> void:
	if delta <= 0.0:
		return
	add_qi(base_qi_rate() * time_qi_bonus * delta)

func affordable_expand_cap(current_cells: int) -> int:
	var quota_cap: int = max_land_cells()
	if current_cells >= quota_cap:
		return quota_cap
	var affordable_new: int = floori(spirit_qi / EXPAND_QI_COST)
	return mini(quota_cap, current_cells + maxi(0, affordable_new))

func reconcile_terrain_delta(before_cells: int, after_cells: int, before_wet: int, after_wet: int, tool_name: String) -> float:
	var net_qi_delta: float = 0.0
	if tool_name == "expand" and after_cells > before_cells:
		var added: int = after_cells - before_cells
		var cost: float = float(added) * EXPAND_QI_COST
		spirit_qi = maxf(0.0, spirit_qi - cost)
		net_qi_delta = -cost
	elif tool_name == "contract" and after_cells < before_cells:
		var removed: int = before_cells - after_cells
		var refund: float = float(removed) * CONTRACT_QI_REFUND
		add_qi(refund)
		net_qi_delta = refund
	elif tool_name == "water" and after_wet > before_wet:
		var wet_added: int = after_wet - before_wet
		var water_cost: float = float(wet_added) * WATER_QI_COST
		spirit_qi = maxf(0.0, spirit_qi - water_cost)
		net_qi_delta = -water_cost
	if net_qi_delta != 0.0:
		state_changed.emit()
	return net_qi_delta

func record_catch(item_name: String, quality: String, qi_gain: float, insight_gain: float) -> void:
	total_fish_caught += 1
	if quality == "perfect":
		perfect_catches += 1
	var prev: int = int(discoveries.get(item_name, 0))
	discoveries[item_name] = prev + 1
	add_qi(qi_gain)
	add_insight(insight_gain)
	catch_logged.emit(item_name, quality)
	state_changed.emit()

func serialize() -> Dictionary:
	return {
		"realm_index": realm_index,
		"spirit_qi": snappedf(spirit_qi, 0.01),
		"dao_insight": snappedf(dao_insight, 0.01),
		"baseline_cells": baseline_cells,
		"total_fish_caught": total_fish_caught,
		"perfect_catches": perfect_catches,
		"meditation_seconds": snappedf(meditation_seconds, 0.1),
		"discoveries": discoveries.duplicate(),
	}

func deserialize(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	realm_index = clampi(int(payload.get("realm_index", 0)), 0, REALMS.size() - 1)
	baseline_cells = maxi(64, int(payload.get("baseline_cells", baseline_cells)))
	spirit_qi = clampf(float(payload.get("spirit_qi", 160.0)), 0.0, current_qi_cap())
	dao_insight = maxf(0.0, float(payload.get("dao_insight", 0.0)))
	total_fish_caught = maxi(0, int(payload.get("total_fish_caught", 0)))
	perfect_catches = maxi(0, int(payload.get("perfect_catches", 0)))
	meditation_seconds = maxf(0.0, float(payload.get("meditation_seconds", 0.0)))
	var disc: Variant = payload.get("discoveries", {})
	discoveries = (disc as Dictionary).duplicate() if disc is Dictionary else {}
	state_changed.emit()
