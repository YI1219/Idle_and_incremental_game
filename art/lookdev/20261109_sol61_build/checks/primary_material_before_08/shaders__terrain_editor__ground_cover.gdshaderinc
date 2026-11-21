#include "weathering.gdshaderinc"
uniform vec2 footpath_points[8];
uniform int footpath_count=0;
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
// Fine colour and lighting contrast. Lower default yields soft color-block cover.
uniform float ground_fine_strength : hint_range(0.0, 1.0) = .05;
uniform float lantern_glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lantern_glow_color : source_color = vec3(1.0, .65, .25);
// World-space compression is supplied by TerrainRenderer.set_grass_compression.
uniform sampler2D grass_compression : filter_linear, repeat_disable, hint_default_black;
uniform vec2 compression_origin = vec2(-64.0);
uniform vec2 compression_extent = vec2(128.0);
float gc_standing(vec2 p){
 vec2 uv=(p-compression_origin)/compression_extent;
 float inside=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
 return 1.0-texture(grass_compression,uv).r*inside;
}
float gc_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec2 gc_hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float gc_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);
	// C2 quintic interpolation eliminates grid-line derivative creases and moire bands when zoomed in:
	vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
	return mix(mix(gc_hash(i),gc_hash(i+vec2(1,0)),u.x),mix(gc_hash(i+vec2(0,1)),gc_hash(i+vec2(1,1)),u.x),u.y);
}
float gc_cover_height(vec2 p){
	mat2 turn=mat2(vec2(.8,.6),vec2(-.6,.8));
	return gc_noise(p*1.1)*.56+gc_noise(turn*p*2.3+vec2(5.2,1.3))*.30+gc_noise(turn*turn*p*4.2+vec2(2.7,8.1))*.14;
}
float gc_path_dist(vec2 p){
	float distance_to_path=1000.0;
	for(int i=0;i<7;i++){
		if(i+1>=footpath_count)break;
		vec2 a=footpath_points[i];vec2 edge=footpath_points[i+1]-a;
		float t=clamp(dot(p-a,edge)/max(dot(edge,edge),.0001),0.0,1.0);
		distance_to_path=min(distance_to_path,length(p-a-edge*t));
	}
	return distance_to_path;
}
// Broad 1.6m–4.2m isotropic soft moss-meadow cushion height (rotated octaves, zero grid or stripe artifacts!):
float gc_pillow_core(vec2 p){
	mat2 r1=mat2(vec2(.80,.60),vec2(-.60,.80));
	mat2 r2=mat2(vec2(-.44,.90),vec2(-.90,-.44));
	return gc_noise(r1*p*.34+vec2(3.7,8.2))*.62+gc_noise(r2*p*.68+vec2(14.3,5.9))*.38;
}
float gc_pillow_h(vec2 p){
	float d_path=gc_path_dist(p);
	float path_shoulder=smoothstep(.48,.92,d_path)*(1.0-smoothstep(1.05,1.85,d_path))*.14;
	return gc_pillow_core(p)+path_shoulder;
}
vec2 gc_pillow_grad(vec2 p){
	float e=.22;
	float h0=gc_pillow_core(p);
	return vec2(gc_pillow_core(p+vec2(e,0.0))-h0,gc_pillow_core(p+vec2(0.0,e))-h0)/e;
}
// Multi-scale gouache meadow cushions (水粉绒毯草甸 · 柔和色块 · 零条纹零摩尔纹):
vec3 ground_cover(vec3 position,float detail,out vec2 slope){
 vec2 p=position.xz;
 float standing=gc_standing(p);
 mat2 a=mat2(vec2(.80,.60),vec2(-.60,.80));
 mat2 b=mat2(vec2(-.44,.90),vec2(-.90,-.44));
 float broad=gc_noise(a*p*.32+vec2(4.3,9.1));
 float wash=gc_noise(b*p*.72+vec2(13.7,2.4));
 float pillow=gc_pillow_h(p);
 float pigment=smoothstep(.14,.88,broad*.64+wash*.36);
 vec3 moss=mix(grass_base,grass_highlight,.24+pigment*.61);
 vec3 cool_paint=moss*vec3(.96,1.04,.95);
 vec3 warm_paint=moss*vec3(1.28,1.20,1.02);
 vec3 color=mix(cool_paint,warm_paint,smoothstep(.12,.88,pillow*.58+wash*.42));
 float paper=gc_noise(b*p*2.1+vec2(6.1,11.4));
 color*=.985+.030*paper;
 vec2 gradient=gc_pillow_grad(p);
 slope=gradient*.10*standing;
 float distance_to_path=gc_path_dist(p);
 float wobble=(gc_noise(p*1.6)-.5)*.10+(gc_noise(p*4.2)-.5)*.04;
 float wear=1.0-smoothstep(.24+wobble,.52+wobble,distance_to_path);
 float verge=smoothstep(.34,.52,distance_to_path)*(1.0-smoothstep(.54,.84,distance_to_path));
 color=mix(color,color*vec3(.90,1.02,.86),verge*.22);
 float soil=max(wear*.92,(1.0-standing)*.42);
 float sand_wash=gc_noise(p*1.1)*.65+gc_noise(p*2.8)*.35;
 vec3 warm_sand=mix(vec3(.245,.236,.145),vec3(.330,.312,.192),sand_wash);
 color=mix(color,warm_sand,soil);
 slope*=1.0-soil*.85;
 if(lantern_glow_strength>.001){
  float d=length(p-vec2(12.3,-2.45));
  color+=lantern_glow_color*exp(-d*d*.68)*lantern_glow_strength*.42;
 }
 return color;
}

void meadow_diffuse(vec3 n,vec3 l,vec3 light_color,float attenuation,inout vec3 diffuse){
 vec3 lc=light_color/PI;
 float nl=dot(n,l);
 float response=.18+.88*smoothstep(-.25,.92,nl);
 float light_peak=max(lc.r,max(lc.g,lc.b));
 if(light_peak<.45){diffuse+=lc*(.38+.36*max(nl,0.0));return;}
 diffuse+=lc*(response*attenuation+(.055+.035*max(nl,0.0))*(1.0-attenuation));
}
