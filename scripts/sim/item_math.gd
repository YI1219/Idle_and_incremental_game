extends Object
## Item shapes, research work, topic keys. No nodes.


static func topic_key(topic_id: String, variant_id: String) -> String:
	return "%s|%s" % [topic_id, variant_id]


static func research_work(rarity: int, base_work: float = 2.0, rarity_mult: float = 1.5) -> float:
	return base_work * pow(rarity_mult, float(rarity))


static func rotate_shape(shape: Array, turns: int) -> Array:
	var result: Array = []
	for point in shape:
		result.append(Vector2i(int(point[0]) if point is Array else point.x, int(point[1]) if point is Array else point.y))
	for _i in range(posmod(turns, 4)):
		var rotated: Array = []
		for p in result:
			var v: Vector2i = p
			rotated.append(Vector2i(-v.y, v.x))
		result = rotated
	if result.is_empty():
		return result
	var min_x: int = (result[0] as Vector2i).x
	var min_y: int = (result[0] as Vector2i).y
	for p in result:
		var v: Vector2i = p
		min_x = mini(min_x, v.x)
		min_y = mini(min_y, v.y)
	var normalized: Array = []
	for p in result:
		var v: Vector2i = p
		normalized.append(Vector2i(v.x - min_x, v.y - min_y))
	return normalized


static func placed_cells(shape: Array, origin: Vector2i, turns: int) -> Array:
	var out: Array = []
	for p in rotate_shape(shape, turns):
		var v: Vector2i = p
		out.append(origin + v)
	return out


static func fits(shape: Array, origin: Vector2i, turns: int, occupied: Dictionary, width: int = 6, height: int = 5) -> bool:
	for cell in placed_cells(shape, origin, turns):
		var v: Vector2i = cell
		if v.x < 0 or v.y < 0 or v.x >= width or v.y >= height:
			return false
		if occupied.has(v):
			return false
	return true
