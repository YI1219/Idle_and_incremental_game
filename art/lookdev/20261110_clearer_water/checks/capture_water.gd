extends "res://tools/art/capture_lookdev.gd"
var water_view:int=0
func _frame(center:Vector2,height:float,yaw:float,pitch:float)->void:
 if water_view==3:
  super._frame(Vector2(-3.0,0.0),9.0,16.0,42.0)
  editor.camera.position.y+=3.5
 else:super._frame(center,height,yaw,pitch)
 water_view+=1
func _capture(label:String,time_progress:float)->void:
 if label!='cliff_close':await super._capture(label,time_progress)
