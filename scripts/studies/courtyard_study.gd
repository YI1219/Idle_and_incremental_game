extends Node3D
## Independent composition study. No economy, scene switching or character edits.
const Art := preload("res://scripts/studies/courtyard_palette.gd")
var terrain: Node3D
var house: Node3D
var art: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var environment: WorldEnvironment
var path_points := PackedVector3Array()
var plant_roots: Array[Vector3] = []
var layout_id := 0
var yaw := 0.40
var orbit_goal := 0.40
var distance := 20.5
var focus := Vector3(0,0.8,-0.7)
var reference: Node3D
var panel: CanvasLayer
var caption: Label
var dragging := false
var auto_orbit := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build_lighting()
	terrain = preload("res://scripts/world/river_terrain.gd").new()
	terrain.name="StudyTerrain"
	add_child(terrain)
	var cells: Array[Vector2i]=[]
	for x in range(-20,21):
		for z in range(-19,20): cells.append(Vector2i(x,z))
	terrain.configure(cells)
	terrain.water_cells.clear()
	terrain.bridge_cells.clear()
	terrain.rebuild()
	house=preload("res://scripts/world/cottage.gd").new()
	add_child(house)
	art=Art.new()
	add_child(art)
	art.attach(terrain,house)
	art.ground_material.shader=preload("res://shaders/studies/courtyard_ground.gdshader")
	camera=Camera3D.new()
	camera.fov=42
	camera.far=100
	camera.current=true
	add_child(camera)
	_build_reference()
	_build_ui()
	set_layout(0)
	update_camera()

func _build_lighting() -> void:
	environment=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("d5dfd8")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("c2d5d9")
	env.ambient_light_energy=.48
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.fog_enabled=true
	env.fog_light_color=Color("d5dfd8")
	env.fog_density=.002
	env.ssao_enabled=true
	env.ssao_radius=.65
	env.ssao_intensity=.75
	env.ssao_power=1.1
	environment.environment=env
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-35,0)
	sun.light_color=Color("fff0d2")
	sun.light_energy=1.05
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=55
	sun.light_angular_distance=2.2
	add_child(sun)

func _build_reference() -> void:
	reference=preload("res://assets/characters/qinglan/qinglan_garment_v06.glb").instantiate()
	reference.name="ScaleReference"
	add_child(reference)
	var animation := reference.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animation:
		for clip in animation.get_animation_list():
			if clip.ends_with("idle"):
				animation.play(clip)
				animation.seek(0,true)
				animation.pause()
				break

func set_layout(id: int) -> void:
	layout_id=clampi(id,0,1)
	_rng.seed=30921+layout_id
	art.clear_communities()
	plant_roots.clear()
	house.position=Vector3(-1.8,0,-3.3) if layout_id==0 else Vector3(3.0,0,-3.7)
	house.rotation.y=0.0 if layout_id==0 else -.75
	var door: Vector3=house.to_global(Vector3(0,0,2.2))
	var approach: Vector3=house.to_global(Vector3(0,0,4.0))
	path_points=PackedVector3Array([door,approach,Vector3(.5,0,2.4),Vector3(2.5,0,5),Vector3(1.2,0,8.5)])
	if layout_id==1:
		path_points=PackedVector3Array([door,approach,Vector3(-1.1,0,1.1),Vector3(-3.0,0,4.5),Vector3(-1.0,0,8.5)])
	art.set_paths(path_points)
	_place_path()
	var clusters: Array= [
		[Vector3(-6.2,0,-4.9),6.2,0], [Vector3(4.2,0,-6),5.9,1],
		[Vector3(-6.6,0,1.6),4.5,1], [Vector3(6.6,0,2.2),5.1,0],
		[Vector3(-3.8,0,5.5),0.,0], [Vector3(5.1,0,6.4),0.,1]]
	if layout_id==1:
		clusters=[[Vector3(-5.8,0,-5.3),6.3,1],[Vector3(7.5,0,-5.4),5.8,0],
		[Vector3(-7.1,0,1.5),4.8,0],[Vector3(5.9,0,4),5.4,1],
		[Vector3(.9,0,5.6),0.,0],[Vector3(-5.8,0,6.3),0.,1]]
	for c in clusters: _cluster(c[0],c[1],c[2])
	# Secondary groups form tapered edges around the open court, not a filled lawn.
	for at in [Vector3(-9,0,-8),Vector3(9,0,-9),Vector3(9,0,7),Vector3(-9,0,7)]:
		_cluster(at,4.3 if at.z<0 else 0.0,1)
	reference.position=approach+Vector3(.8,0,.5)
	reference.rotation.y=.45
	if caption: caption.text="疏庭 · 留白" if layout_id==0 else "移舍 · 同一套景物"

func clear_for_plant(at: Vector3, margin: float) -> bool:
	if not terrain.is_walkable(at): return false
	var local: Vector3=house.to_local(at)
	if local.x > -3.15-margin and local.x < 1.95+margin and local.z > -2.5-margin and local.z < 2.65+margin: return false
	for i in path_points.size()-1:
		var a:=Vector2(path_points[i].x,path_points[i].z)
		var b:=Vector2(path_points[i+1].x,path_points[i+1].z)
		var p:=Vector2(at.x,at.z)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<.9+margin:return false
	return true

func _cluster(origin: Vector3, tree_height: float, variant: int) -> void:
	if not clear_for_plant(origin,.4):return
	plant_roots.append(origin)
	if tree_height>0:
		art.add_model("CommonTree_4" if variant==0 else "CommonTree_5",origin,tree_height,_rng.randf()*TAU)
	art._patches.append(Vector4(origin.x,origin.z,2.4,.68))
	for i in 5:
		var a:=float(i)*1.1+.2
		var at:=origin+Vector3(cos(a)*1.35,0,sin(a)*.9)
		if clear_for_plant(at,.35):
			var id: String="Rock_Medium_1" if i<2 else "Bush_Common"
			art.add_model(id,at,_rng.randf_range(.4,.9),a)
	for i in 38:
		var a:=_rng.randf()*TAU
		var r:=sqrt(_rng.randf())*2.4
		var at:=origin+Vector3(cos(a)*r,0,sin(a)*r*.7)
		if not clear_for_plant(at,.16):continue
		var id: String="Grass_Wispy_Short" if i%3==0 else "Grass_Common_Short"
		art.add_model(id,at,_rng.randf_range(.18,.38),a)
		if i%11==0:art.add_model("Flower_3_Group",at+Vector3(.1,0,.1),.24,a)
	art._sync_contacts()

func _place_path() -> void:
	for i in path_points.size()-1:
		var start:=path_points[i]
		var finish:=path_points[i+1]
		var steps:=maxi(1,int(ceil(start.distance_to(finish)/1.4)))
		var direction:=finish-start
		for j in steps:
			var t: float=(float(j)+.5)/steps
			var at:=start.lerp(finish,t)
			var stone: Node3D=art.add_model("RockPath_Round_Thin",at,.055,0.0)
			# Fit preserved paving modules along the path, then rotate as a unit.
			var box: AABB=art._bounds(stone)
			stone.scale.x*=1.15/maxf(box.size.x,.001)
			stone.scale.z*=(direction.length()/steps*.96)/maxf(box.size.z,.001)
			stone.rotation.y=atan2(direction.x,direction.z)+(PI if j%2 else 0.0)

func update_camera() -> void:
	var pitch:=deg_to_rad(42)
	camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Q): orbit_goal-=delta*.9
	if Input.is_key_pressed(KEY_E): orbit_goal+=delta*.9
	if auto_orbit:orbit_goal+=delta*.20
	yaw=lerp_angle(yaw,orbit_goal,1.0-exp(-delta*8))
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: set_layout(0)
			KEY_2: set_layout(1)
			KEY_H: panel.visible=not panel.visible
			KEY_C: reference.visible=not reference.visible
			KEY_R: auto_orbit=not auto_orbit
			KEY_HOME:
				orbit_goal=.4
				distance=20.5
				focus=Vector3(0,.8,-.7)
			KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(10.,distance-1.)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(32.,distance+1.)
	if event is InputEventMouseMotion and dragging:orbit_goal-=event.relative.x*.006

func _build_ui() -> void:
	panel=CanvasLayer.new()
	add_child(panel)
	var box:=VBoxContainer.new()
	box.position=Vector2(30,25)
	panel.add_child(box)
	var title:=Label.new()
	title.text="识海 · 小庭"
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("f5f0df"))
	title.add_theme_color_override("font_shadow_color",Color("35483e"))
	title.add_theme_constant_override("shadow_offset_y",2)
	box.add_child(title)
	caption=Label.new()
	caption.add_theme_font_size_override("font_size",17)
	box.add_child(caption)
	var footer:=Label.new()
	footer.text="Q / E 或右键拖动 · 转镜头    滚轮 · 远近    1 / 2 · 换布局    R · 环看    C · 比例参照    H · 隐藏文字"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position=Vector2(30,675)
	footer.add_theme_font_size_override("font_size",15)
	footer.add_theme_color_override("font_color",Color("f5f0df"))
	footer.add_theme_color_override("font_shadow_color",Color("35483e"))
	footer.add_theme_constant_override("shadow_offset_y",2)
	panel.add_child(footer)
