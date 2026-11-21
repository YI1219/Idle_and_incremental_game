shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Soft spray where a fall meets receiving water. Each instance is one camera-facing
// puff that rises, swells and fades on its own phase (INSTANCE_CUSTOM.x).
uniform vec3 mist_color : source_color = vec3(.92,.95,.94);
uniform float opacity = .20;
uniform float rise = .75;
uniform float cycle_seconds = 4.6;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
varying float life;
varying float seed;
varying float strength;
varying float waist_mode;

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
	waist_mode=step(.75,INSTANCE_CUSTOM.w);
	float apron_mode=step(.25,INSTANCE_CUSTOM.w)-waist_mode;
	life=fract(TIME/cycle_seconds+seed);
	float size=length(MODEL_MATRIX[0].xyz)*mix(.76+.54*life,.88+.24*sin(life*6.28318),waist_mode);
	vec3 origin=MODEL_MATRIX[3].xyz+vec3(0.0,rise*life*INSTANCE_CUSTOM.y*(1.0-waist_mode*.7)*(1.0-apron_mode*.78),0.0);
	mat4 facing=mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size*mix(1.0,.48,apron_mode),INV_VIEW_MATRIX[2]*size,vec4(origin,1.0));
	MODELVIEW_MATRIX=VIEW_MATRIX*facing;
}

void fragment(){
	vec2 c=UV*2.0-1.0;
	float puff=noise_mist(UV*3.0+vec2(seed*17.0,-TIME*.10))*.58+noise_mist(UV*6.4+vec2(TIME*.07,seed*9.0))*.42;
	float r=length(c)+(puff-.5)*.46;
	float body=pow(clamp(1.0-smoothstep(.06,.98,r),0.0,1.0),1.25);
	float waterfall_fade=smoothstep(0.0,.20,life)*(1.0-smoothstep(.42,1.0,life));
	float waist_fade=.78+.22*sin(life*6.28318);
	float fade=mix(waterfall_fade,waist_fade,waist_mode);
	// Soft contact with water, rock and curtain instead of hard card edges.
	float scene_depth=texture(depth_texture,SCREEN_UV).r;
	vec4 scene=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_depth,1.0);
	float contact_span=mix(.38,2.35,waist_mode);
	float contact=clamp((VERTEX.z-scene.z/scene.w)/contact_span,0.0,1.0);
	// Volumetric sunlit top-right cream rim + cool celadon-jade mist belly!
	float sun_rim=clamp(.52+.36*c.x-.34*c.y+(puff-.5)*.28,0.0,1.0);
	vec3 shadow_mist=mist_color*vec3(.76,.90,.92);
	vec3 sunlit_mist=mist_color*vec3(1.05,1.02,.97);
	ALBEDO=mix(shadow_mist,sunlit_mist,mix(sun_rim,.55,waist_mode));
	ALPHA=body*fade*contact*opacity*strength;
}
