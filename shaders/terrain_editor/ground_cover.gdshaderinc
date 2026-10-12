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
// Broad olive fields, a softer metre-scale mottling, settled hollows and a
// directional nap. Blossoms stay inside that field so a clump cannot cut a
// disc out of the carpet. Requires land_palette.gdshaderinc.
float gc_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float gc_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(gc_hash(i),gc_hash(i+vec2(1,0)),u.x),mix(gc_hash(i+vec2(0,1)),gc_hash(i+vec2(1,1)),u.x),u.y);
}
vec3 lawn_normal(vec3 base,vec2 slope,float detail,float relief){
	return normalize(base+vec3(-slope.x*relief*detail,0.0,-slope.y*relief*detail));
}
// Returns the cover colour; slope receives a small world-space tilt for lighting.
vec3 ground_cover(vec2 p,float detail,out vec2 slope){
	float standing=gc_standing(p);
	detail*=standing;
	mat2 turn=mat2(vec2(.80,.60),vec2(-.60,.80));
	// ~8 m fields, then ~3 m, then ~1.2 m. Smoothstep keeps them as soft
	// olive patches rather than a sand of mixed pixels or a tile.
	float field=gc_noise(p*.125+vec2(1.7,5.2));
	float broad=gc_noise(p*.34+vec2(2.2,6.4));
	float mid=gc_noise(turn*p*1.15+vec2(11.0,3.4));
	float mix_t=smoothstep(.12,.88,clamp(field*.46+broad*.34+mid*.20,0.0,1.0));
	vec3 deep=grass_base*vec3(.90,.94,.88);
	vec3 lit=grass_highlight*vec3(1.03,1.04,.99);
	vec3 color=mix(deep,lit,mix_t);
	float slow=gc_noise(p*.16+vec2(4.1,9.2));
	color*=1.0+(slow-.5)*.16;
	// Settled hollows. A soft darkening in the low part of the nap, not a crease
	// and not a hard camouflage patch.
	float hollow=gc_noise(p*.42+vec2(8.4,1.6));
	float settle=smoothstep(.64,.26,hollow);
	color*=mix(1.0,.84,settle*.58*standing);
	// Directional nap a few decimetres long, plus a quieter cross tone.
	float weave=gc_noise(p*vec2(3.4,1.45)+vec2(8.2,1.4));
	float crossw=gc_noise(turn*p*vec2(1.5,3.2)+vec2(1.2,5.5));
	color*=1.0+((weave-.5)*.20+(crossw-.5)*.08)*mix(.70,1.0,detail);
	color+=vec3(.024,.015,.003)*smoothstep(.54,.86,weave)*detail;
	float thread=gc_noise(p*vec2(6.6,2.5)+vec2(3.2,8.6));
	color*=1.0+(thread-.5)*.09*detail;
	vec4 mapped=texture(ground_detail_map,p*.16);
	color*=1.0+(mapped.r-.5)*.055*detail;
	// Moss beds with small dabs inside them.
	float mossy=smoothstep(.48,.78,gc_noise(p*.72+vec2(2.2,6.4)));
	color=mix(color,color*vec3(.84,.98,.80),mossy*.34*standing);
	float moss=smoothstep(.70,.90,gc_noise(p*5.6+vec2(14.2,3.1)))*mossy;
	color=mix(color,color*vec3(.74,.94,.72),moss*.48*standing);
	// Short olive strokes, like flattened stems in the nap.
	vec2 stem=floor(p*2.4);
	vec2 stem_at=(stem+.5)/2.4+(vec2(gc_hash(stem+vec2(3.0,1.0)),gc_hash(stem+vec2(1.0,4.0)))-.5)*.22;
	vec2 sd=p-stem_at;
	float stem_ang=gc_hash(stem+vec2(9.0,2.0))*6.2;
	vec2 stem_dir=vec2(cos(stem_ang),sin(stem_ang));
	float along=dot(sd,stem_dir);
	float across=dot(sd,vec2(-stem_dir.y,stem_dir.x));
	float stroke=smoothstep(.07,.0,abs(along))*smoothstep(.012,.0,abs(across))*step(.76,gc_hash(stem+vec2(6.0,8.0)))*standing;
	color=mix(color,color*vec3(.76,.90,.68),stroke*.48*detail);
	// Blossoms sit in the nap: small, soft, not paper stickers.
	vec2 plot=floor(p*1.15);
	float spawn=gc_hash(plot+vec2(2.0,5.0));
	float kind=gc_hash(plot+vec2(19.0,7.0));
	vec2 heart=(plot+.5)/1.15+(vec2(gc_hash(plot+vec2(1.0,0.0)),gc_hash(plot+vec2(0.0,3.0)))-.5)*.34;
	vec2 d=p-heart;
	float ang=atan(d.y,d.x);
	float petal=.62+.38*cos(ang*(kind>.55?5.0:4.0)+kind*6.0);
	float rad=.030+petal*.016;
	float bloom=smoothstep(rad,rad*.22,length(d))*step(.58,spawn)*standing;
	vec3 flower=mix(vec3(.62,.60,.50),vec3(.58,.48,.32),step(.46,kind));
	color=mix(color,mix(color,flower,.72),bloom*.62);
	vec2 plot2=floor(p*3.4);
	float speck=smoothstep(.016,.003,length(p-(plot2+.5)/3.4))*step(.82,gc_hash(plot2+vec2(8.0,1.0)))*standing;
	color=mix(color,vec3(.70,.66,.52),speck*.48);
	color*=mix(vec3(.88,.90,.86),vec3(1.0),standing);
	float e=.22;
	float h=gc_noise(p*.85);
	float hx=gc_noise((p+vec2(e,0.0))*.85);
	float hz=gc_noise((p+vec2(0.0,e))*.85);
	float g=gc_noise(turn*p*1.8+vec2(3.0,5.0));
	float gx=gc_noise(turn*(p+vec2(e,0.0))*1.8+vec2(3.0,5.0));
	float gz=gc_noise(turn*(p+vec2(0.0,e))*1.8+vec2(3.0,5.0));
	slope=vec2(hx-h,hz-h)/e*.05;
	slope+=vec2(gx-g,gz-g)/e*.018;
	float nap=gc_noise(p*vec2(4.2,3.6)+vec2(2.0,4.0));
	float napx=gc_noise((p+vec2(e,0.0))*vec2(4.2,3.6)+vec2(2.0,4.0));
	float napz=gc_noise((p+vec2(0.0,e))*vec2(4.2,3.6)+vec2(2.0,4.0));
	slope+=vec2(napx-nap,napz-nap)/e*.20;
	slope+=(mapped.gb-.5)*.035;
	slope*=standing*mix(.55,1.0,detail);
	return color;
}
// Cap and pads share this, including the quiet meadow whisper, so a pad
// cannot redraw itself as a different disc.
vec3 lawn_color(vec2 p,float detail,out vec2 slope){
	vec3 color=ground_cover(p,detail,slope);
	float meadow=clamp((sin(p.x*1.15+p.y*.42)*sin(p.y*1.35-p.x*.33)*.55+sin(p.x*2.05-p.y*.70)*sin(p.y*1.80+p.x*.55)*.45)*.5+.82,0.0,1.0);
	meadow=meadow*meadow*(3.0-2.0*meadow);
	color=mix(color*vec3(.992,.995,.990),color,mix(.988,1.0,meadow));
	return color;
}
