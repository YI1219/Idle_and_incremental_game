shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled,fog_disabled;
// Brush ghost: COLOR.r 0 = land being formed (jade), 1 = land being removed
// (pale veil); COLOR.g fades the skirt downward; COLOR.b marks the rim.
uniform vec3 form_color : source_color = vec3(.60,.93,.82);
uniform vec3 remove_color : source_color = vec3(.95,.90,.78);
void fragment(){
	float pulse=.86+.14*sin(TIME*3.6);
	vec3 color=mix(form_color,remove_color,COLOR.r);
	float rim=COLOR.b*COLOR.g;
	ALBEDO=color*(1.0+rim*.25);
	ALPHA=clamp((.16+.42*rim)*mix(COLOR.g,1.0,1.0-COLOR.b)*pulse,0.0,.7);
}
