extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func run()->void:
 var editor=load("res://scenes/terrain_editor.tscn").instantiate()
 root.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false)
 var props=editor.renderer.props
 var cottage:Node3D=props.entries[0].node
 check(cottage.scale.is_equal_approx(Vector3(1.05,.70,.82)*.65),"Cottage and attached architecture uniformly reduced to 65%")
 check(cottage.position.is_equal_approx(Vector3(-11,3.5,-7)),"Cottage retains terrain contact and location")
 var heights:Array[float]=[]
 var deco=editor.renderer.decoration
 for chunk in editor.renderer.chunks:
  for pose:Transform3D in deco.placements(editor.data,chunk).tree:
   var low:=INF;var high:=-INF
   for v:Vector3 in deco.assets.tree[0].mesh.get_faces():
    var y:float=(pose*v).y
    low=minf(low,y);high=maxf(high,y)
   heights.append(high-low)
   var ground:Dictionary=editor.renderer.contours.surface_at(Vector2(pose.origin.x,pose.origin.z))
   check(absf(low-ground.height)<.001,"Tree measured from its own terrain contact")
 heights.sort()
 check(heights.size()==4 and heights[-1]/heights[0]<1.10,"Four mature trees within 10% world height")
 var rows:Array=[]
 for entry:Dictionary in props.entries:
  if str(entry.node.name).begins_with("KitchenGardenRow"):
   rows.append(entry)
   check(entry.node.visible,"Each crop row supported on dry upper terrace")
   check(entry.node.position.x-entry.footprint.x> -11+.55,"Garden leaves the entrance path clear")
 check(rows.size()==5,"Five kitchen garden rows")
 for top in [1.5,3.5]:
  for p in [Vector2.ZERO,Vector2(13,7),Vector2(-16,-3)]:
   var previous:float=-2.8+.18*sin(p.x*.43+p.y*.31)+.09*sin(p.x*.87-p.y*.57)
   var floor_y:float=Contours._shell_floor(p,top)
   var ratio:float=(top-floor_y)/(top-previous)
   check(ratio>=.78 and ratio<=.82,"Thick slab keeps 80% of the original underside depth, upper boundary anchored")
   var keel:float=Contours._keel_floor(p,top)
   check(keel<=floor_y and keel>=Contours.KEEL_LIMIT-.001,"Uneven keel hangs below the slab without passing the shell floor limit")
 check(Contours._shell_floor(Vector2.ZERO,-4)<=-4.5,"Minimum legal height retains supporting thickness")
 # Farm support uses the same editable field, including removal and undo.
 var row:Dictionary=rows[2]
 editor.data.begin_stroke();editor.data.apply_brush(row.at,.6,"contract",false,1.5,3);editor.data.end_stroke()
 editor.renderer.rebuild_all()
 check(not row.node.visible,"Unsupported crop row disappears after terrain removal")
 editor.data.undo();editor.renderer.rebuild_all()
 check(row.node.visible,"Undo restores supported crop row")
 check(editor.camera.rotation_degrees.is_equal_approx(Vector3(-27,16,0)),"Existing camera orientation retained")
 print("HOMESTEAD: %d/%d passed; tree heights=%s"%[checks-failures,checks,heights])
 editor.free()
 quit(1 if failures else 0)
