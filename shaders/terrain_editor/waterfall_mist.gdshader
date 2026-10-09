shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft spray where a fall meets receiving water. Each instance is one camera-facing
// puff that rises, swells and fades on its own phase (INSTANCE_CUSTOM.x).
uniform vec3 mist_color : source_color = vec3(.97,.95,.89);
uniform float opacity = .42;
uniform float rise = .9;
uniform float cycle_seconds = 4.2;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
varying float life;
varying float seed;
varying float strength;

float hash_mist(vec2 p){
	vec3 q=fract(vec3(p.xyx)*.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}

float noise_mist(vec2 p){
	vec2 i=floor(p); vec2 f=fract(p); vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash_mist(i),hash_mist(i+vec2(1,0)),u.x),mix(hash_mist(i+vec2(0,1)),hash_mist(i+vec2(1,1)),u.x),u.y);
}

void vertex(){
	seed=INSTANCE_CUSTOM.x;
	// Plunge puffs rise (positive y); curtain veil puffs drift down with the fall.
	strength=INSTANCE_CUSTOM.z;
	life=fract(TIME/cycle_seconds+seed);
	float size=length(MODEL_MATRIX[0].xyz)*(.70+.65*life);
	vec3 origin=MODEL_MATRIX[3].xyz+vec3(0.0,rise*life*INSTANCE_CUSTOM.y,0.0);
	mat4 facing=mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,vec4(origin,1.0));
	MODELVIEW_MATRIX=VIEW_MATRIX*facing;
}

void fragment(){
	vec2 c=UV*2.0-1.0;
	float puff=noise_mist(UV*3.2+vec2(seed*17.0,-TIME*.12))*.6+noise_mist(UV*6.5+vec2(TIME*.08,seed*9.0))*.4;
	float body=1.0-smoothstep(.15,1.0,length(c)+(puff-.5)*.55);
	float fade=smoothstep(0.0,.18,life)*(1.0-smoothstep(.45,1.0,life));
	// Soft contact with water, rock and curtain instead of hard card edges.
	float scene_depth=texture(depth_texture,SCREEN_UV).r;
	vec4 scene=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_depth,1.0);
	float contact=clamp((VERTEX.z-scene.z/scene.w)/.45,0.0,1.0);
	ALBEDO=mist_color;
	ALPHA=body*fade*contact*opacity*strength;
}
