extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func settle(background: Node3D) -> void:
 for frame: int in 4:background.sync();await process_frame
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(2);return
 var view: SubViewport=SubViewport.new();view.size=Vector2i(2560,1440);view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var editor: Node3D=load("res://scenes/terrain_editor.tscn").instantiate();view.add_child(editor)
 editor.process_mode=Node.PROCESS_MODE_DISABLED;editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED;editor.set_native_preview(false);Engine.max_fps=0
 var background: Node3D=editor.get("background_view")
 check(background!=null,"the scene has a background renderer with an independent render budget")
 if background==null:editor.free();view.free();quit(1);return
 editor.set_native_preview(true)
 check(not background.is_active() and not background._warm_callback.is_valid(),"native override cancels the first warm-up before any draw")
 editor.set_native_preview(false);editor.runtime_power.refresh(true,true)
 check(not background.is_active() and not background._warm_callback.is_valid(),"minimizing cancels the first warm-up before any draw")
 editor.runtime_power.refresh(true,false);Engine.max_fps=0
 await settle(background)
 check(background.is_active(),"native2K balanced mode activates the background budget")
 if background.view==null:
  print("DIAGNOSTIC supported=",background._supported," radius=",background._clear_radius," near=",background._near_cloud_radius," safe=",background._safe_ordering()," morph=",editor.renderer.morph_progress," native=",editor.preview_quality.native," scale=",view.scaling_3d_scale," bounds=",background._bounds)
  editor.free();view.free();quit(1);return
 check(background.view.size==Vector2i(1280,720) and view.size==Vector2i(2560,1440),"only the background uses half the 3D width and height")
 check(background.view.use_hdr_2d and background.view.get_texture().get_image().get_format() in [Image.FORMAT_RGBH,Image.FORMAT_RGBAH],"intermediate background preserves linear HDR rather than tonemapping twice")
 var near_cloud: GeometryInstance3D=editor.landscape.get_child(0)
 var far_cloud: GeometryInstance3D=editor.landscape.get_child(2)
 check((near_cloud.layers & editor.camera.cull_mask)!=0 and (near_cloud.layers & background.camera.cull_mask)==0,"island-waist clouds remain in the full-resolution foreground")
 check((far_cloud.layers & editor.camera.cull_mask)==0 and (far_cloud.layers & background.camera.cull_mask)!=0,"far clouds render once in the background camera")
 view.size=Vector2i(2880,1620);background.sync()
 check(not background.is_active() and background._warm_callback.is_valid(),"active resize keeps the original background while the new image warms")
 await settle(background)
 check(background.is_active() and background.view.size==Vector2i(1440,810),"resized image activates only after its warm-up draw")
 view.size=Vector2i(2560,1440);await settle(background)
 editor.camera.position+=Vector3(1,2,3);editor.gameplay.time_system.set_progress(0.0,editor);background.sync()
 check(background.camera.global_transform==editor.camera.global_transform,"same-frame camera movement reaches the background camera")
 var palette_matches: bool=true
 for key: StringName in background._uniforms:
  palette_matches=palette_matches and background._background_material.get_shader_parameter(key)==background._original_sky.sky_material.get_shader_parameter(key)
 check(palette_matches,"same-frame manual lighting reaches the background sky")
 editor.set_native_preview(true)
 check(not background.is_active() and background.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"native quality restores full-resolution background and stops the extra viewport")
 var original_mask: int=editor.camera.cull_mask
 var original_layer: int=far_cloud.layers
 var original_sky: Material=editor.get_node("WorldEnvironment").environment.sky.sky_material
 editor.set_native_preview(false);await settle(background)
 editor.runtime_power.refresh(true,true)
 check(not background.is_active() and background.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"minimizing explicitly stops the offscreen viewport")
 editor.runtime_power.refresh(true,false);await settle(background)
 check(background.is_active(),"restoring the window resumes background rendering")
 view.size=Vector2i(1920,1080);editor.preview_quality.refresh();background.sync()
 check(not background.is_active() and background.view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"1080p internal rendering bypasses extra viewport overhead")
 view.size=Vector2i(2560,1440);editor.preview_quality.refresh();await settle(background)
 check(background.is_active(),"returning to a larger render budget reuses the background renderer")
 # A large foreground must not be composited in front of nearer distant mountains.
 editor.renderer._pick_bounds[Vector2i(999,999)]=AABB(Vector3(-1000,-6,-1000),Vector3(2000,8,2000))
 editor.renderer.terrain_published.emit();background.sync()
 check(not background.is_active(),"a foreground outside the safe distant scenery radius falls back to correct depth ordering")
 editor.renderer._pick_bounds.erase(Vector2i(999,999));editor.renderer.terrain_published.emit();await settle(background)
 check(background.is_active(),"a safe compact foreground may resume after the fallback")
 background.free()
 check(editor.camera.cull_mask==original_mask and far_cloud.layers==original_layer,"disposing the renderer restores culling masks and geometry layers")
 check(editor.get_node("WorldEnvironment").environment.sky.sky_material==original_sky,"disposing restores the original sky material")
 editor.free()
 var second: Node3D=load("res://scenes/terrain_editor.tscn").instantiate();view.add_child(second);second.process_mode=Node.PROCESS_MODE_DISABLED;second.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
 var warming: Node3D=second.background_view
 var mask: int=second.camera.cull_mask
 var far: GeometryInstance3D=second.landscape.get_child(2)
 var layer: int=warming._layers[far]
 warming.free()
 check(second.camera.cull_mask==mask and far.layers==layer,"disposing before the first draw restores all geometry layers")
 await process_frame
 check(second.camera.cull_mask==mask and far.layers==layer,"no late callback reactivates a disposed renderer")
 second.free();view.free();print("BACKGROUND RENDERER ",checks," checks, ",failures," failures");quit(1 if failures else 0)
