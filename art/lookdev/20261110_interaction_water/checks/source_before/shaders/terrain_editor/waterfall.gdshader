shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Convert approximate metre-scale displacement to projected UV at this fragment.
uniform float refraction_strength : hint_range(0.0,.15) = .045;
uniform float flow_time = -1.0;
uniform vec3 sun_direction = vec3(.56,.43,.71);
varying vec3 world_position;

float hash_flow(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*.1031);
	q += dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}

float flow_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f*f*(3.0-2.0*f);
	float a = hash_flow(cell);
	float b = hash_flow(cell+vec2(1.0,0.0));
	float c = hash_flow(cell+vec2(0.0,1.0));
	float d = hash_flow(cell+vec2(1.0,1.0));
	return mix(mix(a,b,blend.x),mix(c,d,blend.x),blend.y);
}

// Stretched along the fall: strands are long and narrow, never a regular comb.
float strands(vec2 p) {
	return flow_noise(p)*.55+flow_noise(p*vec2(2.03,1.97)+vec2(7.1,3.3))*.30+flow_noise(p*vec2(4.1,3.9)+vec2(1.7,9.2))*.15;
}

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.y += terrain_morph_offset(world_position);
}

void fragment() {
	float time=flow_time<0.0?TIME:flow_time;
	bool is_core = COLOR.g>=.495;
	float drop_raw = is_core ? max(0.0,COLOR.g-.5) : COLOR.g;
	float drop = drop_raw*32.0;
	float inverse_width = COLOR.b/max(1.0-COLOR.b,.0001);
	bool connected = COLOR.b>.001;
	// External curtains encode their full lip-to-foot progress in alpha.
	bool free_fall = COLOR.a>=.495 && COLOR.a<.995;
	float free_progress = free_fall ? clamp((COLOR.a-.5)/.49,0.0,1.0) : 0.0;
	// Connected-run coordinates survive chunk clipping and curved outlets.
	float across = dot(world_position.xz,vec2(.80,.60));
	if (connected) {
		across = COLOR.r/max(inverse_width,.0001);
	}
	float receiver = connected ? (free_fall ? 0.0 : COLOR.a) : COLOR.r;
	float landing = smoothstep(.54,1.0,receiver/.4);
	float y = world_position.y;
	float accelerate = smoothstep(.08,1.15,drop);
	// Broad flow groups carry the fall, with finer threads kept subordinate.
	vec2 chute_uv = vec2(across*3.15,(y+time*1.10)*.24);
	vec2 slow = vec2(across*6.8,(y+time*1.55)*.30);
	vec2 fast = vec2(across*12.6,(y+time*2.75)*.24);
	float chute = strands(chute_uv+vec2(2.3,5.1));
	float sheet = strands(slow);
	float torrent = strands(fast+vec2(13.7,0.0));
	float body = mix(sheet,torrent,accelerate*.80);
	float fine = strands(vec2(across*18.0,(y+time*3.1)*.36)+vec2(3.1,17.0));
	float packets = flow_noise(vec2(across*5.2,(y+time*2.3)*.62)+vec2(5.0,1.0));

	// Unequal stream groups avoid a repeated fluted silhouette.
	float col_wave = flow_noise(vec2(across*2.6,4.3))*.70+flow_noise(vec2(across*6.3,9.1))*.30;
	float chute_crest = clamp(col_wave*.62+chute*.38,0.0,1.0);

	float lip = (1.0-smoothstep(.035,.28+.10*chute,drop))*smoothstep(0.0,.025,drop);
	float plunge = smoothstep(.72,1.0,receiver/.4);
	float ext_spray = free_fall ? smoothstep(.54,.84,free_progress)*(1.0-smoothstep(.88,1.0,free_progress)) : 0.0;
	float filament = chute_crest*.24+body*.48+fine*.28;

	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL);
	vec3 r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	float relief = body*.60+fine*.40;
	if(abs(determinant)>.00000001) {
		vec3 gradient = sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
		NORMAL = normalize(abs(determinant)*NORMAL-gradient*.005);
	}
	if (connected && abs(determinant)>.00000001) {
		vec3 across_gradient = sign(determinant)*(dFdx(COLOR.r)*r1+dFdy(COLOR.r)*r2);
		if (length(across_gradient)>.0000001) {
			vec3 side_direction = normalize(across_gradient);
			float wrap = (COLOR.r-.5)*2.0;
			// Let the same moving stream groups drive their shallow relief.
			float col_tilt = ((chute-.5)*.32+(sheet-.5)*.18)*(is_core ? .26 : .62);
			float total_lat = clamp(wrap*.42+col_tilt,-.78,.78);
			NORMAL = normalize(NORMAL*sqrt(max(.05,1.0-total_lat*total_lat))+side_direction*total_lat);
		}
	}
	vec3 world_n = normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	float sun_bevel = clamp(dot(world_n,normalize(sun_direction))*.5+.5,0.0,1.0);

	vec3 color;
	float white;
	float opacity;
	float side = 1.0;
	if (is_core) {
		// Recessed jade body behind the translucent moving ribbons.
		float core_foam = lip*.36+plunge*.48+ext_spray*.34+pow(smoothstep(.52,.86,chute*.6+body*.4),1.4)*.24;
		white = clamp(core_foam,0.0,.72);
		vec3 deep_jade = mix(vec3(.052,.232,.264),vec3(.138,.372,.392),clamp(chute*.6+body*.4,0.0,1.0));
		deep_jade = mix(deep_jade,vec3(.215,.455,.458),lip*.48+sun_bevel*.18);
		vec3 core_mist = mix(vec3(.46,.65,.67),vec3(.76,.85,.85),plunge*.5+lip*.3);
		color = mix(deep_jade,core_mist,white);
		if (connected) {
			float edge = min(COLOR.r,1.0-COLOR.r);
			float inset = clamp(.038*inverse_width,0.0,.085);
			float softness = clamp(.085*inverse_width,fwidth(edge)*1.5,.14);
			side = smoothstep(inset,inset+max(softness,.0001),edge);
		}
		float lip_join = smoothstep(0.0,.05,drop);
		// A dense inner body absorbs the hard silhouette of the backing wet wall.
		opacity = mix(.985,.995,clamp(chute*.5+body*.5+white*.35,0.0,1.0))*mix(.45,1.0,lip_join);
		opacity *= mix(1.0,.76,landing);
	} else {
		// The outer curtain separates broad pale ribbons and jade troughs.
		float thread_foam = pow(smoothstep(.30,.68,filament),.90)*(.46+.34*smoothstep(.26,.74,packets));
		float lip_foam = lip*(.34+.42*smoothstep(.22,.68,chute_crest*.6+body*.4))*(.45+.55*flow_noise(vec2(across*4.5,.4)));
		float plunge_foam = (plunge+ext_spray*.50)*(.48+.36*smoothstep(.20,.68,filament));
		white = clamp(max(thread_foam,lip_foam)+plunge_foam*.58,0.0,.76);
		vec3 water = mix(vec3(.062,.265,.302),vec3(.192,.455,.466),clamp(chute_crest*.55+body*.45,0.0,1.0));
		water = mix(water,vec3(.278,.525,.516),lip*.50+pow(sun_bevel,1.6)*.24);
		vec3 foam_shadow = vec3(.56,.73,.74);
		vec3 foam_sun = vec3(.90,.93,.91);
		vec3 foam = mix(foam_shadow,foam_sun,clamp(sun_bevel*.58+white*.32+lip*.20,0.0,1.0));
		color = mix(water,foam,white);
		if (connected) {
			float edge = min(COLOR.r,1.0-COLOR.r);
			float ragged = (fine-.5)*.045+(chute-.5)*.035;
			float inset = clamp((.010+ragged)*inverse_width,0.0,.045);
			float softness = clamp(.068*inverse_width,fwidth(edge)*1.5,.108);
			side = smoothstep(inset,inset+max(softness,.0001),edge);
		}
		float lip_join = smoothstep(0.0,.032,drop);
		opacity = mix(mix(.62,.80,chute_crest*.55+body*.45),.93,white)*mix(.66,1.0,lip_join);
		opacity *= mix(1.0,.72+.24*body,landing);
	}

	vec2 sample_uv=SCREEN_UV;
	if(refraction_strength>0.0){
		float projection_divisor=max(abs((PROJECTION_MATRIX*vec4(VERTEX,1.0)).w),.5);
		vec2 bend=vec2(body-.5,(fine-.5)*.30)*refraction_strength*vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1])*.46/projection_divisor;
		vec2 bent_uv=clamp(SCREEN_UV+bend,vec2(.001),vec2(.999));
		float depth=texture(depth_texture,bent_uv).r;
		vec4 behind_view=INV_PROJECTION_MATRIX*vec4(bent_uv*2.0-1.0,depth,1.0);
		if(depth<.00001 || behind_view.z/behind_view.w<VERTEX.z-.01)sample_uv=bent_uv;
	}
	// The opaque scene-color buffer switches from wet cliff to sky at the
	// backing mesh silhouette. Free falls keep that hard edge out of their
	// color, while the thin receiving curtain retains a little refraction.
	vec3 behind=min(texture(screen_texture,sample_uv).rgb,vec3(.34,.46,.45))*vec3(.62,.86,.88);
	float transmission=(is_core || free_fall ? 0.0 : .06)*(1.0-white*.85);
	ALBEDO=color*(1.0-transmission);
	EMISSION=behind*transmission+vec3(.018,.030,.031)*white+color*.028;
	// The free curtain is a dense water body until its terminal spray fade.
	// Keep the backing-cliff silhouette from showing through the outer fringe.
	if(free_fall)opacity=max(opacity,.99);
	ALPHA = opacity*side;
	if(free_fall){
		float tail=free_progress+(chute-.5)*.12+(fine-.5)*.04;
		ALPHA*=1.0-smoothstep(.66,.985,tail);
		// Every curtain reaches zero before its own terminal mesh row.
		ALPHA*=1.0-smoothstep(.92,.98,free_progress);
	}
	ROUGHNESS = mix(.46,.68,white);
	SPECULAR = .06;
}
