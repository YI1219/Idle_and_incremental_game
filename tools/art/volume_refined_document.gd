extends 'res://scripts/terrain_volume/patch_document.gd'
## Local comparison only. Inherited save validation instantiates this script,
## so it cannot replay the refined density overrides against the old source.
const REFINED := 'res://assets/terrain/volume_patch/source_rock_lower_return_v1.res'
const Profile := preload('res://tools/art/volume_bank_profile.gd')
func load_preset() -> bool:
	if not ResourceLoader.exists(REFINED): return false
	var base := Base.new()
	if not base.configure(load(REFINED)): return false
	base.source_sha256 = FileAccess.get_sha256(REFINED)
	data = Data.new()
	data.rocks.base = base
	Profile.apply_to(self)
	return true
