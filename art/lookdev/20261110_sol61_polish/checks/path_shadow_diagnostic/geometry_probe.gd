extends SceneTree
## Characterization only. Measures the actual path mesh and placement code.
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:int=0
func _initialize()->void:
	var models:=Models.new()
	var mesh:Mesh=models._path_models()[0].mesh
	var arrays:Array=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var side_low:float=INF
	var side_high:float=-INF
	var outward_low:float=INF
	for i:int in vertices.size():
		if colors[i].r>.34:continue
		side_low=minf(side_low,normals[i].y)
		side_high=maxf(side_high,normals[i].y)
		outward_low=minf(outward_low,normals[i].dot(Vector3(vertices[i].x,0.0,vertices[i].z).normalized()))
	var data:=Data.new()
	data.make_preset(0)
	var reports:Array=[]
	for seed_value:int in [7301,2104,4242,913]:
		data.seed=seed_value
		var field:=Contours.new()
		field.refresh(data)
		var decor:=Decoration.new()
		var chunks:Dictionary={}
		for cell:Vector2i in data.cells:chunks[Data.chunk_of(cell)]=true
		var count:int=0
		var bottom_gap_low:float=INF
		var bottom_gap_high:float=-INF
		var top_gap_low:float=INF
		var top_gap_high:float=-INF
		var footprint_gap_low:float=INF
		var footprint_gap_high:float=-INF
		var footprint_checks:int=0
		for chunk:Vector2i in chunks:
			var result:Dictionary={"path":[]}
			decor._path(result,field,chunk)
			for pose:Transform3D in result.path:
				count+=1
				var sample:Dictionary=field.surface_at(Vector2(pose.origin.x,pose.origin.z))
				var center_gap:float=pose.origin.y-float(sample.height)
				bottom_gap_low=minf(bottom_gap_low,center_gap+mesh.get_aabb().position.y)
				bottom_gap_high=maxf(bottom_gap_high,center_gap+mesh.get_aabb().position.y)
				top_gap_low=minf(top_gap_low,center_gap+mesh.get_aabb().end.y)
				top_gap_high=maxf(top_gap_high,center_gap+mesh.get_aabb().end.y)
				for vertex:Vector3 in vertices:
					if vertex.y>-.017:continue
					var point:Vector3=pose*vertex
					var support:Dictionary=field.surface_at(Vector2(point.x,point.z))
					if support.is_empty():continue
					var gap:float=point.y-float(support.height)
					footprint_gap_low=minf(footprint_gap_low,gap)
					footprint_gap_high=maxf(footprint_gap_high,gap)
					footprint_checks+=1
		reports.append({"seed":seed_value,"count":count,"bottom_vs_center_ground":[bottom_gap_low,bottom_gap_high],"top_vs_center_ground":[top_gap_low,top_gap_high],"bottom_ring_vs_terrain":[footprint_gap_low,footprint_gap_high],"bottom_ring_samples":footprint_checks})
		if count<1 or bottom_gap_high>=0.0:failures+=1
	if side_low<0.0 or outward_low<=0.0:failures+=1
	print("PATH_GEOMETRY ",JSON.stringify({"mesh_aabb":{"position":[mesh.get_aabb().position.x,mesh.get_aabb().position.y,mesh.get_aabb().position.z],"size":[mesh.get_aabb().size.x,mesh.get_aabb().size.y,mesh.get_aabb().size.z]},"vertices":vertices.size(),"side_normal_y":[side_low,side_high],"side_radial_dot_min":outward_low,"seeds":reports,"failures":failures,"art_accepted":false}))
	quit(1 if failures else 0)
