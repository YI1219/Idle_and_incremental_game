shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
uniform vec4 water : source_color = vec4(0.42, 0.72, 0.70, 0.78);
uniform vec4 foam : source_color = vec4(0.93, 0.96, 0.95, 0.92);
uniform float scroll = 0.85;
varying vec2 uvv;

void vertex() {
	uvv = UV;
}

void fragment() {
	float flow = fract(uvv.y * 2.4 - TIME * scroll);
	float streak = smoothstep(0.18, 0.0, abs(fract(uvv.x * 5.0 + flow * 0.35) - 0.5));
	float veil = 0.55 + streak * 0.45;
	float head = smoothstep(0.22, 0.0, uvv.y);
	ALBEDO = mix(water.rgb, foam.rgb, clamp(head + streak * 0.25, 0.0, 1.0));
	ALPHA = mix(water.a, foam.a, head) * veil;
}
