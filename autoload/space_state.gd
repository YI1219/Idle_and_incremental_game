extends Node
## Tiny location state for the Don't Starve camera and doorway teleport.
## Production, inventory, combat and saves do not live here.

signal space_changed(previous: String, current: String)

const HOME_ORIGIN := Vector3(1024.0, 0.0, 1024.0)
const EXPLORE_ORIGIN := Vector3(2048.0, 0.0, 0.0)
const ENTRY_WIDTH := 1.8
const GATE := Vector3(0.5, 0.0, 3.85)

var space_id := "outside"
var player_x := 0.0
var player_z := 2.4
var house_door := Vector3(0.0, 0.0, 0.0)


func is_inside() -> bool:
	return space_id == "inside"


func is_exploring() -> bool:
	return space_id == "explore"


func is_courtyard() -> bool:
	return space_id == "outside"


func home_origin() -> Vector3:
	return HOME_ORIGIN


func explore_origin() -> Vector3:
	return EXPLORE_ORIGIN


func explore_arrival() -> Vector3:
	return EXPLORE_ORIGIN + Vector3(0.5, 0.0, 1.35)


func gate_return() -> Vector3:
	return Vector3(0.5, 0.0, 2.55)


func exit_position() -> Vector3:
	return house_door + Vector3(0.0, 0.0, 1.3)


func home_arrival(offset_x: float = 0.0) -> Vector3:
	return HOME_ORIGIN + Vector3(offset_x, 0.0, 4.55)


func enter(next: String) -> void:
	if next not in ["outside", "inside", "explore"] or next == space_id:
		return
	var previous := space_id
	space_id = next
	space_changed.emit(previous, space_id)
