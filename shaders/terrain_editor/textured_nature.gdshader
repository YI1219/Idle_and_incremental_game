shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "terrain_morph.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool is_leaf=true;
uniform bool is_meadow=false;
uniform sampler2D grass_compression : filter_linear, repeat_disable, hint_default_black;
uniform vec2 compression_origin=vec2(-64.0);
uniform vec2 compression_extent=vec2(128.0);
uniform float preserve_color=0.0;
uniform float plant_height=4.15;
uniform vec3 leaf_shadow : source_color=vec3(.31,.40,.27);
uniform vec3 leaf_light : source_color=vec3(.68,.72,.43);
varying vec3 world_position;
varying float crown;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 crown=clamp(VERTEX.y/plant_height,0.0,1.0);
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 if(is_meadow){
  vec2 uv=(origin.xz-compression_origin)/compression_extent;
  float inside=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
  float standing=1.0-texture(grass_compression,uv).r*inside;
  VERTEX.y*=mix(.06,1.0,standing);
 }
 VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;
 if(is_leaf){
  VERTEX.x+=sin(TIME*.85+world_position.x*.38+world_position.z*.3)*.025*crown;
  NORMAL=normalize(mix(NORMAL,vec3(0.0,1.0,0.0),.68));
 }
}
void fragment(){
 vec4 source=texture(albedo_tex,UV);
 if(is_leaf){
  ALPHA=source.a;
  ALPHA_SCISSOR_THRESHOLD=.32;
  float value=dot(source.rgb,vec3(.3,.5,.2));
  float group=sin(world_position.x*1.1+world_position.z*.7)*.08;
  vec3 color=mix(leaf_shadow,leaf_light,clamp(value*.85+crown*.28+group,0.0,1.0));
  vec3 petal=mix(vec3(.89,.85,.70),vec3(.99,.97,.86),dot(source.rgb,vec3(.3,.5,.2)));
  ALBEDO=mix(color,petal,preserve_color);
  BACKLIGHT=ALBEDO*.25;
 }else{
  ALPHA=1.0;
  ALBEDO=source.rgb*vec3(.74,.71,.66);
 }
 ROUGHNESS=.94;
}
