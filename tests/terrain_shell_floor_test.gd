extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
func _initialize():call_deferred("run")
func run():
 var d=Data.new();d.make_preset(0);var initial=d.serialize();var failures=0
 for spec in [["default",Vector2.ZERO,0.0],["lower",Vector2(13,7),2.0],["contract",Vector2(3,7),2.2],["raise",Vector2(-13,2),2.3],["expand",Vector2(18,4),2.6]]:
  d.deserialize(initial)
  if spec[0]!="default":d.begin_stroke();d.apply_brush(spec[1],spec[2],spec[0],false,1.5,3);d.end_stroke()
  var f=Contours.new();f.refresh(d);var low=INF;var spikes=0
  for v in f.surfaces.cliff.vertices:
   low=minf(low,v.y)
   if v.y< Contours.KEEL_LIMIT-.08:spikes+=1
  print("SHELL FLOOR ",spec[0],": low=",low,", below intended floor=",spikes)
  if spikes:failures+=1
 quit(1 if failures else 0)
