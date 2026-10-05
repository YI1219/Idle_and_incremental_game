shader_type spatial;
render_mode cull_disabled;
uniform bool show_grid = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 p=world_position.xz;
	float broad=sin(p.x*0.51+p.y*0.22)*sin(p.y*0.47-p.x*0.18)*0.5+0.5;
	float flecks=step(0.965,hash(floor(p*13.0)));
	vec3 base=mix(vec3(0.40,0.59,0.13),vec3(0.70,0.76,0.27),broad);
	base=mix(base,vec3(0.79,0.8,0.38),flecks*0.45);
	if(show_grid){vec2 g=abs(fract(p)-0.5);float edge=step(0.486,max(g.x,g.y));base=mix(base,vec3(0.91,0.95,0.66),edge*0.35);}
	ALBEDO=base*COLOR.rgb;
	ROUGHNESS=0.95;
}
