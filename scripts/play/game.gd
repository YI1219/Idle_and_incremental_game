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
	var rig: Node3D = CameraRig.new()
	rig.name = "CameraRig"
	rig.default_distance = 16.5
	rig.min_distance = 6.0
	rig.max_distance = 23.0
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 46
	cam.far = 160
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
	sky.background_color = Color("becfd4")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("dbe3d6")
	sky.ambient_light_energy = 0.55
	sky.fog_enabled = true
	sky.fog_light_color = Color("becfd4")
	sky.fog_density = 0.008
	env.environment = sky
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_color = Color("f3e4c4")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
