shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled,fog_disabled;
// Brush ghost: COLOR.r 0 = land being formed (jade), 1 = land being removed
// (pale veil); COLOR.g fades the skirt downward; COLOR.b marks the rim.
uniform vec3 form_color : source_color = vec3(.60,.93,.82);
uniform vec3 remove_color : source_color = vec3(.95,.90,.78);
uniform float committed = 0.0;
uniform float commit_phase = 0.0;
uniform float commit_alpha = 1.0;
varying vec2 world_xz;
void vertex(){
	world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
	float phase=smoothstep(0.0,1.0,commit_phase);
	float lift=mix(-.18*(1.0-phase),.12*phase,COLOR.r);
	VERTEX.y+=committed*lift;
}
void fragment(){
	float pulse=.86+.14*sin(TIME*3.6);
	vec3 color=mix(form_color,remove_color,COLOR.r);
	float rim=COLOR.b*COLOR.g;
	float flow=.5+.5*sin(dot(world_xz,vec2(1.2,.8))-TIME*3.2);
	float draft_alpha=(.16+.42*rim)*pulse;
	float release_alpha=.28+.17*flow+.2*rim;
	ALBEDO=color*(1.0+rim*.25+committed*flow*.12);
	ALPHA=clamp(mix(draft_alpha,release_alpha,committed)*mix(COLOR.g,1.0,1.0-COLOR.b)*commit_alpha,0.0,.7);
}
