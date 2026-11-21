extends "res://art/lookdev/20261112_fps/checks/ablation.gd"
var original_codes: Dictionary={}
var gradient: String=FileAccess.get_file_as_string("res://art/lookdev/20261113_render_work/checks/hash_gradient.txt")
func variant(name: String) -> void:
 for id: int in frozen_shaders:
  var shader: Shader=frozen_shaders[id]
  if not original_codes.has(id):original_codes[id]=shader.code
  var code: String=original_codes[id]
  if name in ["steady","combined"]:code=code.replace("if(!terrain_transition_visible(FRAGCOORD.xy))discard;","")
  if name in ["hash","combined"]:
   var a: int=code.find(" float e=.10;")
   if a>=0:
    var end: int=code.find(" vec3 broad=",a)
    code=code.substr(0,a)+" vec3 g=stone_mineral_gradient(p);\n"+code.substr(end)
    var start: int=code.find("vec3 stone_mineral_normal(")
    code=code.substr(0,start)+gradient+"\n"+code.substr(start)
  if name in ["cloud","combined"] and shader.resource_path.ends_with("cloud_deck.gdshader"):
   code=code.replace("vec3 factors=sky_view_factors(view/distance);","float elevation=.5-(asin(clamp(normalize(view/distance).y,-1.0,1.0))+.471239)/.54;")
   code=code.replace("smoothstep(.04,.34,factors.x)","smoothstep(.04,.34,elevation)")
   code=code.replace("if(density<=0.0)discard;","if(density<=0.0)discard;\n vec3 factors=sky_view_factors(view/distance);")
  shader.code=code
func run() -> void:
 viewport=SubViewport.new();viewport.size=Vector2i(2560,1440);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.process_mode=Node.PROCESS_MODE_DISABLED;Engine.max_fps=0
 editor.set_native_preview(false);editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);editor.water_view.tick(.1);editor.water_view.flush();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
 for i: int in 40:RenderingServer.force_draw(false);await process_frame
 for size: Vector2i in [Vector2i(2560,1440),Vector2i(3840,2160)]:
  for name: String in ["base","steady","hash","cloud","combined","base_repeat"]:
   variant(name)
   viewport.scaling_3d_scale=1.0
   await sample(name,size)
 FileAccess.open("res://art/lookdev/20261113_render_work/checks/probe.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":rows,"method":"current balanced settings;fixedphase1.25/current water.1;15warm50explicit;no limiter/imageIO;candidate shader substitutions only in memory"},"\t"))
 editor.free();viewport.queue_free();quit()
