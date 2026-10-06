shader_type spatial;
render_mode cull_disabled;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.0);
uniform vec2 shore_extent = vec2(1.0);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	vec4 basin = texture(shore_field, (p-shore_origin)/shore_extent);
	// The published field follows authoritative banks and bed height after edits.
	float bank = 1.0-smoothstep(.10, .55, basin.r);
	float depth = smoothstep(.0, 1.0, basin.g*4.0);
	vec3 color = mix(vec3(.026,.28,.44), vec3(.008,.16,.32), depth);
	color = mix(color, vec3(.050,.30,.31), bank*.30);
	// Continuous world-space slopes, with no cell/triangle color discontinuities.
	vec2 first = normalize(vec2(.92,.38));
	vec2 second = normalize(vec2(-.43,.90));
	float warp1 = dot(p,second)*.73-TIME*.23;
	float warp2 = dot(p,first)*.52;
	float phase1 = dot(p,first)*2.9 + sin(warp1)*.35-TIME*.65;
	float phase2 = dot(p,second)*4.7 + sin(warp2)*.25-TIME*.48;
	// Derivatives of the same mildly warped wave height, in world XZ.
	vec2 slope = (first*2.9+second*cos(warp1)*.2555)*cos(phase1)*.042;
	slope += (second*4.7+first*cos(warp2)*.13)*cos(phase2)*.014;
	slope += first*cos(dot(p,first)*13.0-TIME*.9)*.022;
	// Incoming drops disturb only nearby receiving water, including after edits.
	slope += second*cos(dot(p,second)*9.0-TIME*3.2)*basin.b*.075;
	vec3 normal_world = normalize(vec3(-slope.x,1.0,-slope.y));
	NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	// Restrained stylized absorption modulation; this is not scene reflection.
	ALBEDO = color*(1.0+.045*(sin(phase1)*.65+sin(phase2)*.35));
	METALLIC = 0.0;
	ROUGHNESS = .16 + basin.b*.06;
	// Godot's dielectric BRDF already includes angle-dependent reflectivity.
	SPECULAR = .30;
}
