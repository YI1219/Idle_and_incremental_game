extends 'res://tests/terrain_shore_stone_contact_test.gd'
## Dry surface props must follow the real sculpted cap, including its edge.
## This independently samples the published source triangles, not SDF queries.
func run()->void:
 var data:=Data.new();data.make_preset(0);data.set_sculpt_base(true)
 if OS.get_cmdline_user_args().has('recess'):load('res://tools/art/author_unified_cliff_recess.gd').author(data)
 var initial:Dictionary=data.serialize();var deco:=Deco.new();deco.load_assets()
 # Exercise seating as well as removal using a real flat volume and real mesh.
 var flat:=Data.new()
 for z in range(-2,3):
  for x in range(-2,3):flat.cells[Vector2i(x,z)]={'height':3.5,'water':-1}
 flat.set_sculpt_base(true)
 var floor_field:=Field.new();floor_field.refresh(flat)
 var box:=BoxMesh.new();box.size=Vector3.ONE
 var fixture_pose:=Transform3D(Basis.IDENTITY,Vector3(0,3.8,0))
 var seated:Dictionary=load('res://scripts/terrain_editor/surface_stone_support.gd').seat(floor_field,box,fixture_pose)
 if seated.is_empty() or absf(seated.pose.origin.y-3.67)>.002:failures+=1
 var buried:=Transform3D(Basis.IDENTITY,Vector3(0,3.5,0))
 var retained:Dictionary=load('res://scripts/terrain_editor/surface_stone_support.gd').seat(floor_field,box,buried)
 if retained.is_empty() or retained.pose!=buried:failures+=1
 var unsupported:Dictionary=load('res://scripts/terrain_editor/surface_stone_support.gd').seat(floor_field,box,Transform3D(Basis.IDENTITY,Vector3(20,3.5,0)))
 if not unsupported.is_empty():failures+=1
 var submerged:Dictionary=load('res://scripts/terrain_editor/surface_stone_support.gd').seat(floor_field,box,Transform3D(Basis.IDENTITY,Vector3(0,4.8,0)))
 if not submerged.is_empty():failures+=1
 var reports:Array=[]
 for state in ['default','raise','contract']:
  data.deserialize(initial)
  if state!='default':data.begin_stroke();data.apply_brush(Vector2(-15.3,1.8),2.0,state,false,1.5,3);data.end_stroke()
  var field:=Field.new();field.refresh(data);deco.contours=field
  var chunks:Dictionary={};var count:=0;var before:=failures
  for cell in data.cells:chunks[Data.chunk_of(cell)]=true
  for chunk in chunks:
   for pose:Transform3D in deco.placements(data,chunk).surface_rock:
    count+=1
    var faces:PackedVector3Array=deco.assets.surface_rock[0].mesh.get_faces();var lo:=INF;var hi:=-INF
    for i in faces.size():faces[i]=pose*faces[i];lo=minf(lo,faces[i].y);hi=maxf(hi,faces[i].y)
    var section:=lo+(hi-lo)*.30
    var unique:Dictionary={}
    for i in range(0,faces.size(),3):
     for j in 3:
      var a:=faces[i+j];var b:=faces[i+(j+1)%3]
      if (a.y-section)*(b.y-section)>=0:continue
      var point:=a.lerp(b,(section-a.y)/(b.y-a.y));var at:=Vector2(point.x,point.z)
      var key:=at.snapped(Vector2.ONE*.001)
      if unique.has(key):continue
      unique[key]=true;checked+=1
      var ground:=ground_height(field,at,hi)
      var sample:Dictionary=field.surface_at(at)
      if ground==-INF or sample.is_empty() or sample.water>=0 or section>ground+.015:failures+=1
    if unique.is_empty():failures+=1
  if count<1:failures+=1
  reports.append({'state':state,'stones':count,'failures':failures-before})
 print('SURFACE STONE CONTACT: ',JSON.stringify({'states':reports,'probes':checked,'failures':failures}))
 quit(0 if failures==0 else 1)
