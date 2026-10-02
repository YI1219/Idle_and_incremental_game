shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float ripple=sin(p.x*4.0+p.y*6.0+TIME*0.8)+sin(p.x*7.0-p.y*3.0-TIME*0.6);
 float glint=pow(max(0.0,sin(p.x*10.0+p.y*2.0+sin(p.y*6.0+TIME)*0.5)),22.0);
 ALBEDO=mix(vec3(0.10,0.32,0.30),vec3(0.22,0.48,0.43),ripple*0.12+0.5)+glint*0.032;
 NORMAL=normalize(NORMAL+vec3(sin(p.x*4.0+TIME*0.8)*0.065,sin(p.y*5.0-TIME*0.6)*0.04,0.0));
 ROUGHNESS=0.30; SPECULAR=0.55;
}
