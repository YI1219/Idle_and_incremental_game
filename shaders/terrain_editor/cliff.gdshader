shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec3 rock_hash(vec3 p){
	vec3 q=fract(p*vec3(.123,.117,.139));
	q+=dot(q,q.zxy+vec3(19.19));
	return fract(vec3((q.x+q.y)*q.z,(q.y+q.z)*q.x,(q.z+q.x)*q.y));
}
void fragment(){
	// One world-space rock field across the joined cliff volume. Broad facets
	// stay anchored through edits instead of exposing the mesh's height rows.
	vec3 p=world_position/vec3(2.2,1.8,2.2);
	vec3 cell=floor(p);vec3 f=fract(p);float nearest=10.0;vec3 selected=cell;
	for(int z=-1;z<=1;z++)for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec3 offset=vec3(float(x),float(y),float(z));
		vec3 delta=offset+rock_hash(cell+offset)*.72+.14-f;
		float d=dot(delta,delta);
		if(d<nearest){nearest=d;selected=cell+offset;}
	}
	vec3 variation=rock_hash(selected+vec3(17.0));
	vec3 perturb=(variation-.5)*.90;
	vec3 facet_normal=normalize(world_normal+perturb);
	NORMAL=normalize((VIEW_MATRIX*vec4(facet_normal,0.0)).xyz);
	vec3 gray=mix(vec3(.32,.345,.345),vec3(.49,.49,.435),variation.x);
	ALBEDO=gray;
	ROUGHNESS=.96;
	SPECULAR=.15;
}
