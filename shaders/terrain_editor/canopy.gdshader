shader_type spatial;
#include "terrain_morph.gdshaderinc"
// Soft mass shading for merged crowns, shrubs and cliff drapes. Vertex colour
// stays the authored sRGB tint. Leaf masses (green above red) lose their
// hard facet read; wood keeps a geometric trunk.
render_mode cull_disabled;
uniform float foliage_soft = 0.68;
uniform float foliage_belly = 0.32;
uniform float foliage_lift = 1.0;
varying float rise;
varying vec3 world_position;
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 pivot=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	rise=world.y-pivot.y;
	world_position=world;
	if(terrain_morph_progress<1.0){
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(pivot),0.0,0.0)).xyz;
	}
}
void fragment(){
	vec3 srgb=COLOR.rgb;
	vec3 color=mix(pow((srgb+vec3(.055))*(1.0/1.055),vec3(2.4)),srgb*(1.0/12.92),lessThan(srgb,vec3(.04045)));
	float leaf=smoothstep(0.0,.04,color.g-color.r);
	vec3 geo=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
	if(dot(geo,NORMAL)<0.0)geo=-geo;
	vec3 pivot=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	vec3 radial=normalize(world_position-pivot);
	vec3 radial_view=normalize((VIEW_MATRIX*vec4(radial,0.0)).xyz);
	vec3 up=normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);
	vec3 soft=normalize(mix(radial_view,up,.45));
	NORMAL=normalize(mix(geo,soft,foliage_soft*leaf));
	vec3 world_n=normalize((INV_VIEW_MATRIX*vec4(geo,0.0)).xyz);
	float under=1.0-smoothstep(-.2,.62,world_n.y);
	color*=mix(1.0,foliage_lift,leaf);
	float crown=smoothstep(-.2,1.2,rise);
	color=mix(color*vec3(.84,.92,.82),color*vec3(1.08,1.10,1.02),crown*leaf);
	float breath=sin(world_position.x*1.35+world_position.z*1.05)*.5+.5;
	float high=sin(world_position.x*.62-world_position.y*.4+world_position.z*.5)*.5+.5;
	color=mix(color,color*vec3(.82,1.14,.78),leaf*breath*.42);
	color=mix(color,color*vec3(1.08,1.04,.90),leaf*high*.20);
	color*=mix(1.0,1.0-foliage_belly,under*leaf);
	float contact=(1.0-smoothstep(0.0,.22,rise))*smoothstep(-.05,.02,rise);
	color*=mix(1.0,.76,contact*(1.0-leaf));
	color*=mix(1.0,.90,contact*leaf*.65);
	ALBEDO=color;
	ROUGHNESS=mix(.94,.86,leaf);
	SPECULAR=.04;
}
