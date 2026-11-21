// One publication transitions old and new geometry with complementary coverage.
// Field channels carry old nominal top, new nominal top and previously shown top.
global uniform sampler2D terrain_morph_field : filter_linear, repeat_disable;
global uniform vec4 terrain_morph_rect;
global uniform float terrain_morph_progress;
// Stable geometry has role 2, incoming geometry 0 and retiring geometry 1.
instance uniform float terrain_transition_role : instance_index(15) = 2.0;
const float TERRAIN_MORPH_FLOOR = -7.0;

float terrain_morph_ease(float t){
 float u=clamp(t,0.0,1.0);
 return u*u*(3.0-2.0*u);
}
float terrain_morph_offset(vec3 p){
 if(terrain_morph_progress>=1.0 || terrain_transition_role>1.5)return 0.0;
 vec2 uv=(p.xz-terrain_morph_rect.xy)/terrain_morph_rect.zw;
 if(uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0)return 0.0;
 vec4 tops=texture(terrain_morph_field,uv);
 if(tops.a<.01)return 0.0;
 bool retiring=terrain_transition_role>.5;
 float nominal=retiring?tops.r:tops.g;
 float denominator=max(nominal-TERRAIN_MORPH_FLOOR,.001);
 float initial_y=TERRAIN_MORPH_FLOOR+(p.y-TERRAIN_MORPH_FLOOR)*(tops.b-TERRAIN_MORPH_FLOOR)/denominator;
 float final_y=retiring?TERRAIN_MORPH_FLOOR+(p.y-TERRAIN_MORPH_FLOOR)*(tops.g-TERRAIN_MORPH_FLOOR)/denominator:p.y;
 return mix(initial_y,final_y,terrain_morph_ease(terrain_morph_progress))-p.y;
}
bool terrain_transition_visible(vec2 pixel){
 if(terrain_transition_role>1.5)return true;
 float progress=terrain_morph_ease(terrain_morph_progress);
 float noise=fract(52.9829189*fract(dot(floor(pixel),vec2(.06711056,.00583715))));
 return terrain_transition_role>.5?noise>=progress:noise<progress;
}
