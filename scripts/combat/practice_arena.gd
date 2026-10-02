extends Node3D
const Rules := preload("res://scripts/combat/action_state.gd")
const Ward := preload("res://scripts/combat/ward_state.gd")
const Geometry := preload("res://scripts/combat/combat_geometry.gd")
var ward_state := Ward.new()
var health := 100.0
var completed := 0
var notice := "J / 左键挥剑，K / 右键拆招，空格身法"
var _body: Node3D
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _time := 0.0
var _flash := 0.0
var _respawn := 0.0
var _telegraph := -1.0
var _cooldown := 1.8
var _effects: Node3D

func _ready() -> void:
	add_to_group("combat_arena")
	_body = Node3D.new()
	_body.position = Vector3(-3.8,0,1.65)
	add_child(_body)
	_mat = _material(Color("78949a"))
	_cylinder(_body, Vector3(0,.35,0), .20, .24, .7, _mat)
	_cylinder(_body, Vector3(0,.78,0), .15, .17, .18, _material(Color("d4c6a6")))
	_cylinder(_body, Vector3(0,.03,0), .36, .36, .06, _material(Color("9aab98")))
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.07
	torus.outer_radius = 1.13
	torus.rings = 40
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.position.y = .03
	_ring.material_override = _material(Color("e9ba6c"))
	_body.add_child(_ring)
	_ring.hide()
	var col := StaticBody3D.new()
	col.collision_layer = 1
	col.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .23
	cylinder.height = .85
	shape.shape = cylinder
	shape.position.y = .425
	col.add_child(shape)
	_body.add_child(col)
	_effects = Node3D.new()
	add_child(_effects)

func target_position() -> Vector3:
	return _body.global_position

func _process(delta: float) -> void:
	var island := get_tree().get_first_node_in_group("island_shell")
	if island and island.build_mode:
		return
	if not SpaceState.is_courtyard():
		_telegraph = -1.0
		_ring.hide()
		return
	var space := get_tree().get_first_node_in_group("space_controller")
	if space and space.is_input_blocked():
		return
	var ui := get_tree().get_first_node_in_group("preview_menu")
	if ui and ui.is_open(): return
	_time += delta
	_flash = maxf(0.0,_flash-delta)
	_mat.albedo_color = Color("eddbb1") if _flash>0 else Color("78949a")
	_body.rotation.z = sin(_time*40.0)*_flash*.15
	if _respawn>0.0:
		_respawn-=delta
		if _respawn<=0.0:
			health=100.0
			ward_state = Ward.new()
			_body.scale=Vector3.ONE
			notice="灵偶已复原，可以继续试招"
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player==null:
		return
	ward_state.advance(delta, Geometry.pressure_from(_body.global_position,player.global_position,6.0))
	_cooldown -= delta
	if _telegraph>=0.0:
		_telegraph += delta
		_ring.scale = Vector3.ONE * lerpf(.45,1.0, minf(1,_telegraph/.7))
		if _telegraph>=.7:
			if player.global_position.distance_to(_body.global_position)<1.3:
				player.receive_hit()
			_ring.hide()
			_telegraph=-1.0
			_cooldown=2.0
	elif _cooldown<=0 and player.global_position.distance_to(_body.global_position)<1.8:
		_telegraph=0
		_ring.show()

func strike(player: Node3D) -> void:
	if not SpaceState.is_courtyard():
		return
	_arc(player.global_position, player.facing())
	if _respawn>0 or not Rules.in_range(player.global_position,player.facing(),_body.global_position):
		return
	var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.65, _body.global_position+Vector3.UP*.65,1)
	var result := get_world_3d().direct_space_state.intersect_ray(ray)
	if not result.is_empty() and not _body.is_ancestor_of(result.collider):
		return
	ward_state.receive_attack(25,8,0)
	health=ward_state.health
	_flash=.22
	notice="剑招命中 · 灵偶气血 %.0f / 护体 %.0f" % [health,ward_state.ward]
	if health<=0:
		completed+=1
		_respawn=2.5
		_body.scale=Vector3(.8,.2,.8)
		_ring.hide()
		_telegraph=-1
		notice="试招完成 · 灵偶稍后复原"

func _arc(origin: Vector3, direction: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var yaw := atan2(direction.x,direction.z)
	for i in 18:
		var a := yaw-1.05+i*2.1/18
		var b := yaw-1.05+(i+1)*2.1/18
		var points := [Vector3(sin(a)*.8,.53,cos(a)*.8),Vector3(sin(b)*1.3,.62,cos(b)*1.3),Vector3(sin(a)*1.3,.62,cos(a)*1.3),Vector3(sin(a)*.8,.53,cos(a)*.8),Vector3(sin(b)*.8,.53,cos(b)*.8),Vector3(sin(b)*1.3,.62,cos(b)*1.3)]
		for p in points:st.add_vertex(p)
	st.generate_normals()
	var effect := MeshInstance3D.new()
	effect.mesh = st.commit()
	var mat := _material(Color(.78,.9,.85,.72))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	effect.material_override = mat
	_effects.add_child(effect)
	effect.global_position = origin
	var tween := create_tween().set_parallel()
	tween.tween_property(effect,"scale",Vector3.ONE*1.25,.22)
	tween.tween_property(mat,"albedo_color:a",0.0,.22)
	tween.chain().tween_callback(effect.queue_free)

func _material(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.88
	return m

func _cylinder(parent: Node3D,at: Vector3,top: float,bottom: float,height: float,mat: Material) -> void:
	var mesh:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=top
	cylinder.bottom_radius=bottom
	cylinder.height=height
	cylinder.radial_segments=8
	mesh.mesh=cylinder
	mesh.material_override=mat
	mesh.position=at
	parent.add_child(mesh)

func pressure_at(at: Vector3) -> float:
	return Geometry.pressure_from(at,target_position(),6.0) if _respawn <= 0.0 else 0.0

func reset_after_defeat() -> void:
	_cooldown = 3.5
	_telegraph = -1.0
	_ring.hide()
