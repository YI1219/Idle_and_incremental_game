shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise21(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash21(i),hash21(i+vec2(1.,0.)),f.x),mix(hash21(i+vec2(0.,1.)),hash21(i+1.),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	ALBEDO=mix(vec3(.19,.265,.065),vec3(.29,.355,.115),noise21(world_position.xz*.85));
	vec3 up=(VIEW_MATRIX*vec4(0.,1.,0.,0.)).xyz;
	NORMAL=normalize(mix(NORMAL,up,.3));
	ROUGHNESS=.95;SPECULAR=.12;
}
