shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;
uniform vec4 shallow : source_color = vec4(0.16, 0.52, 0.50, 0.62);
uniform vec4 deep : source_color = vec4(0.04, 0.28, 0.34, 0.82);
uniform vec4 foam_color : source_color = vec4(0.78, 0.90, 0.86, 0.70);
varying vec3 world_pos;
varying float shore;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = COLOR.r;
}

void fragment() {
	float depth = clamp(shore, 0.0, 1.0);
	vec2 p = world_pos.xz;
	float n1 = sin(p.x * 3.2 + TIME * 0.52) + sin(p.y * 4.0 - TIME * 0.38);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.06, 0.70, depth));
	col += n1 * 0.012;
	float bright = 1.0 - smoothstep(0.04, 0.55, depth);
	col = mix(col, col * vec3(1.15, 1.22, 1.12), bright * 0.45);
	float seam = exp(-depth * 8.0);
	col *= 1.0 - seam * 0.42;
	float foam = (1.0 - smoothstep(0.0, 0.16, depth)) * 0.35;
	col = mix(col, foam_color.rgb, foam);
	ALBEDO = col;
	ALPHA = mix(0.48, 0.80, smoothstep(0.04, 0.60, depth));
	ROUGHNESS = mix(0.28, 0.12, depth);
	SPECULAR = 0.45;
}
