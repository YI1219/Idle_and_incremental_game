extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Renderer=preload('res://scripts/terrain_editor/terrain_renderer.gd')
var viewport:SubViewport
func _initialize():call_deferred('run')
func picture()->Image:
 for i in 3:
  RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func run():
 viewport=SubViewport.new();viewport.size=Vector2i(384,384);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1
 viewport.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6;viewport.add_child(camera)
 camera.position=Vector3(0,3,8);camera.look_at(Vector3(0,2.4,0));camera.current=true
 var d=Data.new();d.apply_brush(Vector2.ZERO,3,'expand',false,1.5,3);d.end_stroke()
 d.apply_rock_brush(Vector3(.2,2.6,.3),1.15,'rock_add');d.end_stroke()
 var renderer=Renderer.new();viewport.add_child(renderer);renderer.configure(d);renderer.rebuild_all();renderer.set_process(false)
 var original=d.rocks.records()
 d.apply_brush(Vector2.ZERO,3,'raise',false,1.5,3);d.end_stroke()
 while renderer.has_pending_updates():renderer.flush_dirty(64)
 for chunk in renderer.chunks.values():
  for child in chunk.get_children():child.visible=child.name=='sculpted_rock'
 var images:Array[Image]=[]
 for phase:float in [0.0,.5,1.0]:
  RenderingServer.global_shader_parameter_set('terrain_morph_progress',phase)
  images.append(await picture())
 var changed:=0;var foreground:=0
 for y in 384:
  for x in 384:
   var a:Color=images[2].get_pixel(x,y)
   var mask_a=maxf(a.r,maxf(a.g,a.b))>.03
   if mask_a:foreground+=1
   for index in [0,1]:
    var b:Color=images[index].get_pixel(x,y)
    if mask_a!=(maxf(b.r,maxf(b.g,b.b))>.03):changed+=1
 var hit=renderer.pick(Vector3(.2,8,.3),Vector3.DOWN)
 var passed=changed<=2 and foreground>1000 and d.rocks.records()==original and not hit.is_empty() and hit.position.y>3.7
 print('SCULPT MORPH RENDER: foreground=',foreground,' changing_mask_pixels=',changed,' pick_y=',hit.get('position',Vector3.ZERO).y,' passed=',passed)
 RenderingServer.global_shader_parameter_set('terrain_morph_progress',1.0)
 renderer.free();viewport.queue_free()
 quit(0 if passed else 1)
