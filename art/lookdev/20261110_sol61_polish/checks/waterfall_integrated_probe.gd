extends SceneTree
var checks:int=0
var failures:int=0
var results:Array=[]
func verify(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func compile_script(path:String)->GDScript:
 var script:=GDScript.new()
 script.source_code=FileAccess.get_file_as_string(path).replace('class_name ContourTerrain\n','').replace('multimesh.instance_count=puffs.size()', 'set_meta("probe_puffs",puffs.duplicate(true))\n\tmultimesh.instance_count=puffs.size()')
 verify(script.reload()==OK,'candidate compiles '+path)
 return script
func tail_factor(progress:float)->float:
 return (1.0-smoothstep(.66,.985,progress))*(1.0-smoothstep(.92,.98,progress))
func _initialize()->void:
 var candidate=compile_script('res://scripts/terrain_editor/contour_terrain.gd')
 var mist_script=compile_script('res://scripts/terrain_editor/waterfall_mist.gd')
 for seed_value:int in [7301,2104,4242,913]:
  var data=load('res://scripts/terrain_editor/terrain_data.gd').new()
  data.make_preset(0)
  data.seed=seed_value
  var source_hash:=hash(data.cells)
  var baseline=compile_script('res://art/lookdev/20261110_sol61_polish/checks/source_before/scripts__terrain_editor__contour_terrain.gd').new()
  baseline.refresh(data)
  var field=candidate.new()
  field.refresh(data)
  verify(hash(data.cells)==source_hash,'authoritative data unchanged '+str(seed_value))
  verify(field.water_regions==baseline.water_regions,'water regions unchanged '+str(seed_value))
  verify(field.fall_veils.size()==2,'two curtains retained '+str(seed_value))
  for i:int in field.fall_veils.size():
   var before:Dictionary=baseline.fall_veils[i]
   var after:Dictionary=field.fall_veils[i]
   verify(before.lip==after.lip,'lip anchor unchanged '+str(seed_value))
   verify(is_equal_approx(before.half_width,after.half_width),'width unchanged '+str(seed_value))
  var surface=field.surfaces.waterfall
  var terminal:int=0
  var encoded:int=0
  var bad_finite:int=0
  var mesh:ArrayMesh=surface.mesh()
  var upload_colors:PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
  for i:int in surface.vertices.size():
   var color:Color=surface.colors[i]
   var vertex:Vector3=surface.vertices[i]
   if not vertex.is_finite():bad_finite+=1
   if color.a>=.495 and color.a<.995:
    encoded+=1
    if is_equal_approx(color.a,.99):
     terminal+=1
     var uploaded:Color=upload_colors[i]
     var progress:=clampf((uploaded.a-.5)/.49,0,1)
     # Test the least faded noisy tail as well as the deterministic terminal taper.
     var largest_alpha:float=(1.0-smoothstep(.66,.985,progress-.08))*(1.0-smoothstep(.92,.98,progress))
     verify(largest_alpha==0.0,'uploaded external end reaches zero '+str(seed_value))
  verify(terminal>0 and encoded>0,'external tail metadata exists '+str(seed_value))
  verify(bad_finite==0,'finite curtain vertices '+str(seed_value))
  var mist=mist_script.new()
  mist.sync(field.splash_points,field.fall_veils,field.land_regions)
  var old_mist=compile_script('res://art/lookdev/20261110_sol61_polish/checks/source_before/scripts__terrain_editor__waterfall_mist.gd').new()
  old_mist.sync(baseline.splash_points,baseline.fall_veils,baseline.land_regions)
  verify(mist.multimesh.instance_count==old_mist.multimesh.instance_count,'puff count retained '+str(seed_value))
  var waist_unchanged:bool=true
  var apron_count:int=0
  for i:int in mist.multimesh.instance_count:
   var custom:Color=mist.get_meta("probe_puffs")[i][2]
   if custom.a>.75:
    waist_unchanged=waist_unchanged and mist.get_meta("probe_puffs")[i]==old_mist.get_meta("probe_puffs")[i]
   elif custom.a>.25:apron_count+=1
  verify(waist_unchanged,'island waist cloud untouched '+str(seed_value))
  verify(apron_count==4*field.splash_points.size(),'receiving apron encoded '+str(seed_value))
  results.append({'seed':seed_value,'curtains':field.fall_veils.size(),'vertices_before':baseline.surfaces.waterfall.vertices.size(),'vertices_after':surface.vertices.size(),'external_vertices':encoded,'zero_alpha_end_vertices':terminal,'puffs':mist.multimesh.instance_count,'apron_puffs':apron_count})
  mist.free()
  old_mist.free()
 # Check geometry with no falls, and the second two-pond authoring preset.
 for preset:int in [1,2]:
  var data=load('res://scripts/terrain_editor/terrain_data.gd').new()
  data.make_preset(preset)
  var field=candidate.new()
  field.refresh(data)
  verify((field.surfaces.waterfall.vertices.size()>0)==(preset==1),'other authoring presets remain valid '+str(preset))
 var output:Dictionary={'checks':checks,'failures':failures,'results':results}
 print(JSON.stringify(output,'  '))
 var file=FileAccess.open('/tmp/sol61_waterfall_integrated_validation.json',FileAccess.WRITE)
 file.store_string(JSON.stringify(output,'  '))
 quit(1 if failures>0 else 0)
