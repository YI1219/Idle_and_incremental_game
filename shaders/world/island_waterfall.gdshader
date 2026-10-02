shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
uniform vec4 water : source_color = vec4(0.58, 0.86, 0.84, 0.88);
uniform vec4 foam : source_color = vec4(0.97, 0.98, 0.97, 0.98);
uniform float scroll = 1.05;
varying vec2 uvv;

void vertex() {
	uvv = UV;
}

void fragment() {
	float flow = fract(uvv.y * 3.2 - TIME * scroll);
	float streak = smoothstep(0.16, 0.0, abs(fract(uvv.x * 7.0 + flow * 0.40) - 0.5));
	float streak2 = smoothstep(0.12, 0.0, abs(fract(uvv.x * 3.4 - flow * 0.22) - 0.5));
	float veil = 0.50 + streak * 0.50 + streak2 * 0.22;
	float head = smoothstep(0.28, 0.0, uvv.y);
	float foot = smoothstep(0.72, 1.0, uvv.y);
	float white = clamp(head * 1.15 + streak * 0.45 + foot * 0.35, 0.0, 1.0);
	ALBEDO = mix(water.rgb, foam.rgb, white);
	ALPHA = mix(water.a, foam.a, head) * veil;
	ALBEDO += foam.rgb * head * 0.25;
}
