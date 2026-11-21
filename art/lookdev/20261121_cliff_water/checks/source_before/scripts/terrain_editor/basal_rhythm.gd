extends RefCounted
## Broad world-anchored unequal feet, shared by the wall and closed underside.
const VERSION:int=1
const Seed=preload('res://scripts/terrain_editor/geology_seed.gd')
static func offset(p:Vector2,seed_value:int)->float:
 var phase:Vector3=Seed.phase(seed_value)
 return .95*sin(p.x*.19+p.y*.11+phase.x)+.60*sin(-p.x*.09+p.y*.27+phase.z)
