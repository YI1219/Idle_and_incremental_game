extends "res://tools/art/capture_lookdev.gd"
## Diagnostic only. Path-cast toggle and candidate pigment are process-local.
## Source meshes, placements, all lights and environment remain untouched.
var path_nodes:Array[MultiMeshInstance3D]=[]
var path_materials:Array[ShaderMaterial]=[]

func _find_paths(node:Node)->void:
	if node is MultiMeshInstance3D and node.name=="path_0":
		path_nodes.append(node)
		var material:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
		if not path_materials.has(material):path_materials.append(material)
	for child:Node in node.get_children():_find_paths(child)

func _capture(label:String,time_progress:float)->void:
	if label!="close":return
	_find_paths(editor)
	assert(not path_nodes.is_empty(),"No live path instances found")
	await super._capture("01_original",time_progress)
	for node:MultiMeshInstance3D in path_nodes:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await super._capture("02_original_path_cast_off",time_progress)
	for material:ShaderMaterial in path_materials:
		var candidate:Shader=material.shader.duplicate()
		assert(candidate.code.contains("vec3 rim_tone=stone_shadow_color*vec3(.78,.82,.82);"))
		candidate.code=candidate.code.replace("vec3 rim_tone=stone_shadow_color*vec3(.78,.82,.82);","vec3 rim_tone=mix(stone_mid_color,stone_lit_color,.18)*vec3(.90,.94,.98);")
		material.shader=candidate
	await super._capture("03_pigment_candidate_path_cast_off",time_progress)
	for node:MultiMeshInstance3D in path_nodes:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await super._capture("04_pigment_candidate",time_progress)
	print("PATH_DIAGNOSTIC ",JSON.stringify({"path_nodes":path_nodes.size(),"path_materials":path_materials.size(),"only_process_local_changes":true,"source_edited":false}))
