extends 'res://tools/art/pack_refined_volume.gd'
func locations() -> Array[String]:
	var work := 'res://art/work/volume_modules/2026-10-20/'
	return [work,work+'three_rock_assembly_v1.glb','res://assets/terrain/volume_patch/source_rock_modules_v1.res']
func triangle_file() -> String:
	return locations()[0]+'assembled.bin'
func preset_metadata() -> Dictionary:
	# Authored lower planting terrain in this multi-level source. Other source
	# presets retain the inspected2.85m default; this is not a global art rule.
	return {'planting_min_y':2.4}
