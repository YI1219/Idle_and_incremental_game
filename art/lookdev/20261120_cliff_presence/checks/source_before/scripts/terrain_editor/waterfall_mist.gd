extends MultiMeshInstance3D
## Camera-facing spray puffs at each plunge published by ContourTerrain, plus
## a veil along each curtain's sides and foot so falls read as thick white
## water dissolving into spray. Falls off the island end in a mist cloud.
const PUFFS_PER_SPLASH := 12
const MAX_VEIL_PUFFS := 4
const END_PUFFS := 6

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

func sync(splashes:Array,veils:Array=[],land_regions:Dictionary={})->void:
	var puffs:Array=[]
	for splash:Dictionary in splashes:
		var center:Vector3=splash.center
		var out:=Vector3(splash.out.x,0,splash.out.y)
		var tangent:=Vector3(out.z,0,-out.x)
		var width:float=splash.half_width
		var intensity:float=clampf(float(splash.get("intensity",1.0)),0.0,1.0)
		if intensity<=.001:continue
		for puff in PUFFS_PER_SPLASH:
			var a:=_hash(center,puff,1)
			var b:=_hash(center,puff,2)
			var c:=_hash(center,puff,3)
			# Small short-lived droplets launch from the actual receiving level.
			var position:=center+tangent*(a*2.0-1.0)*width*.80+out*lerpf(.02,.32,b)+Vector3.UP*lerpf(.035,.12,c)
			var size:=lerpf(.035,.09,c)*sqrt(intensity)
			puffs.append([position,size,Color(a,lerpf(.20,.65,b),intensity,2.0)])
		# A little spray stays local to impact, without an opaque cloud apron.
		for puff in 3:
			var a:=_hash(center,puff,10)
			var b:=_hash(center,puff,11)
			var position:=center+tangent*(a*2.0-1.0)*width*.6+Vector3.UP*.07
			puffs.append([position,lerpf(.22,.38,b),Color(a,.18,intensity*.42,0.0)])
	for veil:Dictionary in veils:
		var lip:Vector3=veil.lip
		var foot:Vector3=veil.foot
		var out:=Vector3(veil.out.x,0,veil.out.y)
		var tangent:=Vector3(out.z,0,-out.x)
		var width:float=veil.half_width
		var height:=lip.y-foot.y
		# Place spray against the same complete lip-to-foot span as the curtain.
		var reach:=height
		var intensity:float=clampf(float(veil.get("intensity",1.0)),0.0,1.0)
		if intensity<=.001:continue
		var count:=4 if veil.external else 0
		for puff in count:
			var a:=_hash(lip,puff,4)
			var b:=_hash(lip,puff,5)
			var c:=_hash(lip,puff,6)
			var t:=lerpf(.66,.98,b) if veil.external else lerpf(.78,.99,b)
			var drop:=reach*t
			var along:=lip.lerp(foot,drop/maxf(.001,height))
			var side:=(a*2.0-1.0)*(.62 if veil.external else .52)
			var position:=along+tangent*side*minf(width,1.10)+out*lerpf(.12,.32,c)
			var size:=lerpf(.78,1.18,c)*clampf(minf(width,1.10)/.62,.80,1.30)
			puffs.append([position,size,Color(a+c*.3,-lerpf(.28,.55,b),(.68 if veil.external else .58)*intensity,0)])
		if veil.external:
			# Terminal wisps follow the curtain fade instead of masking its middle.
			for puff in END_PUFFS:
				var a:=_hash(foot,puff,7)
				var b:=_hash(foot,puff,8)
				var c:=_hash(foot,puff,9)
				var along:=lip.lerp(foot,reach*lerpf(.80,1.00,b)/maxf(.001,height))
				var position:=along+tangent*(a*2.0-1.0)*width*.76+out*lerpf(.08,.44,c)
				var size:=lerpf(1.04,1.52,c)*clampf(width/.62,.82,1.30)
				puffs.append([position,size,Color(a+b*.4,-lerpf(.22,.48,c),.84*intensity,0)])
	# Subtle deep root-tip cloud wisps under shadowed cliff keels without washing out solid front cliffs (Ref 1)
	if not land_regions.is_empty():
		var all_loops:Array=[]
		for lvl_k in land_regions:
			for lp:PackedVector2Array in land_regions[lvl_k]:
				if lp.size()>=4:all_loops.append(lp)
		for lvl_h:float in land_regions:
			for loop:PackedVector2Array in land_regions[lvl_h]:
				if loop.size()<8:continue
				var step_i:=maxi(4,loop.size()/14)
				var idx:=0
				while idx<loop.size():
					var p2:Vector2=loop[idx]
					var prev2:Vector2=loop[(idx-1+loop.size())%loop.size()]
					var next2:Vector2=loop[(idx+1)%loop.size()]
					var out2:=Vector2(next2.y-prev2.y,prev2.x-next2.x).normalized()
					var probe:=p2+out2*1.75
					var interior:=false
					for other_lp:PackedVector2Array in all_loops:
						if Geometry2D.is_point_in_polygon(probe,other_lp):
							interior=true
							break
					var sunlit_front:bool=(p2.x>-1.5 and p2.y>1.2)
					if not interior and not sunlit_front:
						var anchor:=Vector3(p2.x,lvl_h,p2.y)
						var ha:=_hash(anchor,idx,21)
						var hb:=_hash(anchor,idx,22)
						var hc:=_hash(anchor,idx,23)
						var pos:=Vector3(p2.x,-lerpf(3.85,5.15,hb),p2.y)+Vector3(out2.x,0.0,out2.y)*lerpf(-.35,.65,hc)
						var sz:=lerpf(3.6,5.2,ha)
						puffs.append([pos,sz,Color(ha,lerpf(.08,.18,hb),.68,1.0)])
					idx+=step_i
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
