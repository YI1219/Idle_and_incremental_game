extends MultiMeshInstance3D
## Camera-facing spray puffs at each plunge published by ContourTerrain.
const PUFFS_PER_SPLASH := 7

func _init()->void:
	name="WaterfallMist"
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/waterfall_mist.gdshader")
	material.render_priority=1
	quad.material=material
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data=true
	multimesh.mesh=quad

func sync(splashes:Array)->void:
	multimesh.instance_count=splashes.size()*PUFFS_PER_SPLASH
	var bounds:=AABB()
	var index:=0
	for splash:Dictionary in splashes:
		var center:Vector3=splash.center
		var out:=Vector3(splash.out.x,0,splash.out.y)
		var tangent:=Vector3(out.z,0,-out.x)
		var width:float=splash.half_width
		for puff in PUFFS_PER_SPLASH:
			var a:=_hash(center,puff,1)
			var b:=_hash(center,puff,2)
			var c:=_hash(center,puff,3)
			# Puffs hug the curtain foot and drift a short way into the lake.
			var position:=center+tangent*(a*2.0-1.0)*width*.9+out*lerpf(-.25,.85,b)+Vector3(0,.15+.35*c,0)
			var size:=lerpf(1.0,1.9,c)*clampf(width/.62,.8,1.6)
			multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ONE*size),position))
			multimesh.set_instance_custom_data(index,Color(float(puff)/PUFFS_PER_SPLASH+a*.1,lerpf(.6,1.3,b),0,0))
			var box:=AABB(position-Vector3.ONE*size*1.4,Vector3.ONE*size*2.8+Vector3(0,1.4,0))
			bounds=box if index==0 else bounds.merge(box)
			index+=1
	custom_aabb=bounds

static func _hash(center:Vector3,puff:int,salt:int)->float:
	return fposmod(sin(center.x*12.9898+center.z*78.233+puff*37.719+salt*4.581)*43758.5453,1.0)
