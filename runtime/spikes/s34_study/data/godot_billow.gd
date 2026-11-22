extends SceneTree
func _init():
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 4127
	noise.frequency = .016
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = .50
	var image := noise.get_seamless_image(256, 256)
	print("FORMAT ", image.get_format(), " ", image.get_width(), "x", image.get_height())
	image.save_png("/tmp/tsw_godot/billow_4127.png")
	quit()
