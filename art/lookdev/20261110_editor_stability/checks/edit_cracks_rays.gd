extends "res://art/lookdev/20261110_editor_stability/checks/edit_cracks_probe.gd"
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")

func hits(origin:Vector3,direction:Vector3,vertices:PackedVector3Array,kind:String,field) -> Array:
	var result: Array = []
	for i:int in range(0,vertices.size(),3):
		var hit:Variant=Geometry3D.ray_intersects_triangle(origin,direction,vertices[i],vertices[i+1],vertices[i+2])
		if hit==null:continue
		var p:Vector3=hit
		result.append({"kind":kind,"i":i,"distance":origin.distance_to(p),"point":str(p),"point_vector":[p.x,p.y,p.z],"surface":str(field.surface_at(Vector2(p.x,p.z))),"a":str(vertices[i]),"b":str(vertices[i+1]),"c":str(vertices[i+2])})
	return result

func run() -> void:
	var data=Data.new()
	data.deserialize(JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("edit_cracks_fixture_04.json"))))
	var field=Field.new()
	field.refresh(data)
	var raw:PackedVector3Array=field.surfaces.cliff.vertices.duplicate()
	var decoration=Decoration.new()
	decoration.load_assets()
	decoration._column_layout(field,data.seed)
	var frame:=Basis.from_euler(Vector3(deg_to_rad(-55),deg_to_rad(196),0))
	var horizontal:float=8.0/tan(deg_to_rad(55))
	var origin:=Vector3(-8+sin(deg_to_rad(196))*horizontal,8,-5+cos(deg_to_rad(196))*horizontal)
	var report:Array=[]
	for pixel:Vector2 in [Vector2(1800,600),Vector2(1850,550),Vector2(1900,500),Vector2(2000,400),Vector2(1500,850),Vector2(2200,800)]:
		var scale:float=tan(deg_to_rad(31*.5))
		var direction:Vector3=frame*Vector3((pixel.x/2560*2-1)*(2560.0/1440)*scale,(1-pixel.y/1440*2)*scale,-1).normalized()
		var found:Array=[]
		found.append_array(hits(origin,direction,raw,"raw_cliff",field))
		for kind:String in ["cliff","stone_mantle","grass"]:found.append_array(hits(origin,direction,field.surfaces[kind].vertices,kind,field))
		for column:Dictionary in decoration._columns:
			var faces:PackedVector3Array=Geometry.faces_of(decoration.assets[column.kind][0].render_mesh)
			for i:int in faces.size():faces[i]=column.pose*faces[i]
			var column_hits:Array=hits(origin,direction,faces,column.kind,field)
			for hit:Dictionary in column_hits:
				hit.column=str(column)
				var p:Vector2=Vector2(hit.point_vector[0],hit.point_vector[2])
				hit.raw_upper_contains=Field.contains(field.land_regions[column.pose.origin.y],p)
				hit.rim_upper_contains=Field.contains(field.rim_regions[column.pose.origin.y],p)
				var cap:PackedVector2Array=decoration.assets[column.kind][0].cap_polygon
				var world_cap:=PackedVector2Array()
				for point:Vector2 in cap:
					var q:Vector3=column.pose*Vector3(point.x,0,point.y)
					world_cap.append(Vector2(q.x,q.z))
				hit.source_cap_contains=Geometry2D.is_point_in_polygon(p,world_cap)
			found.append_array(column_hits)
		found.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
		report.append({"pixel":str(pixel),"hits":found.slice(0,6)})
		print(pixel,found.slice(0,2))
	FileAccess.open(OUT.path_join("edit_cracks_rays.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()
