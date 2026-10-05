shader_type spatial;
render_mode cull_disabled;
uniform bool fall = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float veins(vec2 p){
	vec2 cell=floor(p);vec2 f=fract(p);float first=10.0;float second=10.0;
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 offset=vec2(float(x),float(y));vec2 d=offset+hash2(cell+offset)-f;float v=dot(d,d);
		if(v<first){second=first;first=v;}else if(v<second){second=v;}
	}
	return 1.0-smoothstep(0.018,0.075,second-first);
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
	if(fall){
		vec2 flow=vec2(UV.x*1.65,UV.y*1.25-TIME*0.85);
		flow.x+=sin(UV.y*4.1-TIME*.8)*.13+sin(UV.x*5.2+UV.y*1.7)*.08;
		float line=veins(flow);
		float streak=pow(0.5+0.5*sin(UV.x*28.0+sin(UV.y*1.8-TIME*2.0)),10.0);
		color=mix(vec3(0.07,0.46,0.68),vec3(0.73,0.94,1.0),max(line*0.72,streak*.16));
		EMISSION=color*.2;
	}
	ALBEDO=color;
	ROUGHNESS=0.32;
	SPECULAR=0.45;
}
