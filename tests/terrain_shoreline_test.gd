extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func sample(material:ShaderMaterial,p:Vector2)->Color:
	var image:Image=material.get_shader_parameter("shore_field").get_image()
	var origin:Vector2=material.get_shader_parameter("shore_origin")
	var pixel:=Vector2i((p-origin).floor())
	return image.get_pixel(pixel.x,pixel.y)
func run()->void:
	var data:=Data.new()
	data.make_preset(0)
	var renderer:=Renderer.new()
	root.add_child(renderer)
	renderer.configure(data)
	renderer.rebuild_all()
	var material:ShaderMaterial=renderer.materials.water
	var initial:Texture2D=material.get_shader_parameter("shore_field")
	check(initial!=null,"published pond has terrain-derived shoreline shading")
	if initial==null:
		renderer.free();quit(1);return
	var center:=Vector2(-5.5,.5)
	var neighbor:=Vector2(-4.5,.5)
	check(data.cells[Vector2i(center.floor())].water>=0,"regression center is an existing pond cell")
	var before_neighbor:=sample(material,neighbor).r
	check(sample(material,center).a>.99,"water field covers the rendered pond")
	data.begin_stroke()
	data.apply_brush(center,.49,"contract",true,1.5,3)
	data.end_stroke()
	renderer.flush_dirty(1)
	check(renderer.has_pending_updates(),"edit spans more than one chunk")
	check(material.get_shader_parameter("shore_field")==initial,"partial build preserves visible shoreline texture")
	check(sample(material,center).a>.99,"partial build preserves visible pond coverage")
	while renderer.has_pending_updates():renderer.flush_dirty(1)
	check(material.get_shader_parameter("shore_field")!=initial,"shoreline publishes with the completed terrain snapshot")
	check(sample(material,center).a<.01,"contracted pond cell leaves the water field")
	check(sample(material,neighbor).r<before_neighbor,"new shore makes neighboring water shallower in appearance")
	renderer.free()
	print("TERRAIN SHORELINE: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
