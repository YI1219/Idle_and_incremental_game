extends Object
## Closed-form land ledger. No nodes, no frames. Matches docs/design_v0_2/formula_audit.py.


static func ledger(area: int, protection: int = 0, seep: float = 10.0, base: int = 64, tax: float = 0.1, budget: float = 2.4) -> Dictionary:
	if mini(area, protection) < 0 or seep < 0.0 or base < 0 or tax < 0.0 or budget < 0.0:
		return {}
	var free: int = mini(area, base + protection)
	var uncovered: int = area - free
	var paid: int
	if tax <= 0.0:
		paid = uncovered
	else:
		paid = mini(uncovered, int(floor((minf(budget, seep) + 1e-9) / tax)))
	var maintenance: float = float(paid) * tax
	return {
		"free": free,
		"uncovered": uncovered,
		"paid": paid,
		"dormant": uncovered - paid,
		"maintenance": maintenance,
		"inflow": seep - maintenance,
	}


static func efficiency(coverage: float, floor_phi: float = 0.35, sensitivity: float = 1.0) -> float:
	if coverage < 0.0 or coverage > 1.0 or floor_phi < 0.0 or floor_phi > 1.0 or sensitivity < 0.0 or sensitivity > 1.0:
		push_error("Coverage, floor, sensitivity must be in [0, 1].")
		return 1.0
	return 1.0 - sensitivity * (1.0 - floor_phi) * (1.0 - coverage)


static func split_inflows(rates: PackedFloat64Array, total_tax: float) -> PackedFloat64Array:
	var total := 0.0
	for s in rates:
		total += s
	var out := PackedFloat64Array()
	out.resize(rates.size())
	if total <= 0.0:
		for i in rates.size():
			out[i] = 0.0
		return out
	for i in rates.size():
		out[i] = rates[i] - total_tax * rates[i] / total
	return out
