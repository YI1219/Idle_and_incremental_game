shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
uniform vec4 water : source_color = vec4(0.42, 0.70, 0.68, 0.55);
uniform vec4 foam : source_color = vec4(0.86, 0.92, 0.90, 0.62);
uniform float scroll = 1.05;
varying vec2 uvv;

void vertex() {
	uvv = UV;
}

void fragment() {
	float flow = fract(uvv.y * 3.2 - TIME * scroll);
	float streak = smoothstep(0.14, 0.0, abs(fract(uvv.x * 6.0 + flow * 0.40) - 0.5));
	float head = smoothstep(0.22, 0.0, uvv.y);
	ALBEDO = mix(water.rgb, foam.rgb, clamp(head * 0.55 + streak * 0.25, 0.0, 1.0));
	ALPHA = mix(water.a, foam.a, head * 0.5) * (0.45 + streak * 0.25);
}
