class_name TerrainProps
extends Node3D
## Supporting modules anchored to the same editable terrain. Bench and lantern are placeholders.
const Cottage=preload("res://scripts/world/cottage.gd")
var entries:Array=[]
func _ready()->void:
	var cottage:=Cottage.new()
	add_child(cottage)
	cottage.name="ReferenceCottage"
	cottage.scale=Vector3(1.05,.70,.82)
	_roof_detail(cottage)
	var door_wood:=_material(Color("936943"))
	var dark_wood:=_material(Color("65492f"))
	_box(cottage,Vector3(0,.92,2.24),Vector3(1.54,1.8,.06),door_wood)
	for x in [-.55,-.19,.19,.55]:_box(cottage,Vector3(x,.92,2.28),Vector3(.025,1.77,.025),dark_wood)
	for y in [.42,1.28]:_box(cottage,Vector3(0,y,2.29),Vector3(1.52,.055,.03),dark_wood)
	for x in [-.10,.10]:_box(cottage,Vector3(x,.94,2.33),Vector3(.035,.12,.04),dark_wood)
	entries.append({"node":cottage,"at":Vector2(-11,-7),"radius":2.7})
	var bench:=Node3D.new()
	bench.name="BenchPlaceholder"
	add_child(bench)
	var wood:=_material(Color("89633c"))
	_box(bench,Vector3(0,.65,0),Vector3(1.9,.14,.6),wood)
	_box(bench,Vector3(0,1.08,-.25),Vector3(1.9,.14,.1),wood)
	for x in [-.72,.72]:
		_box(bench,Vector3(x,.32,0),Vector3(.13,.65,.42),wood)
		_box(bench,Vector3(x,.91,-.25),Vector3(.09,.85,.09),wood)
	bench.rotation.y=-.12
	entries.append({"node":bench,"at":Vector2(11,-2),"radius":1.05})
	var lamp:=Node3D.new()
	lamp.name="LanternPlaceholder"
	add_child(lamp)
	_box(lamp,Vector3(0,1.35,0),Vector3(.13,2.7,.13),wood)
	_box(lamp,Vector3(-.24,2.55,0),Vector3(.66,.1,.12),wood)
	_box(lamp,Vector3(-.48,2.26,0),Vector3(.035,.36,.035),wood)
	var glow:=_material(Color("f4d082"))
	glow.emission_enabled=true
	glow.emission=Color("c9964f")
	glow.emission_energy_multiplier=.35
	_box(lamp,Vector3(-.48,2.06,0),Vector3(.25,.32,.25),glow)
	for y in [1.87,2.25]:_box(lamp,Vector3(-.48,y,0),Vector3(.34,.07,.34),wood)
	entries.append({"node":lamp,"at":Vector2(12.3,-2.5),"radius":.35})
func sync(field)->void:
	for entry:Dictionary in entries:
		var at:Vector2=entry.at
		var sample:Dictionary=field.surface_at(at)
		var supported:bool=not sample.is_empty() and sample.water<0
		if supported:
			var radius:float=entry.radius
			var steps:=ceili(radius*4)
			for z in range(steps+1):
				for x in range(steps+1):
					var point:=at+Vector2(lerpf(-radius,radius,float(x)/steps),lerpf(-radius,radius,float(z)/steps))
					var support:Dictionary=field.surface_at(point)
					if support.is_empty() or support.water>=0 or absf(support.height-sample.height)>.01:supported=false;break
				if not supported:break
		entry.node.visible=supported
		if supported:entry.node.position=Vector3(at.x,sample.height,at.y)
func _material(color:Color)->StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=.95
	return material
func _box(parent:Node3D,at:Vector3,size:Vector3,material:Material)->void:
	var instance:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	instance.mesh=mesh
	instance.material_override=material
	instance.position=at
	parent.add_child(instance)

func _roof_detail(node:Node)->void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original:Material=node.get_active_material(surface)
			if not original is StandardMaterial3D:continue
			var material:=ShaderMaterial.new()
			material.shader=load("res://shaders/terrain_editor/cottage_roof.gdshader")
			material.set_shader_parameter("base_color",original.albedo_color)
			material.set_shader_parameter("use_texture",original.albedo_texture!=null)
			if original.albedo_texture!=null:material.set_shader_parameter("albedo_tex",original.albedo_texture)
			node.set_surface_override_material(surface,material)
	for child in node.get_children():_roof_detail(child)
