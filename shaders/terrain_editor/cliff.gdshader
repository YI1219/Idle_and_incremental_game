shader_type spatial;
#include "land_palette.gdshaderinc"
render_mode cull_disabled;
#include "cliff_palette.gdshaderinc"
varying vec3 world_position;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
	// One world-space rock field across the joined cliff volume. Broad facets
	// stay anchored through edits instead of exposing the mesh's height rows.
	vec3 frame=vec3(world_position.x+world_position.y*.16,world_position.y+world_position.x*.28+world_position.z*.19,world_position.z-world_position.y*.12);
	vec3 p=frame/vec3(3.2,2.7,3.2);
	vec3 cell=floor(p);vec3 f=fract(p);float nearest=10.0;float second=10.0;vec3 selected=cell;vec3 local=vec3(0.0);
	for(int z=-1;z<=1;z++)for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec3 offset=vec3(float(x),float(y),float(z));
		vec3 delta=offset+rock_hash(cell+offset)*.72+.14-f;
		vec3 shape=rock_hash(cell+offset+vec3(31.0));
		float angle=(shape.z-.5)*1.1;
		vec3 rotated=vec3(delta.x*cos(angle)-delta.z*sin(angle),delta.y,delta.x*sin(angle)+delta.z*cos(angle));
		vec3 axis=abs(rotated)/(vec3(.85)+shape*.25);
		float d=max(max(axis.x,max(axis.y,axis.z)),dot(axis,vec3(.57)));
		if(d<nearest){second=nearest;nearest=d;selected=cell+offset;local=-delta;}
		else if(d<second){second=d;}
	}
	vec3 variation=rock_hash(selected+vec3(17.0));
	// The staggered render mesh now supplies the actual broad rock planes.
	// Keep its geometric normal and let real relief light the recesses.
	vec3 gray=cliff_gray(variation.x);
	// A few short turf lips join the flat cap to the same cliff mesh. The
	// published alpha describes true dry-cap proximity, never hidden ground.
	float patch=sin(world_position.x*.81+sin(world_position.z*.59)*1.7);
	float fringe=.5+.5*sin(world_position.x*9.3+world_position.z*7.1);
	float turf=smoothstep(.80+fringe*.09,.96,COLOR.a)*smoothstep(.05,.55,patch);
	float lawn=sin(world_position.x*.51+world_position.z*.22)*sin(world_position.z*.47-world_position.x*.18)*.5+.5;
	vec3 grass=mix(grass_base,grass_highlight,lawn);
	ALBEDO=mix(gray,grass,turf);
	ROUGHNESS=.96;
	SPECULAR=.15;
}
