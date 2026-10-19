shader_type spatial;
// Deliberately restrained world-space maps also cover newly cut surfaces.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool detailed = true;
uniform bool use_contact_field = false;
uniform sampler2D contact_field : filter_linear, repeat_disable;
uniform vec2 contact_origin;
uniform vec2 contact_extent = vec2(1.);
uniform vec2 lake_center;
uniform float lake_level;
uniform bool lake_enabled = true;
varying vec3 world_position;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise21(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+1.),f.x),f.y);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec3 p=world_position;
	vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);
	vec3 w=pow(abs(n),vec3(4.)); w/=max(dot(w,vec3(1.)),.001);
	float broad=noise21(p.xz*.72+p.y*.17);
	vec3 rock=mix(vec3(.235,.255,.265),vec3(.32,.325,.30),broad);
	vec3 shading_n=n;
	if(detailed){
		vec4 x=texture(stone_detail_map,p.zy*.38);
		vec4 y=texture(stone_detail_map,p.xz*.38);
		vec4 z=texture(stone_detail_map,p.xy*.38);
		vec4 detail=x*w.x+y*w.y+z*w.z;
		vec3 mineral=texture(stone_mineral_map,p.zy*.27).rgb*w.x+texture(stone_mineral_map,p.xz*.27).rgb*w.y+texture(stone_mineral_map,p.xy*.27).rgb*w.z;
		rock*=vec3(.90)+mineral*.26;
		rock*=1.+(detail.r-.5)*.12;
		vec3 slope=vec3(0.,x.b-.5,x.g-.5)*w.x+vec3(y.g-.5,0.,y.b-.5)*w.y+vec3(z.g-.5,z.b-.5,0.)*w.z;
		shading_n=normalize(n-(slope-n*dot(slope,n))*.27);
	}
	float patches=noise21(p.xz*1.7)+noise21(p.xz*5.1)*.2;
	float cover=COLOR.r,local_soil=COLOR.g,wet=COLOR.b;
	if(use_contact_field){
		vec2 uv_contact=(p.xz-contact_origin)/contact_extent;
		vec4 field=texture(contact_field,uv_contact);
		float inside=step(0.,uv_contact.x)*step(0.,uv_contact.y)*step(uv_contact.x,1.)*step(uv_contact.y,1.);
		float depth=abs(field.r-p.y);
		cover=field.g*inside*(1.-smoothstep(.06,.28,depth))*smoothstep(.35,.82,n.y);
		local_soil=field.g*inside*(1.-smoothstep(.12,.48,depth))*smoothstep(-.5,.2,n.y);
		wet=lake_enabled?(1.-smoothstep(1.15,1.65,length(p.xz-lake_center)))*(1.-smoothstep(lake_level+.04,lake_level+.12,p.y)):0.;
		cover*=1.-wet;
	}
	float grass=clamp(cover+(patches-.55)*.25*cover,0.,1.);
	float soil=clamp(local_soil*(.30+noise21(p.xz*3.8)*.45),0.,1.);
	vec3 earth=mix(vec3(.24,.18,.105),vec3(.34,.27,.16),broad);
	vec3 green=mix(vec3(.19,.265,.065),vec3(.29,.355,.115),noise21(p.xz*.85));
	if(detailed) green*=1.+(texture(ground_detail_map,p.xz*.48).r-.5)*.13;
	vec3 color=mix(rock,earth,soil);
	color=mix(color,green,grass);
	color=mix(color,color*vec3(.65,.77,.75),wet*.52);
	ALBEDO=color;
	NORMAL=normalize((VIEW_MATRIX*vec4(mix(shading_n,n,grass),0.)).xyz);
	ROUGHNESS=.93; SPECULAR=.14;
}
