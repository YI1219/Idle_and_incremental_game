"""Clip diagonal corner planes into retained integrated copies, never originals.
Study only: preserve the axis extrema of every runtime cap section so crown
normalization cannot turn a smaller cut into an enlarged lower spear.
"""
import bpy,bmesh,json,hashlib,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/cliff_corner_planes/2026-10-16'
REVIEW=ROOT/'art/review/terrain_fidelity/2026-10-16/corner_planes'
OUT.mkdir(parents=True,exist_ok=True)
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','v2']
reports=[]
for kind,stem,reference,cuts in [
 ('main','cliff_integrated_main_v1','cliff_main_v4',[(.78,-.62,.03,.13),(-.64,-.77,-.04,.10)]),
 ('tall','cliff_integrated_tall_v1','cliff_tall_v2',[(.72,-.69,-.02,.12),(-.77,-.64,.035,.075)])]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 def imported(name):
  before=set(bpy.context.scene.objects)
  bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/nature/refined'/(name+'.glb')))
  meshes=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH'];assert len(meshes)==1
  obj=meshes[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  return obj
 ref=imported(reference)
 reflo=min(v.co.z for v in ref.data.vertices);refhi=max(v.co.z for v in ref.data.vertices)
 bpy.data.objects.remove(ref,do_unlink=True)
 source=ROOT/'assets/nature/refined'/(stem+'.glb');source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
 obj=imported(stem);bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 bmesh.ops.dissolve_limit(bm,angle_limit=.001,verts=list(bm.verts),edges=list(bm.edges),delimit=set())
 low=Vector(tuple(min(v.co[k] for v in bm.verts) for k in range(3)))
 high=Vector(tuple(max(v.co[k] for v in bm.verts) for k in range(3)))
 size=high-low;center=(high+low)*.5
 fractions=[.62,.72,.86]
 def section(z):
  points=[]
  for edge in bm.edges:
   a,b=[v.co for v in edge.verts]
   if abs(a.z-z)<1e-7:points.append(a.copy())
   if (a.z-z)*(b.z-z)<0:points.append(a.lerp(b,(z-a.z)/(b.z-a.z)))
  assert points
  return points
 # Protect actual support points of the cap's x/y bounding box at all profiles.
 protected=[]
 for fraction in fractions:
  points=section(reflo+(refhi-reflo)*fraction)
  for axis in [0,1]:
   protected.extend([min(points,key=lambda p:p[axis]).copy(),max(points,key=lambda p:p[axis]).copy()])
 def normalized(p):return Vector(tuple((p[k]-center[k])/size[k] for k in range(3)))
 evidence=[]
 for nx,ny,nz,depth in cuts:
  n=Vector((nx,ny,nz)).normalized()
  old=max(n.dot(normalized(v.co)) for v in bm.verts)
  limit=max(old-depth,max(n.dot(normalized(p)) for p in protected)+.00005)
  normal=Vector(tuple(n[k]/size[k] for k in range(3)))
  point=center+normal*(limit/normal.length_squared)
  before=len(bm.faces)
  result=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-7,plane_co=point,plane_no=normal,clear_inner=False,clear_outer=True)
  boundary=[e for e in bm.edges if e.is_boundary]
  if boundary:bmesh.ops.holes_fill(bm,edges=boundary,sides=0)
  evidence.append({'normal':list(n),'requested_depth':depth,'actual_maximum_cut':old-limit,'faces_before':before,'faces_after':len(bm.faces)})
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
 if VERSION=='v2':
  # Runtime's general source merger discards extremely small triangles.
  # Collapse cut slivers on the actual source before export, rather than
  # accepting holes or loosening the runtime closure check.
  for cleanup in range(8):
   tiny_faces=[f for f in bm.faces if f.calc_area()<.00012]
   if not tiny_faces:break
   edges=set(min(f.edges,key=lambda e:e.calc_length()) for f in tiny_faces)
   bmesh.ops.collapse(bm,edges=list(edges),uvs=False)
   bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 bm.normal_update()
 bad=sum(not e.is_manifold for e in bm.edges);tiny=sum(f.calc_area()<1e-12 for f in bm.faces);volume=bm.calc_volume(signed=True)
 assert bad==tiny==0 and volume>0,(kind,bad,tiny,volume)
 count=len(bm.faces);bm.to_mesh(obj.data);bm.free();obj.data.update()
 for polygon in obj.data.polygons:polygon.use_smooth=False
 obj.name='Cliff_Corner_'+kind+'_'+VERSION
 blend=OUT/(obj.name+'.blend');glb=OUT/(obj.name+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(blend))
 bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT',export_cameras=False,export_lights=False)
 assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
 reports.append({'kind':kind,'source':str(source.relative_to(ROOT)),'source_sha256':source_hash,'reference':reference,'cuts':evidence,'triangles':count,'nonmanifold_edges':bad,'degenerate_faces':tiny,'volume':volume,'blend':str(blend.relative_to(ROOT)),'glb':str(glb.relative_to(ROOT)),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blender_version':bpy.app.version_string,'variant':VERSION,'cut_sliver_cleanup':VERSION=='v2','stage':'Unaccepted source-refinement study; actual Godot cap closure and scene comparison required.'})
(REVIEW/('source_'+VERSION+'.json')).write_text(json.dumps(reports,indent=2))
print('CORNER PLANE SOURCES:',json.dumps(reports))
