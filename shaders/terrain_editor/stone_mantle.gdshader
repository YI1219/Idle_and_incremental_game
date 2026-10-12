shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
 vec3 material_normal=normalize(cross(dFdx(world_position),dFdy(world_position)));
 if(dot(material_normal,(INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz)<0.0)material_normal=-material_normal;
 ALBEDO=cliff_weather(stone_surface(world_position,material_normal)*mix(vec3(1.0),COLOR.rgb,.55),world_position,material_normal);
 ROUGHNESS=stone_map(world_position,material_normal).a;SPECULAR=.08;AO=.94;
 NORMAL=normalize((VIEW_MATRIX*vec4(cliff_face_normal(world_position,material_normal),0.0)).xyz);
}
