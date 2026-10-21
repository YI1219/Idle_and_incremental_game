extends MultiMeshInstance3D
## Camera-facing spray puffs at each plunge published by ContourTerrain, plus
## a veil along each curtain's sides and foot so falls read as thick white
## water dissolving into spray. Falls off the island end in a mist cloud.
const PUFFS_PER_SPLASH := 7
const MAX_VEIL_PUFFS := 16
const END_PUFFS := 4

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

func sync(splashes:Array,veils:Array=[])->void:
	var puffs:Array=[]
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
			puffs.append([position,size,Color(float(puff)/PUFFS_PER_SPLASH+a*.1,lerpf(.6,1.3,b),1.0,0)])
	for veil:Dictionary in veils:
		var lip:Vector3=veil.lip
		var foot:Vector3=veil.foot
		var out:=Vector3(veil.out.x,0,veil.out.y)
		var tangent:=Vector3(out.z,0,-out.x)
		var width:float=veil.half_width
		var height:=lip.y-foot.y
		# External curtains fade out a few metres down; their cloud sits there.
		var reach:=minf(height,4.2) if veil.external else height
		var count:=clampi(int(reach*1.6+width*1.2),4,MAX_VEIL_PUFFS)
		for puff in count:
			var a:=_hash(lip,puff,4)
			var b:=_hash(lip,puff,5)
			var c:=_hash(lip,puff,6)
			var t:=lerpf(.30,1.0,sqrt(b))
			var drop:=reach*t
			var along:=lip.lerp(foot,drop/maxf(.001,height))
			# Most puffs gather at the ragged sides; the rest veil the face.
			var side:=(1.0 if a>.5 else -1.0)*lerpf(.75,1.15,c) if a<.25 or a>.5 else (a*8.0-3.0)*.6
			var position:=along+tangent*side*width+out*lerpf(.15,.45,c)
			var size:=lerpf(.7,1.3,c)*clampf(width/.62,.8,1.5)*lerpf(.8,1.3,t)
			var opacity:=lerpf(.60,1.0,t)
			# Negative rise: veil puffs drift down with the falling water.
			puffs.append([position,size,Color(a+c*.3,-lerpf(.4,.9,b),opacity,0)])
		if veil.external:
			# The free fall dissolves into a soft cloud where the sheet fades.
			for puff in END_PUFFS:
				var a:=_hash(foot,puff,7)
				var b:=_hash(foot,puff,8)
				var c:=_hash(foot,puff,9)
				var along:=lip.lerp(foot,reach*lerpf(.80,1.05,b)/maxf(.001,height))
				var position:=along+tangent*(a*2.0-1.0)*width*.8+out*lerpf(.10,.50,c)
				var size:=lerpf(1.7,2.6,c)*clampf(width/.62,.8,1.6)
				puffs.append([position,size,Color(a+b*.4,-lerpf(.3,.6,c),1.0,0)])
	multimesh.instance_count=puffs.size()
	var bounds:=AABB()
	for index in puffs.size():
		var position:Vector3=puffs[index][0]
		var size:float=puffs[index][1]
		multimesh.set_instance_transform(index,Transform3D(Basis.from_scale(Vector3.ONE*size),position))
		multimesh.set_instance_custom_data(index,puffs[index][2])
		var box:=AABB(position-Vector3.ONE*size*1.4-Vector3(0,1.4,0),Vector3.ONE*size*2.8+Vector3(0,2.8,0))
		bounds=box if index==0 else bounds.merge(box)
	custom_aabb=bounds

static func _hash(center:Vector3,puff:int,salt:int)->float:
	return fposmod(sin(center.x*12.9898+center.z*78.233+puff*37.719+salt*4.581)*43758.5453,1.0)
