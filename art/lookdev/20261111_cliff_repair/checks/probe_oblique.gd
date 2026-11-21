extends "res://tests/interior_terrain_edit_test.gd"
func run() -> void:
	var data:=Data.new();data.make_preset(0)
	var field:=Field.new();field.refresh(data)
	var raw:PackedVector3Array=field.surfaces.cliff.vertices.duplicate()
	var deco:=Decoration.new();deco.load_assets();deco._column_layout(field,data.seed)
	var frame:=Basis.from_euler(Vector3(deg_to_rad(-32),deg_to_rad(65),0))
	var origin:=Vector3(11.4039564,10,14.7233057)
	for pixel:Vector2 in [Vector2(1310,420),Vector2(1320,460),Vector2(1320,500),Vector2(1320,540),Vector2(1340,480)]:
		var direction:Vector3=frame*Vector3((pixel.x/2560*2-1)*(2560.0/1440)*tan(deg_to_rad(15.5)),(1-pixel.y/1440*2)*tan(deg_to_rad(15.5)),-1).normalized()
		print("PIXEL ",pixel," raw ",first_hit(raw,origin,direction)," core ",first_hit(field.surfaces.cliff.vertices,origin,direction)," crown ",first_hit(column_faces(deco),origin,direction))
	for col:Dictionary in deco._columns:
		if col.edge.distance_to(Vector2(-3.1,7.96))<4:print("COL ",col)
	for height:float in field.land_regions:
		for loop:PackedVector2Array in field.land_regions[height]:
			for i:int in loop.size():
				var a:Vector2=loop[i];var b:Vector2=loop[(i+1)%loop.size()];var mid:Vector2=(a+b)*.5
				if mid.distance_to(Vector2(-3.1,7.96))>1.5:continue
				var direction:Vector2=(b-a).normalized();var outward:=Vector2(direction.y,-direction.x)
				var coverage:Array=[]
				for point:Vector2 in [a,a.lerp(b,.25),mid,a.lerp(b,.75),b]:
					var inside:=false
					for col:Dictionary in deco._columns:
						if absf(col.pose.origin.y-height)>.01:continue
						var polygon:=PackedVector2Array()
						for p:Vector2 in deco.assets[col.kind][0].cap_polygon:
							var q:Vector3=col.pose*Vector3(p.x,0,p.y);polygon.append(Vector2(q.x,q.z))
						if Geometry2D.is_point_in_polygon(point,polygon):inside=true
					coverage.append(inside)
				print("COVER ",coverage)
				print("SPAN ",height," ",a," ",b," upper ",field.surface_at(mid-outward*.25)," receiver ",field.surface_at(mid+outward*.3))
	quit()
