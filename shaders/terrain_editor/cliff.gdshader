shader_type spatial;
render_mode cull_disabled;
#include "cliff_palette.gdshaderinc"
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	// One world-space rock field across the joined cliff volume. Broad facets
	// stay anchored through edits instead of exposing the mesh's height rows.
	vec3 p=world_position/vec3(2.2,1.8,2.2);
	vec3 cell=floor(p);vec3 f=fract(p);float nearest=10.0;vec3 selected=cell;vec3 local=vec3(0.0);
	for(int z=-1;z<=1;z++)for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec3 offset=vec3(float(x),float(y),float(z));
		vec3 delta=offset+rock_hash(cell+offset)*.72+.14-f;
		vec3 axis=abs(delta);
		float d=max(max(axis.x,max(axis.y,axis.z)),dot(axis,vec3(.57)));
		if(d<nearest){nearest=d;selected=cell+offset;local=-delta;}
	}
	vec3 variation=rock_hash(selected+vec3(17.0));
	// Three oblique planes split each rock into smaller angular faces. Their
	// coordinates are site-relative and world anchored, never screen dependent.
	vec3 face=step(vec3(0.0),vec3(dot(local,vec3(.78,.21,.58)),dot(local,vec3(-.42,.86,.29)),dot(local,vec3(.35,.38,-.85))));
	vec3 face_variation=rock_hash(selected+face*vec3(7.0,13.0,19.0)+vec3(31.0));
	vec3 perturb=(variation-.5)*.24+(face_variation-.5)*.20;
	// Let the rock faces dominate broad height-row curvature, keeping the
	// silhouette/picking mesh intact while reducing horizontal shading bands.
	vec3 planar_normal=normalize(vec3(world_normal.x,world_normal.y*.30,world_normal.z));
	vec3 facet_normal=normalize(planar_normal+perturb);
	NORMAL=normalize((VIEW_MATRIX*vec4(facet_normal,0.0)).xyz);
	vec3 gray=cliff_gray(variation.x);
	gray*=.94+.10*face_variation.y;
	ALBEDO=gray;
	ROUGHNESS=.96;
	SPECULAR=.15;
}
