extends "res://tools/art/capture_lookdev.gd"
var view_index:int=0
var legacy_installed:bool=false
var legacy_mode:bool=false
func _frame(center:Vector2,height:float,yaw:float,pitch:float)->void:
	match view_index:
		0:super._frame(Vector2(3.0,.8),7.0,20.0,42.0)
		1,2,4:super._frame(center,height,yaw,pitch)
		3:super._frame(Vector2(3.0,.8),7.0,67.0,36.0)
	if view_index in [0,3]:editor.camera.position.y+=2.5
	view_index+=1
func _capture(label:String,time_progress:float)->void:
	if not legacy_installed:
		legacy_installed=true
		legacy_mode="before" in output
		if legacy_mode:
			# Reconstruct only the old waterfall from the task's exact source snapshot.
			# The same live scene, terrain, pools, camera and solar lighting remain.
			var old_code:=GDScript.new()
			old_code.source_code=FileAccess.get_file_as_string("res://art/lookdev/20261110_interaction_water/checks/source_before/scripts/terrain_editor/contour_terrain.gd").replace("class_name ContourTerrain\n","")
			if old_code.reload()!=OK:
				errors.append("Cannot reconstruct waterfall baseline")
				return
			var old_field:RefCounted=old_code.new()
			old_field.refresh(editor.data)
			editor.water_view.get_node("waterfall").mesh=old_field.surfaces.waterfall.mesh()
			var old_material:=ShaderMaterial.new()
			old_material.shader=Shader.new()
			old_material.shader.code=_expand_includes(FileAccess.get_file_as_string("res://art/lookdev/20261110_interaction_water/checks/source_before/shaders/terrain_editor/waterfall.gdshader"),"res://shaders/terrain_editor/")
			editor.renderer.materials.waterfall=old_material
			editor.water_view.get_node("waterfall").material_override=old_material
			_freeze_material(old_material)
			var old_mist_script:=GDScript.new()
			old_mist_script.source_code=FileAccess.get_file_as_string("res://art/lookdev/20261110_interaction_water/checks/source_before/scripts/terrain_editor/waterfall_mist.gd")
			if old_mist_script.reload()!=OK:
				errors.append("Cannot reconstruct mist baseline")
				return
			var old_mist:MultiMeshInstance3D=old_mist_script.new()
			editor.renderer.mist.visible=false
			editor.renderer.add_child(old_mist)
			old_mist.sync(old_field.splash_points,old_field.fall_veils,old_field.land_regions)
			var mist_material:=ShaderMaterial.new()
			mist_material.shader=Shader.new()
			mist_material.shader.code=_expand_includes(FileAccess.get_file_as_string("res://art/lookdev/20261110_interaction_water/checks/source_before/shaders/terrain_editor/waterfall_mist.gdshader"),"res://shaders/terrain_editor/")
			old_mist.material_override=mist_material
			_freeze_material(mist_material)
	await super._capture(label,time_progress)
	if not captures.is_empty():captures[-1]["waterfall_variant"]="task_source_before" if legacy_mode else "live_flow"
