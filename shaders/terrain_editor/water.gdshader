shader_type spatial;
render_mode cull_disabled;
uniform bool fall = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=world_position.xz;
	if(fall)p=vec2(UV.x*3.0,UV.y-TIME*1.4);
	vec2 tile=floor(p*1.8);
	float triangle=step(1.0,fract(p.x*1.8)+fract(p.y*1.8));
	float facet=fract(sin(dot(tile,vec2(127.1,311.7))+triangle*31.71)*43758.5453);
	float wave=sin(p.x*3.2+p.y*2.6+TIME*1.1)*0.2+(facet-0.5)*0.8;
	if(fall)wave=sin(p.x*8.0+p.y*6.0)*sin(p.x*3.0-p.y*4.0);
	float sparkle=smoothstep(0.48,0.67,wave);
	ALBEDO=mix(vec3(0.12,0.54,0.67),vec3(0.43,0.78,0.86),wave*0.3+0.55);
	ALBEDO=mix(ALBEDO,vec3(0.87,0.97,0.96),sparkle*(fall ? 0.8 : 0.3));
	ROUGHNESS=0.35;
	SPECULAR=0.45;
}
