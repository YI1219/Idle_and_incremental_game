extends 'res://tests/terrain_rock_sculpt_test.gd'
## A lower terrace must not turn the higher terrace into a vertical extrusion.
## Old saved base profiles remain geometrically unchanged when reopened.
func run():
 var d=Data.new()
 for z in range(-5,5):
  for x in range(-8,8):d.cells[Vector2i(x,z)]={'height':3.5 if x<0 else 1.5,'water':-1}
 check(d.set_sculpt_base(true),'Two-terrace layout converts through the ordinary player API')
 check(d.rocks.value_at(Vector3(-4,3.25,4.25))<0,'High terrace retains its original upper shoulder and footprint')
 check(d.rocks.value_at(Vector3(-4,0,4.25))>0,'High side returns inward below its own shoulder despite the lower terrace')
 check(d.rocks.value_at(Vector3(4,0,4.25))<0,'Low terrace retains the appropriate shallower side profile')
 check(d.rocks.value_at(Vector3(0,-2,0))<0,'Both terraces retain a shared solid core above the common bottom')
 var saved=d.serialize();var copy=Data.new()
 check(copy.deserialize(JSON.parse_string(JSON.stringify(saved))) and copy.ensure_sculpt_base() and copy.rocks.value_at(Vector3(-4,0,4.25))>0,'A new saved profile reopens with the same higher-side recession')
 var legacy:Dictionary={'version':3,'seed':7301,'cells':saved.cells,'sculpt_base':true,'rocks':[]}
 var old=Data.new()
 check(old.deserialize(legacy) and old.ensure_sculpt_base() and old.rocks.value_at(Vector3(-4,0,4.25))<0,'Existing version3 files retain their previous lower-terrace-derived body')
 check(old.serialize()==legacy,'Unedited legacy profile roundtrip preserves its saved representation')
 var before=copy.serialize();var bad:Dictionary=saved.duplicate(true);bad.sculpt_profile='unknown'
 check(not copy.deserialize(bad) and copy.serialize()==before,'Unknown body profile is rejected before changing current data')
 var missing_profile:Dictionary=saved.duplicate(true);missing_profile.erase('sculpt_profile')
 check(not copy.deserialize(missing_profile) and copy.serialize()==before,'A new-format file missing its body profile cannot silently load as the old shape')
 var steep=Data.new()
 for z in range(-4,4):
  for x in range(-4,1):steep.cells[Vector2i(x,z)]={'height':12.0 if x<0 else 1.5,'water':-1}
 check(steep.set_sculpt_base(true),'A valid tall cliff next to a narrow low shelf converts')
 var missing:=0
 for x:float in [.25,.5,.75]:
  var height:float=steep.rocks.height_at(Vector2(x,.5))
  if is_nan(height) or absf(height-1.5)>.01:missing+=1
 check(missing==0 and steep.rocks.value_at(Vector3(.5,1.49,.5))<0,'Nearby high land cannot erase the original lower shelf cap')
 inspect(load('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(d.rocks),d.rocks,'local terrace profile',.001)
 print('SCULPT PROFILE: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
