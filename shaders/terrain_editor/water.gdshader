shader_type spatial;
render_mode cull_disabled;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.0);
uniform vec2 shore_extent = vec2(1.0);
uniform vec3 water_shallow : source_color = vec3(.35,.51,.52);
uniform vec3 water_deep : source_color = vec3(.24,.36,.40);
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
}

void fragment() {
	vec2 p = world_position.xz;
	vec4 basin = texture(shore_field, (p-shore_origin)/shore_extent);
	// Actual bed depth remains authoritative. Bank distance shortens the
	// apparent path over the shallow margin without painting an edge/foam ring.
	float bed_depth = basin.g*4.0;
	float path_depth = bed_depth*mix(.08,1.0,smoothstep(.04,.55,basin.r));
	float absorption = 1.0-exp(-path_depth*1.65);
	vec3 color = mix(water_shallow,water_deep,absorption);
	mat2 turn = mat2(vec2(.80,.60),vec2(-.60,.80));
	mat2 fine_turn = mat2(vec2(.39,-.9208),vec2(.9208,.39));
	vec3 broad = height_gradient(p*.95+vec2(TIME*.055,-TIME*.043));
	vec3 small = height_gradient(turn*p*2.8+vec2(-TIME*.08,TIME*.061)+vec2(17.3,5.8));
	vec3 fine = height_gradient(fine_turn*p*6.4+vec2(TIME*.03,-TIME*.07)+vec2(2.1,31.7));
	vec2 slope = broad.yz*(.055*.95);
	slope += transpose(turn)*small.yz*(.020*2.8);
	slope += transpose(fine_turn)*fine.yz*(.004*6.4);
	slope *= 1.45*mix(.75,1.0,smoothstep(.08,.55,basin.r));
	// Faster short disturbances stay in connected receiving water. The same
	// published mask fades both aeration and slopes into the calm lake body.
	vec3 impact = height_gradient(p*4.1+vec2(TIME*.30,TIME*1.25)+vec2(41.2,7.3));
	slope += impact.yz*(.018*4.1)*basin.b;
	vec3 normal_world = normalize(vec3(-slope.x,1.0,-slope.y));
	NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	// Broken irregular wavelets carry pale sky light across the lake.
 vec2 ripple_p=p*vec2(2.5,5.5)+vec2(TIME*.08,-TIME*.11);
 vec3 ripple=height_gradient(ripple_p);
 float glint=smoothstep(.69,.76,ripple.x)*(1.0-smoothstep(.77,.84,ripple.x));
 glint*=smoothstep(.36,.70,small.x);
 float wave=glint*.12;
 ALBEDO = mix(color*(.90+broad.x*.20),vec3(.55,.70,.69),wave)+vec3(.008,.018,.019)*basin.b;
	METALLIC = 0.0;
	ROUGHNESS = .28+basin.b*.06;
	// Keep the existing dielectric BRDF and directional static sky radiance.
	SPECULAR = .40;
}
