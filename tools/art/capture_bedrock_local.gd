extends 'res://tools/art/capture_sculpt_base.gd'
## Form isolation first: three actual local views, no whole-island sweep.
func capture(name:String)->void:
 if name.ends_with('_close') or name.ends_with('_grass') or name.ends_with('_reverse'):
  await super.capture(name)
