shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float broad=.5+.5*sin(world_position.x*.71+sin(world_position.z*.63));
 ALBEDO=COLOR.rgb*mix(vec3(.92,.98,.89),vec3(1.06,1.02,.94),broad);
 ROUGHNESS=.88;
 SPECULAR=.15;
}
