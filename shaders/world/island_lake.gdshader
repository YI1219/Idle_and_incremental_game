shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;
uniform vec4 shallow : source_color = vec4(0.46, 0.82, 0.74, 0.62);
uniform vec4 deep : source_color = vec4(0.06, 0.36, 0.40, 0.90);
uniform vec4 foam_color : source_color = vec4(0.94, 0.97, 0.95, 0.80);
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
	float n2 = sin(p.x * 7.6 - p.y * 5.1 + TIME * 0.88);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.10, 0.80, depth));
	col += n1 * 0.018;
	float foam = (1.0 - smoothstep(0.0, 0.30, depth)) * (0.72 + n2 * 0.10);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.88));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	col = mix(col, vec3(0.78, 0.90, 0.88), fres * 0.28);
	ALBEDO = col;
	ALPHA = mix(0.42, deep.a, smoothstep(0.08, 0.70, depth));
	ROUGHNESS = mix(0.22, 0.08, depth);
	SPECULAR = 0.70;
	METALLIC = 0.06;
	EMISSION = col * (0.05 + foam * 0.10 + fres * 0.08);
	NORMAL = normalize(NORMAL + vec3(n1 * 0.045, 0.0, n2 * 0.035));
}
