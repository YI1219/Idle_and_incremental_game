extends SceneTree
const OUT='res://art/work/cliff_art_patch/2026-10-18/'
const Probe=preload('res://tools/art/probe_cliff_manifold.gd')
func _initialize():call_deferred('run')
func run():
 # Diagnostic only: both cage/seated unions fail the finite geometry gate.
 var variant:String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else 'cage'
 var directory:String=OUT+'rejected_plane_fit/' if variant=='planes' else OUT
 var combined:=CSGCombiner3D.new();root.add_child(combined)
 for id in [36,37,38]:
  var mesh:=CSGMesh3D.new();mesh.mesh=Probe.mesh_from_points(Probe.read_points(directory+variant+'_'+str(id)+'.bin'));combined.add_child(mesh)
 await process_frame;combined._update_shape()
 var result:Array=combined.get_meshes();assert(result.size()==2)
 var points:=PackedVector3Array()
 for p:Vector3 in result[1].get_faces():points.append(result[0]*p)
 assert(not points.is_empty())
 FileAccess.open(directory+variant+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
 FileAccess.open(OUT+'baseline.bin',FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes('res://art/work/cliff_representation/2026-10-17/union.bin'))
 print('CLIFF ART UNION: ',points.size()/3,' triangles');quit()
