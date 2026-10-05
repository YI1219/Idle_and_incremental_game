shader_type spatial;
render_mode cull_disabled;
uniform bool fall = false;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin=vec2(0.0);
uniform vec2 shore_extent=vec2(1.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec2 veins(vec2 p){
	vec2 cell=floor(p);vec2 f=fract(p);float first=10.0;float second=10.0;vec2 selected=vec2(0.0);
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 offset=vec2(float(x),float(y));vec2 d=offset+hash2(cell+offset)-f;float v=dot(d,d);
		if(v<first){second=first;first=v;selected=cell+offset;}else if(v<second){second=v;}
	}
	float border=second-first;
	float softness=max(.022,fwidth(border)*.9);
	float edge=1.0-smoothstep(.010,.010+softness,border);
	float brightness=mix(.48,1.0,smoothstep(.18,.82,hash2(selected+vec2(17.0)).y));
	return vec2(edge*brightness,hash2(selected).x);
}
void fragment(){
	vec2 p=world_position.xz;
	vec2 warped=p*1.9+vec2(sin(p.y*.71),sin(p.x*.83))*.25;
	vec2 cell=floor(warped);vec2 f=fract(warped);float nearest=10.0;vec2 selected=vec2(0.0);
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 offset=vec2(float(x),float(y));vec2 delta=offset+hash2(cell+offset)-f;
		float distance=dot(delta,delta);
		if(distance<nearest){nearest=distance;selected=cell+offset;}
	}
	float facet=hash2(selected).x;
	float wave=sin(p.x*2.2+p.y*1.8+TIME*0.7)*0.12+(facet-0.5)*0.48;
	vec3 color=mix(vec3(0.012,0.25,0.55),vec3(0.065,0.50,0.80),clamp(wave+0.55,0.0,1.0));
	if(!fall){
		vec4 shore_data=texture(shore_field,(p-shore_origin)/shore_extent);
		float shallow=1.0-smoothstep(.08,.78,shore_data.r);
		float depth=clamp(shore_data.g*4.0,0.0,1.0);
		color=mix(color,vec3(.025,.18,.35),depth*.18);
		vec3 bank_color=mix(vec3(.035,.30,.26),vec3(.10,.40,.31),facet);
		color=mix(color,bank_color,shallow*.72);
		float glint=pow(.5+.5*sin(p.x*4.5+p.y*7.3+TIME*.42),28.0)*pow(.5+.5*sin(p.x*2.6-p.y*5.8-TIME*.2),6.0);
		color=mix(color,vec3(.58,.76,.78),glint*.14);
	}
	if(fall){
		vec2 flow=vec2(UV.x*5.2,UV.y*2.6+TIME*1.45);
		flow.x+=sin(flow.y*1.8)*.20+sin(flow.x*.93+flow.y*.73)*.10;
		vec2 field=veins(flow);
		float line=field.x;
		// Finer advected facets with varied vein brightness, avoiding a wire cage.
		float sheet=field.y;
		float glint=line*.55;
		color=mix(vec3(.055,.47,.76),vec3(.27,.75,.90),sheet*.85);
		color=mix(color,vec3(.84,.98,1.0),glint);
		EMISSION=color*.06;
	}
	ALBEDO=color;
	ROUGHNESS=fall?.6:.32;
	SPECULAR=fall?.2:.45;
}
