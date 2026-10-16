extends SceneTree
## Technical slope bake from an AI grayscale relief guide, not measured height.
## Preserve the retained stone map's value/roughness bytes and fine response.
const N:=1024
const OUT:='res://art/work/stone_spall/2026-10-16/'
func _initialize()->void:
 var broad:=OS.get_cmdline_user_args().has('broad')
 var local_only:=OS.get_cmdline_user_args().has('local')
 var version:='v3' if local_only else ('v2' if broad else 'v1')
 var blur_radius:=5 if broad else 2
 var shader_strength:=.25 if local_only else (.30 if broad else .20)
 var height_scale:=.060 if local_only else (.070 if broad else .025)
 var guide:=Image.load_from_file('res://art/source/materials/2026-10-16/cliff_spall_height_v1.png')
 var original:=Image.load_from_file('res://assets/textures/terrain/stone_detail.png')
 assert(guide!=null and original!=null)
 guide.resize(N,N,Image.INTERPOLATE_LANCZOS);original.convert(Image.FORMAT_RGBA8)
 var h:=PackedFloat32Array();h.resize(N*N)
 for y in N:
  for x in N:h[y*N+x]=guide.get_pixel(x,y).r
 # Equalize opposing boundary bands; periodic blur/derivatives then avoid
 # a strong relief discontinuity at the texture wrap. Albedo is untouched.
 for y in N:
  for x in 64:
   var a:=y*N+x;var b:=y*N+N-1-x;var mix:float=.5*(1.0-smoothstep(0,63,x))
   var va:=h[a];var vb:=h[b];h[a]=lerpf(va,vb,mix);h[b]=lerpf(vb,va,mix)
 for y in 64:
  for x in N:
   var a:=y*N+x;var b:=(N-1-y)*N+x;var mix:float=.5*(1.0-smoothstep(0,63,y))
   var va:=h[a];var vb:=h[b];h[a]=lerpf(va,vb,mix);h[b]=lerpf(vb,va,mix)
 for pass_index in 2:
  for axis in [1,N]:
   var blurred:=PackedFloat32Array();blurred.resize(N*N)
   for y in N:
    for x in N:
     var value:=0.0
     for d in range(-blur_radius,blur_radius+1):value+=h[y*N+posmod(x+d,N) if axis==1 else posmod(y+d,N)*N+x]/float(blur_radius*2+1)
     blurred[y*N+x]=value
   h=blurred
 var relief_coverage:=1.0
 if local_only:
  # Keep most broad faces calm. Only the guide's lower35% contributes
  # chipped depressions; do not emboss the whole stone with soft noise.
  var ordered:=h.duplicate();ordered.sort()
  var threshold:float=ordered[floori(ordered.size()*.35)]
  var changed:=0
  for i in h.size():
   h[i]=minf(0.0,h[i]-threshold)
   if h[i]<0:changed+=1
  relief_coverage=float(changed)/h.size()
 var bytes:=original.get_data();var old:=bytes.duplicate()
 var fine_squared:=0.0;var geological_squared:=0.0;var combined_squared:=0.0;var clipped:=0
 # Projection .38 repeats/metre and the configured relief scale; grayscale is an
 # artistic guide. .60 gain tempers the derived slope, not pigment contrast.
 for y in N:
  for x in N:
   var gradient:=Vector2(h[y*N+posmod(x+1,N)]-h[y*N+posmod(x-1,N)],h[posmod(y+1,N)*N+x]-h[posmod(y-1,N)*N+x])*(N*.38*height_scale*.5*.60)
   var at:=(y*N+x)*4
   for channel in 2:
    var fine:float=(float(old[at+channel+1])/255.0-.5)*2.0*.07
    var combined:float=fine+gradient[channel]
    fine_squared+=fine*fine;geological_squared+=gradient[channel]*gradient[channel]
    if absf(combined)>shader_strength*.975:clipped+=1
    combined=clampf(combined,-shader_strength*.975,shader_strength*.975)
    bytes[at+channel+1]=roundi((.5+combined/(2.0*shader_strength))*255.0)
    combined_squared+=combined*combined
 var result:=Image.create_from_data(N,N,false,Image.FORMAT_RGBA8,bytes)
 for i in range(0,bytes.size(),4):assert(bytes[i]==old[i] and bytes[i+3]==old[i+3])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 assert(result.save_png(OUT+'stone_detail_spall_'+version+'.png')==OK)
 result.generate_mipmaps()
 # A native lossless ImageTexture resource carries its own mip chain and
 # linear packed bytes. It needs no unrelated source-model editor imports.
 assert(ResourceSaver.save(ImageTexture.create_from_image(result),OUT+'stone_detail_spall_'+version+'.res',ResourceSaver.FLAG_COMPRESS)==OK)
 var count:float=N*N*2
 var report:Dictionary={'source':'Generated grayscale artistic relief guide; not measured displacement','guide':'art/source/materials/2026-10-16/cliff_spall_height_v1.png','output':OUT.trim_prefix('res://')+'stone_detail_spall_'+version+'.png','size':N,'original_fine_strength':.07,'candidate_shader_strength':shader_strength,'guide_height_scale_metres':height_scale,'blur_radius_pixels':blur_radius,'fine_slope_rms':sqrt(fine_squared/count),'new_geological_slope_rms':sqrt(geological_squared/count),'combined_slope_rms':sqrt(combined_squared/count),'clipped_channel_fraction':clipped/count,'value_and_roughness_bytes_identical':true,'changes_geometry':false,'accepted_in_engine':false}
 report['guide_relief_coverage']=relief_coverage
 FileAccess.open(OUT+'bake_'+version+'.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('SPALL SLOPE BAKE: ',JSON.stringify(report));quit()
