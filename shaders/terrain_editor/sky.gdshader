shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float cloud_field(vec2 p){
	return noise(p)*.52+noise(p*2.03)*.25+noise(p*4.13)*.13+noise(p*8.3)*.065+noise(p*16.7)*.035;
}
void sky(){
	float h=EYEDIR.y;
	vec3 color=mix(vec3(.67,.84,.95),vec3(.35,.70,.90),smoothstep(-1.0,.6,h));
	vec2 p=EYEDIR.xz/(abs(h)+.25)*5.5;
	float volume=cloud_field(p);
	float cloud=smoothstep(.55,.66,volume);
	float light=clamp(.78+(cloud_field(p+vec2(-.1,.16))-volume)*3.5+(volume-.55)*1.5,.58,1.0);
	vec3 white=mix(vec3(.69,.80,.89),vec3(1.0,.99,.96),light);
	COLOR=mix(color,white,cloud*.96);
}
