shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.0);
uniform vec2 shore_extent = vec2(1.0);
uniform vec3 water_shallow : source_color = vec3(.40,.70,.69);
uniform vec3 water_deep : source_color = vec3(.14,.40,.45);
uniform vec3 bed_color : source_color = vec3(.50,.60,.52);
uniform vec3 bank_reflection : source_color = vec3(.20,.24,.15);
varying vec3 world_position;

float hash_water(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// A continuous height and its exact XZ derivatives. Unlike directional sine
// waves, its slopes cannot align a whole lake into equally spaced bands.
vec3 height_gradient(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f*f*(3.0-2.0*f);
	vec2 derivative = 6.0*f*(1.0-f);
	float a = hash_water(cell);
	float b = hash_water(cell+vec2(1.0,0.0));
	float c = hash_water(cell+vec2(0.0,1.0));
	float d = hash_water(cell+vec2(1.0,1.0));
	float cross_term = a-b-c+d;
	float height = a+(b-a)*blend.x+(c-a)*blend.y+cross_term*blend.x*blend.y;
	vec2 gradient = derivative*vec2(b-a+cross_term*blend.y,c-a+cross_term*blend.x);
	return vec3(height,gradient);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += terrain_morph_offset(world_position);
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 field_uv = (p-shore_origin)/shore_extent;
	vec4 basin = texture(shore_field, field_uv);
	// Actual bed depth remains authoritative. Bank distance shortens the
	// apparent path over the shallow margin without painting an edge/foam ring.
	float bed_depth = basin.g*4.0;
	float path_depth = bed_depth*mix(.08,1.0,smoothstep(.04,.55,basin.r));
	float absorption = 1.0-exp(-path_depth*1.45);
	mat2 turn = mat2(vec2(.80,.60),vec2(-.60,.80));
	mat2 fine_turn = mat2(vec2(.39,-.9208),vec2(.9208,.39));
	vec3 broad = height_gradient(p*.95+vec2(TIME*.055,-TIME*.043));
	vec3 small = height_gradient(turn*p*2.8+vec2(-TIME*.08,TIME*.061)+vec2(17.3,5.8));
	vec3 fine = height_gradient(fine_turn*p*6.4+vec2(TIME*.03,-TIME*.07)+vec2(2.1,31.7));
	// Stylised clarity: the bed tint and soft moving caustics show through
	// the shallow margin (no refraction pass; the lake stays opaque).
	vec3 caustic_a = height_gradient(p*1.9+vec2(TIME*.11,TIME*.07)+vec2(5.1,9.3));
	vec3 caustic_b = height_gradient(turn*p*2.3-vec2(TIME*.09,TIME*.05)+vec2(13.7,2.2));
	float caustic = smoothstep(.62,.95,1.0-abs(caustic_a.x-caustic_b.x)*2.2);
	vec3 bed = bed_color*(.88+caustic*.18);
	vec3 color = mix(mix(bed,water_shallow,.60),water_deep,absorption);
 // The shallowest centimetres expose a damp mineral bed; uneven caustics
 // interrupt the transition instead of outlining the pond with foam.
 float shallows=1.0-smoothstep(.005,.16+(broad.x-.5)*.05,basin.r);
 color=mix(color,bed*vec3(.80,.86,.78),shallows*.68);
	vec2 slope = broad.yz*(.055*.95);
	slope += transpose(turn)*small.yz*(.020*2.8);
	slope += transpose(fine_turn)*fine.yz*(.004*6.4);
	slope *= 1.45*mix(.75,1.0,smoothstep(.08,.55,basin.r));
	// Faster short disturbances stay in connected receiving water. The same
	// published mask fades both aeration and slopes into the calm lake body.
	vec3 impact = height_gradient(p*4.1+vec2(TIME*.30,TIME*1.25)+vec2(41.2,7.3));
	slope += impact.yz*(.026*4.1)*basin.b;
	vec3 normal_world = normalize(vec3(-slope.x,1.0,-slope.y));
	NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	// Broken irregular wavelets carry pale sky light across the lake.
	vec2 ripple_p=p*vec2(2.5,5.5)+vec2(TIME*.08,-TIME*.11);
	vec3 ripple=height_gradient(ripple_p);
	float glint=smoothstep(.69,.76,ripple.x)*(1.0-smoothstep(.77,.84,ripple.x));
	glint*=smoothstep(.36,.70,small.x);
	color = mix(color*(.92+broad.x*.16),vec3(.92,.88,.76),glint*.09);
	// Approximate reflection of the far bank: next to a shore that lies
	// beyond the water along the view, swap sky reflection for a dark
	// bank tone. The shore field gradient gives the bank's direction.
	vec2 texel = 1.0/shore_extent;
	float toward_lake_x = texture(shore_field, field_uv+vec2(texel.x,0.0)).r-texture(shore_field, field_uv-vec2(texel.x,0.0)).r;
	float toward_lake_z = texture(shore_field, field_uv+vec2(0.0,texel.y)).r-texture(shore_field, field_uv-vec2(0.0,texel.y)).r;
	vec2 view_xz = normalize(world_position.xz-CAMERA_POSITION_WORLD.xz);
	vec2 toward_lake = vec2(toward_lake_x,toward_lake_z);
	float far_bank = smoothstep(.0,.6,-dot(view_xz,toward_lake/max(length(toward_lake),.0001)));
	float bank_band = (1.0-smoothstep(.06,.38,basin.r))*far_bank*(1.0-basin.b);
	color = mix(color,bank_reflection,bank_band*.55);
	// Receiving water is aerated and paler around the plunge.
	color = mix(color,vec3(.76,.86,.86),basin.b*basin.b*.40);
	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = .20+basin.b*.10;
	// Dielectric BRDF with the warm sky radiance cubemap; bank band and
	// shallow margins reflect less sky so the bed and bank tones read.
	SPECULAR = mix(.50,.18,bank_band)*mix(.75,1.0,absorption);
}
