shader_type sky;
// The offscreen sky already includes background fog, in linear HDR.
render_mode disable_fog;
#include "sky_surface.gdshaderinc"
uniform sampler2D background_color : filter_linear, repeat_disable;
void sky(){
 if(AT_CUBEMAP_PASS)COLOR=painted_sky(EYEDIR,true);
 else COLOR=texture(background_color,SCREEN_UV).rgb;
}
