extends SceneTree
const Renderer=preload('res://scripts/terrain_editor/terrain_renderer.gd')
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
func _initialize():call_deferred('run')
func run():
 var renderer:=Renderer.new();root.add_child(renderer)
 if not renderer.has_method('set_grass_compression'):
  push_error('Renderer has no grass compression data path');renderer.free();quit(1);return
 var data:=Data.new();data.make_preset(0)
 var image:=Image.create(2,2,false,Image.FORMAT_R8)
 image.set_pixel(0,0,Color.BLACK);image.set_pixel(1,0,Color(.5,0,0));image.set_pixel(0,1,Color(1,0,0))
 var texture:=ImageTexture.create_from_image(image)
 var bounds:=Rect2(-20,-12,44,25)
 var ok:bool=renderer.set_grass_compression(texture,bounds)
 renderer.configure(data)
 for kind in ['grass','cliff','rim_green']:
  ok=ok and renderer.materials[kind].get_shader_parameter('grass_compression')==texture
  ok=ok and renderer.materials[kind].get_shader_parameter('compression_origin')==bounds.position
  ok=ok and renderer.materials[kind].get_shader_parameter('compression_extent')==bounds.size
 ok=ok and not renderer.set_grass_compression(texture,Rect2(0,0,0,1))
 renderer.configure(data)
 ok=ok and renderer.materials.grass.get_shader_parameter('grass_compression')==texture
 ok=ok and renderer.set_grass_compression(null,bounds)
 ok=ok and renderer.materials.grass.get_shader_parameter('grass_compression')==null
 renderer.free()
 print('GRASS COMPRESSION: texture/origin/extent, preconfigure, reconfigure, invalid bounds and clear: ',ok)
 quit(0 if ok else 1)
