extends 'res://tests/terrain_rock_sculpt_test.gd'
## A full-strength bounded cut is one deterministic removal, rather than
## repeated density blending that changes its shape every time it is stamped.
func run():
 var d=Data.new()
 stroke(d,'rock_add',Vector3.ZERO,3.0)
 var initial=d.serialize()
 var outside:float=d.rocks.value_at(Vector3(2.5,1.25,0))
 stroke(d,'rock_plane',Vector3(0,1,0),2.0,Vector3.UP)
 check(d.rocks.value_at(Vector3(1.75,1.25,0))>0,'Cut removes rock above its selected plane in the outer brush region')
 check(d.rocks.value_at(Vector3(1.75,.75,0))<0,'The matching point below the plane stays solid')
 check(d.rocks.value_at(Vector3(2.5,1.25,0))==outside,'Distant rock beyond the bounded cutter is untouched')
 var once=d.serialize()
 stroke(d,'rock_plane',Vector3(0,1,0),2.0,Vector3.UP)
 check(d.serialize()==once,'Stamping the same full-strength plane twice does not deepen its transition')
 check(d.undo() and d.serialize()==initial,'One effective plane stroke undoes exactly after an inert repeat')
 check(d.redo() and d.serialize()==once,'Redo restores the deterministic cut')
 var copy=Data.new()
 check(copy.deserialize(JSON.parse_string(JSON.stringify(once))) and copy.serialize()==once,'Cut samples save and reopen without reapplying a brush')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'bounded plane',.001)
 print('ROCK PLANE: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
