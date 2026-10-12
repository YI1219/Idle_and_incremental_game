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
	color*=1.0+(slow-.5)*.12;
	// Short cover. A directional weave a couple of decimetres long, plus a
	// softer cross tone. Low enough that it stays nap, not grain.
	float weave=gc_noise(p*vec2(6.4,2.6)+vec2(8.2,1.4));
	float crossw=gc_noise(turn*p*vec2(2.8,5.6)+vec2(1.2,5.5));
	color*=1.0+((weave-.5)*.14+(crossw-.5)*.07)*mix(.7,1.0,detail);
	color+=vec3(.020,.012,0.0)*smoothstep(.55,.84,weave)*detail;
	// Short strokes, about a decimetre. They fill the close carpet without
	// returning to millimetre grain.
	float thread=gc_noise(p*vec2(10.5,4.2)+vec2(3.2,8.6));
	color*=1.0+(thread-.5)*.09*detail;
	float fibre=gc_noise(p*vec2(4.2,4.8)+vec2(1.2,8.0));
	color*=1.0+(fibre-.5)*.018*detail;
	vec4 mapped=texture(ground_detail_map,p*.20);
	color*=1.0+(mapped.r-.5)*.03*detail;
	// Moss speckles inside broader mossy ground. Small dabs, not shadow puddles.
	float mossy=smoothstep(.58,.82,gc_noise(p*1.15+vec2(2.2,6.4)));
	float moss=smoothstep(.74,.90,gc_noise(p*8.2+vec2(14.2,3.1)))*mossy;
	color=mix(color,color*vec3(.80,.93,.76),moss*.50*standing);
	// Little wildflowers. A cell either blooms or it does not; petals stay
	// a few centimetres so a close crop reads as blossoms, not lamps.
	vec2 plot=floor(p*1.35);
	float spawn=gc_hash(plot+vec2(2.0,5.0));
	float kind=gc_hash(plot+vec2(19.0,7.0));
	vec2 heart=(plot+.5)/1.35+(vec2(gc_hash(plot+vec2(1.0,0.0)),gc_hash(plot+vec2(0.0,3.0)))-.5)*.28;
	vec2 d=p-heart;
	float ang=atan(d.y,d.x);
	float petal=.55+.45*cos(ang*(kind>.5?5.0:4.0)+kind*6.0);
	float rad=.046+petal*.032;
	float bloom=smoothstep(rad,rad*.30,length(d))*step(.40,spawn)*standing;
	vec3 flower=mix(vec3(.86,.84,.72),vec3(.80,.68,.40),step(.46,kind));
	color=mix(color,flower,bloom*.82);
	vec2 plot2=floor(p*4.2);
	float speck=smoothstep(.020,.004,length(p-(plot2+.5)/4.2))*step(.74,gc_hash(plot2+vec2(8.0,1.0)))*standing;
	color=mix(color,vec3(.88,.86,.74),speck*.72);
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
	slope+=vec2(napx-nap,napz-nap)/e*.08;
	slope+=(mapped.gb-.5)*.04;
	slope*=standing*mix(.5,1.0,detail);
	return color;
}
