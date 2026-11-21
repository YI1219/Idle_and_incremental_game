extends MeshInstance3D
## Immediate brush feedback while the terrain worker rebuilds the revision: a
## soft jade ghost (灵光) of the land a stroke will produce, and a pale veil over
## land it removes. It vanishes once the real terrain publishes and grows in.
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const SKIRT:=.85
var _key:=""
## Main-thread cost of the last rebuild of the ghost mesh.
var last_refresh_ms:=0.0

func _ready()->void:
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/edit_preview.gdshader")
	material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible=false

static func _top(record:Dictionary)->float:
	return record.water*.5 if record.water>=0 else float(record.height)

func refresh(data,renderer,blueprint:bool=false)->void:
	var shown=renderer._published_data
	if shown==null or (not blueprint and not renderer.has_pending_updates()):
		visible=false
		_key=""
		return
	var key:="%d|%d|%d"%[data.get_instance_id(),data.revision,shown.get_instance_id()]
	if key==_key:return
	_key=key
	var start:=Time.get_ticks_usec()
	var grown:Dictionary={}
	var removed:Dictionary={}
	for cell:Vector2i in data.cells:
		var top:=_top(data.cells[cell])
		var old:Variant=shown.cells.get(cell)
		if old!=null and absf(_top(old)-top)<.001:continue
		if old!=null and top<_top(old):
			var old_top:float=_top(old)
			if not removed.has(old_top):removed[old_top]={}
			removed[old_top][cell]=true
			continue
		if not grown.has(top):grown[top]={}
		grown[top][cell]=true
	for cell:Vector2i in shown.cells:
		if data.cells.has(cell):continue
		var top:=_top(shown.cells[cell])
		if not removed.has(top):removed[top]={}
		removed[top][cell]=true
	var surface:=Surface.new()
	for top:float in grown:_ghost(surface,grown[top],top,0.0)
	for top:float in removed:_ghost(surface,removed[top],top,1.0)
	visible=not surface.vertices.is_empty()
	mesh=surface.mesh() if visible else null
	last_refresh_ms=(Time.get_ticks_usec()-start)/1000.0

static func _ghost(surface,cells:Dictionary,top:float,kind:float)->void:
	# Same smoothed outline family as the real contour, so the ghost already
	# reads as the soft shape the island will take.
	for loop:PackedVector2Array in Contours._outlines(cells):
		if loop.size()<3 or Contours._area(loop)<=0.0:continue
		var y:=top+.04
		var indices:=Geometry2D.triangulate_polygon(loop)
		for i in range(0,indices.size(),3):
			for k in 3:
				var p:Vector2=loop[indices[i+k]]
				surface.vertices.append(Vector3(p.x,y,p.y));surface.normals.append(Vector3.UP)
				surface.colors.append(Color(kind,1.0,0.0,1.0));surface.uv.append(Vector2.ZERO)
		for e in loop.size():
			var a:Vector2=loop[e];var b:Vector2=loop[(e+1)%loop.size()]
			var quad:=[Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(b.x,y-SKIRT,b.y),Vector3(a.x,y-SKIRT,a.y)]
			var shade:=[Color(kind,1.0,1.0,1.0),Color(kind,1.0,1.0,1.0),Color(kind,0.0,1.0,1.0),Color(kind,0.0,1.0,1.0)]
			for k:int in [0,1,2,0,2,3]:
				surface.vertices.append(quad[k]);surface.normals.append(Vector3.UP)
				surface.colors.append(shade[k]);surface.uv.append(Vector2.ZERO)
