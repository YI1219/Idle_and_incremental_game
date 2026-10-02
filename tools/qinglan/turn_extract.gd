extends SceneTree
func _initialize() -> void:
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(doc.append_from_file("res://art/work/turn_motion/turn_motion.glb",state)==OK)
	var scene:=doc.generate_scene(state)
	root.add_child(scene)
	var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
	assert(player!=null)
	var library:=AnimationLibrary.new()
	for name in player.get_animation_list():
		if not String(name).begins_with("turn_"):continue
		var animation:=player.get_animation(name).duplicate(true) as Animation
		animation.loop_mode=Animation.LOOP_NONE
		print(name," ",animation.length," ",animation.track_get_path(0))
		library.add_animation(name,animation)
	assert(library.get_animation_list().size()==4)
	assert(ResourceSaver.save(library,"res://assets/characters/qinglan/turn_motion.tres")==OK)
	quit()
