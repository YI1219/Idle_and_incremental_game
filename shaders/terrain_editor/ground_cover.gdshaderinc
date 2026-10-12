uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
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
// Lawn colour shared by the terrain cap, lip, banks and turf clumps.
// World-space blotches a few metres across, then a second blotch near a
// metre, between two close grey-olives. A quieter weave, moss patches and
// small flower dabs live in the same field so the carpet stays continuous.
// Requires land_palette.gdshaderinc.
float gc_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float gc_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(gc_hash(i),gc_hash(i+vec2(1,0)),u.x),mix(gc_hash(i+vec2(0,1)),gc_hash(i+vec2(1,1)),u.x),u.y);
}
// Returns the cover colour; slope receives a small world-space tilt for lighting.
vec3 ground_cover(vec2 p,float detail,out vec2 slope){
	float standing=gc_standing(p);
	detail*=standing;
	mat2 turn=mat2(vec2(.80,.60),vec2(-.60,.80));
	// ~3 m blotches, then ~0.9 m blotches. Smoothstep keeps the pair as
	// soft patches instead of a sand of mixed pixels.
	float broad=gc_noise(p*.34+vec2(2.2,6.4));
	float mid=gc_noise(turn*p*1.65+vec2(11.0,3.4));
	float mix_t=smoothstep(.16,.84,clamp(broad*.55+mid*.45,0.0,1.0));
	vec3 color=mix(grass_base,grass_highlight,mix_t);
	float slow=gc_noise(p*.22+vec2(4.1,9.2));
	color*=1.0+(slow-.5)*.10;
	// Short cover, a few decimetres across. Low contrast, so it reads as
	// nap rather than grain.
	float weave=gc_noise(p*vec2(5.2,6.1)+vec2(8.2,1.4));
	float crossw=gc_noise(turn*p*vec2(3.4,7.6)+vec2(1.2,5.5));
	color*=1.0+((weave-.5)*.055+(crossw-.5)*.035)*detail;
	float fibre=gc_noise(p*vec2(4.2,4.8)+vec2(1.2,8.0));
	color*=1.0+(fibre-.5)*.02*detail;
	vec4 mapped=texture(ground_detail_map,p*.20);
	color*=1.0+(mapped.r-.5)*.035*detail;
	// Moss: darker, a little cooler, broken into patches rather than a stain.
	float moss_n=gc_noise(p*2.35+vec2(14.2,3.1));
	float moss_break=gc_noise(turn*p*5.4+vec2(2.4,9.1));
	float moss=smoothstep(.70,.88,moss_n)*smoothstep(.28,.62,moss_break);
	color=mix(color,color*vec3(.74,.90,.72),moss*.62*standing);
	// Wildflower dabs. World-locked circles, clustered, small.
	vec2 cell=floor(p*9.0);
	float blob=smoothstep(.30,.04,length(fract(p*9.0)-.5));
	float gate=gc_hash(cell+vec2(2.0,5.0));
	float kind=gc_hash(cell+vec2(19.0,7.0));
	float cluster=smoothstep(.52,.78,gc_noise(p*.52+vec2(3.2,8.4)));
	float flower=step(.962,gate)*cluster*blob*standing;
	vec3 bloom=mix(vec3(.82,.78,.62),vec3(.76,.66,.42),step(.55,kind));
	color=mix(color,bloom,flower*.78);
	vec2 cell2=floor(p*13.0+vec2(4.0,1.0));
	float blob2=smoothstep(.22,.03,length(fract(p*13.0+vec2(4.0,1.0))-.5));
	float flower2=step(.978,gc_hash(cell2+vec2(8.0,3.0)))*cluster*blob2*standing;
	color=mix(color,vec3(.88,.86,.74),flower2*.62);
	color*=mix(vec3(.86,.88,.84),vec3(1.0),standing);
	float e=.20;
	float h=gc_noise(p*1.25);
	float hx=gc_noise((p+vec2(e,0.0))*1.25);
	float hz=gc_noise((p+vec2(0.0,e))*1.25);
	float g=gc_noise(turn*p*2.8+vec2(3.0,5.0));
	float gx=gc_noise(turn*(p+vec2(e,0.0))*2.8+vec2(3.0,5.0));
	float gz=gc_noise(turn*(p+vec2(0.0,e))*2.8+vec2(3.0,5.0));
	slope=vec2(hx-h,hz-h)/e*.06;
	slope+=vec2(gx-g,gz-g)/e*.02;
	float nap=gc_noise(p*vec2(7.4,6.6)+vec2(2.0,4.0));
	float napx=gc_noise((p+vec2(e,0.0))*vec2(7.4,6.6)+vec2(2.0,4.0));
	float napz=gc_noise((p+vec2(0.0,e))*vec2(7.4,6.6)+vec2(2.0,4.0));
	slope+=vec2(napx-nap,napz-nap)/e*.012;
	slope+=(mapped.gb-.5)*.04;
	slope*=standing*mix(.5,1.0,detail);
	return color;
}
