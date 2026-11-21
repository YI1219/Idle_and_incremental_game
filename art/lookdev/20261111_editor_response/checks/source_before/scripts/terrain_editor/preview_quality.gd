extends RefCounted
## Limit interactive 3D pixel work independently of the native UI resolution.
## Capture tools can explicitly request native rendering for exported stills.
const BUDGET:=Vector2(2560,1440)
var native:bool=false
var viewport:Viewport
var _native_msaa:int=Viewport.MSAA_DISABLED
var _last_size:=Vector2i.ZERO
var _last_native:bool=true
func configure(target:Viewport)->void:
	viewport=target
	_native_msaa=target.msaa_3d
	refresh()
func set_native(value:bool)->void:
	native=value
	refresh()
func refresh()->void:
	if not is_instance_valid(viewport):return
	var size:Vector2i
	if viewport is SubViewport:size=(viewport as SubViewport).size
	else:
		size=Vector2i(viewport.get_texture().get_size())
		if viewport is Window:
			var window_size:Vector2i=(viewport as Window).size
			size.x=maxi(size.x,window_size.x);size.y=maxi(size.y,window_size.y)
	if size==_last_size and native==_last_native:return
	_last_size=size;_last_native=native
	var scale:float=1.0 if native else minf(1.0,minf(BUDGET.x/maxf(size.x,1),BUDGET.y/maxf(size.y,1)))
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR if scale<.999 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale=maxf(.1,scale)
	viewport.msaa_3d=mini(_native_msaa,Viewport.MSAA_2X) if scale<.999 else _native_msaa
