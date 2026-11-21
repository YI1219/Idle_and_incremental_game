extends "res://tools/art/capture_lookdev.gd"
var cavity_view:int=0
func _frame(center:Vector2,height:float,yaw:float,pitch:float)->void:
 match cavity_view:
  0:super._frame(Vector2(3.0,.8),7.0,20.0,42.0)
  1:super._frame(center,height,yaw,pitch)
  2:super._frame(Vector2(3.0,.8),7.0,67.0,36.0)
  3:super._frame(Vector2(3.0,.8),7.0,-27.0,36.0)
  4:super._frame(Vector2(3.0,.8),7.0,196.0,36.0)
 if cavity_view!=1:editor.camera.position.y+=2.5
 cavity_view+=1
