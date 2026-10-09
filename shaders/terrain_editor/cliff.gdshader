shader_type spatial;
#include "land_palette.gdshaderinc"
render_mode cull_disabled;
#include "cliff_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
uniform float cover_relief = .55;
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
	vec3 color=cliff_gray(variation.x);
	// UV carries the cap height this rock rises to and whether the cap is dry.
	// A dry rim rounds over: the cap's own lawn runs onto the shoulder, then
	// a ragged moss fringe hangs down the face. Undersides stay bare rock.
	float below=UV.x-world_position.y;
	float dry=step(.5,UV.y);
	vec3 world_normal=(INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
	float facing=smoothstep(-.30,.10,world_normal.y);
	vec2 along=world_position.xz;
	float ragged=gc_noise(vec2(along.x+along.y,along.x-along.y)*1.7)*.65+gc_noise((along.x-along.y)*vec2(7.0,3.0))*.35;
	float moss=dry*facing*(1.0-smoothstep(.18+.45*ragged,.30+.75*ragged,below));
	vec3 moss_color=vec3(.40,.45,.27);
	color=mix(color,moss_color,moss*.78);
	float shoulder=dry*facing*(1.0-smoothstep(.10+.18*ragged,.28+.26*ragged,below));
	float footprint=length(fwidth(along))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	vec2 slope=vec2(0.0);
	vec3 lawn=color;
	// Most cliff fragments are bare rock; skip the lawn there.
	if(shoulder>0.0)lawn=ground_cover(along,detail,slope);
	ALBEDO=mix(color,lawn,shoulder);
	// The shoulder is lit like the cap, so the rim turns rather than folds.
	vec3 lawn_normal=normalize(vec3(-slope.x*cover_relief*detail,1.0,-slope.y*cover_relief*detail));
	NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(lawn_normal,0.0)).xyz,shoulder));
	ROUGHNESS=mix(.96,.95,shoulder);
	SPECULAR=mix(.15,.30,shoulder);
}
