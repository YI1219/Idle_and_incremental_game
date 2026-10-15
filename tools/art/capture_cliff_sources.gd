extends SceneTree
## Neutral inspection views of unchanged retained source meshes.
const OUT="res://art/review/terrain_fidelity/2026-10-15/cliff_refinement/"
var viewport:SubViewport
var camera:Camera3D
var reports:Array=[]
func _initialize():call_deferred("run")
func bounds(node:Node,pose:Transform3D,points:Array)->void:
 if node is Node3D:pose=pose*node.transform
 if node is MeshInstance3D:
  var box:AABB=pose*node.mesh.get_aabb()
  points.append(box.position);points.append(box.end)
  var material:=StandardMaterial3D.new();material.albedo_color=Color(.60,.61,.59);material.roughness=.9
  node.material_override=material
 for child in node.get_children():bounds(child,pose,points)
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1024,1024);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("e6e6df")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("d9e0e5");environment.environment.ambient_light_energy=.65
 viewport.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-28,0);light.light_energy=1.0;viewport.add_child(light)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;viewport.add_child(camera)
 for id:String in ["Rock_Medium_1","Rock_Medium_2"]:
  var path:="res://assets/nature/quaternius/"+id+".gltf"
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  if document.append_from_file(path,state)!=OK:push_error("Cannot load "+path);quit(1);return
  var model:=document.generate_scene(state);var points:Array=[];bounds(model,Transform3D.IDENTITY,points)
  var box:=AABB(points[0],Vector3.ZERO)
  for p:Vector3 in points:box=box.expand(p)
  model.position-=box.get_center();viewport.add_child(model)
  camera.size=maxf(box.size.x,maxf(box.size.y,box.size.z))*1.35
  var views={"front":Vector3(0,0,8),"left":Vector3(-8,0,0),"right":Vector3(8,0,0),"back":Vector3(0,0,-8),"quarter":Vector3(7,5,8)}
  for view:String in views:
   camera.position=views[view];camera.look_at(Vector3.ZERO)
   for i in 8:RenderingServer.force_draw(false);await process_frame
   RenderingServer.force_draw(false)
   var error:=viewport.get_texture().get_image().save_png(OUT+id+"_"+view+".png")
   if error!=OK:push_error("Capture failed");quit(1);return
  reports.append({"source":path,"source_bounds":str(box),"camera_size":camera.size,"views":views.keys(),"geometry":"Unchanged source geometry; neutral preview material override only"})
  viewport.remove_child(model);model.free()
 FileAccess.open(OUT+"source_views.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"\t"))
 print("CLIFF SOURCE INSPECTION: ",reports.size()," sources, five views each")
 quit()
