class_name Blob47
extends RefCounted
## Eight-neighbour blob masks reduced to the canonical 47 valid shapes.

const N := 1
const E := 2
const S := 4
const W := 8
const NE := 16
const SE := 32
const SW := 64
const NW := 128

const OFFSETS := {
	N: Vector2i(0, -1), E: Vector2i(1, 0),
	S: Vector2i(0, 1), W: Vector2i(-1, 0),
	NE: Vector2i(1, -1), SE: Vector2i(1, 1),
	SW: Vector2i(-1, 1), NW: Vector2i(-1, -1),
}


static func normalize(mask: int) -> int:
	mask &= 0xff
	if (mask & (N | E)) != (N | E):
		mask &= ~NE
	if (mask & (E | S)) != (E | S):
		mask &= ~SE
	if (mask & (S | W)) != (S | W):
		mask &= ~SW
	if (mask & (W | N)) != (W | N):
		mask &= ~NW
	return mask


static func from_cells(cell: Vector2i, cells: Dictionary) -> int:
	var mask := 0
	for bit: int in OFFSETS:
		if cells.has(cell + OFFSETS[bit]):
			mask |= bit
	return normalize(mask)


static func mirror_x(mask: int) -> int:
	var result := mask & (N | S)
	if mask & E: result |= W
	if mask & W: result |= E
	if mask & NE: result |= NW
	if mask & NW: result |= NE
	if mask & SE: result |= SW
	if mask & SW: result |= SE
	return normalize(result)

