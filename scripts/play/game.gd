extends Node3D
## Playable art and interaction demo, retaining the existing simulation kernel.

const CameraRig := preload("res://scripts/camera_rig.gd")
const Space := preload("res://scripts/world/dongtian_space.gd")
const CourtyardArt := preload("res://scripts/world/courtyard_art.gd")
const Menu := preload("res://scripts/preview_menu.gd")

var house: Node3D


func _ready() -> void:
	SpaceState.house_door = Vector3(0.0, 0.0, 0.0)
	SpaceState.player_x = 0.0
	SpaceState.player_z = 2.4
	SpaceState.space_id = "outside"
	_lights()
	var homestead := Node3D.new()
	homestead.name = "Homestead"
	add_child(homestead)
	house = preload("res://scripts/world/cottage.gd").new()
	homestead.add_child(house)
	var island := preload("res://scripts/world/island_shell.gd").new()
	island.name = "IslandShell"
	homestead.add_child(island)
	var art := CourtyardArt.new()
	homestead.add_child(art)
	art.attach(island.terrain, house)
	CourtyardArt.apply_atmosphere(get_node("WorldEnvironment"), get_node("Sun"))
	var arena := preload("res://scripts/combat/practice_arena.gd").new()
	arena.name = "PracticeArena"
	homestead.add_child(arena)
	var space: Node3D = Space.new()
	space.name = "DongtianSpace"
	space.configure(house)
	homestead.add_child(space)
	var player: CharacterBody3D = preload("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0.0, 0.0, 2.4)
	add_child(player)
	var clouds := preload("res://scripts/world/cloud_sea.gd").new()
	homestead.add_child(clouds)
	var rig: Node3D = CameraRig.new()
	rig.name = "CameraRig"
	rig.default_distance = 22.0
	rig.min_distance = 8.0
	rig.max_distance = 32.0
	rig.lens_fov = 34.0
	rig.spring_omega = 12.0
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 34
	cam.near = 1.2
	cam.far = 240
	rig.add_child(cam)
	add_child(rig)
	rig.set_target(player)
	add_child(Menu.new())
	add_child(preload("res://scripts/play/demo_hud.gd").new())
	var builder := preload("res://scripts/build/builder.gd").new()
	builder.name = "SandboxBuilder"
	builder.configure(island, house, art)
	homestead.add_child(builder)
	if "--build" in OS.get_cmdline_user_args():
		builder.set_active(true)


func _lights() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("6ea0d0")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("b0b8a8")
	sky.ambient_light_energy = 0.12
	sky.fog_enabled = true
	sky.fog_light_color = Color("c8d6e4")
	sky.fog_density = 0.004
	env.environment = sky
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-32, -38, 0)
	sun.light_color = Color("ffd39a")
	sun.light_energy = 1.85
	sun.shadow_enabled = true
	sun.light_angular_distance = 3.6
	sun.shadow_blur = 2.8
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.15
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(28, 142, 0)
	fill.light_color = Color("9eb4cc")
	fill.light_energy = 0.04
	fill.shadow_enabled = false
	add_child(fill)
