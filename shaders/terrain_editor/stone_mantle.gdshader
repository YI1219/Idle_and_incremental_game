shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
float noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(rock_hash(i).x,rock_hash(i+vec3(1,0,0)).x,f.x),mix(rock_hash(i+vec3(0,1,0)).x,rock_hash(i+vec3(1,1,0)).x,f.x),f.y),mix(mix(rock_hash(i+vec3(0,0,1)).x,rock_hash(i+vec3(1,0,1)).x,f.x),mix(rock_hash(i+vec3(0,1,1)).x,rock_hash(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
 float broad=noise(world_position*.9),fine=noise(world_position*6.0);
 vec3 stone=cliff_gray(.55)+vec3(.055,.065,.075);
 stone+=(broad-.5)*vec3(.12,.13,.15)+(noise(world_position*.61+7.0)-.5)*vec3(.07,.015,-.04);
 ALBEDO=stone*COLOR.rgb*(.97+fine*.06);
 ROUGHNESS=.96;SPECULAR=.16;AO=.9;
}
