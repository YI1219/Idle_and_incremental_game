extends "res://tools/art/capture_lookdev.gd"
class QualityClock:
 extends "res://scripts/gameplay/systems/time_solar_system.gd"
 func apply_to_scene(scene: Node3D, _immediate: bool=true) -> void:super.apply_to_scene(scene,true)
var views: Array[SubViewport]=[]
var scenes: Array[Node3D]=[]
func diff(a: Image,b: Image) -> Dictionary:
 var sa: Image=a.duplicate();var sb: Image=b.duplicate();sa.resize(160,90,Image.INTERPOLATE_LANCZOS);sb.resize(160,90,Image.INTERPOLATE_LANCZOS)
 var aa: PackedByteArray=sa.get_data();var bb: PackedByteArray=sb.get_data();var total: int=0;var maximum: int=0;var changed: int=0
 for i: int in aa.size():
  var e: int=absi(int(aa[i])-int(bb[i]));total+=e;maximum=maxi(maximum,e)
  if e>0:changed+=1
 return {"mean":float(total)/aa.size(),"max":maximum,"changed_channels":changed}
func run() -> void:
 output="res://art/lookdev/20261113_render_work/dynamic";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 Engine.max_fps=0
 for old: bool in [true,false]:
  var view: SubViewport=SubViewport.new();view.size=Vector2i(640,360);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
  editor=load("res://scenes/terrain_editor.tscn").instantiate();view.add_child(editor);scenes.append(editor);editor.process_mode=Node.PROCESS_MODE_DISABLED
  editor.set_native_preview(false);editor.hud.hide();editor.brush.hide();_frame(Vector2(-2,-1),32,16,30);_freeze_node(editor)
  if old:editor.gameplay.time_system=QualityClock.new()
  editor.gameplay.time_system.set_progress(.84,editor)
 for i: int in 24:await RenderingServer.frame_post_draw
 var control: Dictionary=diff(views[0].get_texture().get_image(),views[1].get_texture().get_image())
 var rows: Array[Dictionary]=[]
 for step: int in 168:
  var jump: bool=step in [120,136,152]
  for scene: Node3D in scenes:
   if jump:scene.gameplay.time_system.set_progress({120:.29,136:0.0,152:.76}[step],scene)
   scene.gameplay.time_system.tick(1.0/60.0,scene)
  await RenderingServer.frame_post_draw
  var a: Image=views[0].get_texture().get_image();var b: Image=views[1].get_texture().get_image()
  var row: Dictionary=diff(a,b);row.step=step;row.jump=jump;row.progress=scenes[1].gameplay.time_system.day_progress;row.sky_mode=scenes[1].get_node("WorldEnvironment").environment.sky.process_mode
  rows.append(row)
  if step in [0,7,31,63,95,119,120,121,127,135,136,137,143,151,152,153,159,167]:
   a.save_png(output.path_join("%03d_before.png"%step));b.save_png(output.path_join("%03d_after.png"%step))
 FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE).store_string(JSON.stringify({"control":control,"frames":rows,"resolution":[640,360],"metric_resolution":[160,90],"dt":1.0/60.0,"notes":"two independent worlds,same deterministic frozen phase,normal draw;120 slow daylight frames then three manual preset jumps;QUALITY baseline vs production scheduling"},"\t"))
 print("DYNAMIC control=",control," frames=",rows.size())
 for scene: Node3D in scenes:scene.free()
 for view: SubViewport in views:view.free()
 quit()
