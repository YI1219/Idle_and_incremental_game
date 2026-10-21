#include "weathering.gdshaderinc"
uniform vec2 footpath_points[8];
uniform int footpath_count=0;
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
// Fine colour and lighting contrast. The courtyard default keeps metre-scale
// cover and quiets blade grain, seed specks and the detail map.
uniform float ground_fine_strength : hint_range(0.0, 1.0) = 0.58;
// World-space compression is supplied by TerrainRenderer.set_grass_compression.
// No mask means standing cover; outside the supplied field stays standing.
uniform sampler2D grass_compression : filter_linear, repeat_disable, hint_default_black;
uniform vec2 compression_origin = vec2(-64.0);
uniform vec2 compression_extent = vec2(128.0);
float gc_standing(vec2 p){
 vec2 uv=(p-compression_origin)/compression_extent;
 float inside=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
 return 1.0-texture(grass_compression,uv).r*inside;
}
// Simulated low plant cover shared by the terrain cap and the grassy crowns of
// rim blocks: soft multi-scale mottling, sparse darker plant dabs and pale
// seed heads, lit through a gentle world-space height field. Being a pure
// function of world XZ, a crown continues exactly the lawn beside it.
// Requires land_palette.gdshaderinc.
float gc_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec2 gc_hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
float gc_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(gc_hash(i),gc_hash(i+vec2(1,0)),u.x),mix(gc_hash(i+vec2(0,1)),gc_hash(i+vec2(1,1)),u.x),u.y);
}
float gc_cover_height(vec2 p){
	mat2 turn=mat2(vec2(.8,.6),vec2(-.6,.8));
	return gc_noise(p*1.7)*.45+gc_noise(turn*p*4.3+vec2(5.2,1.3))*.35+gc_noise(turn*turn*p*9.1+vec2(2.7,8.1))*.20;
}
// Returns the cover colour; slope receives the surface tilt for lighting.
vec3 ground_cover(vec3 position,float detail,out vec2 slope){
 vec2 p=position.xz;
	float standing=gc_standing(p);
	detail*=standing;
	float fine_detail=detail*ground_fine_strength;
	float broad=sin(p.x*0.51+p.y*0.22)*sin(p.y*0.47-p.x*0.18)*0.5+0.5;
	vec3 base=mix(grass_base,grass_highlight,broad);
	// Metre-scale patches of denser, greener cover between drier open grass.
	float cover=smoothstep(.34,.76,gc_noise(p*.42+vec2(3.1,7.7))*.62+gc_noise(p*1.35)*.38);
	float height=gc_cover_height(p);
	// Soft mottling: one grey-olive family, no cell edges, no yellow-green split.
	vec3 dry=base*vec3(1.02,1.01,.99);
	vec3 lush=base*vec3(.88,.96,.86);
	vec3 color=mix(dry,lush,clamp(cover*.50+(height-.5)*.42*fine_detail,0.0,1.0));
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
			float present=step(gc_hash(id+vec2(9.0,2.0)),.34+.30*cover);
			vec2 d=o+gc_hash2(id)*.8+.1-f;
			float r=mix(.34,.62,gc_hash(id+vec2(4.0,9.0)));
			float wobble=(gc_noise((g-id)*4.0+id*1.7)-.5)*.22;
			float tuft=(1.0-smoothstep(0.0,r+wobble,length(d)))*present;
			if(tuft>best){best=tuft;lean=-d/r;tone=gc_hash(id+vec2(1.0,7.0));}
			if(layer==1)bloom=max(bloom,step(.94,gc_hash(id+vec2(17.0,3.0)))*(1.0-smoothstep(.04,.08,length(d))));
		}
		vec3 dark=mix(base*vec3(.92,.95,.90),vec3(.44,.47,.38),.08);
		vec3 light=base*vec3(1.03,1.02,.98);
		vec3 tuft_color=mix(dark,light,tone*tone)*(.96+.06*best);
		color=mix(color,tuft_color,smoothstep(0.0,.35,best)*(layer==0?.55:.32)*fine_detail);
		slope_tuft-=lean*smoothstep(0.0,.6,best)*(layer==0?.35:.25);
	}
	// Fine blade grain keeps the surface from reading as flat paint.
	float grain=gc_noise(p*vec2(31.0,27.0))*.5+gc_noise(p*vec2(63.0,57.0))*.5;
	color*=1.0+(grain-.5)*.035*fine_detail;
	color=mix(color,vec3(.78,.76,.62),bloom*.18*fine_detail);
	float e=.04;
	slope=vec2(gc_cover_height(p+vec2(e,0.0))-height,gc_cover_height(p+vec2(0.0,e))-height)/e;
	// Sparse clumps get a fine directional blade cue. The same compression
 // mask removes both their color relief and their normal relief.
 float blade=sin(p.x*71.0+p.y*29.0+gc_noise(p*3.0)*5.0);
 color*=1.0+blade*.008*cover*fine_detail;
 slope=(slope*.05+slope_tuft*.55)*standing*ground_fine_strength;
 vec4 mapped=texture(ground_detail_map,p*.48);
 color*=1.0+(mapped.r-.5)*.10*fine_detail;
 slope+=(mapped.gb-.5)*.55*standing*ground_fine_strength;
 // Worn earth follows the authored stepping-stone route. Compression can
 // still flatten cover later; the ribbon itself stays a soft beige block.
 float distance_to_path=1000.0;
 for(int i=0;i<7;i++){
  if(i+1>=footpath_count)break;
  vec2 a=footpath_points[i];vec2 edge=footpath_points[i+1]-a;
  float t=clamp(dot(p-a,edge)/max(dot(edge,edge),.0001),0.0,1.0);
  distance_to_path=min(distance_to_path,length(p-a-edge*t));
 }
 // A soft worn ribbon under the stones. Low-frequency edges stay readable;
 // the centre stays a solid beige block, and grass only feathers the margin.
 float irregular=gc_noise(p*1.15)*.16+gc_noise(p*2.4)*.05;
 float margin=(gc_noise(p*2.5)-.5)*.06;
 float wear=1.0-smoothstep(.28+irregular,.68+irregular,distance_to_path+margin);
 float bare=smoothstep(.84,.96,gc_noise(p*.48+vec2(21.0,8.0))*.7+gc_noise(p*1.4)*.3)*.10;
 vec3 deposits=tw_deposits(position);
 float fragments=smoothstep(.58,.86,gc_noise(p*4.2)*.65+gc_noise(p*1.7)*.35);
 float weathered=deposits.x*(.02+.05*fragments);
 float soil=max(max(max(wear*.94,bare),weathered),1.0-standing);
 soil*=1.0-fragments*.42*standing*(1.0-smoothstep(.22,.62,wear));
 vec3 earth=tw_soil(p);
 color=mix(color,earth,soil);
 float grit=deposits.z*soil*detail;
 color=mix(color,mix(earth,vec3(.58,.56,.49),.40),grit*.12);
 slope*=1.0-soil*.70;
 return color;
}
