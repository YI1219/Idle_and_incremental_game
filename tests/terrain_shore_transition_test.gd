extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const ShoreField=preload("res://scripts/terrain_editor/water_shore_field.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var data:=Data.new()
	data.make_preset(0)
	var field:=Contours.new()
	field.refresh(data)
	if not field.surfaces.has("shore") or field.surfaces.shore.vertices.is_empty():
		push_error("Gently supported grassy banks need a connected graded shore surface")
		quit(1);return
	var checked:=0
	var submerged:=false
	var above:=false
	var wet_crests:=0
	var visible_crests:=0
	for i in range(0,field.surfaces.shore.vertices.size(),3):
		var a:Vector3=field.surfaces.shore.vertices[i]
		var b:Vector3=field.surfaces.shore.vertices[i+1]
		var c:Vector3=field.surfaces.shore.vertices[i+2]
		if not a.is_finite() or not b.is_finite() or not c.is_finite():failures+=1
		if maxf(a.y,maxf(b.y,c.y))-minf(a.y,minf(b.y,c.y))>.5:failures+=1
		for point in [a,b,c]:
			var sample:=field.surface_at(Vector2(point.x,point.z))
			if sample.is_empty():failures+=1
			elif sample.water>=0:
				if point.y<sample.height:submerged=true
				else:
					wet_crests+=1
					if point.y>sample.height+.045:visible_crests+=1
			elif sample.water<0 and point.y>=sample.height:above=true
		checked+=1
	if not submerged or not above:failures+=1
	# The water is opaque at height + .045. Most scalloped bank tips
	# must actually protrude above it, not hide below the old straight edge.
	if wet_crests<10 or visible_crests<float(wet_crests)*.80:failures+=1
	print("VISIBLE SHORE CRESTS: ",visible_crests,"/",wet_crests)
	# At the actual water boundary the connecting bank must clear water too.
	# Otherwise a visible crest can become a detached offshore ribbon.
	var joins:=0
	for i in range(0,field.surfaces.shore.vertices.size(),3):
		var tri:Array=[]
		for j in 3:tri.append(field.surfaces.shore.vertices[i+j])
		for j in 3:
			var a:Vector3=tri[j];var b:Vector3=tri[(j+1)%3]
			for level:int in field.water_regions:
				for loop:PackedVector2Array in field.water_regions[level]:
					for k in loop.size():
						var hit=Geometry2D.segment_intersects_segment(Vector2(a.x,a.z),Vector2(b.x,b.z),loop[k],loop[(k+1)%loop.size()])
						if hit==null:continue
						var length:=Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
						if length<.00001:continue
						var t:float=Vector2(a.x,a.z).distance_to(hit)/length
						var y:=lerpf(a.y,b.y,t)
						if absf(y-level*.5)>.2:continue
						joins+=1
						if y<level*.5+.045-.001:failures+=1
	if joins<10:failures+=1
	print("CONNECTED SHORE JOINS: ",joins)

	# Published R follows actual smoothed water contours. G/B/A keep their
	# bed/connected-impact/wet meaning; tolerate only RGBA8 quantization.
	var curved:Dictionary=ShoreField.build(data,field)
	var raw:Dictionary=ShoreField.build(data)
	var image:Image=curved.texture.get_image()
	var original:Image=raw.texture.get_image()
	var bank_samples:=0
	for cell:Vector2i in data.cells:
		var level:int=data.cells[cell].water
		if level<0:continue
		var center:=Vector2(cell)+Vector2.ONE*.5
		var distance:=3.0
		for loop:PackedVector2Array in field.water_regions[level]:
			for j in loop.size():distance=minf(distance,center.distance_to(Geometry2D.get_closest_point_to_segment(center,loop[j],loop[(j+1)%loop.size()])))
		var pixel:Color=image.get_pixel(cell.x-int(curved.origin.x),cell.y-int(curved.origin.y))
		var before:Color=original.get_pixel(cell.x-int(raw.origin.x),cell.y-int(raw.origin.y))
		if absf(pixel.r*3.0-distance)>.013 or pixel.g!=before.g or pixel.b!=before.b or pixel.a!=before.a:failures+=1
		bank_samples+=1
	if bank_samples<100:failures+=1
	print("CURVED SHORE FIELD: ",bank_samples," actual contour-distance/depth/impact samples")
	# Removed land must not leave its shoreline as an independent decorative shell.
	data.cells.clear()
	data.revision+=1
	field.refresh(data)
	if not field.surfaces.shore.vertices.is_empty():failures+=1
	print("SHORE TRANSITION: %d triangles, wet/dry continuity %s/%s, %d failures"%[checked,submerged,above,failures])
	quit(1 if failures else 0)
