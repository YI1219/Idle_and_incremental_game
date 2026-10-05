class_name WaterShoreField
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const SIDES=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
static func build(data:Data)->Dictionary:
	var wet:Dictionary={}
	var distance:Dictionary={}
	var queue:Array[Vector2i]=[]
	var lo:=Vector2i(1025,1025)
	var hi:=Vector2i(-1025,-1025)
	for cell:Vector2i in data.cells:
		if data.cells[cell].water<0:continue
		wet[cell]=int(data.cells[cell].water)
		lo=lo.min(cell);hi=hi.max(cell)
	for cell:Vector2i in wet:
		distance[cell]=3.0
		for side in SIDES:
			if wet.get(cell+side,-1)!=wet[cell]:
				distance[cell]=.5
				queue.append(cell)
				break
	# Only the shallow band needs propagation. A cursor avoids quadratic queue
	# removal, and coordinates stay in world cells across all render chunks.
	var cursor:=0
	while cursor<queue.size():
		var cell:=queue[cursor]
		cursor+=1
		var next:float=distance[cell]+1.0
		if next>=3.0:continue
		for side in SIDES:
			var neighbor:Vector2i=cell+side
			if wet.get(neighbor,-1)!=wet[cell] or distance[neighbor]<=next:continue
			distance[neighbor]=next
			queue.append(neighbor)
	if wet.is_empty():lo=Vector2i.ZERO;hi=Vector2i.ZERO
	else:lo-=Vector2i.ONE;hi+=Vector2i.ONE
	var size:=hi-lo+Vector2i.ONE
	var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for cell:Vector2i in wet:
		var bed:float=clampf((wet[cell]*.5-data.cells[cell].height)/4.0,0,1)
		image.set_pixel(cell.x-lo.x,cell.y-lo.y,Color(distance[cell]/3.0,bed,0,1))
	return {"texture":ImageTexture.create_from_image(image),"origin":Vector2(lo),"extent":Vector2(size)}
