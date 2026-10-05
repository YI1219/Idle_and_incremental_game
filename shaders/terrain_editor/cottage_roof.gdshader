shader_type spatial;
uniform sampler2D albedo_tex : source_color;
uniform bool use_texture=true;
uniform vec4 base_color : source_color=vec4(1.0);
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	vec3 base=base_color.rgb;
	if(use_texture){base*=texture(albedo_tex,UV).rgb;}
	if(local_position.y>2.3){
		float rib=1.0-smoothstep(0.035,0.11,abs(fract(local_position.x*3.6)-0.5));
		float row=1.0-smoothstep(0.012,0.045,abs(fract(local_position.z*2.8)-0.5));
		base=mix(base*vec3(1.35,1.15,0.85),vec3(.29,.23,.16),.28);
		base*=1.0-rib*0.38-row*0.09;
	}
	if(local_position.y>.35 && local_position.y<=2.3){
		float brightness=max(base.r,max(base.g,base.b));
		float neutral=1.0-smoothstep(.10,.25,brightness-min(base.r,min(base.g,base.b)));
		float wall=smoothstep(.48,.72,brightness)*neutral;
		float along=mix(local_position.x,local_position.z,step(.5,abs(NORMAL.x)));
		float seam=1.0-smoothstep(.01,.045,abs(fract(local_position.y*3.3)-.5));
		float post=1.0-smoothstep(.025,.065,abs(fract((along+.14)/1.05)-.5));
		float beam=1.0-smoothstep(.03,.075,min(abs(local_position.y-.65),abs(local_position.y-1.72)));
		vec3 timber=mix(vec3(.43,.29,.16),vec3(.65,.48,.27),.5+.15*sin(along*21.0+local_position.y*3.0));
		timber*=1.0-seam*.16;
		timber=mix(timber,vec3(.26,.17,.095),max(post,beam)*.85);
		base=mix(base,timber,wall*.92);
	}
	ALBEDO=base;
	ROUGHNESS=.93;
	SPECULAR=.25;
}
