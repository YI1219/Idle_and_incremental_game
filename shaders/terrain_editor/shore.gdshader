shader_type spatial;
#include "land_palette.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float broad=.5+.5*sin(world_position.x*.71+sin(world_position.z*.63));
 vec2 p=world_position.xz;
 float lawn=sin(p.x*.51+p.y*.22)*sin(p.y*.47-p.x*.18)*.5+.5;
 vec3 grass=mix(grass_base,grass_highlight,lawn);
 vec3 earth=COLOR.rgb*mix(vec3(.92,.98,.89),vec3(1.06,1.02,.94),broad);
 ALBEDO=mix(grass,earth,smoothstep(.10,.90,COLOR.a));
 ROUGHNESS=.88;
 SPECULAR=.15;
}
