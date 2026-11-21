shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
uniform float bank_stone = 0.0;
// 0.0 = chiseled garden/shore/Taihu stone, 1.0 = cliff rim_shelf, 2.0 = path flagstone, 3.0 = carved Song青白石 bench, 4.0 = rim-breaking headland crag boulder
uniform float prop_kind = 0.0;
varying vec3 rock_origin;
varying vec3 world_position;
varying vec3 v_facet_n;
varying float v_world_ny;

void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	rock_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	v_facet_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	v_world_ny=v_facet_n.y;
	if(terrain_morph_progress<1.0){
		vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;
	}
}

void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	vec3 material_normal=normalize(v_facet_n);
	// Delicate mineral paper micro-grain without blurring crisp chiseled facet ridges (整体细腻 + 强明暗交界):
	vec3 detail_n=stone_normal(world_position*2.25,material_normal);
	vec3 shade_n=normalize(mix(material_normal,detail_n,.075));
	vec3 variation=rock_hash(floor(rock_origin*1.37)+vec3(17.0,5.0,29.0));
	float h_rel=world_position.y-rock_origin.y;
	float wet=bank_stone*(1.0-smoothstep(.02,.15,h_rel));
	float cav=clamp(UV.y,0.0,.80);

	// Soft, calm watercolor block wash + fine mineral tooth (色块柔和 + 整体细腻):
	vec3 gouache_wash=stone_gouache(world_position*1.35,shade_n);
	vec3 brush_tint=clamp(gouache_wash/vec3(.46,.50,.46),vec3(.95),vec3(1.05));
	float micro_grain=stone_map(world_position*2.40,shade_n).r*.55+stone_noise(world_position*4.60+variation*3.1)*.45;
	float ridge_edge=clamp(length(fwidth(material_normal))*1.20,0.0,1.0);
	float sun_dir_dot=dot(shade_n,normalize(vec3(.88,.43,.11)));
	float away_sun=smoothstep(.14,-.52,sun_dir_dot);

	vec3 base_col;
	float base_ao=1.0;
	if(abs(prop_kind-4.0)<.4){
		// Rim-breaking headland crag boulder (3B): rich multi-facet crystalline crown + cliff-matched stone body
		// (avoids over-bright flat white top slabs while blending seamlessly into stacked cliff boulders!):
		float top_crown=smoothstep(.42,.88,shade_n.y);
		float under_face=smoothstep(-.10,-.62,shade_n.y);
		vec3 rock_under=mix(stone_shadow_color,stone_mid_color,.38)*vec3(.93,.96,1.06);
		vec3 rock_mid=mix(stone_mid_color,stone_lit_color,.24)*vec3(.99,.98,.96);
		vec3 rock_top=mix(stone_mid_color,stone_lit_color,.64)*vec3(1.03,.99,.93);
		base_col=mix(rock_mid,rock_top,top_crown);
		base_col=mix(base_col,rock_under,under_face*.52);
		vec3 mineral_shift=mix(vec3(.95,.97,1.03),vec3(1.04,1.01,.96),variation.x)*(.93+.12*variation.y);
		base_col*=mineral_shift*mix(vec3(1.0),brush_tint,.18)*(0.980+0.040*micro_grain);
		base_col*=clamp(COLOR.r/.708,.86,1.06);
		base_col+=base_col*ridge_edge*(.014+.028*smoothstep(.02,.64,sun_dir_dot)*top_crown);
		float crev=cav*(1.0-top_crown*.84);
		base_col*=mix(vec3(1.0),vec3(.72,.78,.91),crev*.85);
		base_col=stone_mist_dissolve(base_col,world_position,shade_n);
		base_ao=mix(1.0,.62,crev)*mix(.84,1.0,top_crown);
	}else if(abs(prop_kind-1.0)<.4){
		float facet_tint=clamp(COLOR.r/.61,.86,1.05);
		base_col=stone_surface(world_position,shade_n)*(.95+.04*variation.x)*facet_tint;
		base_col*=mix(vec3(1.0),vec3(.74,.80,.86),cav*.52);
		base_ao=mix(.78,1.0,smoothstep(-.04,.20,h_rel))*(1.0-cav*.38)*mix(1.0,.84,away_sun);
	}else if(abs(prop_kind-2.0)<.4){
		// Shared limestone pigment across the table and bevel. Scene light supplies the side shadow.
		float top_face=smoothstep(.38,.86,shade_n.y);
		vec3 rim_tone=mix(stone_mid_color,stone_lit_color,.18)*vec3(.90,.94,.98);
		vec3 top_tone=mix(stone_mid_color,stone_lit_color,.64)*vec3(.86,.84,.77);
		vec3 warm_jit=mix(vec3(.96,.98,1.02),vec3(1.04,1.01,.95),variation.x);
		base_col=mix(rim_tone,top_tone,top_face)*warm_jit*mix(vec3(1.0),brush_tint,.22);
		base_col*=clamp(COLOR.r/.52,.84,1.06)*(0.974+0.052*micro_grain);
		base_ao=mix(.76,1.0,smoothstep(-.01,.07,h_rel))*mix(.84,1.0,top_face);
	}else if(abs(prop_kind-3.0)<.4){
		// Carved Song-style celadon-limestone garden bench (宋式青白石琴榻)
		float top_slab=smoothstep(.36,.84,shade_n.y);
		vec3 leg_shadow=mix(stone_shadow_color,stone_mid_color,.32)*vec3(.96,.98,1.02);
		vec3 carved_mid=mix(stone_mid_color,stone_lit_color,.24)*vec3(1.00,1.00,.98);
		vec3 slab_lit=mix(stone_mid_color,stone_lit_color,.72)*vec3(.98,.96,.90);
		base_col=mix(carved_mid,slab_lit,top_slab);
		base_col=mix(base_col,leg_shadow,away_sun*(1.0-top_slab)*.48);
		base_col*=mix(vec3(1.0),brush_tint,.20)*clamp(COLOR.r/.62,.80,1.06)*(0.976+0.048*micro_grain);
		base_col*=mix(vec3(1.0),vec3(.74,.80,.84),cav*.50);
		float foot_moss=(1.0-smoothstep(.0,.10,h_rel))*smoothstep(.55,-.15,shade_n.y);
		base_col=mix(base_col,vec3(.095,.140,.072),foot_moss*.30);
		base_ao=mix(.72,1.0,smoothstep(.0,.16,h_rel))*(1.0-cav*.38)*mix(1.0,.82,away_sun*(1.0-top_slab));
	}else{
		// Pure local limestone pigment on garden boulders, shore stones & Taihu scholar rock (Tiny Glade / Dredge logic:
		// clean warm-cream crown + cool-grey base contact; lighting model drives crisp bright-top vs cool-shadow contrast!):
		float top_crown=smoothstep(.42,.88,shade_n.y);
		float under_face=smoothstep(-.08,-.60,shade_n.y);
		vec3 rock_under=mix(stone_shadow_color,stone_mid_color,.42)*vec3(.96,.98,1.02);
		vec3 rock_mid=mix(stone_mid_color,stone_lit_color,.24)*vec3(.98,.97,.95);
		vec3 rock_top=mix(stone_mid_color,stone_lit_color,.68)*vec3(1.03,.99,.93);

		base_col=mix(rock_mid,rock_top,top_crown);
		base_col=mix(base_col,rock_under,under_face*.48);

		vec3 mineral_shift=mix(vec3(.98,.99,1.01),vec3(1.02,1.00,.97),variation.x);
		base_col*=mineral_shift*mix(vec3(1.0),brush_tint,.18)*(0.980+0.040*micro_grain);
		base_col*=clamp(COLOR.r/.56,.86,1.04);
		base_col+=base_col*ridge_edge*(.012+.020*smoothstep(.05,.70,sun_dir_dot)*top_crown);

		// Grounded moss-turf base contact on lawn stones (pairs with SSIL & SSAO!):
		float moss_noise=stone_noise(world_position*1.8+vec3(4.2));
		float moss_skirt=(1.0-bank_stone)*(1.0-smoothstep(0.0,.09+.04*moss_noise,h_rel))*(1.0-top_crown*.85);
		vec3 moss_col=mix(vec3(.085,.124,.062),vec3(.132,.170,.085),moss_noise);
		base_col=mix(base_col,moss_col,clamp(moss_skirt*.28,0.0,.24));
		base_col*=mix(vec3(1.0),vec3(.78,.82,.86),cav*(1.0-top_crown*.80)*.36);
		base_ao=mix(.74,1.0,smoothstep(-.02,.15,h_rel))*(1.0-cav*(1.0-top_crown*.80)*.30);
	}

	ALBEDO=base_col*mix(vec3(1.0),vec3(.70,.75,.75),wet*(1.0-smoothstep(.45,.85,shade_n.y)*.68));
	ROUGHNESS=mix(.94,.52,wet);
	SPECULAR=mix(.02,.14,wet);
	AO=base_ao;
	NORMAL=normalize((VIEW_MATRIX*vec4(shade_n,0.0)).xyz);
}

void light(){
	stone_crisp_facet_light(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,LIGHT_IS_DIRECTIONAL,v_world_ny,DIFFUSE_LIGHT);
}
