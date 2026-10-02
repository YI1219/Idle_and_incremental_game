extends RefCounted
## Unique item instances. Locations are mutually exclusive.

const ItemMath := preload("res://scripts/sim/item_math.gd")

var items: Dictionary = {} ## id -> Dictionary
var next_serial: int = 1
var overhead: PackedStringArray = PackedStringArray()
var bag_width: int = 6
var bag_height: int = 5
var overhead_k: int = 3
var collection_id: String = ""


func configure(cfg: RefCounted) -> void:
	var bag: Dictionary = cfg.raw.get("backpack", {})
	bag_width = int(bag.get("columns", 6))
	bag_height = int(bag.get("rows", 5))
	overhead_k = int(cfg.raw.get("loot", {}).get("overhead_slots", 3))


func spawn_starter() -> String:
	return spawn({
		"def_id": "float_core",
		"topic_id": "protection_quota",
		"variant": "basic",
		"rarity": 1,
		"portable": true,
		"stack": 1,
		"stack_max": 1,
		"shape": [[0, 0], [1, 0], [0, 1], [1, 1]],
		"reward": "protection_16",
		"location": "world",
		"revealed": true,
		"auto_sale_blocked": false,
		"recipe_blocked": false,
	})


func spawn(fields: Dictionary) -> String:
	var id := "it_%d" % next_serial
	next_serial += 1
	var item: Dictionary = fields.duplicate(true)
	item["id"] = id
	item["location"] = String(item.get("location", "world"))
	item["bag_x"] = int(item.get("bag_x", -1))
	item["bag_y"] = int(item.get("bag_y", -1))
	item["bag_rot"] = int(item.get("bag_rot", 0))
	items[id] = item
	return id


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func topic_of(id: String) -> String:
	var item: Dictionary = get_item(id)
	if item.is_empty():
		return ""
	return ItemMath.topic_key(String(item["topic_id"]), String(item["variant"]))


func count_all() -> int:
	return items.size()


func ids_in(location: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in items.keys():
		if String(items[id]["location"]) == location:
			out.append(String(id))
	return out


func first_in(location: String) -> String:
	var found: PackedStringArray = ids_in(location)
	return found[0] if found.size() > 0 else ""


func move(id: String, location: String) -> String:
	if not items.has(id):
		return "missing"
	if location == "collection" and collection_id != "" and collection_id != id:
		return "collection_full"
	var item: Dictionary = items[id]
	_leave_location(id, String(item["location"]))
	item["location"] = location
	if location != "bag":
		item["bag_x"] = -1
		item["bag_y"] = -1
	if location == "collection":
		if collection_id != "" and collection_id != id:
			return "collection_full"
		collection_id = id
		item["auto_sale_blocked"] = true
		item["recipe_blocked"] = true
	return "ok"


func assign_overhead(id: String) -> String:
	if not items.has(id):
		return "missing"
	if not bool(items[id].get("portable", true)):
		return "not_portable"
	if overhead.size() >= overhead_k:
		return "overhead_full"
	var moved := move(id, "overhead")
	if moved != "ok":
		return moved
	overhead.append(id)
	return "ok"


func try_pack(id: String) -> String:
	if not items.has(id):
		return "missing"
	if String(items[id]["location"]) == "overhead" and not bool(items[id].get("revealed", true)):
		return "unrevealed"
	var occupied := _bag_occupied(id)
	var shape: Array = items[id].get("shape", [[0, 0]])
	for y in bag_height:
		for x in bag_width:
			for rot in 4:
				if ItemMath.fits(shape, Vector2i(x, y), rot, occupied, bag_width, bag_height):
					var prev: String = String(items[id]["location"])
					_leave_location(id, prev)
					items[id]["location"] = "bag"
					items[id]["bag_x"] = x
					items[id]["bag_y"] = y
					items[id]["bag_rot"] = rot
					return "ok"
	return "no_fit"


func pack_all_overhead() -> PackedStringArray:
	var results := PackedStringArray()
	var copy: PackedStringArray = overhead.duplicate()
	for id in copy:
		results.append("%s:%s" % [id, try_pack(id)])
	return results


func wipe_carried() -> PackedStringArray:
	var lost := PackedStringArray()
	for id in overhead:
		lost.append(id)
	for id in ids_in("bag"):
		lost.append(id)
	for id in lost:
		items.erase(id)
	overhead = PackedStringArray()
	return lost


func carried_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in overhead:
		out.append(id)
	for id in ids_in("bag"):
		out.append(id)
	return out


func to_dict() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"next_serial": next_serial,
		"overhead": Array(overhead),
		"collection_id": collection_id,
		"bag_width": bag_width,
		"bag_height": bag_height,
		"overhead_k": overhead_k,
	}


func from_dict(data: Dictionary) -> void:
	items = (data.get("items", {}) as Dictionary).duplicate(true)
	next_serial = int(data.get("next_serial", 1))
	overhead = PackedStringArray()
	for id in data.get("overhead", []):
		overhead.append(String(id))
	collection_id = String(data.get("collection_id", ""))
	bag_width = int(data.get("bag_width", 6))
	bag_height = int(data.get("bag_height", 5))
	overhead_k = int(data.get("overhead_k", 3))


func _leave_location(id: String, previous: String) -> void:
	if previous == "overhead":
		var next_oh := PackedStringArray()
		for other in overhead:
			if other != id:
				next_oh.append(other)
		overhead = next_oh
	if previous == "collection" and collection_id == id:
		collection_id = ""


func _bag_occupied(except_id: String) -> Dictionary:
	var occupied: Dictionary = {}
	for id in items.keys():
		if id == except_id:
			continue
		var item: Dictionary = items[id]
		if String(item["location"]) != "bag":
			continue
		for cell in ItemMath.placed_cells(item.get("shape", [[0, 0]]), Vector2i(int(item["bag_x"]), int(item["bag_y"])), int(item["bag_rot"])):
			occupied[cell] = id
	return occupied
