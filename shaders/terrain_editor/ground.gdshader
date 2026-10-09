shader_type spatial;
#include "land_palette.gdshaderinc"
render_mode cull_disabled;
uniform bool show_grid = false;
// Simulated low plant cover: soft multi-scale mottling, sparse darker plant
// dabs and pale seed heads, lit through a gentle world-space height field.
uniform float cover_relief = .55;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float value_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);
}
float cover_height(vec2 p){
	mat2 turn=mat2(vec2(.8,.6),vec2(-.6,.8));
	return value_noise(p*1.7)*.45+value_noise(turn*p*4.3+vec2(5.2,1.3))*.35+value_noise(turn*turn*p*9.1+vec2(2.7,8.1))*.20;
}
void fragment(){
	vec2 p=world_position.xz;
	float broad=sin(p.x*0.51+p.y*0.22)*sin(p.y*0.47-p.x*0.18)*0.5+0.5;
	vec3 base=mix(grass_base,grass_highlight,broad);
	// Metre-scale patches of denser, greener cover between drier open grass.
	float cover=smoothstep(.34,.76,value_noise(p*.42+vec2(3.1,7.7))*.62+value_noise(p*1.35)*.38);
	float height=cover_height(p);
	float footprint=length(fwidth(p))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	// Soft mottling: low-contrast, no cell edges.
	vec3 dry=base*vec3(1.04,1.02,.90);
	vec3 lush=base*vec3(.70,.82,.58);
	vec3 color=mix(dry,lush,clamp(cover*.75+(height-.5)*1.3*detail,0.0,1.0));
	// Two overlapping layers of irregular low tufts: darker green and
	// yellow-green, each lit as a gentle dome so the sun picks out its side.
	vec2 slope_tuft=vec2(0.0);
	float bloom=0.0;
	for(int layer=0;layer<2;layer++){
		float scale=layer==0?2.3:4.6;
		vec2 g=p*scale+vec2(sin(p.y*1.3),sin(p.x*1.1))*.30+float(layer)*vec2(17.3,5.1);
		vec2 cell=floor(g);vec2 f=fract(g);
		float best=0.0;vec2 lean=vec2(0.0);float tone=0.0;
		for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
			vec2 o=vec2(float(x),float(y));
			vec2 id=cell+o;
			float present=step(hash(id+vec2(9.0,2.0)),.62+.33*cover);
			vec2 d=o+hash2(id)*.8+.1-f;
			float r=mix(.34,.62,hash(id+vec2(4.0,9.0)));
			float wobble=(value_noise((g-id)*4.0+id*1.7)-.5)*.22;
			float tuft=(1.0-smoothstep(0.0,r+wobble,length(d)))*present;
			if(tuft>best){best=tuft;lean=-d/r;tone=hash(id+vec2(1.0,7.0));}
			if(layer==1)bloom=max(bloom,step(.94,hash(id+vec2(17.0,3.0)))*(1.0-smoothstep(.04,.08,length(d))));
		}
		vec3 dark=mix(base*vec3(.56,.68,.48),vec3(.22,.27,.15),.25);
		vec3 light=base*vec3(.96,.97,.84);
		vec3 tuft_color=mix(dark,light,tone*tone)*(.92+.14*best);
		color=mix(color,tuft_color,smoothstep(0.0,.35,best)*(layer==0?.82:.55)*detail);
		slope_tuft-=lean*smoothstep(0.0,.6,best)*(layer==0?.35:.25);
	}
	// Fine blade grain keeps the surface from reading as flat paint.
	float grain=value_noise(p*vec2(31.0,27.0))*.5+value_noise(p*vec2(63.0,57.0))*.5;
	color*=1.0+(grain-.5)*.10*detail;
	color=mix(color,vec3(.88,.85,.70),bloom*.65*detail);
	if(show_grid){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
	ALBEDO=color*COLOR.rgb;
	// A gentle height field (plus raised dabs) varies the sun's response.
	float e=.04;
	vec2 slope=vec2(cover_height(p+vec2(e,0.0))-height,cover_height(p+vec2(0.0,e))-height)/e;
	slope=slope*.08+slope_tuft;
	vec3 normal_world=normalize(vec3(-slope.x*cover_relief*detail,1.0,-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=0.95;
	SPECULAR=.30;
}
