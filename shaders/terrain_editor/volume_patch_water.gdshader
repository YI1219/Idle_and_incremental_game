shader_type spatial;
render_mode cull_disabled;
// Opaque small-pond study: no screen-space refraction or fluid simulation.
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 p=world_position.xz;
	float wave=sin(p.x*7.3+p.y*4.1+TIME*.6)*sin(p.y*5.7-p.x*2.2-TIME*.4);
	ALBEDO=mix(vec3(.055,.21,.19),vec3(.10,.29,.25),wave*.5+.5);
	ROUGHNESS=.34; SPECULAR=.36;
}
