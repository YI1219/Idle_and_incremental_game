extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func run()->void:
 var camera=load("res://scripts/terrain_editor/editor_camera.gd").new()
 root.add_child(camera)
 camera.set_process(false)
 var before:Vector3=camera.rotation
 var center:Vector2=camera._center
 var press:=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true
 camera._unhandled_input(press)
 var motion:=InputEventMouseMotion.new()
 motion.relative=Vector2(120,25)
 camera._unhandled_input(motion)
 camera.advance(1)
 check(absf(camera.rotation.y-before.y)>.1,"Right drag must orbit")
 check(is_equal_approx(camera.position.y,21.0),"Orbit preserves wheel-selected height")
 check(camera._center.is_equal_approx(center),"Orbit preserves terrain focus")
 var look:Vector3=-camera.global_basis.z
 var intercept:Vector3=camera.position+look*(-camera.position.y/look.y)
 check(Vector2(intercept.x,intercept.z).distance_to(center)<.02,"Orbit keeps center under view center")
 camera.cancel_input()
 var rotation:Vector3=camera.rotation
 camera._unhandled_input(motion);camera.advance(1)
 check(camera.rotation.is_equal_approx(rotation),"Focus loss releases orbit drag")
 camera.wheel(-2);camera.advance(1)
 check(camera.position.y<21 and camera.position.y>=camera.MIN_HEIGHT,"Zoom works after rotation")
 print("ORBIT failures=",failures)
 quit(1 if failures else 0)
