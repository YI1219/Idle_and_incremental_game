shader_type spatial;
uniform sampler2D albedo_tex : source_color;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	vec3 base=texture(albedo_tex,UV).rgb;
	if(local_position.y>2.3){
		float rib=1.0-smoothstep(0.035,0.11,abs(fract(local_position.x*3.6)-0.5));
		float row=1.0-smoothstep(0.012,0.045,abs(fract(local_position.z*2.8)-0.5));
		base*=vec3(1.35,1.15,0.85);
		base*=1.0-rib*0.38-row*0.09;
	}
	if(local_position.y<=2.3){
		float brightness=max(base.r,max(base.g,base.b));
		float neutral=1.0-smoothstep(.10,.25,brightness-min(base.r,min(base.g,base.b)));
		base=mix(base,base*vec3(1.0,.77,.48),smoothstep(.48,.72,brightness)*neutral*.70);
	}
	ALBEDO=base;
	ROUGHNESS=.93;
	SPECULAR=.25;
}
