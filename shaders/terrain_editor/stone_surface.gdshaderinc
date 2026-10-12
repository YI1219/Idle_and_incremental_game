// Linear RGBA: mineral value, local U/V slopes, roughness. World-space
// triplanar projection continues across independent bodies and their backing.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
vec3 stone_weights(vec3 n){vec3 w=pow(abs(n),vec3(4.0));return w/max(dot(w,vec3(1.0)),.001);}
vec4 stone_map(vec3 p,vec3 n){vec3 w=stone_weights(n);return texture(stone_detail_map,p.zy*.38)*w.x+texture(stone_detail_map,p.xz*.38)*w.y+texture(stone_detail_map,p.xy*.38)*w.z;}
vec3 stone_normal(vec3 p,vec3 n){
 vec3 w=stone_weights(n);
 vec2 x=(texture(stone_detail_map,p.zy*.38).gb-.5)*2.0;
 vec2 y=(texture(stone_detail_map,p.xz*.38).gb-.5)*2.0;
 vec2 z=(texture(stone_detail_map,p.xy*.38).gb-.5)*2.0;
 vec3 slope=vec3(0.0,x.y,x.x)*w.x+vec3(y.x,0.0,y.y)*w.y+vec3(z.x,z.y,0.0)*w.z;
 vec2 x2=(texture(stone_detail_map,p.zy*1.65+vec2(3.1,1.7)).gb-.5)*2.0;
 vec2 y2=(texture(stone_detail_map,p.xz*1.65+vec2(8.4,2.2)).gb-.5)*2.0;
 vec2 z2=(texture(stone_detail_map,p.xy*1.65+vec2(1.3,6.6)).gb-.5)*2.0;
 vec3 fine=vec3(0.0,x2.y,x2.x)*w.x+vec3(y2.x,0.0,y2.y)*w.y+vec3(z2.x,z2.y,0.0)*w.z;
 // Colour carries the broad mineral variation. A coarse normal bend
 // shades the middle of a flat cut as a pit, so only a short grit remains.
 vec3 bent=(fine-n*dot(n,fine))*.04;
 return normalize(n-bent);
}
// Quiet world-anchored mineral variation shared by the stone envelope,
// fractured sides and shore rocks. Physical planes provide the large facets.
float stone_noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(rock_hash(i).x,rock_hash(i+vec3(1,0,0)).x,f.x),mix(rock_hash(i+vec3(0,1,0)).x,rock_hash(i+vec3(1,1,0)).x,f.x),f.y),mix(mix(rock_hash(i+vec3(0,0,1)).x,rock_hash(i+vec3(1,0,1)).x,f.x),mix(rock_hash(i+vec3(0,1,1)).x,rock_hash(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
vec3 stone_surface(vec3 p,vec3 n){
 float cloud=stone_noise(p*.72);
 float mineral=stone_noise(p*.29+vec3(13.0,4.0,7.0));
 float grain=stone_noise(p*8.0);
 float chip=stone_noise(p*3.3);
 float grit=stone_noise(p*12.5);
 vec3 stone=cliff_gray(.66)+vec3(.085,.088,.092);
 stone+=(cloud-.5)*vec3(.09,.095,.10)+(mineral-.5)*vec3(.04,.035,.02);
 stone+=(chip-.5)*vec3(.045,.048,.05)+(grit-.5)*vec3(.03,.032,.034);
 return stone*(.98+grain*.04)*(1.0+(stone_map(p,n).r-.5)*.22);
}
// Colour weathering for a cliff cut. The caller keeps one outward geometric
// normal. Moss and stains are broken patches, not a lip or a green shoulder.
vec3 cliff_weather(vec3 stone,vec3 p,vec3 n){
	float mass=stone_noise(p*.11+vec3(3.0,1.4,8.0));
	float mid=stone_noise(p*.28+vec3(1.2,6.0,2.4));
	stone*=.84+.26*mass+.08*(mid-.5);
	// Convex wear stays a colour. Upward faces lighten to a warm grey;
	// the caller still shades with one outward normal per cut.
	float worn=smoothstep(-.05,.78,n.y);
	stone=mix(stone,stone*vec3(1.16,1.12,1.05),worn*.50);
	float cool=smoothstep(.40,-.20,n.y);
	stone=mix(stone,stone*vec3(.93,.96,1.02),cool*.20);
	float chip=stone_noise(p*1.35+vec3(4.0,2.0,7.0));
	stone*=.88+.22*chip;
	float column=stone_noise(p*vec3(.35,.05,.35)+vec3(4.0,0.0,9.0));
	float drip=stone_noise(vec3(p.x*.72,p.y*.11,p.z*.72)+vec3(2.0,7.0,1.0));
	float stain=smoothstep(.60,.88,drip)*smoothstep(.40,.76,column);
	stone=mix(stone,stone*vec3(.72,.74,.68),stain*.40);
	// Moss is a pocket and a thin hanging veil. The cut itself stays grey.
	float shelf=smoothstep(.22,.74,n.y);
	float pocket=stone_noise(p*vec3(.24,.12,.24)+vec3(9.0,2.0,4.0));
	float moss=smoothstep(.64,.88,pocket)*mix(.28,1.0,max(shelf*.55,stain));
	float veil=stone_noise(vec3(p.x*1.2,p.y*.20,p.z*1.2)+vec3(5.0,1.0,3.0));
	float hang=smoothstep(.52,.82,veil)*smoothstep(.30,.62,column);
	hang*=1.0-smoothstep(.16,.58,n.y);
	vec3 moss_col=vec3(.30,.44,.22)*(.92+.14*mass);
	vec3 deep=vec3(.20,.32,.16);
	stone=mix(stone,mix(moss_col,deep,hang*.45),clamp(moss*.55+hang*.66,0.0,.52));
	float grit=stone_noise(p*3.2);
	stone*=.96+.08*grit;
	return stone;
}
// Short tangent grit. High frequency, so a flat cut is not one slab and
// the face is not bent into a pit.
vec3 cliff_face_normal(vec3 p,vec3 n){
	vec3 base=stone_normal(p,n);
	float a=stone_noise(p*6.2);
	float b=stone_noise(p*6.2+vec3(2.2,.4,1.3));
	float c=stone_noise(p*10.5+vec3(1.0,3.2,.6));
	vec3 chip=vec3(a-.5,c-.5,b-.5);
	chip=(chip-n*dot(n,chip))*.065;
	return normalize(base-chip);
}
