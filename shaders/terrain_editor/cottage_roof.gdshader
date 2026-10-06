shader_type spatial;
uniform sampler2D albedo_tex : source_color;
uniform bool use_texture=true;
uniform vec4 base_color : source_color=vec4(1.0);
// 0 retained textured surfaces, 1 timber, 2 plaster panels, 3 foundation stone.
uniform int surface_role=0;
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
	vec3 base=base_color.rgb;
	if(use_texture){base*=texture(albedo_tex,UV).rgb;}
	if(surface_role==0 && local_position.y>2.3){
		float rib=1.0-smoothstep(0.035,0.11,abs(fract(local_position.x*3.6)-0.5));
		float row=1.0-smoothstep(0.012,0.045,abs(fract(local_position.z*2.8)-0.5));
		float value=dot(base,vec3(.299,.587,.114));
		base=vec3(.122,.147,.138)*(.80+value*.65);
		base*=1.0-rib*0.38-row*0.09;
	}
	if(surface_role==2 && local_position.y>.35){
		float along=mix(local_position.x,local_position.z,step(.5,abs(local_normal.x)));
		float seam=1.0-smoothstep(.01,.045,abs(fract(local_position.y*3.3)-.5));
		float post=1.0-smoothstep(.025,.065,abs(fract((along+.14)/1.05)-.5));
		float beam=1.0-smoothstep(.03,.075,min(abs(local_position.y-.65),abs(local_position.y-1.72)));
		vec3 timber=mix(vec3(.18,.125,.083),vec3(.28,.20,.13),.5+.15*sin(along*21.0+local_position.y*3.0));
		timber*=1.0-seam*.16;
		timber=mix(timber,vec3(.12,.095,.068),max(post,beam)*.85);
		base=mix(base,timber,.94);
	}
	ALBEDO=base;
	ROUGHNESS=.93;
	SPECULAR=.25;
}
