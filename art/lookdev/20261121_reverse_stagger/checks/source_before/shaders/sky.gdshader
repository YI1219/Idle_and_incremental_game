shader_type sky;
#include "sky_surface.gdshaderinc"
void sky(){COLOR=painted_sky(EYEDIR,AT_CUBEMAP_PASS);}
