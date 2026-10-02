extends SceneTree
## Blend two licensed human gaits at matching stride phases; no sinusoidal body posing.
const SOURCE := "res://assets/characters/qinglan/qinglan_clothed_v04.glb"
const OUTPUT := "res://assets/characters/qinglan/gentle_jog.tres"
const BLEND := 0.55
const DURATION := 1.0
func _initialize()->void:
	var model=load(SOURCE).instantiate()
	root.add_child(model)
	var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	var walk:=player.get_animation("walk")
	var jog:=player.get_animation("jog")
	var result:=Animation.new()
	result.resource_name="gentle_jog"
	result.length=DURATION
	result.loop_mode=Animation.LOOP_LINEAR
	for source_track in walk.get_track_count():
		var path:=walk.track_get_path(source_track)
		var type:=walk.track_get_type(source_track)
		var jog_track:=jog.find_track(path,type)
		assert(jog_track>=0,"Both source clips must cover the same rig channels")
		var track:=result.add_track(type)
		result.track_set_path(track,path)
		result.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
		for frame in 31:
			var phase:float=frame/30.0
			var time:float=phase*DURATION
			if type==Animation.TYPE_ROTATION_3D:
				result.rotation_track_insert_key(track,time,walk.rotation_track_interpolate(source_track,phase*walk.length).slerp(jog.rotation_track_interpolate(jog_track,phase*jog.length),BLEND).normalized())
			elif type==Animation.TYPE_POSITION_3D:
				result.position_track_insert_key(track,time,walk.position_track_interpolate(source_track,phase*walk.length).lerp(jog.position_track_interpolate(jog_track,phase*jog.length),BLEND))
			elif type==Animation.TYPE_SCALE_3D:
				result.scale_track_insert_key(track,time,walk.scale_track_interpolate(source_track,phase*walk.length).lerp(jog.scale_track_interpolate(jog_track,phase*jog.length),BLEND))
			else:
				push_error("Unsupported source track "+str(type));quit(1);return
	assert(ResourceSaver.save(result,OUTPUT)==OK)
	var metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/qinglan/template_motion.json"))
	var distance:float=lerpf(float(metadata.clips.walk.native_travel_speed)*walk.length,float(metadata.clips.jog.native_travel_speed)*jog.length,BLEND)
	var report={"source":SOURCE,"source_clips":["walk","jog"],"jog_weight":BLEND,"seconds":DURATION,"estimated_native_speed":distance/DURATION,"method":"phase-aligned quaternion/translation blend of licensed human templates","visual_acceptance":"pending"}
	var file:=FileAccess.open("res://assets/characters/qinglan/gentle_jog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit()
